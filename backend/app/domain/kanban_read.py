from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.domain.project_read import cipher, project_or_404
from app.models import Employee, KanbanColumn, Task, TaskEmployee
from app.schemas.kanban import KanbanBoardResponse, KanbanCardResponse, KanbanColumnResponse
from app.schemas.task import TaskMemberSummary


def get_kanban_board(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    employee_id: str | None = None,
) -> KanbanBoardResponse:
    project = project_or_404(
        db,
        company_id=company_id,
        project_id=project_id,
        employee_id=employee_id,
    )
    field_cipher = cipher()
    columns = db.scalars(
        select(KanbanColumn)
        .where(KanbanColumn.project_id == project.id)
        .order_by(KanbanColumn.position, KanbanColumn.id),
    ).all()
    tasks = db.scalars(
        select(Task)
        .options(selectinload(Task.employee_links).selectinload(TaskEmployee.employee))
        .where(Task.project_id == project.id)
        .order_by(Task.kanban_column_id, Task.kanban_position, Task.id),
    ).unique().all()
    tasks_by_column: dict[str, list[Task]] = {column.id: [] for column in columns}
    for task in tasks:
        tasks_by_column.setdefault(task.kanban_column_id, []).append(task)

    column_responses: list[KanbanColumnResponse] = []
    for column in columns:
        cards: list[KanbanCardResponse] = []
        for task in tasks_by_column.get(column.id, []):
            assignees = [
                TaskMemberSummary(
                    employee_id=link.employee_id,
                    task_id=task.id,
                    employee_name=field_cipher.decrypt(link.employee.name_ciphertext) or "",
                    created_at=link.created_at,
                )
                for link in sorted(
                    task.employee_links,
                    key=lambda link: (link.created_at, link.employee_id),
                )
                if link.employee is not None
            ]
            cards.append(
                KanbanCardResponse(
                    id=task.id,
                    project_id=task.project_id,
                    parent_task_id=task.parent_task_id,
                    card_number=task.card_number,
                    kanban_column_id=task.kanban_column_id,
                    kanban_position=task.kanban_position,
                    name=field_cipher.decrypt(task.name_ciphertext) or "",
                    description=field_cipher.decrypt(task.description_ciphertext) or "",
                    type=task.type,
                    assignees=assignees,
                    created_at=task.created_at,
                    updated_at=task.updated_at,
                ),
            )
        cards.sort(key=lambda card: (card.kanban_position, card.id))
        column_responses.append(
            KanbanColumnResponse(
                id=column.id,
                project_id=column.project_id,
                name=field_cipher.decrypt(column.name_ciphertext) or "",
                position=column.position,
                cards=cards,
                created_at=column.created_at,
                updated_at=column.updated_at,
            ),
        )

    return KanbanBoardResponse(
        project_id=project.id,
        kanban_version=project.kanban_version,
        columns=column_responses,
    )
