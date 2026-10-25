from __future__ import annotations

from datetime import datetime, timedelta, timezone

import pytest
from sqlalchemy import text
from app.db import SessionLocal
from app.models import AuditEvent, UserAccount, Company
from app.seed import MARINA_EMAIL, CAIO_EMAIL

def login_headers(client, email):
    from app.config import get_settings
    response = client.post(
        "/api/v1/auth/login",
        json={
            "email": email,
            "password": get_settings().seed_admin_password,
            "keepConnected": True,
        },
    )
    assert response.status_code == 200
    token = response.json()["accessToken"]
    return {"Authorization": f"Bearer {token}"}


def test_audit_end_date_is_exclusive_at_next_day_utc_boundary(client):
    headers = login_headers(client, MARINA_EMAIL)
    with SessionLocal() as db:
        company = db.query(Company).first()
        assert company is not None
        boundary = datetime(2026, 3, 9, tzinfo=timezone.utc)
        start_boundary = datetime(2026, 3, 8, tzinfo=timezone.utc)
        db.add_all(
            [
                AuditEvent(
                    id="evt_at_start_boundary",
                    company_id=company.id,
                    action="boundary.test",
                    entity_type="test",
                    entity_id="at_start",
                    result="success",
                    timestamp=start_boundary,
                ),
                AuditEvent(
                    id="evt_before_end_boundary",
                    company_id=company.id,
                    action="boundary.test",
                    entity_type="test",
                    entity_id="before",
                    result="success",
                    timestamp=boundary - timedelta(microseconds=1),
                ),
                AuditEvent(
                    id="evt_at_end_boundary",
                    company_id=company.id,
                    action="boundary.test",
                    entity_type="test",
                    entity_id="at",
                    result="success",
                    timestamp=boundary,
                ),
            ]
        )
        db.commit()

    response = client.get(
        "/api/v1/audit-events",
        headers=headers,
        params={
            "start_date": "2026-03-08T00:00:00Z",
            "end_date": "2026-03-09T00:00:00Z",
        },
    )
    assert response.status_code == 200, response.text
    ids = {event["id"] for event in response.json()}
    assert "evt_at_start_boundary" in ids
    assert "evt_before_end_boundary" in ids
    assert "evt_at_end_boundary" not in ids

def test_audit_list_tenant_isolation(client):
    with SessionLocal() as db:
        # Isolated companies must both be valid referenced entities when SQLite
        # enforces the same foreign keys used by PostgreSQL.
        company1 = db.query(Company).first()
        assert company1 is not None
        company2 = Company(
            id="comp_audit_other",
            legal_name_ciphertext=company1.legal_name_ciphertext,
            trade_name_ciphertext=company1.trade_name_ciphertext,
            cnpj_ciphertext=company1.cnpj_ciphertext,
            cnpj_hash="audit-tenant-other-cnpj-hash",
            contact_email_ciphertext=company1.contact_email_ciphertext,
            contact_email_hash="audit-tenant-other-email-hash",
            contact_phone_ciphertext=company1.contact_phone_ciphertext,
            consented_at=datetime.now(timezone.utc),
        )
        db.add(company2)
        db.flush()
        evt1 = AuditEvent(
            id="evt_audit_1", company_id=company1.id, action="test_action", 
            entity_type="test", entity_id="test", result="success",
            timestamp=datetime.now(timezone.utc)
        )
        evt2 = AuditEvent(
            id="evt_audit_2", company_id=company2.id, action="test_action",
            entity_type="test", entity_id="test", result="success",
            timestamp=datetime.now(timezone.utc)
        )
        db.add(evt1)
        db.add(evt2)
        db.commit()

    # Marina is admin, she has audit.read permission.
    headers_admin = login_headers(client, MARINA_EMAIL)
    response = client.get("/api/v1/audit-events", headers=headers_admin)
    
    assert response.status_code == 200
    data = response.json()
    
    # Should only see evt_audit_1, not evt_audit_2
    ids = [e["id"] for e in data]
    assert "evt_audit_1" in ids
    assert "evt_audit_2" not in ids

def test_audit_list_unauthorized(client):
    # Caio is manager, he does NOT have audit.read by default (unless we gave it to him)
    # Let's check his access.
    headers_manager = login_headers(client, CAIO_EMAIL)
    response = client.get("/api/v1/audit-events", headers=headers_manager)
    
    # If managers don't have it, should be 403.
    # If they do, then this assert fails and we need a standard employee (Joao).
    if response.status_code == 200:
        from app.seed import JOAO_EMAIL
        headers_employee = login_headers(client, JOAO_EMAIL)
        resp_emp = client.get("/api/v1/audit-events", headers=headers_employee)
        assert resp_emp.status_code == 403
    else:
        assert response.status_code == 403
