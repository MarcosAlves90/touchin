from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session

from app.db import begin_serialized_write
from app.domain.kanban_read import get_kanban_board
from app.domain.project_read import cipher
from app.errors import DomainError, ErrorKind
from app.models import KanbanColumn, Project, Task
from app.schemas.kanban import (
    KanbanBoardResponse,
    KanbanCardOrderPayload,
    KanbanColumnMutation,
    KanbanColumnOrderPayload,
)


def _locked_project_or_404(db: Session, *, company_id: str, project_id: str) -> Project:
    query = select(Project).where(Project.company_id == company_id, Project.id == project_id)
    if db.bind is not None and db.bind.dialect.name != "sqlite":
        query = query.with_for_update()
    project = db.scalar(query)
    if project is None:
        raise DomainError(ErrorKind.not_found, "Project not found.")
    return project


def _check_version(project: Project, expected_version: int) -> None:
    if project.kanban_version != expected_version:
        raise DomainError(
            ErrorKind.conflict,
            f"Kanban version conflict: expected {expected_version}, current {project.kanban_version}.",
        )


def _column_or_404(db: Session, *, project_id: str, column_id: str) -> KanbanColumn:
    column = db.scalar(
        select(KanbanColumn).where(
            KanbanColumn.project_id == project_id,
            KanbanColumn.id == column_id,
        ),
    )
    if column is None:
        raise DomainError(ErrorKind.not_found, "Kanban column not found.")
    return column


def create_column(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    payload: KanbanColumnMutation,
    actor_user_id: str | None = None,
) -> KanbanBoardResponse:
    from app.services.audit import AuditService
    begin_serialized_write(db)
    project = _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    _check_version(project, payload.expected_version)
    max_position = db.scalar(
        select(func.max(KanbanColumn.position)).where(KanbanColumn.project_id == project.id),
    )
    field_cipher = cipher()
    column = KanbanColumn(
        project_id=project.id,
        name_ciphertext=field_cipher.encrypt(payload.name) or "",
        position=0 if max_position is None else int(max_position) + 1,
    )
    db.add(column)
    project.kanban_version += 1
    db.flush()
    AuditService.log_action(
        db, company_id=company_id, actor_user_id=actor_user_id,
        action="kanban.column_created", entity_type="kanban_column", entity_id=column.id, project_id=project.id,
        result="success", metadata={"position": column.position}
    )
    db.commit()
    return get_kanban_board(db, company_id=company_id, project_id=project_id)


def rename_column(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    column_id: str,
    payload: KanbanColumnMutation,
    actor_user_id: str | None = None,
) -> KanbanBoardResponse:
    from app.services.audit import AuditService
    begin_serialized_write(db)
    project = _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    _check_version(project, payload.expected_version)
    column = _column_or_404(db, project_id=project.id, column_id=column_id)
    field_cipher = cipher()
    name_changed = field_cipher.decrypt(column.name_ciphertext) != payload.name
    column.name_ciphertext = field_cipher.encrypt(payload.name) or ""
    project.kanban_version += 1
    if name_changed:
        AuditService.log_action(
            db, company_id=company_id, actor_user_id=actor_user_id,
            action="kanban.column_updated", entity_type="kanban_column", entity_id=column.id, project_id=project.id,
            result="success", metadata={"changedFields": ["name"]}
        )
    db.commit()
    return get_kanban_board(db, company_id=company_id, project_id=project_id)


def reorder_columns(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    payload: KanbanColumnOrderPayload,
    actor_user_id: str | None = None,
) -> KanbanBoardResponse:
    from app.services.audit import AuditService
    begin_serialized_write(db)
    project = _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    _check_version(project, payload.expected_version)
    columns = db.scalars(
        select(KanbanColumn).where(KanbanColumn.project_id == project.id),
    ).all()
    by_id = {column.id: column for column in columns}
    if len(payload.column_ids) != len(set(payload.column_ids)):
        raise DomainError(ErrorKind.bad_request, "Column order contains duplicate IDs.")
    if set(payload.column_ids) != set(by_id):
        raise DomainError(ErrorKind.bad_request, "Column order must include every project column.")
    old_positions = {column.id: column.position for column in columns}
    for position, column_id in enumerate(payload.column_ids):
        by_id[column_id].position = position
    project.kanban_version += 1
    for position, column_id in enumerate(payload.column_ids):
        previous_position = old_positions[column_id]
        if previous_position == position:
            continue
        AuditService.log_action(
            db,
            company_id=company_id,
            actor_user_id=actor_user_id,
            action="kanban.column_reordered",
            entity_type="kanban_column",
            entity_id=column_id,
            project_id=project.id,
            result="success",
            metadata={
                "fromPosition": previous_position,
                "toPosition": position,
            },
        )
    db.commit()
    return get_kanban_board(db, company_id=company_id, project_id=project_id)


