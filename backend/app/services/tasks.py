from __future__ import annotations

from sqlalchemy import func, select
from sqlalchemy.orm import Session, selectinload

from app.db import begin_serialized_write
from app.domain.project_read import cipher, employee_or_404
from app.domain.task_read import serialize_task, serialize_task_member
from app.errors import DomainError, ErrorKind
from app.models import EmployeeProject, Project, Task, TaskEmployee
from app.schemas.task import TaskDraftPayload, TaskMemberSummary, TaskResponse, TaskType


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
    field_cipher = cipher()
    task = Task(
        project_id=project.id,
        parent_task_id=payload.parent_task_id,
        name_ciphertext=field_cipher.encrypt(payload.name) or "",
        description_ciphertext=field_cipher.encrypt(payload.description) or "",
        type=payload.type.value if isinstance(payload.type, TaskType) else payload.type,
    )
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
    payload: TaskDraftPayload,
) -> TaskResponse:
    begin_serialized_write(db)
    _locked_project_or_404(db, company_id=company_id, project_id=project_id)
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
    db.commit()
    db.refresh(task)
    return serialize_task(task, field_cipher=field_cipher)


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
    _locked_project_or_404(db, company_id=company_id, project_id=project_id)
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
        db.commit()
