import json
from datetime import datetime
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import AuditEvent
from app.schemas.audit import AuditEventResponse


def serialize_audit_event(event: AuditEvent) -> AuditEventResponse:
    metadata = None
    if event.metadata_payload:
        try:
            metadata = json.loads(event.metadata_payload)
        except Exception:
            pass

    return AuditEventResponse(
        id=event.id,
        timestamp=event.timestamp,
        company_id=event.company_id,
        actor_user_id=event.actor_user_id,
        project_id=event.project_id,
        action=event.action,
        entity_type=event.entity_type,
        entity_id=event.entity_id,
        result=event.result,
        metadata_payload=metadata,
        correlation_id=event.correlation_id,
    )


def list_audit_events(
    db: Session,
    *,
    company_id: str,
    start_date: datetime | None = None,
    end_date: datetime | None = None,
    actor_user_id: str | None = None,
    action: str | None = None,
    entity_type: str | None = None,
    entity_id: str | None = None,
    project_id: str | None = None,
    result: str | None = None,
    limit: int = 50,
    offset: int = 0,
) -> list[AuditEventResponse]:
    query = select(AuditEvent).where(AuditEvent.company_id == company_id)

    if start_date:
        query = query.where(AuditEvent.timestamp >= start_date)
    if end_date:
        query = query.where(AuditEvent.timestamp <= end_date)
    if actor_user_id:
        query = query.where(AuditEvent.actor_user_id == actor_user_id)
    if action:
        query = query.where(AuditEvent.action == action)
    if entity_type:
        query = query.where(AuditEvent.entity_type == entity_type)
    if entity_id:
        query = query.where(AuditEvent.entity_id == entity_id)
    if project_id:
        query = query.where(AuditEvent.project_id == project_id)
    if result:
        query = query.where(AuditEvent.result == result)

    query = query.order_by(AuditEvent.timestamp.desc(), AuditEvent.id.desc())
    query = query.limit(limit).offset(offset)

    events = db.scalars(query).all()
    return [serialize_audit_event(e) for e in events]
