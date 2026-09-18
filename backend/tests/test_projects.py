from __future__ import annotations

from sqlalchemy import select, text

from app.db import SessionLocal
from app.models import Punch, TaskEmployee

from test_api import TEST_SEED_SECRET, login_headers, login_headers_for


def _create_project(client, headers, *, name: str = "Implantacao ERP") -> dict:
    response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={
            "name": name,
            "description": "Projeto de implantacao interna com equipe operacional.",
        },
    )
    assert response.status_code == 201
    return response.json()


def _clear_employee_punches(employee_id: str) -> None:
    with SessionLocal() as db:
        punches = db.scalars(select(Punch).where(Punch.employee_id == employee_id)).all()
        for punch in punches:
            db.delete(punch)
        db.commit()


def test_project_crud_encrypts_fields_and_soft_deletes(client):
    headers = login_headers(client)

    created = _create_project(client, headers)
    assert created["name"] == "Implantacao ERP"
    assert created["description"] == "Projeto de implantacao interna com equipe operacional."
    assert created["status"] == "active"

    with SessionLocal() as db:
        stored = db.execute(
            text(
                "select name_ciphertext, description_ciphertext "
                "from projects where id = :project_id",
            ),
            {"project_id": created["id"]},
        ).mappings().one()
        assert stored["name_ciphertext"] != "Implantacao ERP"
        assert "Implantacao" not in stored["name_ciphertext"]
        assert "implantacao interna" not in (stored["description_ciphertext"] or "")

    list_response = client.get("/api/v1/projects", headers=headers)
    assert list_response.status_code == 200
    assert [item["id"] for item in list_response.json()] == [created["id"]]

    update_response = client.put(
        f"/api/v1/projects/{created['id']}",
        headers=headers,
        json={
            "name": "Implantacao ERP - fase 2",
            "description": "Descrição obrigatória na fase 2.",
            "status": "inactive",
        },
    )
    assert update_response.status_code == 200
    assert update_response.json()["name"] == "Implantacao ERP - fase 2"
    assert update_response.json()["description"] == "Descrição obrigatória na fase 2."
    assert update_response.json()["status"] == "inactive"

    inactive_response = client.get("/api/v1/projects?status=inactive", headers=headers)
    assert inactive_response.status_code == 200
    assert [item["id"] for item in inactive_response.json()] == [created["id"]]

    patch_response = client.patch(
        f"/api/v1/projects/{created['id']}",
        headers=headers,
        json={
            "name": "Implantacao ERP - fase 3",
            "description": "Descricao ajustada via patch.",
            "status": "active",
        },
    )
    assert patch_response.status_code == 200
    assert patch_response.json()["name"] == "Implantacao ERP - fase 3"
    assert patch_response.json()["description"] == "Descricao ajustada via patch."
    assert patch_response.json()["status"] == "active"

    delete_response = client.delete(f"/api/v1/projects/{created['id']}", headers=headers)
    assert delete_response.status_code == 204

    get_response = client.get(f"/api/v1/projects/{created['id']}", headers=headers)
    assert get_response.status_code == 200
    assert get_response.json()["status"] == "inactive"


def test_project_member_assignment_and_employee_project_listing(client):
    headers = login_headers(client)
    project = _create_project(client, headers, name="App Operacional")

    assign_response = client.post(
        f"/api/v1/projects/{project['id']}/members",
        headers=headers,
        json={"employeeId": "emp-04"},
    )
    assert assign_response.status_code == 201
    member = assign_response.json()
    assert member["employeeId"] == "emp-04"
    assert member["projectId"] == project["id"]
    assert member["employeeName"] == "Joao Pedro Lima"

    duplicate_response = client.post(
        f"/api/v1/projects/{project['id']}/members",
        headers=headers,
        json={"employeeId": "emp-04"},
    )
    assert duplicate_response.status_code == 200

    members_response = client.get(f"/api/v1/projects/{project['id']}/members", headers=headers)
    assert members_response.status_code == 200
    assert [item["employeeId"] for item in members_response.json()] == ["emp-04"]

    employee_projects_response = client.get("/api/v1/employees/emp-04/projects", headers=headers)
    assert employee_projects_response.status_code == 200
    assert [item["id"] for item in employee_projects_response.json()] == [project["id"]]

    remove_response = client.delete(
        f"/api/v1/projects/{project['id']}/members/emp-04",
        headers=headers,
    )
    assert remove_response.status_code == 204
    with SessionLocal() as db:
        link = db.execute(
            text(
                "select 1 from employee_projects "
                "where employee_id = :employee_id and project_id = :project_id",
            ),
            {"employee_id": "emp-04", "project_id": project["id"]},
        ).first()
        assert link is None



