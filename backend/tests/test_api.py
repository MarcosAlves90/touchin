from __future__ import annotations

from uuid import uuid4

from sqlalchemy import select

from app.api.routes import auth as auth_routes
from app.api.routes import employees as employees_routes
from app.config import get_settings
from app.db import SessionLocal
from app.models import Employee, Punch, UserAccount
from app.services.employees import _cipher

TEST_SEED_SECRET = get_settings().seed_admin_password
TEST_REGISTER_SECRET = f"test-register-{uuid4().hex}"


def login_headers(client):
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "marina.costa@touchin.com",
            "password": TEST_SEED_SECRET,
            "keepConnected": True,
        },
    )
    assert response.status_code == 200
    token = response.json()["accessToken"]
    return {"Authorization": f"Bearer {token}"}


def login_headers_for(client, *, email: str, password: str):
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": email,
            "password": password,
            "keepConnected": True,
        },
    )
    assert response.status_code == 200
    token = response.json()["accessToken"]
    return {"Authorization": f"Bearer {token}"}


def _clear_employee_punches(employee_id: str) -> None:
    with SessionLocal() as db:
        punches = db.scalars(select(Punch).where(Punch.employee_id == employee_id)).all()
        for punch in punches:
            db.delete(punch)
        db.commit()


def test_health_check(client):
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}


def test_login_and_get_employees(client):
    headers = login_headers(client)
    response = client.get("/api/v1/employees", headers=headers)
    assert response.status_code == 200
    employees = response.json()
    assert len(employees) == 5
    assert employees[0]["id"] == "emp-05"
    assert employees[-1]["id"] == "emp-01"
    assert employees[-1]["requiresLocationOnPunch"] is True


def test_employee_cannot_list_employees(client):
    headers = login_headers_for(
        client,
        email="joao.lima@touchin.com",
        password=TEST_SEED_SECRET,
    )
    response = client.get("/api/v1/employees", headers=headers)
    assert response.status_code == 403


def test_create_and_update_employee(client):
    headers = login_headers(client)
    create_response = client.post(
        "/api/v1/employees",
        headers=headers,
        json={
            "name": "Renata Souza",
            "role": "Analista Financeira",
            "department": "Financeiro",
            "email": "renata.souza@touchin.com",
            "phone": "(11) 94444-6060",
            "unit": "Backoffice Centro",
            "expectedShiftStart": "08:00",
            "expectedShiftEnd": "17:00",
            "status": "active",
            "workMode": "hybrid",
            "roleLevel": "specialist",
            "accessRole": "manager",
            "requiresLocationOnPunch": False,
            "trustedDeviceRequired": True,
            "notes": "Nova contratacao para apoiar o fechamento mensal.",
        },
    )
    assert create_response.status_code == 201
    employee = create_response.json()
    assert employee["email"] == "renata.souza@touchin.com"
    assert employee["expectedShiftStart"] == "08:00:00"
    assert employee["expectedShiftEnd"] == "17:00:00"
    assert employee["todayWorkedMinutes"] == 0

    with SessionLocal() as db:
        user = db.scalar(select(UserAccount).where(UserAccount.employee_id == employee["id"]))
        assert user is not None
        cipher = _cipher()
        assert cipher.decrypt(user.email_ciphertext) == "renata.souza@touchin.com"
        assert user.role == "manager"

    update_response = client.put(
        f"/api/v1/employees/{employee['id']}",
        headers=headers,
        json={
            "name": "Renata Souza",
            "role": "Analista Financeira Senior",
            "department": "Financeiro",
            "email": "renata.souza@touchin.com",
            "phone": "(11) 94444-6060",
            "unit": "Backoffice Centro",
            "expectedShiftStart": "08:00",
            "expectedShiftEnd": "17:00",
            "status": "active",
            "workMode": "remote",
            "roleLevel": "specialist",
            "accessRole": "employee",
            "requiresLocationOnPunch": False,
            "trustedDeviceRequired": True,
            "notes": "Atualizada para operacao remota.",
        },
    )
    assert update_response.status_code == 200
    updated = update_response.json()
    assert updated["role"] == "Analista Financeira Senior"
    assert updated["workMode"] == "remote"

    patch_response = client.patch(
        f"/api/v1/employees/{employee['id']}",
        headers=headers,
        json={
            "name": "Renata Souza",
            "role": "Analista Financeira Lead",
            "department": "Financeiro",
            "email": "renata.souza@touchin.com",
            "phone": "(11) 94444-6060",
            "unit": "Backoffice Centro",
            "expectedShiftStart": "08:00",
            "expectedShiftEnd": "17:00",
            "status": "active",
            "workMode": "hybrid",
            "roleLevel": "specialist",
            "accessRole": "employee",
            "requiresLocationOnPunch": False,
            "trustedDeviceRequired": True,
            "notes": "Atualizada via patch.",
        },
    )
    assert patch_response.status_code == 200
    assert patch_response.json()["role"] == "Analista Financeira Lead"

    with SessionLocal() as db:
        user = db.scalar(select(UserAccount).where(UserAccount.employee_id == employee["id"]))
        assert user is not None
        assert user.role == "employee"


