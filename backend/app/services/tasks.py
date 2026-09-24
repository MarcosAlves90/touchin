from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.db import begin_serialized_write
from app.domain.project_read import cipher, employee_or_404
from app.domain.task_read import serialize_task, serialize_task_member
from app.errors import DomainError, ErrorKind
from app.models import EmployeeProject, KanbanColumn, Project, Task, TaskEmployee
from app.schemas.task import (
    TaskDraftPayload,
    TaskMemberSummary,
    TaskResponse,
    TaskType,
    TaskUpdatePayload,
)


def _locked_project_or_404(db: Session, *, company_id: str, project_id: str) -> Project:
    query = select(Project).where(Project.company_id == company_id, Project.id == project_id)
    if db.bind is not None and db.bind.dialect.name != "sqlite":
        query = query.with_for_update()
    project = db.scalar(query)
    if project is None:
        raise DomainError(ErrorKind.not_found, "Project not found.")
    return project


def _locked_task_or_404(
    db: Session,
    *,
    project_id: str,
    task_id: str,
) -> Task:
    query = select(Task).where(Task.project_id == project_id, Task.id == task_id)
    if db.bind is not None and db.bind.dialect.name != "sqlite":
        query = query.with_for_update()
    task = db.scalar(query)
    if task is None:
        raise DomainError(ErrorKind.not_found, "Task not found.")
    return task


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


def _initial_column_or_404(db: Session, *, project_id: str) -> KanbanColumn:
    column = db.scalar(
        select(KanbanColumn)
        .where(KanbanColumn.project_id == project_id)
        .order_by(KanbanColumn.position, KanbanColumn.id),
    )
    if column is None:
        raise DomainError(ErrorKind.conflict, "Project has no Kanban column.")
    return column


def _next_position(db: Session, *, column_id: str) -> int:
    current = db.scalar(
        select(func.max(Task.kanban_position)).where(Task.kanban_column_id == column_id),
    )
    return 0 if current is None else int(current) + 1


def _normalize_column_positions(db: Session, *, column_id: str) -> None:
    tasks = db.scalars(
        select(Task)
        .where(Task.kanban_column_id == column_id)
        .order_by(Task.kanban_position, Task.created_at, Task.id),
    ).all()
    for position, task in enumerate(tasks):
        task.kanban_position = position


def _validate_parent(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    parent_task_id: str | None,
    task_id: str | None = None,
) -> None:
    if parent_task_id is None:
        return
    if task_id is not None and parent_task_id == task_id:
        raise DomainError(ErrorKind.bad_request, "Task cannot be its own parent.")

    parent = db.scalar(
        select(Task)
        .join(Project, Project.id == Task.project_id)
        .where(Project.company_id == company_id, Task.id == parent_task_id),
    )
    if parent is None:
        raise DomainError(ErrorKind.not_found, "Parent task not found.")
    if parent.project_id != project_id:
        raise DomainError(ErrorKind.bad_request, "Parent task must belong to the same project.")

    if task_id is None:
        return

    current: Task | None = parent
    visited: set[str] = set()
    while current is not None:
        if current.id == task_id or current.id in visited:
            raise DomainError(ErrorKind.conflict, "Task hierarchy cycle detected.")
        visited.add(current.id)
        if current.parent_task_id is None:
            break
        current = db.get(Task, current.parent_task_id)


def create_task(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    payload: TaskDraftPayload,
) -> TaskResponse:
    begin_serialized_write(db)
    project = _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    _validate_parent(
        db,
        company_id=company_id,
        project_id=project.id,
        parent_task_id=payload.parent_task_id,
    )
    column = (
        _column_or_404(db, project_id=project.id, column_id=payload.column_id)
        if payload.column_id is not None
        else _initial_column_or_404(db, project_id=project.id)
    )
    field_cipher = cipher()
    task = Task(
        project_id=project.id,
        parent_task_id=payload.parent_task_id,
        card_number=project.next_card_number,
        kanban_column_id=column.id,
        kanban_position=_next_position(db, column_id=column.id),
        name_ciphertext=field_cipher.encrypt(payload.name) or "",
        description_ciphertext=field_cipher.encrypt(payload.description) or "",
        type=payload.type.value if isinstance(payload.type, TaskType) else payload.type,
    )
    project.next_card_number += 1
    project.kanban_version += 1
    db.add(task)
    db.commit()
    db.refresh(task)
    return serialize_task(task, field_cipher=field_cipher)


