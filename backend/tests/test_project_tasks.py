from __future__ import annotations

from sqlalchemy import func, select

from app.db import SessionLocal
from app.models import Task, TaskEmployee

from test_api import TEST_SEED_SECRET, login_headers_for


MANAGER_EMAIL = "caio.martins@touchin.com"
EMPLOYEE_EMAIL = "joao.lima@touchin.com"


def _manager_headers(client):
    return login_headers_for(client, email=MANAGER_EMAIL, password=TEST_SEED_SECRET)


def _employee_headers(client):
    return login_headers_for(client, email=EMPLOYEE_EMAIL, password=TEST_SEED_SECRET)


def _assign_project_member(client, headers, project_id: str, employee_id: str) -> None:
    response = client.post(
        f"/api/v1/projects/{project_id}/members",
        headers=headers,
        json={"employeeId": employee_id},
    )
    assert response.status_code in {200, 201}, response.text


def _create_project(client, headers, *, name="Projeto Tasks", limit=2):
    response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={
            "name": name,
            "description": "Projeto para validar tarefas.",
            "taskEmployeeLimit": limit,
        },
    )
    assert response.status_code == 201
    return response.json()


def _create_task(
    client,
    headers,
    project_id,
    *,
    name="Implementar quadro",
    task_type="feature",
    parent_task_id=None,
):
    payload = {
        "name": name,
        "description": f"Descrição da tarefa {name}.",
        "type": task_type,
    }
    if parent_task_id is not None:
        payload["parentTaskId"] = parent_task_id
    response = client.post(
        f"/api/v1/projects/{project_id}/tasks",
        headers=headers,
        json=payload,
    )
    assert response.status_code == 201, response.text
    return response.json()


def test_manager_can_create_typed_tasks_and_employee_cannot(client):
    manager_headers = _manager_headers(client)
    employee_headers = _employee_headers(client)
    project = _create_project(client, manager_headers)

    created = _create_task(client, manager_headers, project["id"], task_type="feature")
    assert created["projectId"] == project["id"]
    assert created["name"] == "Implementar quadro"
    assert created["description"] == "Descrição da tarefa Implementar quadro."
    assert created["type"] == "feature"
    assert created["parentTaskId"] is None

    bug = _create_task(client, manager_headers, project["id"], name="Corrigir erro", task_type="bug")
    fetched_bug = client.get(
        f"/api/v1/projects/{project['id']}/tasks/{bug['id']}",
        headers=manager_headers,
    )
    assert fetched_bug.status_code == 200
    assert fetched_bug.json()["type"] == "bug"

    improvement = _create_task(
        client,
        manager_headers,
        project["id"],
        name="Melhorar fluxo",
        task_type="improvement",
    )
    assert improvement["type"] == "improvement"
    _assign_project_member(client, manager_headers, project["id"], "emp-04")

    denied = client.post(
        f"/api/v1/projects/{project['id']}/tasks",
        headers=employee_headers,
        json={
            "name": "Tarefa sem permissão",
            "description": "Funcionário não gestor não pode criar.",
            "type": "bug",
        },
    )
    assert denied.status_code == 403

    denied_update = client.put(
        f"/api/v1/projects/{project['id']}/tasks/{created['id']}",
        headers=employee_headers,
        json={
            "name": "Tarefa sem permissão",
            "description": "Funcionário não gestor não pode gerenciar.",
            "type": "bug",
        },
    )
    assert denied_update.status_code == 403

    listed = client.get(f"/api/v1/projects/{project['id']}/tasks", headers=employee_headers)
    assert listed.status_code == 200
    assert {item["id"] for item in listed.json()} == {created["id"], bug["id"], improvement["id"]}


def test_task_requires_non_empty_name_description_and_valid_type(client):
    headers = _manager_headers(client)
    project = _create_project(client, headers)
    endpoint = f"/api/v1/projects/{project['id']}/tasks"

    for payload in (
        {"description": "Descrição válida", "type": "feature"},
        {"name": "   ", "description": "Descrição válida", "type": "feature"},
        {"name": "Nome válido", "type": "feature"},
        {"name": "Nome válido", "description": "   ", "type": "feature"},
        {"name": "Nome válido", "description": "Descrição válida", "type": "unknown"},
    ):
        response = client.post(endpoint, headers=headers, json=payload)
        assert response.status_code == 422, response.text