def test_admin_can_edit_self(client):
    headers = login_headers(client)
    response = client.put(
        "/api/v1/employees/emp-01",
        headers=headers,
        json={
            "name": "Marina Costa",
            "role": "Coordenadora de Operacoes",
            "department": "Operacoes",
            "email": "marina.costa@touchin.com",
            "phone": "(11) 99123-1001",
            "unit": "Unidade Paulista",
            "expectedShiftStart": "08:00",
            "expectedShiftEnd": "17:00",
            "status": "active",
            "workMode": "onsite",
            "roleLevel": "leadership",
            "requiresLocationOnPunch": True,
            "trustedDeviceRequired": True,
            "notes": "Atualizacao do proprio cadastro.",
        },
    )

    assert response.status_code == 200
    assert response.json()["notes"] == "Atualizacao do proprio cadastro."


def test_manager_cannot_edit_self_or_admin(client):
    headers = login_headers_for(
        client,
        email="caio.martins@touchin.com",
        password=TEST_SEED_SECRET,
    )

    self_response = client.put(
        "/api/v1/employees/emp-02",
        headers=headers,
        json={
            "name": "Caio Martins",
            "role": "Analista de RH",
            "department": "People Ops",
            "email": "caio.martins@touchin.com",
            "phone": "(11) 98888-2020",
            "unit": "Backoffice Centro",
            "expectedShiftStart": "09:00",
            "expectedShiftEnd": "18:00",
            "status": "active",
            "workMode": "hybrid",
            "roleLevel": "specialist",
            "accessRole": "manager",
            "requiresLocationOnPunch": False,
            "trustedDeviceRequired": True,
            "notes": "Tentativa de autoedicao.",
        },
    )
    assert self_response.status_code == 403

    admin_response = client.put(
        "/api/v1/employees/emp-01",
        headers=headers,
        json={
            "name": "Marina Costa",
            "role": "Coordenadora de Operacoes",
            "department": "Operacoes",
            "email": "marina.costa@touchin.com",
            "phone": "(11) 99123-1001",
            "unit": "Unidade Paulista",
            "expectedShiftStart": "08:00",
            "expectedShiftEnd": "17:00",
            "status": "active",
            "workMode": "onsite",
            "roleLevel": "leadership",
            "requiresLocationOnPunch": True,
            "trustedDeviceRequired": True,
            "notes": "Tentativa de editar admin.",
        },
    )
    assert admin_response.status_code == 403


