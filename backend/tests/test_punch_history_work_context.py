import pytest
from sqlalchemy import delete

from app.config import get_settings
from app.crypto import FieldCipher
from app.db import SessionLocal
from app.models import Employee, EmployeeProject, KanbanColumn, Project, Punch, Task, WorkLog
from app.seed import CAIO_EMAIL, COMPANY_ID, JOAO_EMAIL, MARINA_EMAIL

from test_audit import login_headers


ROOT = "/api/v1/time-clock"
TEAM_HISTORY = f"{ROOT}/employees/emp-04/punches"


@pytest.mark.parametrize("closing_type", ["breakStart", "checkOut"])
def test_employee_and_team_history_show_the_same_historical_tasks(client, closing_type):
    cipher = FieldCipher(get_settings().encryption_secret)
    with SessionLocal() as db:
        employee = db.get(Employee, "emp-04")
        employee.requires_location_on_punch = False
        employee.trusted_device_required = False
        db.execute(delete(Punch).where(Punch.employee_id == employee.id))
        project = Project(id="history-atlas", company_id=COMPANY_ID,
                          name_ciphertext=cipher.encrypt("Projeto Atlas"))
        updated_project = Project(id="history-horizon", company_id=COMPANY_ID,
                                  name_ciphertext=cipher.encrypt("Projeto Horizonte"))
        column = KanbanColumn(project=project, position=0,
                              name_ciphertext=cipher.encrypt("Em andamento"))
        tasks = [
            Task(id=f"history-task-{i}", project=project, kanban_column=column,
                 card_number=i, kanban_position=i, type="feature",
                 name_ciphertext=cipher.encrypt(title), description_ciphertext="")
            for i, title in enumerate(["Revisar checklist", "Validar relatório"], 1)
        ]
        db.add_all([project, updated_project, column, *tasks])
        db.flush()
        db.add_all([
            EmployeeProject(employee=employee, project=project),
            EmployeeProject(employee=employee, project=updated_project),
        ])
        db.commit()

    employee_headers = login_headers(client, JOAO_EMAIL)
    admin_headers = login_headers(client, MARINA_EMAIL)
    manager_headers = login_headers(client, CAIO_EMAIL)
    opened = client.post(f"{ROOT}/me/punches", headers=employee_headers, json={
        "type": "checkIn", "projectId": "history-atlas",
    })
    assert opened.status_code == 200, opened.text
    assert opened.json()["projectId"] is None
    assert opened.json()["projectName"] is None
    assert opened.json()["workLog"] is None
    closed = client.post(f"{ROOT}/me/punches", headers=employee_headers, json={
        "type": closing_type, "projectId": "history-atlas",
        "workLog": {"description": "Atividades de teste",
                    "taskIds": ["history-task-1", "history-task-2"]},
    })
    assert closed.status_code == 200, closed.text
    original = closed.json()["workLog"]
    assert original["projectName"] == "Projeto Atlas"
    assert set(original["taskNames"]) == {"Revisar checklist", "Validar relatório"}
    assert {task["id"]: (task["name"], task["cardNumber"]) for task in original["tasks"]} == {
        "history-task-1": ("Revisar checklist", 1),
        "history-task-2": ("Validar relatório", 2),
    }
    assert "description" not in original

    def assert_legacy_history():
        for path, headers in (
            (f"{ROOT}/me?limit=1", employee_headers),
            (f"{TEAM_HISTORY}?limit=1", admin_headers),
            (f"{TEAM_HISTORY}?limit=1", manager_headers),
        ):
            response = client.get(path, headers=headers)
            assert response.status_code == 200, response.text
            [record] = response.json()["records"]
            assert record["workLog"]["taskNames"] == original["taskNames"]
            assert record["workLog"]["tasks"] == [
                {"name": name, "id": None, "cardNumber": None}
                for name in original["taskNames"]
            ]

    with SessionLocal() as db:
        source = db.query(WorkLog).filter_by(employee_id="emp-04").one()
        structured_snapshot = source.task_snapshots_ciphertext
        source.task_snapshots_ciphertext = cipher.encrypt_json(original["taskNames"])
        # The current matches remain unique even though both titles were swapped.
        db.get(Task, "history-task-1").name_ciphertext = cipher.encrypt("Validar relatório")
        db.get(Task, "history-task-2").name_ciphertext = cipher.encrypt("Revisar checklist")
        db.commit()

    assert_legacy_history()

    with SessionLocal() as db:
        # Card 1 keeps the historical title of deleted card 2.
        db.delete(db.get(Task, "history-task-2"))
        db.commit()

    assert_legacy_history()

    with SessionLocal() as db:
        source = db.query(WorkLog).filter_by(employee_id="emp-04").one()
        source.task_snapshots_ciphertext = structured_snapshot
        db.commit()

    with SessionLocal() as db:
        db.get(Task, "history-task-1").name_ciphertext = cipher.encrypt("Nome posterior")
        db.commit()
        # A same-company log for another employee, even if incorrectly linked,
        # must not supply activity details to this punch.
        source = db.query(WorkLog).filter_by(employee_id="emp-04").one()
        db.add(WorkLog(
            id="history-wrong-employee",
            company_id=COMPANY_ID, employee_id="emp-02", punch_id=source.punch_id,
            start_time=source.start_time, end_time=source.end_time, duration_seconds=0,
            description_ciphertext="", task_snapshots_ciphertext=cipher.encrypt('["Tarefa privada"]'),
        ))
        db.commit()

    assert client.get(TEAM_HISTORY, headers=employee_headers).status_code == 403
    managed_id = None
    for path, headers in (
        (f"{ROOT}/me?limit=1", employee_headers),
        (f"{TEAM_HISTORY}?limit=1", admin_headers),
        (f"{TEAM_HISTORY}?limit=1", manager_headers),
    ):
        response = client.get(path, headers=headers)
        assert response.status_code == 200, response.text
        [record] = response.json()["records"]
        assert record["type"] == closing_type
        assert record["projectName"] == "Projeto Atlas"
        assert record["workLog"] == original
        managed_id = record.get("id") or managed_id

    with SessionLocal() as db:
        db.delete(db.get(WorkLog, "history-wrong-employee"))
        db.commit()

    changed = client.patch(f"{TEAM_HISTORY}/{managed_id}", headers=admin_headers,
                           json={"projectId": "history-horizon"})
    assert changed.status_code == 200, changed.text
    assert changed.json()["projectName"] == "Projeto Horizonte"
    assert changed.json()["workLog"] == original
    current = client.get(f"{ROOT}/me?limit=1", headers=employee_headers).json()["records"][0]
    assert current["projectName"] == "Projeto Horizonte"
    assert current["workLog"] == original

    # Old punches without a linked log remain readable; no unrelated tasks are inferred.
    old = client.get(f"{TEAM_HISTORY}?page=2&limit=1", headers=admin_headers).json()["records"][0]
    assert old["type"] == "checkIn"
    assert old["projectId"] is None
    assert old["projectName"] is None
    assert old["workLog"] is None


