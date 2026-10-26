from __future__ import annotations

import tempfile
from collections.abc import Iterator
from datetime import datetime, timezone
from typing import BinaryIO

from fastapi import APIRouter, Depends, Query
from fastapi.responses import StreamingResponse
from sqlalchemy.orm import Session

from app.authorization import require_permission
from app.dependencies import get_db
from app.services.auth import AuthenticatedContext
from app.schemas.audit import AuditEventResponse
from app.domain.audit_read import (
    AuditEventFilters,
    iter_audit_export_rows,
    list_audit_events,
)
from app.services.audit_export import write_audit_csv

router = APIRouter()


def audit_event_filters(
    start_date: datetime | None = Query(None),
    end_date: datetime | None = Query(None),
    actor_user_id: str | None = Query(None),
    action: str | None = Query(None),
    entity_type: str | None = Query(None),
    entity_id: str | None = Query(None),
    project_id: str | None = Query(None),
    result: str | None = Query(None),
) -> AuditEventFilters:
    return AuditEventFilters(
        start_date=start_date,
        end_date=end_date,
        actor_user_id=actor_user_id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        project_id=project_id,
        result=result,
    )


@router.get("", response_model=list[AuditEventResponse])
def list_audit_events_route(
    filters: AuditEventFilters = Depends(audit_event_filters),
    page: int = Query(1, ge=1),
    limit: int = Query(50, ge=1, le=100),
    context: AuthenticatedContext = Depends(require_permission("audit.read")),
    db: Session = Depends(get_db),
) -> list[AuditEventResponse]:
    return list_audit_events(
        db,
        company_id=context.company.id,
        start_date=filters.start_date,
        end_date=filters.end_date,
        actor_user_id=filters.actor_user_id,
        action=filters.action,
        entity_type=filters.entity_type,
        entity_id=filters.entity_id,
        project_id=filters.project_id,
        result=filters.result,
        limit=limit,
        offset=(page - 1) * limit,
    )


def _materialize_audit_export(
    db: Session,
    *,
    company_id: str,
    filters: AuditEventFilters,
) -> tuple[BinaryIO, int]:
    """Write the scoped export to a bounded-memory spool.

    Materializing the same iterator that is streamed to the client makes the
    row-count header and the "no data" decision deterministic. Large exports
    spill to disk, so server memory remains bounded.
    """
    spool = tempfile.SpooledTemporaryFile(max_size=4 * 1024 * 1024, mode="w+b")
    try:
        row_count = write_audit_csv(
            iter_audit_export_rows(db, company_id=company_id, filters=filters),
            spool,
        )
        spool.seek(0)
    except Exception:
        spool.close()
        raise
    return spool, row_count


def _stream_spool(spool: BinaryIO) -> Iterator[bytes]:
    try:
        while chunk := spool.read(64 * 1024):
            yield chunk
    finally:
        spool.close()


@router.get("/export")
def export_audit_events_route(
    filters: AuditEventFilters = Depends(audit_event_filters),
    context: AuthenticatedContext = Depends(require_permission("audit.read")),
    db: Session = Depends(get_db),
) -> StreamingResponse:
    spool, row_count = _materialize_audit_export(
        db,
        company_id=context.company.id,
        filters=filters,
    )
    filename = f"audit-events-{datetime.now(timezone.utc):%Y%m%dT%H%M%SZ}.csv"

    return StreamingResponse(
        _stream_spool(spool),
        media_type="text/csv; charset=utf-8",
        headers={
            "Content-Disposition": f'attachment; filename="{filename}"',
            "Cache-Control": "no-store",
            "X-Content-Type-Options": "nosniff",
            "X-Audit-Export-Rows": str(row_count),
        },
    )