def test_manager_can_edit_other_manager(client):
    admin_headers = login_headers(client)
    create_response = client.post(
        "/api/v1/employees",
        headers=admin_headers,
        json={
            "name": "Renata Souza",
            "role": "Analista Financeira",
            "department": "Financeiro",
            "email": "renata.souza@touchin.com",
            "phone": "(11) 94444-6060",
            "unit": "Backoffice Centro",
            "expectedShiftStart": "08:00",
            "expectedShiftEnd": "17:00",
            "status": "active",
            "workMode": "hybrid",
            "roleLevel": "specialist",
            "accessRole": "manager",
            "requiresLocationOnPunch": False,
            "trustedDeviceRequired": True,
            "notes": "Cadastro para teste de edicao por gestor.",
        },
    )
    assert create_response.status_code == 201
    employee = create_response.json()

    manager_headers = login_headers_for(
        client,
        email="caio.martins@touchin.com",
        password=TEST_SEED_SECRET,
    )
    update_response = client.put(
        f"/api/v1/employees/{employee['id']}",
        headers=manager_headers,
        json={
            "name": "Renata Souza",
            "role": "Analista Financeira Senior",
            "department": "Financeiro",
            "email": "renata.souza@touchin.com",
            "phone": "(11) 94444-6060",
            "unit": "Backoffice Centro",
            "expectedShiftStart": "08:00",
            "expectedShiftEnd": "17:00",
            "status": "active",
            "workMode": "remote",
            "roleLevel": "specialist",
            "accessRole": "manager",
            "requiresLocationOnPunch": False,
            "trustedDeviceRequired": True,
            "notes": "Edicao feita pelo gestor.",
        },
    )

    assert update_response.status_code == 200
    assert update_response.json()["workMode"] == "remote"


def test_create_employee_triggers_credentials_email_task(client, monkeypatch):
    calls: list[dict[str, str]] = []

    def fake_send_employee_credentials_email(
        *,
        recipient_email: str,
        employee_name: str,
        temp_password: str,
    ) -> None:
        calls.append(
            {
                "recipient_email": recipient_email,
                "employee_name": employee_name,
                "temp_password": temp_password,
            },
        )

    monkeypatch.setattr(
        employees_routes,
        "send_employee_credentials_email",
        fake_send_employee_credentials_email,
    )

    headers = login_headers(client)
    response = client.post(
        "/api/v1/employees",
        headers=headers,
        json={
            "name": "Gabriel Paiva",
            "role": "Analista de Operacoes",
            "department": "Operacoes",
            "email": "gabriel.paiva@touchin.com",
            "phone": "(11) 95555-7070",
            "unit": "Operacoes Central",
            "expectedShiftStart": "09:00",
            "expectedShiftEnd": "18:00",
            "status": "active",
            "workMode": "onsite",
            "roleLevel": "staff",
            "requiresLocationOnPunch": True,
            "trustedDeviceRequired": False,
            "notes": "Entrada para reforcar a equipe de operacoes.",
        },
    )

    assert response.status_code == 201
    assert len(calls) == 1
    assert calls[0]["recipient_email"] == "gabriel.paiva@touchin.com"
    assert calls[0]["employee_name"] == "Gabriel Paiva"
    assert len(calls[0]["temp_password"]) >= 12

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "gabriel.paiva@touchin.com",
            "password": calls[0]["temp_password"],
            "keepConnected": True,
        },
    )
    assert login_response.status_code == 200
    assert login_response.json()["mustChangePassword"] is True


def test_delete_employee(client):
    headers = login_headers(client)
    create_response = client.post(
        "/api/v1/employees",
        headers=headers,
        json={
            "name": "Renata Souza",
            "role": "Analista Financeira",
            "department": "Financeiro",
            "email": "renata.souza@touchin.com",
            "phone": "(11) 94444-6060",
            "unit": "Backoffice Centro",
            "expectedShiftStart": "08:00",
            "expectedShiftEnd": "17:00",
            "status": "active",
            "workMode": "hybrid",
            "roleLevel": "specialist",
            "requiresLocationOnPunch": False,
            "trustedDeviceRequired": True,
            "notes": "Nova contratacao para apoiar o fechamento mensal.",
        },
    )
    assert create_response.status_code == 201
    employee = create_response.json()

    delete_response = client.delete(
        f"/api/v1/employees/{employee['id']}",
        headers=headers,
    )
    assert delete_response.status_code == 204

    with SessionLocal() as db:
        user = db.scalar(select(UserAccount).where(UserAccount.employee_id == employee["id"]))
        assert user is None

    list_response = client.get("/api/v1/employees", headers=headers)
    assert list_response.status_code == 200
    ids = [item["id"] for item in list_response.json()]
    assert employee["id"] not in ids


