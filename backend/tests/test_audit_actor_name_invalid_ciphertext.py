from __future__ import annotations

from datetime import datetime, timezone

from app.config import get_settings
from app.crypto import FieldCipher, lookup_digest
from app.db import SessionLocal
from app.domain.identity import normalize_email
from app.models import AuditEvent, Company, Employee, UserAccount
from app.security import hash_password
from app.seed import MARINA_EMAIL
from tests.test_audit import login_headers

_ENTITY_PREFIX = "audit-invalid-actor-name-regression"
_BAD_USER_ID = "usr_audit_invalid_name"
_GOOD_USER_ID = "usr_audit_valid_name"
_BAD_EVENT_ID = "evt_audit_invalid_name"
_GOOD_EVENT_ID = "evt_audit_valid_name"
_GOOD_NAME = "Nome Válido Isolado"


def test_audit_list_survives_invalid_actor_name_ciphertext(client):
    headers = login_headers(client, MARINA_EMAIL)
    settings = get_settings()
    secret = settings.encryption_secret or ""
    cipher = FieldCipher(secret)

    with SessionLocal() as db:
        company = db.query(Company).first()
        assert company is not None

        for user_id, employee_id, email, name_ciphertext in (
            (
                _BAD_USER_ID,
                "emp_audit_invalid_name",
                "invalid.actor.name@example.com",
                "definitely-not-a-fernet-token",
            ),
            (
                _GOOD_USER_ID,
                "emp_audit_valid_name",
                "valid.actor.name@example.com",
                cipher.encrypt(_GOOD_NAME),
            ),
        ):
            email_hash = lookup_digest(normalize_email(email), secret)
            db.add(
                Employee(
                    id=employee_id,
                    company_id=company.id,
                    name_ciphertext=name_ciphertext,
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
            )
            db.add(
                UserAccount(
                    id=user_id,
                    company_id=company.id,
                    employee_id=employee_id,
                    email_ciphertext=cipher.encrypt(email),
                    email_hash=email_hash,
                    password_hash=hash_password("Password123!"),
                    role="employee",
                    is_active=True,
                )
            )

        db.add_all(
            [
                AuditEvent(
                    id=_BAD_EVENT_ID,
                    company_id=company.id,
                    actor_user_id=_BAD_USER_ID,
                    action="actor.name.regression",
                    entity_type="test",
                    entity_id=f"{_ENTITY_PREFIX}-bad",
                    result="success",
                    timestamp=datetime.now(timezone.utc),
                ),
                AuditEvent(
                    id=_GOOD_EVENT_ID,
                    company_id=company.id,
                    actor_user_id=_GOOD_USER_ID,
                    action="actor.name.regression",
                    entity_type="test",
                    entity_id=f"{_ENTITY_PREFIX}-good",
                    result="success",
                    timestamp=datetime.now(timezone.utc),
                ),
            ]
        )
        db.commit()

    response = client.get(
        "/api/v1/audit-events",
        headers=headers,
        params={"entity_id": _ENTITY_PREFIX},
    )
    assert response.status_code == 200, response.text

    events = {event["id"]: event for event in response.json()}
    assert set(events) == {_BAD_EVENT_ID, _GOOD_EVENT_ID}
    assert events[_BAD_EVENT_ID]["actor_user_id"] == _BAD_USER_ID
    assert events[_BAD_EVENT_ID]["actor_name"] is None
    assert events[_GOOD_EVENT_ID]["actor_user_id"] == _GOOD_USER_ID
    assert events[_GOOD_EVENT_ID]["actor_name"] == _GOOD_NAME