def test_task_hierarchy_persists_and_rejects_invalid_relationships(client):
    headers = _manager_headers(client)
    project = _create_project(client, headers, name="Projeto A")
    other_project = _create_project(client, headers, name="Projeto B")
    parent = _create_task(client, headers, project["id"], name="Pai")
    child = _create_task(
        client,
        headers,
        project["id"],
        name="Filha",
        task_type="improvement",
        parent_task_id=parent["id"],
    )
    grandchild = _create_task(
        client,
        headers,
        project["id"],
        name="Neta",
        parent_task_id=child["id"],
    )
    foreign_parent = _create_task(client, headers, other_project["id"], name="Outro projeto")

    fetched = client.get(
        f"/api/v1/projects/{project['id']}/tasks/{child['id']}",
        headers=headers,
    )
    assert fetched.status_code == 200
    assert fetched.json()["parentTaskId"] == parent["id"]
    assert fetched.json()["type"] == "improvement"

    self_parent = client.put(
        f"/api/v1/projects/{project['id']}/tasks/{parent['id']}",
        headers=headers,
        json={
            "name": "Pai",
            "description": "Descrição atualizada.",
            "type": "feature",
            "parentTaskId": parent["id"],
        },
    )
    assert self_parent.status_code == 400

    cross_project = client.put(
        f"/api/v1/projects/{project['id']}/tasks/{parent['id']}",
        headers=headers,
        json={
            "name": "Pai",
            "description": "Descrição atualizada.",
            "type": "feature",
            "parentTaskId": foreign_parent["id"],
        },
    )
    assert cross_project.status_code == 400

    cycle = client.put(
        f"/api/v1/projects/{project['id']}/tasks/{parent['id']}",
        headers=headers,
        json={
            "name": "Pai",
            "description": "Descrição atualizada.",
            "type": "feature",
            "parentTaskId": child["id"],
        },
    )
    assert cycle.status_code == 409

    indirect_cycle = client.put(
        f"/api/v1/projects/{project['id']}/tasks/{parent['id']}",
        headers=headers,
        json={
            "name": "Pai",
            "description": "Descrição atualizada.",
            "type": "feature",
            "parentTaskId": grandchild["id"],
        },
    )
    assert indirect_cycle.status_code == 409


def test_employee_can_join_leave_and_manager_can_manage_other_task_members_with_capacity(client):
    manager_headers = _manager_headers(client)
    employee_headers = _employee_headers(client)
    project = _create_project(client, manager_headers, limit=2)
    for employee_id in ("emp-03", "emp-04", "emp-05"):
        _assign_project_member(client, manager_headers, project["id"], employee_id)
    task = _create_task(client, manager_headers, project["id"])
    base = f"/api/v1/projects/{project['id']}/tasks/{task['id']}/members"

    joined = client.post(f"{base}/me", headers=employee_headers)
    assert joined.status_code == 201
    assert joined.json()["employeeId"] == "emp-04"

    duplicate_join = client.post(f"{base}/me", headers=employee_headers)
    assert duplicate_join.status_code == 200

    forbidden_add = client.post(base, headers=employee_headers, json={"employeeId": "emp-05"})
    assert forbidden_add.status_code == 403

    added_other = client.post(base, headers=manager_headers, json={"employeeId": "emp-05"})
    assert added_other.status_code == 201
    assert added_other.json()["employeeId"] == "emp-05"

    duplicate_other = client.post(base, headers=manager_headers, json={"employeeId": "emp-05"})
    assert duplicate_other.status_code == 200

    full = client.post(base, headers=manager_headers, json={"employeeId": "emp-03"})
    assert full.status_code == 409
    assert full.json()["detail"] == "Task employee capacity reached."

    members = client.get(base, headers=employee_headers)
    assert members.status_code == 200
    assert {item["employeeId"] for item in members.json()} == {"emp-04", "emp-05"}

    forbidden_remove = client.delete(f"{base}/emp-05", headers=employee_headers)
    assert forbidden_remove.status_code == 403

    removed_other = client.delete(f"{base}/emp-05", headers=manager_headers)
    assert removed_other.status_code == 204
    duplicate_remove_other = client.delete(f"{base}/emp-05", headers=manager_headers)
    assert duplicate_remove_other.status_code == 204

    newly_available = client.post(base, headers=manager_headers, json={"employeeId": "emp-03"})
    assert newly_available.status_code == 201

    left = client.delete(f"{base}/me", headers=employee_headers)
    assert left.status_code == 204
    duplicate_leave = client.delete(f"{base}/me", headers=employee_headers)
    assert duplicate_leave.status_code == 204

    with SessionLocal() as db:
        count = db.scalar(
            select(func.count()).select_from(TaskEmployee).where(TaskEmployee.task_id == task["id"]),
        )
        assert count == 1


def test_task_membership_rejects_unknown_employee_and_cross_project_task_lookup(client):
    manager_headers = _manager_headers(client)
    employee_headers = _employee_headers(client)
    project = _create_project(client, manager_headers)
    other_project = _create_project(client, manager_headers, name="Outro")
    _assign_project_member(client, manager_headers, project["id"], "emp-04")
    task = _create_task(client, manager_headers, project["id"])

    unknown = client.post(
        f"/api/v1/projects/{project['id']}/tasks/{task['id']}/members",
        headers=manager_headers,
        json={"employeeId": "missing"},
    )
    assert unknown.status_code == 404

    wrong_project = client.get(
        f"/api/v1/projects/{other_project['id']}/tasks/{task['id']}",
        headers=employee_headers,
    )
    assert wrong_project.status_code == 404