def test_time_clock_requires_location_when_policy_demands_it(client):
    headers = login_headers(client)

    forbidden_response = client.post(
        "/api/v1/time-clock/me/punches",
        headers=headers,
        json={"type": "checkIn"},
    )
    assert forbidden_response.status_code == 400
    assert (
        forbidden_response.json()["detail"]
        == "Este funcionário precisa enviar dados de localização ao bater ponto."
    )

    success_response = client.post(
        "/api/v1/time-clock/me/punches",
        headers=headers,
        json={
            "type": "checkIn",
            "location": {
                "latitude": -23.5632,
                "longitude": -46.6545,
                "accuracyMeters": 12,
                "capturedAt": "2026-04-25T16:30:00-03:00",
            },
        },
    )
    assert success_response.status_code == 200
    payload = success_response.json()
    assert payload["type"] == "checkIn"
    assert payload["location"]["latitude"] == -23.5632


def test_time_clock_state_paginates_records(client):
    headers = login_headers(client)
    _clear_employee_punches("emp-01")

    punch_payloads = [
        {"type": "checkIn"},
        {"type": "breakStart"},
        {"type": "breakEnd"},
        {"type": "breakStart"},
        {"type": "breakEnd"},
    ]

    for payload in punch_payloads:
        response = client.post(
            "/api/v1/time-clock/me/punches",
            headers=headers,
            json={
                **payload,
                "location": {
                    "latitude": -23.5632,
                    "longitude": -46.6545,
                    "accuracyMeters": 12,
                    "capturedAt": "2026-04-25T16:30:00-03:00",
                },
            },
        )
        assert response.status_code == 200

    page_one = client.get(
        "/api/v1/time-clock/me?page=1&limit=2",
        headers=headers,
    )
    assert page_one.status_code == 200
    payload = page_one.json()
    assert payload["recordsPage"] == 1
    assert payload["recordsPageSize"] == 2
    assert payload["recordsTotal"] == 5
    assert payload["recordsTotalPages"] == 3
    assert payload["recordsHasPrevious"] is False
    assert payload["recordsHasNext"] is True
    assert [item["type"] for item in payload["records"]] == [
        "breakEnd",
        "breakStart",
    ]

    page_three = client.get(
        "/api/v1/time-clock/me?page=3&limit=2",
        headers=headers,
    )
    assert page_three.status_code == 200
    payload = page_three.json()
    assert payload["recordsPage"] == 3
    assert payload["recordsHasPrevious"] is True
    assert payload["recordsHasNext"] is False
    assert [item["type"] for item in payload["records"]] == ["checkIn"]


def test_employee_cannot_manage_employee_punches(client):
    headers = login_headers_for(
        client,
        email="joao.lima@touchin.com",
        password=TEST_SEED_SECRET,
    )
    response = client.get("/api/v1/time-clock/employees/emp-02/punches", headers=headers)
    assert response.status_code == 403