def test_removing_project_member_revokes_task_assignments(client):
    admin_headers = login_headers(client)
    employee_headers = login_headers_for(
        client,
        email="joao.lima@bunchin.com",
        password=TEST_SEED_SECRET,
    )
    project = _create_project(client, admin_headers, name="Projeto revogável")
    assert client.post(
        f"/api/v1/projects/{project['id']}/members",
        headers=admin_headers,
        json={"employeeId": "emp-04"},
    ).status_code == 201
    task_response = client.post(
        f"/api/v1/projects/{project['id']}/tasks",
        headers=admin_headers,
        json={
            "name": "Responsabilidade temporária",
            "description": "Será removida com o acesso ao projeto.",
            "type": "feature",
        },
    )
    assert task_response.status_code == 201
    task = task_response.json()
    assert client.post(
        f"/api/v1/projects/{project['id']}/tasks/{task['id']}/members/me",
        headers=employee_headers,
    ).status_code == 201

    remove_response = client.delete(
        f"/api/v1/projects/{project['id']}/members/emp-04",
        headers=admin_headers,
    )
    assert remove_response.status_code == 204

    with SessionLocal() as db:
        task_link = db.scalar(
            select(TaskEmployee).where(
                TaskEmployee.task_id == task["id"],
                TaskEmployee.employee_id == "emp-04",
            ),
        )
        assert task_link is None

    project_response = client.get(
        f"/api/v1/projects/{project['id']}",
        headers=employee_headers,
    )
    assert project_response.status_code == 404


def test_employee_can_read_only_assigned_projects_and_cannot_create_projects(client):
    admin_headers = login_headers(client)
    employee_headers = login_headers_for(
        client,
        email="joao.lima@bunchin.com",
        password=TEST_SEED_SECRET,
    )
    assigned = _create_project(client, admin_headers, name="Projeto permitido")
    hidden = _create_project(client, admin_headers, name="Projeto oculto")
    assign_response = client.post(
        f"/api/v1/projects/{assigned['id']}/members",
        headers=admin_headers,
        json={"employeeId": "emp-04"},
    )
    assert assign_response.status_code == 201

    list_response = client.get("/api/v1/projects", headers=employee_headers)
    assert list_response.status_code == 200
    listed_ids = {item["id"] for item in list_response.json()}
    assert assigned["id"] in listed_ids
    assert hidden["id"] not in listed_ids

    allowed_get = client.get(f"/api/v1/projects/{assigned['id']}", headers=employee_headers)
    assert allowed_get.status_code == 200
    hidden_get = client.get(f"/api/v1/projects/{hidden['id']}", headers=employee_headers)
    assert hidden_get.status_code == 404

    create_response = client.post(
        "/api/v1/projects",
        headers=employee_headers,
        json={"name": "Projeto sem permissão", "description": "Descrição válida."},
    )
    assert create_response.status_code == 403


def test_punch_accepts_optional_project_only_when_employee_is_linked_to_active_project(client):
    admin_headers = login_headers(client)
    employee_headers = login_headers_for(
        client,
        email="joao.lima@bunchin.com",
        password=TEST_SEED_SECRET,
    )
    _clear_employee_punches("emp-04")

    active_project = _create_project(client, admin_headers, name="Projeto ativo")
    inactive_project = _create_project(client, admin_headers, name="Projeto inativo")
    inactive_response = client.put(
        f"/api/v1/projects/{inactive_project['id']}",
        headers=admin_headers,
        json={
            "name": inactive_project["name"],
            "description": inactive_project["description"],
            "status": "inactive",
        },
    )
    assert inactive_response.status_code == 200

    no_project_response = client.post(
        "/api/v1/time-clock/me/punches",
        headers=employee_headers,
        json={"type": "checkIn"},
    )
    assert no_project_response.status_code == 200
    assert no_project_response.json()["projectId"] is None
    _clear_employee_punches("emp-04")

    unlinked_response = client.post(
        "/api/v1/time-clock/me/punches",
        headers=employee_headers,
        json={"type": "checkIn", "projectId": active_project["id"]},
    )
    assert unlinked_response.status_code == 403

    client.post(
        f"/api/v1/projects/{active_project['id']}/members",
        headers=admin_headers,
        json={"employeeId": "emp-04"},
    )
    valid_response = client.post(
        "/api/v1/time-clock/me/punches",
        headers=employee_headers,
        json={"type": "checkIn", "projectId": active_project["id"]},
    )
    assert valid_response.status_code == 200
    assert valid_response.json()["projectId"] == active_project["id"]
    _clear_employee_punches("emp-04")

    client.post(
        f"/api/v1/projects/{inactive_project['id']}/members",
        headers=admin_headers,
        json={"employeeId": "emp-04"},
    )
    inactive_punch_response = client.post(
        "/api/v1/time-clock/me/punches",
        headers=employee_headers,
        json={"type": "checkIn", "projectId": inactive_project["id"]},
    )
    assert inactive_punch_response.status_code == 403

    missing_response = client.post(
        "/api/v1/time-clock/me/punches",
        headers=employee_headers,
        json={"type": "checkIn", "projectId": "missing-project"},
    )
    assert missing_response.status_code == 404


