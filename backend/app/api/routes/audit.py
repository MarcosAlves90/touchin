from __future__ import annotations

from datetime import datetime
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.authorization import require_permission
from app.dependencies import get_db
from app.services.auth import AuthenticatedContext
from app.schemas.audit import AuditEventResponse 
from app.domain.audit_read import list_audit_events

router = APIRouter()

@router.get("", response_model=list[AuditEventResponse])
def list_audit_events_route(
    start_date: datetime | None = Query(None),
    end_date: datetime | None = Query(None),
    actor_user_id: str | None = Query(None),
    action: str | None = Query(None),
    entity_type: str | None = Query(None),
    entity_id: str | None = Query(None),
    project_id: str | None = Query(None),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    context: AuthenticatedContext = Depends(require_permission("audit.read")),
    db: Session = Depends(get_db),
) -> list[AuditEventResponse]:
    return list_audit_events(
        db,
        company_id=context.company.id,
        start_date=start_date,
        end_date=end_date,
        actor_user_id=actor_user_id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        project_id=project_id,
        limit=limit,
        offset=(page - 1) * limit,
    )
