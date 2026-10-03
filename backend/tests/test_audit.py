from __future__ import annotations

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

def test_audit_list_tenant_isolation(client):
    with SessionLocal() as db:
        # Get existing company and admin user (marina)
        company1 = db.query(Company).first()
        assert company1 is not None
        
        # Create a second company manually (bypassing strict crypto/fields for raw sql or just using an endpoint)
        # Actually, let's just insert an audit event for company1 and an audit event for a fake company
        from datetime import datetime, timezone
        evt1 = AuditEvent(
            id="evt_audit_1", company_id=company1.id, action="test_action", 
            entity_type="test", entity_id="test", result="success",
            timestamp=datetime.now(timezone.utc)
        )
        evt2 = AuditEvent(
            id="evt_audit_2", company_id="comp_fake", action="test_action", 
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
