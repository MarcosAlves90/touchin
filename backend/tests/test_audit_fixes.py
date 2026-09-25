from app.services.audit import AuditService
from app.models import AuditEvent, UserAccount, Company, Employee
from app.db import SessionLocal
import pytest
from datetime import datetime, timezone
import uuid

def test_sanitize_metadata():
    metadata = {
        "access_token": "secret123",
        "nested": {
            "refresh_token": "refresh123",
            "normal": "value"
        },
        "list_of_dicts": [
            {"api_key": "key123", "safe": "1"},
            {"secret_stuff": "dont_redact", "authorization": "Bearer token"}
        ]
    }
    
    sanitized = AuditService._sanitize_metadata(metadata)
    
    assert sanitized["access_token"] == "[REDACTED]"
    assert sanitized["nested"]["refresh_token"] == "[REDACTED]"
    assert sanitized["nested"]["normal"] == "value"
    assert sanitized["list_of_dicts"][0]["api_key"] == "[REDACTED]"
    assert sanitized["list_of_dicts"][0]["safe"] == "1"
    assert sanitized["list_of_dicts"][1]["secret_stuff"] == "[REDACTED]"
    assert sanitized["list_of_dicts"][1]["authorization"] == "[REDACTED]"

def test_actor_identity_preserved_on_delete(client):
    with SessionLocal() as db_session:
        # Get the seeded company and user
        company = db_session.query(Company).first()
        admin_user = db_session.query(UserAccount).first()
        admin_user_id = admin_user.id
        
        # Create an audit event with the admin_user
        event = AuditService.log_action(
            db_session,
            company_id=company.id,
            action="test.action",
            entity_type="test",
            entity_id="123",
            actor_user_id=admin_user.id
        )
        db_session.commit()
        
        # Delete the user account
        db_session.delete(admin_user)
        db_session.commit()
        
        # Refresh the event, actor_user_id should NOT be null
        db_session.refresh(event)
        assert event.actor_user_id is not None
        assert event.actor_user_id == admin_user_id