def test_opening_and_return_never_persist_or_expose_work_context(client):
    cipher = FieldCipher(get_settings().encryption_secret)
    with SessionLocal() as db:
        employee = db.get(Employee, "emp-04")
        employee.requires_location_on_punch = False
        employee.trusted_device_required = False
        db.execute(delete(Punch).where(Punch.employee_id == employee.id))
        project = Project(id="legacy-punch-project", company_id=COMPANY_ID,
                          name_ciphertext=cipher.encrypt("Projeto legado"))
        db.add(project)
        db.add(EmployeeProject(employee=employee, project=project))
        db.commit()

    employee_headers = login_headers(client, JOAO_EMAIL)
    admin_headers = login_headers(client, MARINA_EMAIL)
    employee_path = f"{ROOT}/me/punches"

    def without_context(record):
        for key in ("projectId", "projectName", "workLog"):
            assert record[key] is None

    entry = client.post(employee_path, headers=employee_headers, json={
        "type": "checkIn", "projectId": "ignored-project",
        "workLog": {"description": "Not applicable", "taskIds": ["ignored-task"]},
    })
    assert entry.status_code == 200, entry.text
    without_context(entry.json())

    pause = client.post(employee_path, headers=employee_headers, json={
        "type": "breakStart", "projectId": None,
        "workLog": {"description": "Pausa", "taskIds": []},
    })
    assert pause.status_code == 200, pause.text
    with SessionLocal() as db:
        records = {p.type: p for p in db.query(Punch).filter_by(employee_id="emp-04")}
        assert records["checkIn"].project_id is None
        assert not db.query(WorkLog).filter_by(punch_id=records["checkIn"].id).count()
        # Historical input immediately preceding a return used to be inherited.
        records["breakStart"].project_id = "legacy-punch-project"
        db.commit()

    returned = client.post(employee_path, headers=employee_headers, json={"type": "breakEnd"})
    assert returned.status_code == 200, returned.text
    without_context(returned.json())

    with SessionLocal() as db:
        records = {p.type: p for p in db.query(Punch).filter_by(employee_id="emp-04")}
        assert records["breakEnd"].project_id is None
        for kind in ("checkIn", "breakEnd"):
            records[kind].project_id = "legacy-punch-project"
        entry_id = records["checkIn"].id
        db.commit()

    for path, headers in ((f"{ROOT}/me", employee_headers), (TEAM_HISTORY, admin_headers)):
        response = client.get(path, headers=headers)
        assert response.status_code == 200, response.text
        records = {record["type"]: record for record in response.json()["records"]}
        for kind in ("checkIn", "breakEnd"):
            without_context(records[kind])
        assert records["breakStart"]["projectId"] == "legacy-punch-project"

    updated = client.patch(f"{TEAM_HISTORY}/{entry_id}", headers=admin_headers, json={
        "detail": "Entrada corrigida", "projectId": "legacy-punch-project",
    })
    assert updated.status_code == 200, updated.text
    without_context(updated.json())

    closed = client.post(employee_path, headers=employee_headers, json={
        "type": "checkOut", "projectId": None,
        "workLog": {"description": "Fim", "taskIds": []},
    })
    assert closed.status_code == 200, closed.text
    manual = client.post(TEAM_HISTORY, headers=admin_headers, json={
        "type": "checkIn", "detail": "Entrada manual", "projectId": "legacy-punch-project",
    })
    assert manual.status_code == 201, manual.text
    without_context(manual.json())
    with SessionLocal() as db:
        assert db.get(Punch, entry_id).project_id is None
        assert db.get(Punch, manual.json()["id"]).project_id is None


