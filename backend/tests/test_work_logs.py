from fastapi.testclient import TestClient
from app.main import app
from app.seed import JOAO_EMAIL, MARINA_EMAIL
from tests.test_api import login_headers, login_headers_for, TEST_SEED_SECRET, _clear_employee_punches
from datetime import datetime

def _create_project(client, headers, *, name: str = "Project") -> dict:
    response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={"name": name, "description": "Desc"},
    )
    assert response.status_code == 201
    return response.json()

def _create_task(client, headers, project_id, *, name="Task"):
    res = client.post(
        f"/api/v1/projects/{project_id}/tasks",
        headers=headers,
        json={"name": name, "type": "feature", "description": "desc"}
    )
    assert res.status_code == 201
    return res.json()

def test_mandatory_work_log_on_break_and_checkout(client: TestClient):
    _clear_employee_punches("emp-04")
    admin_headers = login_headers(client)
    project = _create_project(client, admin_headers)
    task = _create_task(client, admin_headers, project["id"])
    
    # assign Joao to project
    client.post(f"/api/v1/projects/{project['id']}/members", headers=admin_headers, json={"employeeId": "emp-04"})
    
    headers = login_headers_for(client, email=JOAO_EMAIL, password=TEST_SEED_SECRET)
    
    # 1. Check in (no work log needed)
    res = client.post("/api/v1/time-clock/me/punches", headers=headers, json={"type": "checkIn"})
    assert res.status_code == 200, res.text
    
    # 2. Try to break_start with projectId but without work_log -> should fail
    res = client.post("/api/v1/time-clock/me/punches", headers=headers, json={"type": "breakStart", "projectId": project["id"]})
    assert res.status_code == 400
    
    # 3. break_start with valid work_log -> should pass
    res = client.post("/api/v1/time-clock/me/punches", headers=headers, json={
        "type": "breakStart",
        "projectId": project["id"],
        "workLog": {"description": "Trabalhei muito", "taskIds": [task["id"]]}
    })
    assert res.status_code == 200, res.text
    
    # 4. break_end (no work log needed)
    res = client.post("/api/v1/time-clock/me/punches", headers=headers, json={"type": "breakEnd"})
    assert res.status_code == 200, res.text
    
    # 5. check_out with work_log -> should pass
    res = client.post("/api/v1/time-clock/me/punches", headers=headers, json={
        "type": "checkOut",
        "projectId": project["id"],
        "workLog": {"description": "Terminei", "taskIds": [task["id"]]}
    })
    assert res.status_code == 200, res.text
    
def test_monthly_work_logs_report(client: TestClient):
    _clear_employee_punches("emp-04")
    admin_headers = login_headers(client)
    project = _create_project(client, admin_headers)
    task = _create_task(client, admin_headers, project["id"], name="Report task")
    
    # assign Joao
    client.post(f"/api/v1/projects/{project['id']}/members", headers=admin_headers, json={"employeeId": "emp-04"})
    
    headers = login_headers_for(client, email=JOAO_EMAIL, password=TEST_SEED_SECRET)
    
    client.post("/api/v1/time-clock/me/punches", headers=headers, json={"type": "checkIn", "projectId": project["id"]})
    client.post("/api/v1/time-clock/me/punches", headers=headers, json={
        "type": "checkOut",
        "projectId": project["id"],
        "workLog": {"description": "Report test", "taskIds": [task["id"]]}
    })
    
    now = datetime.now()
    res = client.get(f"/api/v1/projects/{project['id']}/reports/work-logs?year={now.year}&month={now.month}", headers=admin_headers)
    assert res.status_code == 200, res.text
    data = res.json()
    assert len(data["records"]) >= 1
    record = data["records"][-1]
    assert record["description"] == "Report test"
    assert len(record["tasks"]) == 1
    assert record["tasks"][0] == "Report task"


def test_mandatory_work_log_no_project_id(client: TestClient):
    _clear_employee_punches("emp-04")
    admin_headers = login_headers(client)
    project = _create_project(client, admin_headers)
    task = _create_task(client, admin_headers, project["id"])
    client.post(f"/api/v1/projects/{project['id']}/members", headers=admin_headers, json={"employeeId": "emp-04"})
    headers = login_headers_for(client, email=JOAO_EMAIL, password=TEST_SEED_SECRET)
    res = client.post("/api/v1/time-clock/me/punches", headers=headers, json={"type": "checkIn"})
    res = client.post("/api/v1/time-clock/me/punches", headers=headers, json={"type": "breakStart"})
    assert res.status_code == 400
    assert "registro de atividades" in res.json()["detail"].lower()
    res = client.post("/api/v1/time-clock/me/punches", headers=headers, json={"type": "checkOut"})
    assert res.status_code == 400
    assert "registro de atividades" in res.json()["detail"].lower()
    res = client.post("/api/v1/time-clock/me/punches", headers=headers, json={"type": "checkOut", "workLog": {"description": "desc", "taskIds": [task["id"]]}})
    assert res.status_code == 200, res.text
