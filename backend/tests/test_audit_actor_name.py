from __future__ import annotations

from datetime import datetime, timezone

from app.db import SessionLocal
from app.models import AuditEvent, Company, Employee, UserAccount
from app.seed import MARINA_EMAIL
from tests.test_audit import login_headers


def _company_id() -> str:
    with SessionLocal() as db:
        company = db.query(Company).first()
        assert company is not None
        return company.id


def test_audit_list_returns_actor_name_for_known_user(client):
    headers = login_headers(client, MARINA_EMAIL)
    company_id = _company_id()
    with SessionLocal() as db:
        admin = db.query(UserAccount).filter(UserAccount.role == "admin").first()
        assert admin is not None
        actor_id = admin.id
        db.add(
            AuditEvent(
                id="evt_actor_name_known",
                company_id=company_id,
                actor_user_id=actor_id,
                action="actor.name.test",
                entity_type="test",
                entity_id="known",
                result="success",
                timestamp=datetime.now(timezone.utc),
            )
        )
        db.commit()

    response = client.get(
        "/api/v1/audit-events",
        headers=headers,
        params={"entity_id": "known"},
    )
    assert response.status_code == 200, response.text
    events = response.json()
    assert len(events) == 1
    event = events[0]
    assert event["actor_user_id"] == actor_id
    assert event["actor_name"] == "Marina Costa"


def test_audit_list_returns_safe_fallback_for_removed_user(client):
    headers = login_headers(client, MARINA_EMAIL)
    company_id = _company_id()
    with SessionLocal() as db:
        company = db.get(Company, company_id)
        assert company is not None
        # create a disposable user + employee, log event, then delete user
        from app.config import get_settings
        from app.crypto import FieldCipher, lookup_digest
        from app.domain.identity import normalize_email
        from app.security import hash_password

        settings = get_settings()
        cipher = FieldCipher(settings.encryption_secret or "")
        email = "removed.actor@example.com"
        email_hash = lookup_digest(
            normalize_email(email), settings.encryption_secret or ""
        )
        employee = Employee(
            id="emp_removed_actor",
            company_id=company_id,
            name_ciphertext=cipher.encrypt("Usuário Removido"),
            role_ciphertext=cipher.encrypt("Analista"),
            department_ciphertext=cipher.encrypt("TI"),
            email_ciphertext=cipher.encrypt(email),
            email_hash=email_hash,
            phone_ciphertext=cipher.encrypt("11999999999"),
            unit_ciphertext=cipher.encrypt("HQ"),
            expected_shift_ciphertext=cipher.encrypt("09:00-18:00"),
            status="active",
            work_mode="remote",
            role_level="employee",
            notes_ciphertext=cipher.encrypt(""),
        )
        user = UserAccount(
            id="usr_removed_actor",
            company_id=company_id,
            employee_id=employee.id,
            email_ciphertext=cipher.encrypt(email),
            email_hash=email_hash,
            password_hash=hash_password("Password123!"),
            role="employee",
            is_active=True,
        )
        db.add(employee)
        db.add(user)
        db.flush()
        db.add(
            AuditEvent(
                id="evt_actor_removed",
                company_id=company_id,
                actor_user_id=user.id,
                action="actor.removed.test",
                entity_type="test",
                entity_id="removed-actor",
                result="success",
                timestamp=datetime.now(timezone.utc),
            )
        )
        db.commit()

        db.delete(user)
        db.commit()

    response = client.get(
        "/api/v1/audit-events",
        headers=headers,
        params={"entity_id": "removed-actor"},
    )
    assert response.status_code == 200, response.text
    events = response.json()
    assert len(events) == 1
    event = events[0]
    assert event["actor_user_id"] == "usr_removed_actor"
    # Must not invent names; unknown/removed actor should have no resolved name.
    assert event["actor_name"] is None


def test_audit_list_system_event_has_no_actor_name(client):
    headers = login_headers(client, MARINA_EMAIL)
    company_id = _company_id()
    with SessionLocal() as db:
        db.add(
            AuditEvent(
                id="evt_actor_system",
                company_id=company_id,
                actor_user_id=None,
                action="system.test",
                entity_type="test",
                entity_id="system-actor",
                result="success",
                timestamp=datetime.now(timezone.utc),
            )
        )
        db.commit()

    response = client.get(
        "/api/v1/audit-events",
        headers=headers,
        params={"entity_id": "system-actor"},
    )
    assert response.status_code == 200, response.text
    event = response.json()[0]
    assert event["actor_user_id"] is None
    assert event["actor_name"] is None