def test_manager_can_manage_employee_punches(client):
    headers = login_headers_for(
        client,
        email="caio.martins@touchin.com",
        password=TEST_SEED_SECRET,
    )
    _clear_employee_punches("emp-02")

    create_response = client.post(
        "/api/v1/time-clock/employees/emp-02/punches",
        headers=headers,
        json={
            "type": "checkIn",
            "timestamp": "2026-05-20T09:00:00-03:00",
            "detail": "Ajuste manual aprovado pelo gestor.",
        },
    )
    assert create_response.status_code == 201
    created = create_response.json()
    assert created["id"]
    assert created["employeeId"] == "emp-02"
    assert created["type"] == "checkIn"
    assert created["detail"] == "Ajuste manual aprovado pelo gestor."

    list_response = client.get(
        "/api/v1/time-clock/employees/emp-02/punches?limit=100",
        headers=headers,
    )
    assert list_response.status_code == 200
    payload = list_response.json()
    assert payload["recordsPage"] == 1
    assert payload["recordsPageSize"] == 100
    assert any(item["id"] == created["id"] for item in payload["records"])

    update_response = client.put(
        f"/api/v1/time-clock/employees/emp-02/punches/{created['id']}",
        headers=headers,
        json={"detail": "Ajuste revisado pelo gestor."},
    )
    assert update_response.status_code == 200
    assert update_response.json()["detail"] == "Ajuste revisado pelo gestor."

    patch_response = client.patch(
        f"/api/v1/time-clock/employees/emp-02/punches/{created['id']}",
        headers=headers,
        json={"detail": "Ajuste final via patch."},
    )
    assert patch_response.status_code == 200
    assert patch_response.json()["detail"] == "Ajuste final via patch."

    delete_response = client.delete(
        f"/api/v1/time-clock/employees/emp-02/punches/{created['id']}",
        headers=headers,
    )
    assert delete_response.status_code == 204

    final_list_response = client.get("/api/v1/time-clock/employees/emp-02/punches", headers=headers)
    assert final_list_response.status_code == 200
    final_payload = final_list_response.json()
    assert all(item["id"] != created["id"] for item in final_payload["records"])


def test_manager_paginates_employee_punches(client):
    headers = login_headers_for(
        client,
        email="caio.martins@touchin.com",
        password=TEST_SEED_SECRET,
    )
    _clear_employee_punches("emp-02")

    for index in range(5):
        response = client.post(
            "/api/v1/time-clock/employees/emp-02/punches",
            headers=headers,
            json={
                "type": "checkIn",
                "timestamp": f"2026-05-2{index}T09:00:00-03:00",
                "detail": f"Batch {index + 1}",
            },
        )
        assert response.status_code == 201

    page_one = client.get(
        "/api/v1/time-clock/employees/emp-02/punches?page=1&limit=2",
        headers=headers,
    )
    assert page_one.status_code == 200
    payload = page_one.json()
    assert payload["recordsPage"] == 1
    assert payload["recordsPageSize"] == 2
    assert payload["recordsTotal"] == 5
    assert payload["recordsTotalPages"] == 3
    assert payload["recordsHasPrevious"] is False
    assert payload["recordsHasNext"] is True
    assert [item["detail"] for item in payload["records"]] == ["Batch 5", "Batch 4"]

    page_three = client.get(
        "/api/v1/time-clock/employees/emp-02/punches?page=3&limit=2",
        headers=headers,
    )
    assert page_three.status_code == 200
    payload = page_three.json()
    assert payload["recordsPage"] == 3
    assert payload["recordsHasPrevious"] is True
    assert payload["recordsHasNext"] is False
    assert [item["detail"] for item in payload["records"]] == ["Batch 1"]


def test_pii_is_not_stored_in_plain_text(client):
    login_headers(client)
    with SessionLocal() as db:
        employee = db.scalar(select(Employee).where(Employee.id == "emp-01"))
        assert employee is not None
        assert employee.email_ciphertext != "marina.costa@touchin.com"
        assert "@touchin.com" not in employee.email_ciphertext