def update_task(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    task_id: str,
    payload: TaskUpdatePayload,
) -> TaskResponse:
    begin_serialized_write(db)
    project = _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    task = _locked_task_or_404(db, project_id=project_id, task_id=task_id)
    _validate_parent(
        db,
        company_id=company_id,
        project_id=project_id,
        parent_task_id=payload.parent_task_id,
        task_id=task.id,
    )
    field_cipher = cipher()
    task.parent_task_id = payload.parent_task_id
    task.name_ciphertext = field_cipher.encrypt(payload.name) or ""
    task.description_ciphertext = field_cipher.encrypt(payload.description) or ""
    task.type = payload.type.value if isinstance(payload.type, TaskType) else payload.type
    project.kanban_version += 1
    db.commit()
    db.refresh(task)
    return serialize_task(task, field_cipher=field_cipher)


def delete_task(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    task_id: str,
) -> None:
    begin_serialized_write(db)
    project = _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    task = _locked_task_or_404(db, project_id=project_id, task_id=task_id)
    child_exists = db.scalar(
        select(Task.id).where(Task.parent_task_id == task.id).limit(1),
    )
    if child_exists is not None:
        raise DomainError(ErrorKind.conflict, "Task with children cannot be deleted.")
    column_id = task.kanban_column_id
    db.delete(task)
    db.flush()
    _normalize_column_positions(db, column_id=column_id)
    project.kanban_version += 1
    db.commit()


def add_task_member(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    task_id: str,
    employee_id: str,
) -> tuple[TaskMemberSummary, bool]:
    begin_serialized_write(db)
    project = _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    task = _locked_task_or_404(db, project_id=project_id, task_id=task_id)
    employee = employee_or_404(db, company_id=company_id, employee_id=employee_id)
    project_link = db.scalar(
        select(EmployeeProject).where(
            EmployeeProject.project_id == project.id,
            EmployeeProject.employee_id == employee.id,
        ),
    )
    if project_link is None:
        raise DomainError(ErrorKind.conflict, "Employee is not assigned to this project.")

    existing = db.scalar(
        select(TaskEmployee)
        .options(selectinload(TaskEmployee.employee))
        .where(TaskEmployee.task_id == task.id, TaskEmployee.employee_id == employee.id),
    )
    field_cipher = cipher()
    if existing is not None:
        return serialize_task_member(existing, field_cipher=field_cipher), False

    member_count = db.scalar(
        select(func.count()).select_from(TaskEmployee).where(TaskEmployee.task_id == task.id),
    ) or 0
    if member_count >= project.task_employee_limit:
        raise DomainError(ErrorKind.conflict, "Task employee capacity reached.")

    link = TaskEmployee(task_id=task.id, employee_id=employee.id)
    db.add(link)
    project.kanban_version += 1
    db.commit()
    db.refresh(link)
    link.employee = employee
    return serialize_task_member(link, field_cipher=field_cipher), True


def remove_task_member(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    task_id: str,
    employee_id: str,
) -> None:
    begin_serialized_write(db)
    project = _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    task = _locked_task_or_404(db, project_id=project_id, task_id=task_id)
    employee_or_404(db, company_id=company_id, employee_id=employee_id)
    link = db.scalar(
        select(TaskEmployee).where(
            TaskEmployee.task_id == task.id,
            TaskEmployee.employee_id == employee_id,
        ),
    )
    if link is not None:
        db.delete(link)
        project.kanban_version += 1
        db.commit()