@pytest.mark.parametrize(
    ("opening_type", "closing_type"),
    [("checkIn", "breakStart"), ("breakEnd", "checkOut")],
)
def test_closing_without_project_does_not_inherit_stale_opening_project(
    client, opening_type, closing_type,
):
    cipher = FieldCipher(get_settings().encryption_secret)
    with SessionLocal() as db:
        employee = db.get(Employee, "emp-04")
        employee.requires_location_on_punch = False
        employee.trusted_device_required = False
        db.execute(delete(Punch).where(Punch.employee_id == employee.id))
        project = Project(id="stale-opening", company_id=COMPANY_ID,
                          name_ciphertext=cipher.encrypt("Projeto legado"))
        db.add_all([project, EmployeeProject(employee=employee, project=project)])
        db.commit()

    headers = login_headers(client, JOAO_EMAIL)
    path = f"{ROOT}/me/punches"
    entry = client.post(path, headers=headers, json={"type": "checkIn"})
    assert entry.status_code == 200, entry.text
    if opening_type == "breakEnd":
        pause = client.post(path, headers=headers, json={
            "type": "breakStart", "projectId": None,
            "workLog": {"description": "Atividades da manha", "taskIds": []},
        })
        assert pause.status_code == 200, pause.text
        returned = client.post(path, headers=headers, json={"type": "breakEnd"})
        assert returned.status_code == 200, returned.text

    with SessionLocal() as db:
        opening = db.query(Punch).filter_by(employee_id="emp-04", type=opening_type).one()
        opening.project_id = "stale-opening"
        opening_id = opening.id
        db.commit()

    # No explicit projectId: the persisted value is not a valid fallback.
    closed = client.post(path, headers=headers, json={
        "type": closing_type,
        "workLog": {"description": "Atividades sem projeto", "taskIds": []},
    })
    assert closed.status_code == 200, closed.text
    assert closed.json()["projectId"] is None
    assert closed.json()["workLog"] == {
        "projectId": None, "projectName": None, "taskNames": [], "tasks": [],
    }
    with SessionLocal() as db:
        assert db.get(Punch, opening_id).project_id == "stale-opening"
        punch = db.query(Punch).filter_by(employee_id="emp-04", type=closing_type).one()
        assert punch.project_id is None
        log = db.query(WorkLog).filter_by(punch_id=punch.id).one()
        assert log.project_id is None
        assert log.tasks == []


@pytest.mark.parametrize("selection", ["omitted", "null", "assigned"])
def test_managed_type_change_does_not_restore_stale_return_project(client, selection):
    cipher = FieldCipher(get_settings().encryption_secret)
    with SessionLocal() as db:
        employee = db.get(Employee, "emp-04")
        db.execute(delete(Punch).where(Punch.employee_id == employee.id))
        stale = Project(id="stale-return", company_id=COMPANY_ID,
                        name_ciphertext=cipher.encrypt("Projeto legado sem vinculo"))
        assigned = Project(id="selected-checkout", company_id=COMPANY_ID,
                           name_ciphertext=cipher.encrypt("Projeto selecionado"))
        db.add_all([stale, assigned, EmployeeProject(employee=employee, project=assigned)])
        db.commit()

    headers = login_headers(client, MARINA_EMAIL)
    for hour, kind in [(9, "checkIn"), (12, "breakStart"), (13, "breakEnd")]:
        created = client.post(TEAM_HISTORY, headers=headers, json={
            "type": kind, "timestamp": f"2026-11-26T{hour:02}:00:00Z",
            "detail": "Registro manual",
        })
        assert created.status_code == 201, created.text
    returned_id = created.json()["id"]
    with SessionLocal() as db:
        db.get(Punch, returned_id).project_id = "stale-return"
        db.commit()

    path = f"{TEAM_HISTORY}/{returned_id}"
    rejected = client.patch(path, headers=headers, json={
        "type": "checkOut", "projectId": "stale-return",
    })
    assert rejected.status_code == 403, rejected.text
    with SessionLocal() as db:
        assert db.get(Punch, returned_id).type == "breakEnd"

    payload = {"type": "checkOut"}
    expected = "selected-checkout" if selection == "assigned" else None
    if selection != "omitted":
        payload["projectId"] = expected
    updated = client.patch(path, headers=headers, json=payload)
    assert updated.status_code == 200, updated.text
    assert updated.json()["type"] == "checkOut"
    assert updated.json()["projectId"] == expected
    assert updated.json()["projectName"] == ("Projeto selecionado" if expected else None)
    assert updated.json()["workLog"] is None
    with SessionLocal() as db:
        assert db.get(Punch, returned_id).project_id == expected
        assert not db.query(WorkLog).filter_by(punch_id=returned_id).count()