def test_project_requires_non_empty_name_and_valid_optional_description(client):
    headers = login_headers(client)

    for payload in (
        {"description": "Descrição válida."},
        {"name": "   ", "description": "Descrição válida."},
        {"name": "Projeto válido", "description": "   "},
        {"name": "Projeto válido", "description": "Descrição válida.", "taskEmployeeLimit": 0},
    ):
        response = client.post("/api/v1/projects", headers=headers, json=payload)
        assert response.status_code == 422, response.text


def test_project_task_employee_limit_defaults_for_legacy_clients(client):
    headers = login_headers(client)
    response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={
            "name": "Projeto compatível",
            "description": "Cliente antigo não envia o novo limite.",
        },
    )
    assert response.status_code == 201
    assert response.json()["taskEmployeeLimit"] == 1


def test_manager_can_manage_project_and_employee_cannot(client):
    manager_headers = login_headers_for(
        client,
        email="caio.martins@bunchin.com",
        password=TEST_SEED_SECRET,
    )
    employee_headers = login_headers_for(
        client,
        email="joao.lima@bunchin.com",
        password=TEST_SEED_SECRET,
    )
    project = _create_project(client, manager_headers, name="Gestão autorizada")

    manager_update = client.put(
        f"/api/v1/projects/{project['id']}",
        headers=manager_headers,
        json={
            "name": "Gestão atualizada",
            "description": "Alteração feita pelo gestor.",
            "taskEmployeeLimit": 3,
            "status": "active",
        },
    )
    assert manager_update.status_code == 200
    assert manager_update.json()["taskEmployeeLimit"] == 3

    compatibility_update = client.patch(
        f"/api/v1/projects/{project['id']}",
        headers=manager_headers,
        json={
            "name": "Gestão atualizada novamente",
            "description": "Cliente de atualização sem o novo campo.",
            "status": "active",
        },
    )
    assert compatibility_update.status_code == 200
    assert compatibility_update.json()["taskEmployeeLimit"] == 3

    employee_update = client.put(
        f"/api/v1/projects/{project['id']}",
        headers=employee_headers,
        json={
            "name": "Tentativa indevida",
            "description": "Funcionário não gestor.",
            "taskEmployeeLimit": 3,
            "status": "active",
        },
    )
    assert employee_update.status_code == 403

    employee_delete = client.delete(
        f"/api/v1/projects/{project['id']}",
        headers=employee_headers,
    )
    assert employee_delete.status_code == 403

    employee_assign = client.post(
        f"/api/v1/projects/{project['id']}/members",
        headers=employee_headers,
        json={"employeeId": "emp-05"},
    )
    assert employee_assign.status_code == 403


def test_project_description_remains_nullable_for_api_compatibility(client):
    headers = login_headers(client)

    create_response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={
            "name": "Projeto sem descrição",
            "description": None,
        },
    )
    assert create_response.status_code == 201, create_response.text
    created = create_response.json()
    assert created["description"] is None

    update_response = client.put(
        f"/api/v1/projects/{created['id']}",
        headers=headers,
        json={
            "name": "Projeto ainda sem descrição",
            "description": None,
            "status": "active",
        },
    )
    assert update_response.status_code == 200, update_response.text
    assert update_response.json()["description"] is None
