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
    def _sanitize_metadata(metadata: Any) -> Any:
        sensitive_keys = {"password", "token", "secret", "authorization", "access_token", "refresh_token", "api_key"}
        if isinstance(metadata, dict):
            sanitized = {}
            for k, v in metadata.items():
                if any(sk in k.lower() for sk in sensitive_keys):
                    sanitized[k] = "[REDACTED]"
                else:
                    sanitized[k] = AuditService._sanitize_metadata(v)
            return sanitized
        elif isinstance(metadata, list):
            return [AuditService._sanitize_metadata(item) for item in metadata]
        else:
            return metadata
