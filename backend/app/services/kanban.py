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
) -> KanbanBoardResponse:
    begin_serialized_write(db)
    project = _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    _check_version(project, payload.expected_version)
    max_position = db.scalar(
        select(func.max(KanbanColumn.position)).where(KanbanColumn.project_id == project.id),
    )
    field_cipher = cipher()
    db.add(
        KanbanColumn(
            project_id=project.id,
            name_ciphertext=field_cipher.encrypt(payload.name) or "",
            position=0 if max_position is None else int(max_position) + 1,
        ),
    )
    project.kanban_version += 1
    db.commit()
    return get_kanban_board(db, company_id=company_id, project_id=project_id)


def rename_column(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    column_id: str,
    payload: KanbanColumnMutation,
) -> KanbanBoardResponse:
    begin_serialized_write(db)
    project = _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    _check_version(project, payload.expected_version)
    column = _column_or_404(db, project_id=project.id, column_id=column_id)
    column.name_ciphertext = cipher().encrypt(payload.name) or ""
    project.kanban_version += 1
    db.commit()
    return get_kanban_board(db, company_id=company_id, project_id=project_id)


def reorder_columns(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    payload: KanbanColumnOrderPayload,
) -> KanbanBoardResponse:
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
    for position, column_id in enumerate(payload.column_ids):
        by_id[column_id].position = position
    project.kanban_version += 1
    db.commit()
    return get_kanban_board(db, company_id=company_id, project_id=project_id)


def delete_column(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    column_id: str,
    expected_version: int,
) -> KanbanBoardResponse:
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
    db.delete(column)
    remaining = db.scalars(
        select(KanbanColumn)
        .where(KanbanColumn.project_id == project.id, KanbanColumn.id != column.id)
        .order_by(KanbanColumn.position, KanbanColumn.id),
    ).all()
    for position, current in enumerate(remaining):
        current.position = position
    project.kanban_version += 1
    db.commit()
    return get_kanban_board(db, company_id=company_id, project_id=project_id)


def reorder_cards(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    payload: KanbanCardOrderPayload,
) -> KanbanBoardResponse:
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

    for item in payload.columns:
        for position, task_id in enumerate(item.task_ids):
            task = by_id[task_id]
            task.kanban_column_id = item.column_id
            task.kanban_position = position

    project.kanban_version += 1
    db.commit()
    return get_kanban_board(db, company_id=company_id, project_id=project_id)