def delete_column(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    column_id: str,
    expected_version: int,
    actor_user_id: str | None = None,
) -> KanbanBoardResponse:
    from app.services.audit import AuditService
    begin_serialized_write(db)
    project = _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    _check_version(project, expected_version)
    column = _column_or_404(db, project_id=project.id, column_id=column_id)
    column_count = db.scalar(
        select(func.count()).select_from(KanbanColumn).where(KanbanColumn.project_id == project.id),
    ) or 0
    if column_count <= 1:
        raise DomainError(ErrorKind.conflict, "The last Kanban column cannot be deleted.")
    task_count = db.scalar(
        select(func.count()).select_from(Task).where(Task.kanban_column_id == column.id),
    ) or 0
    if task_count:
        raise DomainError(ErrorKind.conflict, "A non-empty Kanban column cannot be deleted.")
    deleted_position = column.position
    db.delete(column)
    remaining = db.scalars(
        select(KanbanColumn)
        .where(KanbanColumn.project_id == project.id, KanbanColumn.id != column.id)
        .order_by(KanbanColumn.position, KanbanColumn.id),
    ).all()
    for position, current in enumerate(remaining):
        current.position = position
    project.kanban_version += 1
    AuditService.log_action(
        db, company_id=company_id, actor_user_id=actor_user_id,
        action="kanban.column_deleted", entity_type="kanban_column", entity_id=column_id, project_id=project.id,
        result="success", metadata={"position": deleted_position}
    )
    db.commit()
    return get_kanban_board(db, company_id=company_id, project_id=project_id)


def reorder_cards(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    payload: KanbanCardOrderPayload,
    actor_user_id: str | None = None,
) -> KanbanBoardResponse:
    from app.services.audit import AuditService
    begin_serialized_write(db)
    project = _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    _check_version(project, payload.expected_version)

    column_ids = [item.column_id for item in payload.columns]
    if len(column_ids) != len(set(column_ids)):
        raise DomainError(ErrorKind.bad_request, "Card order contains duplicate columns.")
    columns = db.scalars(
        select(KanbanColumn).where(
            KanbanColumn.project_id == project.id,
            KanbanColumn.id.in_(column_ids),
        ),
    ).all()
    if {column.id for column in columns} != set(column_ids):
        raise DomainError(ErrorKind.bad_request, "Card order contains a foreign column.")

    requested_task_ids = [task_id for item in payload.columns for task_id in item.task_ids]
    if len(requested_task_ids) != len(set(requested_task_ids)):
        raise DomainError(ErrorKind.bad_request, "Card order contains duplicate task IDs.")

    current_tasks = db.scalars(
        select(Task).where(
            Task.project_id == project.id,
            Task.kanban_column_id.in_(column_ids),
        ),
    ).all()
    by_id = {task.id: task for task in current_tasks}
    if set(requested_task_ids) != set(by_id):
        raise DomainError(
            ErrorKind.bad_request,
            "Card order must include every card from the affected columns.",
        )

    previous_state = {
        task.id: (task.kanban_column_id, task.kanban_position, task.card_number)
        for task in current_tasks
    }
    target_state: dict[str, tuple[str, int]] = {}
    for item in payload.columns:
        for position, task_id in enumerate(item.task_ids):
            task = by_id[task_id]
            target_state[task_id] = (item.column_id, position)
            task.kanban_column_id = item.column_id
            task.kanban_position = position

    project.kanban_version += 1
    moved_task_ids = {
        task_id
        for task_id, (target_column_id, _) in target_state.items()
        if previous_state[task_id][0] != target_column_id
    }
    reordered_task_ids: set[str] = set()
    for item in payload.columns:
        resident_task_ids = [task_id for task_id in item.task_ids if task_id not in moved_task_ids]
        previous_resident_order = sorted(
            resident_task_ids,
            key=lambda task_id: previous_state[task_id][1],
        )
        previous_resident_rank = {
            task_id: position for position, task_id in enumerate(previous_resident_order)
        }
        reordered_task_ids.update(
            task_id
            for position, task_id in enumerate(resident_task_ids)
            if previous_resident_rank[task_id] != position
        )
    for item in payload.columns:
        for task_id in item.task_ids:
            previous_column_id, previous_position, card_number = previous_state[task_id]
            target_column_id, target_position = target_state[task_id]
            if task_id in moved_task_ids:
                AuditService.log_action(
                    db,
                    company_id=company_id,
                    actor_user_id=actor_user_id,
                    action="card.moved",
                    entity_type="card",
                    entity_id=task_id,
                    project_id=project.id,
                    result="success",
                    metadata={
                        "cardNumber": card_number,
                        "fromColumnId": previous_column_id,
                        "toColumnId": target_column_id,
                    },
                )
            elif previous_position != target_position and task_id in reordered_task_ids:
                AuditService.log_action(
                    db,
                    company_id=company_id,
                    actor_user_id=actor_user_id,
                    action="card.reordered",
                    entity_type="card",
                    entity_id=task_id,
                    project_id=project.id,
                    result="success",
                    metadata={
                        "cardNumber": card_number,
                        "columnId": target_column_id,
                        "fromPosition": previous_position,
                        "toPosition": target_position,
                    },
                )
    db.commit()
    return get_kanban_board(db, company_id=company_id, project_id=project_id)
