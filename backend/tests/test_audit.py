import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.db import get_db
from app.models import AuditEvent, UserAccount, Company

client = TestClient(app)

def test_audit_list_tenant_isolation(db_session, setup_test_db):
    # setup_test_db might have pre-created things, let's create a specific user/company
    company1 = Company(id="comp_audit_1", name="Company 1")
    company2 = Company(id="comp_audit_2", name="Company 2")
    db_session.add(company1)
    db_session.add(company2)
    db_session.commit()

    user1 = UserAccount(id="user_audit_1", email="a1@test.com", password_hash="hash", company_id="comp_audit_1", name="U1")
    user2 = UserAccount(id="user_audit_2", email="a2@test.com", password_hash="hash", company_id="comp_audit_2", name="U2")
    db_session.add(user1)
    db_session.add(user2)
    db_session.commit()

    evt1 = AuditEvent(
        id="evt_audit_1", company_id="comp_audit_1", action="test", 
        entity_type="test", entity_id="test", result="success"
    )
    evt2 = AuditEvent(
        id="evt_audit_2", company_id="comp_audit_2", action="test", 
        entity_type="test", entity_id="test", result="success"
    )
    db_session.add(evt1)
    db_session.add(evt2)
    db_session.commit()

    # Wait, we need a valid token to make API requests!
    # Let's bypass token auth by overriding dependencies or create a token!
    from app.services.auth import create_access_token
    
    token1 = create_access_token(user_id="user_audit_1", company_id="comp_audit_1")
    
    response = client.get("/api/v1/audit", headers={"Authorization": f"Bearer {token1}"})
    
    # If the user does not have permission, it returns 403.
    # We must give them the permission! Or test the failure semantics first.
    assert response.status_code == 403

    # Add permission
    from app.models import Role, RolePermission
    role = Role(id="role_audit_1", company_id="comp_audit_1", name="Admin")
    db_session.add(role)
    db_session.commit()
    
    db_session.add(RolePermission(role_id="role_audit_1", permission_name="audit.read"))
    user1.role_id = "role_audit_1"
    db_session.commit()
    
    response = client.get("/api/v1/audit", headers={"Authorization": f"Bearer {token1}"})
    assert response.status_code == 200
    data = response.json()
    
    # Should only see evt_audit_1, not evt_audit_2
    ids = [e["id"] for e in data]
    assert "evt_audit_1" in ids
    assert "evt_audit_2" not in ids
