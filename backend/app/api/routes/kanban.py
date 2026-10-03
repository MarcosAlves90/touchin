from __future__ import annotations

from fastapi import APIRouter, Depends, HTTPException, Query, Response, status
from sqlalchemy.orm import Session

from app.authorization import is_managerial_role, require_permission
from app.dependencies import get_db
from app.domain.kanban_read import get_kanban_board
from app.domain.project_read import project_or_404
from app.schemas.kanban import (
    KanbanBoardResponse,
    KanbanCardOrderPayload,
    KanbanCardResponse,
    KanbanColumnMutation,
    KanbanColumnOrderPayload,
)
from app.services.auth import AuthenticatedContext
from app.services.kanban import (
    create_column,
    delete_column,
    rename_column,
    reorder_cards,
    reorder_columns,
)
from app.services.tasks import add_task_member, remove_task_member


_KANBAN_STRUCTURE_MANAGE_PERMISSION = "kanban.structure.manage"


router = APIRouter()


def _employee_id_or_403(context: AuthenticatedContext) -> str:
    if context.employee is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Employee profile is required for Kanban access.",
        )
    return context.employee.id


def _project_access_employee_id(context: AuthenticatedContext) -> str | None:
    if is_managerial_role(context.user.role):
        return None
    return _employee_id_or_403(context)


def _ensure_project_access(
    db: Session,
    *,
    context: AuthenticatedContext,
    project_id: str,
) -> str | None:
    employee_id = _project_access_employee_id(context)
    project_or_404(
        db,
        company_id=context.company.id,
        project_id=project_id,
        employee_id=employee_id,
    )
    return employee_id


def _card_from_board(board: KanbanBoardResponse, task_id: str) -> KanbanCardResponse:
    for column in board.columns:
        for card in column.cards:
            if card.id == task_id:
                return card
    raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Task not found.")


@router.get("/{project_id}/kanban", response_model=KanbanBoardResponse)
def get_kanban_route(
    project_id: str,
    context: AuthenticatedContext = Depends(require_permission("kanban.read")),
    db: Session = Depends(get_db),
) -> KanbanBoardResponse:
    employee_id = _project_access_employee_id(context)
    return get_kanban_board(
        db,
        company_id=context.company.id,
        project_id=project_id,
        employee_id=employee_id,
    )


@router.post(
    "/{project_id}/kanban/columns",
    response_model=KanbanBoardResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_kanban_column_route(
    project_id: str,
    payload: KanbanColumnMutation,
    context: AuthenticatedContext = Depends(require_permission(_KANBAN_STRUCTURE_MANAGE_PERMISSION)),
    db: Session = Depends(get_db),
) -> KanbanBoardResponse:
    return create_column(
        db,
        company_id=context.company.id,
        project_id=project_id,
        payload=payload,
        actor_user_id=context.user.id,
    )


@router.put("/{project_id}/kanban/columns/order", response_model=KanbanBoardResponse)
def reorder_kanban_columns_route(
    project_id: str,
    payload: KanbanColumnOrderPayload,
    context: AuthenticatedContext = Depends(require_permission(_KANBAN_STRUCTURE_MANAGE_PERMISSION)),
    db: Session = Depends(get_db),
) -> KanbanBoardResponse:
    return reorder_columns(
        db,
        company_id=context.company.id,
        project_id=project_id,
        payload=payload,
        actor_user_id=context.user.id,
    )


@router.put("/{project_id}/kanban/columns/{column_id}", response_model=KanbanBoardResponse)
def rename_kanban_column_route(
    project_id: str,
    column_id: str,
    payload: KanbanColumnMutation,
    context: AuthenticatedContext = Depends(require_permission(_KANBAN_STRUCTURE_MANAGE_PERMISSION)),
    db: Session = Depends(get_db),
) -> KanbanBoardResponse:
    return rename_column(
        db,
        company_id=context.company.id,
        project_id=project_id,
        column_id=column_id,
        payload=payload,
        actor_user_id=context.user.id,
    )


@router.delete("/{project_id}/kanban/columns/{column_id}", response_model=KanbanBoardResponse)
def delete_kanban_column_route(
    project_id: str,
    column_id: str,
    expected_version: int = Query(alias="expectedVersion", ge=0),
    context: AuthenticatedContext = Depends(require_permission(_KANBAN_STRUCTURE_MANAGE_PERMISSION)),
    db: Session = Depends(get_db),
) -> KanbanBoardResponse:
    return delete_column(
        db,
        company_id=context.company.id,
        project_id=project_id,
        column_id=column_id,
        expected_version=expected_version,
        actor_user_id=context.user.id,
    )


@router.put("/{project_id}/kanban/cards/order", response_model=KanbanBoardResponse)
def reorder_kanban_cards_route(
    project_id: str,
    payload: KanbanCardOrderPayload,
    context: AuthenticatedContext = Depends(require_permission("kanban.cards.move")),
    db: Session = Depends(get_db),
) -> KanbanBoardResponse:
    _ensure_project_access(db, context=context, project_id=project_id)
    return reorder_cards(
        db,
        company_id=context.company.id,
        project_id=project_id,
        payload=payload,
        actor_user_id=context.user.id,
    )


@router.post(
    "/{project_id}/kanban/cards/{task_id}/assignees/{employee_id}",
    response_model=KanbanCardResponse,
)
def add_kanban_assignee_route(
    project_id: str,
    task_id: str,
    employee_id: str,
    context: AuthenticatedContext = Depends(require_permission("kanban.assignees.manage")),
    db: Session = Depends(get_db),
) -> KanbanCardResponse:
    requester_employee_id = _ensure_project_access(db, context=context, project_id=project_id)
    add_task_member(
        db,
        company_id=context.company.id,
        project_id=project_id,
        task_id=task_id,
        employee_id=employee_id,
    )
    board = get_kanban_board(
        db,
        company_id=context.company.id,
        project_id=project_id,
        employee_id=requester_employee_id,
    )
    return _card_from_board(board, task_id)


@router.delete(
    "/{project_id}/kanban/cards/{task_id}/assignees/{employee_id}",
    response_model=KanbanCardResponse,
)
def remove_kanban_assignee_route(
    project_id: str,
    task_id: str,
    employee_id: str,
    context: AuthenticatedContext = Depends(require_permission("kanban.assignees.manage")),
    db: Session = Depends(get_db),
) -> KanbanCardResponse:
    requester_employee_id = _ensure_project_access(db, context=context, project_id=project_id)
    remove_task_member(
        db,
        company_id=context.company.id,
        project_id=project_id,
        task_id=task_id,
        employee_id=employee_id,
    )
    board = get_kanban_board(
        db,
        company_id=context.company.id,
        project_id=project_id,
        employee_id=requester_employee_id,
    )
    return _card_from_board(board, task_id)