def test_list_employees_handles_legacy_invalid_shift_payload(client):
    headers = login_headers(client)
    cipher = _cipher()
    with SessionLocal() as db:
        employee = db.scalar(select(Employee).where(Employee.id == "emp-01"))
        assert employee is not None
        employee.expected_shift_ciphertext = cipher.encrypt("string") or ""
        db.commit()

    response = client.get("/api/v1/employees", headers=headers)
    assert response.status_code == 200
    payload = response.json()
    emp = next(item for item in payload if item["id"] == "emp-01")
    assert emp["expectedShiftStart"] == "08:00:00"
    assert emp["expectedShiftEnd"] == "17:00:00"


def test_super_admin_can_list_companies(client):
    headers = login_headers_for(
        client,
        email="super.admin@touchin.com",
        password=TEST_SEED_SECRET,
    )
    response = client.get("/api/v1/admin/companies", headers=headers)
    assert response.status_code == 200
    assert response.json()[0]["tradeName"] == "TouchIn Servicos Digitais"


def test_register_company_triggers_welcome_email_task(client, monkeypatch):
    calls: list[dict[str, str]] = []

    def fake_send_company_welcome_email(
        *,
        recipient_email: str,
        company_name: str,
        trade_name: str,
    ) -> None:
        calls.append(
            {
                "recipient_email": recipient_email,
                "company_name": company_name,
                "trade_name": trade_name,
            },
        )

    monkeypatch.setattr("app.services.auth.send_company_welcome_email", fake_send_company_welcome_email)

    response = client.post(
        "/api/v1/auth/register-company",
        json={
            "companyName": "Acme Tecnologia Ltda",
            "tradeName": "Acme Tech",
            "cnpj": "98.765.432/0001-10",
            "email": "contato@acmetech.com",
            "phone": "(11) 99888-7766",
            "password": TEST_REGISTER_SECRET,
            "acceptTerms": True,
        },
    )

    assert response.status_code == 201
    assert calls == [
        {
            "recipient_email": "contato@acmetech.com",
            "company_name": "Acme Tecnologia Ltda",
            "trade_name": "Acme Tech",
        },
    ]


def test_reset_password_triggers_email_task(client, monkeypatch):
    calls: list[dict[str, str]] = []

    def fake_send_password_reset_email(
        *,
        recipient_email: str,
        display_name: str,
        temp_password: str,
    ) -> None:
        calls.append(
            {
                "recipient_email": recipient_email,
                "display_name": display_name,
                "temp_password": temp_password,
            },
        )

    monkeypatch.setattr(
        auth_routes,
        "send_password_reset_email",
        fake_send_password_reset_email,
    )

    response = client.post(
        "/api/v1/auth/reset-password",
        json={"email": "marina.costa@touchin.com"},
    )

    assert response.status_code == 200
    assert len(calls) == 1
    assert calls[0]["recipient_email"] == "marina.costa@touchin.com"
    assert len(calls[0]["temp_password"]) >= 12

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "marina.costa@touchin.com",
            "password": calls[0]["temp_password"],
            "keepConnected": True,
        },
    )
    assert login_response.status_code == 200


def test_change_password_triggers_email_task(client, monkeypatch):
    calls: list[dict[str, str]] = []
    new_password = f"test-new-password-{uuid4().hex[:8]}@123"

    def fake_send_password_changed_email(
        *,
        recipient_email: str,
        display_name: str,
    ) -> None:
        calls.append(
            {
                "recipient_email": recipient_email,
                "display_name": display_name,
            },
        )

    monkeypatch.setattr(
        auth_routes,
        "send_password_changed_email",
        fake_send_password_changed_email,
    )

    headers = login_headers(client)
    response = client.post(
        "/api/v1/auth/change-password",
        headers=headers,
        json={
            "currentPassword": TEST_SEED_SECRET,
            "newPassword": new_password,
        },
    )

    assert response.status_code == 200
    assert calls == [
        {
            "recipient_email": "marina.costa@touchin.com",
            "display_name": "Marina Costa",
        },
    ]

    login_response = client.post(
        "/api/v1/auth/login",
        json={
            "email": "marina.costa@touchin.com",
            "password": new_password,
            "keepConnected": True,
        },
    )
    assert login_response.status_code == 200
