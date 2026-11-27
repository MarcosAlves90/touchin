from __future__ import annotations

import json
import logging
from contextlib import closing
from dataclasses import dataclass
from datetime import datetime
from functools import lru_cache
from itertools import islice
from typing import Iterator, Sequence
from unicodedata import category, normalize

from cryptography.fernet import InvalidToken
from sqlalchemy import Select, and_, case, or_, select
from sqlalchemy.orm import Session, aliased

from app.config import get_settings
from app.crypto import FieldCipher
from app.db import ensure_utc
from app.models import AuditEvent, Company, Employee, KanbanColumn, Project, Task, UserAccount
from app.schemas.audit import AuditEventResponse

logger = logging.getLogger(__name__)


@dataclass(frozen=True)
class _AuditNames:
    actor: str | None
    entity: str | None
    project: str | None


def serialize_audit_event(
    event: AuditEvent, *, names: _AuditNames
) -> AuditEventResponse:
    metadata = None
    if event.metadata_payload:
        try:
            decoded = json.loads(event.metadata_payload)
            if isinstance(decoded, dict):
                metadata = decoded
        except (ValueError, TypeError):
            pass

    return AuditEventResponse(
        id=event.id,
        timestamp=ensure_utc(event.timestamp),
        company_id=event.company_id,
        actor_user_id=event.actor_user_id,
        actor_name=names.actor,
        project_id=event.project_id,
        project_name=names.project,
        action=event.action,
        entity_type=event.entity_type,
        entity_id=event.entity_id,
        entity_name=names.entity,
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

    def text_terms(self) -> tuple[str, str, str]:
        return (
            (self.actor_user_id or "").strip(),
            (self.entity_id or "").strip(),
            (self.project_id or "").strip(),
        )


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
    if filters.action:
        query = query.where(AuditEvent.action == filters.action)
    if filters.entity_type:
        query = query.where(AuditEvent.entity_type == filters.entity_type)
    if filters.result:
        query = query.where(AuditEvent.result == filters.result)
    return query.order_by(AuditEvent.timestamp.desc(), AuditEvent.id.desc())


def _add_named_columns(query, event, terms: tuple[str, str, str]):
    author = aliased(Employee)
    entity_employee = aliased(Employee)
    project = aliased(Project)
    entity_project = aliased(Project)
    card_project = aliased(Project)
    column_project = aliased(Project)
    actor_label = author.name_ciphertext
    # Only select card or column names when the referenced object's owning
    # project belongs to the same tenant. Each join is to a unique ID.
    entity_label = case(
        (event.entity_type == "employee", entity_employee.name_ciphertext),
        (event.entity_type == "project", entity_project.name_ciphertext),
        (card_project.id.is_not(None), Task.name_ciphertext),
        (column_project.id.is_not(None), KanbanColumn.name_ciphertext),
        (Company.id.is_not(None), Company.trade_name_ciphertext),
        else_=None,
    )
    project_label = project.name_ciphertext
    query = (
        query.add_columns(actor_label, entity_label, project_label)
        .outerjoin(UserAccount, and_(
            UserAccount.id == event.actor_user_id,
            UserAccount.company_id == event.company_id,
        ))
        .outerjoin(author, and_(
            author.id == UserAccount.employee_id,
            author.company_id == event.company_id,
        ))
        .outerjoin(project, and_(
            project.id == event.project_id,
            project.company_id == event.company_id,
        ))
        .outerjoin(entity_employee, and_(
            event.entity_type == "employee",
            entity_employee.id == event.entity_id,
            entity_employee.company_id == event.company_id,
        ))
        .outerjoin(entity_project, and_(
            event.entity_type == "project",
            entity_project.id == event.entity_id,
            entity_project.company_id == event.company_id,
        ))
        .outerjoin(Task, and_(
            event.entity_type.in_(("card", "task")),
            Task.id == event.entity_id,
        ))
        .outerjoin(card_project, and_(
            card_project.id == Task.project_id,
            card_project.company_id == event.company_id,
        ))
        .outerjoin(KanbanColumn, and_(
            event.entity_type == "kanban_column",
            KanbanColumn.id == event.entity_id,
        ))
        .outerjoin(column_project, and_(
            column_project.id == KanbanColumn.project_id,
            column_project.company_id == event.company_id,
        ))
        .outerjoin(Company, and_(
            event.entity_type == "company_ai_settings",
            Company.id == event.entity_id,
            Company.id == event.company_id,
        ))
    )
    # An event without a resolvable name can only match by literal ID. Let
    # SQL discard those non-matches before examining encrypted names.
    for term, identifier, label in zip(
        terms,
        (event.actor_user_id, event.entity_id, event.project_id),
        (actor_label, entity_label, project_label),
        strict=True,
    ):
        if term:
            query = query.where(or_(label.is_not(None), identifier.icontains(term, autoescape=True)))
    return query


def _normalize_name(value: str) -> str:
    folded = normalize("NFKD", value.casefold())
    return " ".join("".join(char for char in folded if not category(char).startswith("M")).split())


def _matches_term(
    term: str, normalized_term: str, identifier: str | None, display_name: str | None
) -> bool:
    return (
        not term
        or (identifier is not None and term.casefold() in identifier.casefold())
        or (bool(normalized_term) and display_name is not None
            and normalized_term in _normalize_name(display_name))
    )


def _iter_named_audit_events(
    db: Session,
    *,
    company_id: str,
    filters: AuditEventFilters,
    limit: int | None = None,
    offset: int = 0,
    batch_size: int = 500,
) -> Iterator[tuple[AuditEvent, _AuditNames]]:
    terms = filters.text_terms()
    search = any(terms)
    normalized_terms = tuple(_normalize_name(term) for term in terms)
    query = build_audit_query(company_id=company_id, filters=filters)
    event = AuditEvent
    if not search:
        # Resolve names for just this page when SQL can paginate first.
        event = aliased(AuditEvent, query.limit(limit).offset(offset).subquery())
        query = select(event).order_by(event.timestamp.desc(), event.id.desc())
    query = _add_named_columns(query, event, terms)
    cipher = FieldCipher(get_settings().encryption_secret or "")
    invalid_names = 0

    @lru_cache(maxsize=2048)
    def display_name(ciphertext: str | None) -> str | None:
        nonlocal invalid_names
        if not ciphertext:
            return None
        try:
            return (cipher.decrypt(ciphertext) or "").strip() or None
        except (InvalidToken, UnicodeError):
            # An optional corrupt name must not suppress the event or ID search.
            invalid_names += 1
            return None

    if limit is not None:
        batch_size = min(batch_size, limit) or 1
    result = db.execute(query.execution_options(yield_per=batch_size))
    try:
        for event, actor_ciphertext, entity_ciphertext, project_ciphertext in result:
            names = _AuditNames(
                display_name(actor_ciphertext),
                display_name(entity_ciphertext),
                display_name(project_ciphertext),
            )
            if search and not all(
                _matches_term(term, normalized_term, identifier, name)
                for term, normalized_term, identifier, name in zip(
                    terms,
                    normalized_terms,
                    (event.actor_user_id, event.entity_id, event.project_id),
                    (names.actor, names.entity, names.project),
                    strict=True,
                )
            ):
                continue
            yield event, names
    finally:
        result.close()
        if invalid_names:
            logger.warning(
                "Skipped %d undecryptable optional audit name value(s); audit events preserved.",
                invalid_names,
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
    filters = AuditEventFilters(
        start_date=start_date,
        end_date=end_date,
        actor_user_id=actor_user_id,
        action=action,
        entity_type=entity_type,
        entity_id=entity_id,
        project_id=project_id,
        result=result,
    )
    with closing(_iter_named_audit_events(
        db, company_id=company_id, filters=filters, limit=limit, offset=offset
    )) as events:
        # Ciphertext comparisons cannot implement partial name matching. Filter
        # incrementally, count only matches, and stop once this page is full.
        page = islice(events, offset, offset + limit) if any(filters.text_terms()) else events
        return [serialize_audit_event(event, names=names) for event, names in page]


def iter_audit_export_rows(
    db: Session,
    *,
    company_id: str,
    filters: AuditEventFilters,
    batch_size: int = 500,
) -> Iterator[Sequence[object]]:
    if any(filters.text_terms()):
        with closing(_iter_named_audit_events(
            db, company_id=company_id, filters=filters, batch_size=batch_size
        )) as events:
            for event, _ in events:
                yield (
                    event.timestamp, event.actor_user_id, event.action, event.result,
                    event.entity_type, event.entity_id, event.project_id,
                )
        return

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
    try:
        yield from result
    finally:
        result.close()
