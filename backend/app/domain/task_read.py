from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.crypto import FieldCipher
from app.domain.project_read import cipher, project_or_404
from app.errors import DomainError, ErrorKind
from app.models import Employee, Task, TaskEmployee
from app.schemas.task import TaskMemberSummary, TaskResponse


def task_or_404(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    task_id: str,
    employee_id: str | None = None,
) -> Task:
    project_or_404(
        db,
        company_id=company_id,
        project_id=project_id,
        employee_id=employee_id,
    )
    task = db.scalar(
        select(Task).where(Task.project_id == project_id, Task.id == task_id),
    )
    if task is None:
        raise DomainError(ErrorKind.not_found, "Task not found.")
    return task


def serialize_task(task: Task, *, field_cipher: FieldCipher) -> TaskResponse:
    return TaskResponse(
        id=task.id,
        project_id=task.project_id,
        parent_task_id=task.parent_task_id,
        card_number=task.card_number,
        kanban_column_id=task.kanban_column_id,
        kanban_position=task.kanban_position,
        name=field_cipher.decrypt(task.name_ciphertext) or "",
        description=field_cipher.decrypt(task.description_ciphertext) or "",
        type=task.type,
        created_at=task.created_at,
        updated_at=task.updated_at,
    )


def serialize_task_member(link: TaskEmployee, *, field_cipher: FieldCipher) -> TaskMemberSummary:
    return TaskMemberSummary(
        employee_id=link.employee_id,
        task_id=link.task_id,
        employee_name=field_cipher.decrypt(link.employee.name_ciphertext) or "",
        created_at=link.created_at,
    )


def list_tasks(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    employee_id: str | None = None,
) -> list[TaskResponse]:
    field_cipher = cipher()
    project_or_404(
        db,
        company_id=company_id,
        project_id=project_id,
        employee_id=employee_id,
    )
    tasks = db.scalars(
        select(Task)
        .where(Task.project_id == project_id)
        .order_by(Task.created_at.desc(), Task.id.desc()),
    ).all()
    return [serialize_task(task, field_cipher=field_cipher) for task in tasks]


def get_task(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    task_id: str,
    employee_id: str | None = None,
) -> TaskResponse:
    field_cipher = cipher()
    task = task_or_404(
        db,
        company_id=company_id,
        project_id=project_id,
        task_id=task_id,
        employee_id=employee_id,
    )
    return serialize_task(task, field_cipher=field_cipher)


def list_task_members(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    task_id: str,
    employee_id: str | None = None,
) -> list[TaskMemberSummary]:
    field_cipher = cipher()
    task_or_404(
        db,
        company_id=company_id,
        project_id=project_id,
        task_id=task_id,
        employee_id=employee_id,
    )
    links = db.scalars(
        select(TaskEmployee)
        .join(Employee, Employee.id == TaskEmployee.employee_id)
        .options(selectinload(TaskEmployee.employee))
        .where(
            TaskEmployee.task_id == task_id,
            Employee.company_id == company_id,
        )
        .order_by(TaskEmployee.created_at, TaskEmployee.employee_id),
    ).all()
    return [serialize_task_member(link, field_cipher=field_cipher) for link in links]
