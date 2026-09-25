import json
import uuid
from typing import Any
from datetime import datetime, timezone
from sqlalchemy.orm import Session
from app.models import AuditEvent

class AuditService:
    @staticmethod
    def log_action(
        db: Session,
        *,
        company_id: str,
        action: str,
        entity_type: str,
        entity_id: str,
        result: str = "success",
        actor_user_id: str | None = None,
        project_id: str | None = None,
        metadata: dict[str, Any] | None = None,
    ) -> AuditEvent:
        sanitized = AuditService._sanitize_metadata(metadata) if metadata else None
        
        event = AuditEvent(
            id=f"evt_{uuid.uuid4().hex}",
            timestamp=datetime.now(timezone.utc),
            company_id=company_id,
            actor_user_id=actor_user_id,
            project_id=project_id,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            result=result,
            metadata_payload=json.dumps(sanitized) if sanitized else None,
            correlation_id=None,
        )
        
        db.add(event)
        return event

    @staticmethod
    def _sanitize_metadata(metadata: dict[str, Any]) -> dict[str, Any]:
        sensitive_keys = {"password", "token", "secret", "authorization"}
        sanitized = {}
        for k, v in metadata.items():
            if k.lower() in sensitive_keys:
                sanitized[k] = "[REDACTED]"
            elif isinstance(v, dict):
                sanitized[k] = AuditService._sanitize_metadata(v)
            else:
                sanitized[k] = v
        return sanitized