def test_task_membership_requires_project_access(client):
    manager_headers = _manager_headers(client)
    employee_headers = _employee_headers(client)
    project = _create_project(client, manager_headers, limit=2)
    task = _create_task(client, manager_headers, project["id"])
    base = f"/api/v1/projects/{project['id']}/tasks/{task['id']}/members"

    self_join = client.post(f"{base}/me", headers=employee_headers)
    assert self_join.status_code == 404

    _assign_project_member(client, manager_headers, project["id"], "emp-04")
    other_not_in_project = client.post(
        base,
        headers=manager_headers,
        json={"employeeId": "emp-05"},
    )
    assert other_not_in_project.status_code == 409
    assert other_not_in_project.json()["detail"] == "Employee is not assigned to this project."

    _assign_project_member(client, manager_headers, project["id"], "emp-05")
    accepted = client.post(
        base,
        headers=manager_headers,
        json={"employeeId": "emp-05"},
    )
    assert accepted.status_code == 201


def test_project_capacity_cannot_be_lowered_below_existing_task_members(client):
    manager_headers = _manager_headers(client)
    employee_headers = _employee_headers(client)
    project = _create_project(client, manager_headers, limit=2)
    for employee_id in ("emp-04", "emp-05"):
        _assign_project_member(client, manager_headers, project["id"], employee_id)
    task = _create_task(client, manager_headers, project["id"])
    base = f"/api/v1/projects/{project['id']}/tasks/{task['id']}/members"
    assert client.post(f"{base}/me", headers=employee_headers).status_code == 201
    assert (
        client.post(base, headers=manager_headers, json={"employeeId": "emp-05"}).status_code
        == 201
    )

    rejected = client.put(
        f"/api/v1/projects/{project['id']}",
        headers=manager_headers,
        json={
            "name": project["name"],
            "description": project["description"],
            "status": project["status"],
            "taskEmployeeLimit": 1,
        },
    )
    assert rejected.status_code == 409
    assert rejected.json()["detail"] == "Project task employee limit is below current task membership."

    accepted = client.put(
        f"/api/v1/projects/{project['id']}",
        headers=manager_headers,
        json={
            "name": project["name"],
            "description": project["description"],
            "status": project["status"],
            "taskEmployeeLimit": 2,
        },
    )
    assert accepted.status_code == 200
    assert accepted.json()["taskEmployeeLimit"] == 2


def test_task_fields_are_encrypted_at_rest(client):
    headers = _manager_headers(client)
    project = _create_project(client, headers)
    task = _create_task(client, headers, project["id"], name="Segredo operacional")

    with SessionLocal() as db:
        stored = db.get(Task, task["id"])
        assert stored is not None
        assert stored.name_ciphertext != "Segredo operacional"
        assert "Segredo" not in stored.name_ciphertext
        assert "Descrição" not in stored.description_ciphertext


def test_concurrent_task_membership_cannot_exceed_capacity(tmp_path):
    from concurrent.futures import ThreadPoolExecutor
    from threading import Barrier

    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker

    from app.db import Base
    from app.errors import DomainError, ErrorKind
    from app.schemas.project import ProjectDraftPayload
    from app.schemas.task import TaskDraftPayload
    from app.seed import seed_database
    from app.services.projects import assign_project_member, create_project
    from app.services.tasks import add_task_member, create_task

    engine = create_engine(
        f"sqlite:///{tmp_path / 'concurrency.db'}",
        future=True,
        connect_args={"timeout": 10},
    )
    LocalSession = sessionmaker(bind=engine, expire_on_commit=False)
    Base.metadata.create_all(bind=engine)
    with LocalSession() as db:
        seed_database(db)
        project = create_project(
            db,
            company_id="company-touchin",
            payload=ProjectDraftPayload(
                name="Concorrência",
                description="Validação de capacidade concorrente.",
                task_employee_limit=1,
            ),
        )
        for employee_id in ("emp-04", "emp-05"):
            assign_project_member(
                db,
                company_id="company-touchin",
                project_id=project.id,
                employee_id=employee_id,
            )
        task = create_task(
            db,
            company_id="company-touchin",
            project_id=project.id,
            payload=TaskDraftPayload(
                name="Slot único",
                description="Somente um funcionário pode entrar.",
                type="feature",
            ),
        )

    barrier = Barrier(2)

    def worker(employee_id: str) -> str:
        with LocalSession() as db:
            barrier.wait()
            try:
                add_task_member(
                    db,
                    company_id="company-touchin",
                    project_id=project.id,
                    task_id=task.id,
                    employee_id=employee_id,
                )
                return "created"
            except DomainError as exc:
                assert exc.kind is ErrorKind.conflict
                return "capacity"

    with ThreadPoolExecutor(max_workers=2) as executor:
        results = list(executor.map(worker, ["emp-04", "emp-05"]))

    assert sorted(results) == ["capacity", "created"]
    with LocalSession() as db:
        count = db.scalar(
            select(func.count()).select_from(TaskEmployee).where(TaskEmployee.task_id == task.id),
        )
        assert count == 1
