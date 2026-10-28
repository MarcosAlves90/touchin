import json
from dataclasses import dataclass
from datetime import datetime
from typing import Iterator, Sequence

from sqlalchemy import Select, select
from sqlalchemy.orm import Session

from app.db import ensure_utc
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
        timestamp=ensure_utc(event.timestamp),
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


@dataclass(frozen=True)
class AuditEventFilters:
    start_date: datetime | None = None
    end_date: datetime | None = None
    actor_user_id: str | None = None
    action: str | None = None
    entity_type: str | None = None
    entity_id: str | None = None
    project_id: str | None = None
    result: str | None = None


def build_audit_query(
    *,
    company_id: str,
    filters: AuditEventFilters,
) -> Select[tuple[AuditEvent]]:
    query = select(AuditEvent).where(AuditEvent.company_id == company_id)

    if filters.start_date:
        query = query.where(AuditEvent.timestamp >= filters.start_date)
    if filters.end_date:
        query = query.where(AuditEvent.timestamp < filters.end_date)
    # shortcut: leading-wildcard filters scan tenant audit rows; add a trigram index if volume warrants it.
    if filters.actor_user_id:
        query = query.where(
            AuditEvent.actor_user_id.contains(filters.actor_user_id, autoescape=True)
        )
    if filters.action:
        query = query.where(AuditEvent.action == filters.action)
    if filters.entity_type:
        query = query.where(AuditEvent.entity_type == filters.entity_type)
    if filters.entity_id:
        query = query.where(
            AuditEvent.entity_id.contains(filters.entity_id, autoescape=True)
        )
    if filters.project_id:
        query = query.where(
            AuditEvent.project_id.contains(filters.project_id, autoescape=True)
        )
    if filters.result:
        query = query.where(AuditEvent.result == filters.result)

    return query.order_by(AuditEvent.timestamp.desc(), AuditEvent.id.desc())


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
    query = build_audit_query(
        company_id=company_id,
        filters=AuditEventFilters(
            start_date=start_date,
            end_date=end_date,
            actor_user_id=actor_user_id,
            action=action,
            entity_type=entity_type,
            entity_id=entity_id,
            project_id=project_id,
            result=result,
        ),
    )
    query = query.limit(limit).offset(offset)

    events = db.scalars(query).all()
    return [serialize_audit_event(e) for e in events]


def iter_audit_export_rows(
    db: Session,
    *,
    company_id: str,
    filters: AuditEventFilters,
    batch_size: int = 500,
) -> Iterator[Sequence[object]]:
    query = build_audit_query(company_id=company_id, filters=filters).with_only_columns(
        AuditEvent.timestamp,
        AuditEvent.actor_user_id,
        AuditEvent.action,
        AuditEvent.result,
        AuditEvent.entity_type,
        AuditEvent.entity_id,
        AuditEvent.project_id,
        maintain_column_froms=True,
    )
    result = db.execute(query.execution_options(yield_per=batch_size))
    for row in result:
        yield row
