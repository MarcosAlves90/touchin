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

def test_sqlite_legacy_schema_migration_preserves_actor_id():
    from sqlalchemy import create_engine, text, inspect
    from app.database_schema import _upgrade_audit_events
    
    engine = create_engine("sqlite:///:memory:")
    
    with engine.begin() as conn:
        # Create legacy schema
        conn.execute(text("CREATE TABLE companies (id VARCHAR(64) PRIMARY KEY)"))
        conn.execute(text("CREATE TABLE user_accounts (id VARCHAR(64) PRIMARY KEY)"))
        conn.execute(text("CREATE TABLE projects (id VARCHAR(64) PRIMARY KEY)"))
        conn.execute(text("""
            CREATE TABLE audit_events (
                id VARCHAR(64) PRIMARY KEY,
                timestamp DATETIME,
                company_id VARCHAR(64) REFERENCES companies(id) ON DELETE CASCADE,
                actor_user_id VARCHAR(64) REFERENCES user_accounts(id) ON DELETE SET NULL,
                project_id VARCHAR(64) REFERENCES projects(id) ON DELETE CASCADE,
                action VARCHAR(128) NOT NULL,
                entity_type VARCHAR(64) NOT NULL,
                entity_id VARCHAR(64) NOT NULL,
                result VARCHAR(32) NOT NULL,
                metadata_payload TEXT,
                correlation_id VARCHAR(64)
            )
        """))
        
        # Insert data
        conn.execute(text("INSERT INTO companies (id) VALUES ('comp1')"))
        conn.execute(text("INSERT INTO user_accounts (id) VALUES ('user1')"))
        conn.execute(text("INSERT INTO audit_events (id, company_id, actor_user_id, action, entity_type, entity_id, result) VALUES ('evt1', 'comp1', 'user1', 'action1', 'type1', 'ent1', 'success')"))

    # Upgrade schema
    _upgrade_audit_events(engine, inspect(engine))
    
    with engine.begin() as conn:
        conn.execute(text("PRAGMA foreign_keys=on;"))
        conn.execute(text("DELETE FROM user_accounts WHERE id='user1'"))
        result = conn.execute(text("SELECT actor_user_id FROM audit_events WHERE id='evt1'")).scalar()
        
    assert result == 'user1'
