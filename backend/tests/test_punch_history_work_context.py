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
    assert opened.json()["projectName"] == "Projeto Atlas"
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
    assert "description" not in original

    with SessionLocal() as db:
        db.get(Task, "history-task-1").name_ciphertext = cipher.encrypt("Nome posterior")
        db.delete(db.get(Task, "history-task-2"))
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
    assert old["projectName"] == "Projeto Atlas"
    assert old["workLog"] is None
