from fastapi.testclient import TestClient
from app.main import app
from app.seed import JOAO_EMAIL, MARINA_EMAIL
from tests.test_api import login_headers, login_headers_for, TEST_SEED_SECRET, _clear_employee_punches
from datetime import datetime, timedelta, timezone


def test_optional_location_punch_detail_matches_persisted_evidence(client: TestClient):
    from sqlalchemy import select
    from app.config import get_settings
    from app.crypto import FieldCipher
    from app.db import SessionLocal
    from app.models import Punch

    headers = login_headers_for(client, email=JOAO_EMAIL, password=TEST_SEED_SECRET)
    cipher = FieldCipher(get_settings().encryption_secret or "")
    path = "/api/v1/time-clock/me/punches"
    location = {
        "latitude": -23.5632,
        "longitude": -46.6545,
        "accuracyMeters": 12,
        "capturedAt": "2026-04-25T16:30:00-03:00",
    }

    for provided_location in (None, location):
        _clear_employee_punches("emp-04")
        payload = {"type": "checkIn"}
        if provided_location is not None:
            payload["location"] = provided_location
        response = client.post(path, headers=headers, json=payload)
        assert response.status_code == 200, response.text
        result = response.json()
        if provided_location is None:
            assert result["location"] is None
        else:
            assert result["location"] is not None
        assert "validada" not in result["detail"].lower()
        assert "capturada" not in result["detail"].lower()
        assert ("localização informada" in result["detail"].lower()) == (provided_location is not None)

        state = client.get("/api/v1/time-clock/me?page=1&limit=4", headers=headers)
        assert state.status_code == 200
        assert state.json()["records"][0]["detail"] == result["detail"]
        with SessionLocal() as db:
            record = db.scalar(select(Punch).where(Punch.employee_id == "emp-04"))
            assert record is not None
            assert cipher.decrypt(record.detail_ciphertext) == result["detail"]

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


def test_monthly_report_utc_boundaries_order_and_authorization(client: TestClient):
    from sqlalchemy import extract, select
    from app.config import get_settings
    from app.crypto import FieldCipher
    from app.db import SessionLocal, ensure_utc
    from app.domain.project_read import generate_monthly_work_logs_report
    from app.errors import DomainError, ErrorKind
    from app.models import Punch, WorkLog

    admin_headers = login_headers(client)
    project = _create_project(client, admin_headers, name="UTC boundaries")
    other_project = _create_project(client, admin_headers, name="Other project")
    project_id = project["id"]
    membership = client.post(
        f"/api/v1/projects/{project_id}/members",
        headers=admin_headers,
        json={"employeeId": "emp-04"},
    )
    assert membership.status_code in (200, 201)

    field_cipher = FieldCipher(get_settings().encryption_secret or "")
    # São Paulo 2025-12-31 21:00 corresponds to January 1st UTC.
    local_zone = timezone(timedelta(hours=-3))
    fixtures = [
        ("dec-last", datetime(2025, 12, 31, 23, 59, 59, 999999, tzinfo=timezone.utc), "emp-04", project_id),
        ("jan-start", datetime(2025, 12, 31, 21, 0, tzinfo=local_zone), "emp-04", project_id),
        ("jan-middle", datetime(2026, 1, 10, 12, tzinfo=timezone.utc), "emp-04", project_id),
        ("other-employee", datetime(2026, 1, 11, 12, tzinfo=timezone.utc), "emp-01", project_id),
        ("other-project", datetime(2026, 1, 12, 12, tzinfo=timezone.utc), "emp-04", other_project["id"]),
        ("feb-start", datetime(2026, 2, 1, tzinfo=timezone.utc), "emp-04", project_id),
    ]
    with SessionLocal() as db:
        for marker, timestamp, employee_id, target_project in fixtures:
            timestamp = ensure_utc(timestamp)
            punch_id = f"boundary-punch-{marker}"
            db.add(Punch(
                id=punch_id, company_id="company-touchin", employee_id=employee_id,
                project_id=target_project, type="checkIn", timestamp=timestamp,
                detail_ciphertext=field_cipher.encrypt("") or "",
            ))
            db.add(WorkLog(
                id=f"boundary-log-{marker}", company_id="company-touchin",
                employee_id=employee_id, project_id=target_project, punch_id=punch_id,
                start_time=timestamp, end_time=timestamp + timedelta(minutes=15),
                duration_seconds=900,
                description_ciphertext=field_cipher.encrypt(marker) or "",
                task_snapshots_ciphertext=field_cipher.encrypt("[]") or "",
            ))
        db.commit()

        original = db.scalars(
            select(WorkLog).where(
                WorkLog.company_id == "company-touchin",
                WorkLog.project_id == project_id,
                extract("year", WorkLog.start_time) == 2026,
                extract("month", WorkLog.start_time) == 1,
                # Older SQLite versions may round 23:59:59.999999 into the
                # next calendar day during strftime/EXTRACT. Compare legacy
                # behavior only for unambiguous timestamps, and assert the
                # last microsecond of December separately below.
                WorkLog.id != "boundary-log-dec-last",
            ).order_by(WorkLog.start_time)
        ).all()
        expected = [field_cipher.decrypt(log.description_ciphertext) for log in original]
        report = generate_monthly_work_logs_report(
            db, company_id="company-touchin", project_id=project_id, year=2026, month=1
        )
        assert [row.description for row in report.records] == expected == [
            "jan-start", "jan-middle", "other-employee",
        ]

        for month, expected_description in [(12, "dec-last"), (2, "feb-start")]:
            year = 2025 if month == 12 else 2026
            response = generate_monthly_work_logs_report(
                db, company_id="company-touchin", project_id=project_id,
                year=year, month=month,
            )
            assert [row.description for row in response.records] == [expected_description]

        restricted = generate_monthly_work_logs_report(
            db, company_id="company-touchin", project_id=project_id,
            year=2026, month=1, employee_id="emp-04",
        )
        assert [row.description for row in restricted.records] == [
            "jan-start", "jan-middle",
        ]
        try:
            generate_monthly_work_logs_report(
                db, company_id="nonexistent-company", project_id=project_id,
                year=2026, month=1,
            )
            assert False, "cross-company request must be denied"
        except DomainError as exc:
            assert exc.kind == ErrorKind.not_found

    path = f"/api/v1/projects/{project_id}/reports/work-logs?year=2026&month=1"
    admin_result = client.get(path, headers=admin_headers)
    assert admin_result.status_code == 200
    assert [item["description"] for item in admin_result.json()["records"]] == expected
    joao_headers = login_headers_for(client, email=JOAO_EMAIL, password=TEST_SEED_SECRET)
    employee_result = client.get(path, headers=joao_headers)
    assert employee_result.status_code == 200
    assert [item["description"] for item in employee_result.json()["records"]] == [
        "jan-start", "jan-middle",
    ]
    denied = client.get(
        f"/api/v1/projects/{other_project['id']}/reports/work-logs?year=2026&month=1",
        headers=joao_headers,
    )
    assert denied.status_code == 404
    # EXTRACT returned no records for out-of-range calendar values.
    for year, month in [(2026, 0), (2026, 13), (0, 1), (10000, 1), (9999, 12)]:
        response = client.get(
            f"/api/v1/projects/{project_id}/reports/work-logs?year={year}&month={month}",
            headers=admin_headers,
        )
        assert response.status_code == 200
        assert response.json()["records"] == []


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
