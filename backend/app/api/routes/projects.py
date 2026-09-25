from __future__ import annotations

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.authorization import is_managerial_role, require_permission
from app.dependencies import get_db
from app.schemas.project import (
    ProjectDraftPayload,
    ProjectMemberPayload,
    ProjectMemberSummary,
    ProjectResponse,
    ProjectStatus,
)
from app.services.auth import AuthenticatedContext
from app.services.projects import (
    assign_project_member,
    create_project,
    delete_project,
    remove_project_member,
    update_project,
)
from app.domain.project_read import get_project, list_project_members, list_projects


router = APIRouter()


def _project_read_employee_id(context: AuthenticatedContext) -> str | None:
    if is_managerial_role(context.user.role):
        return None
    if context.employee is None:
        return ""
    return context.employee.id


@router.get("", response_model=list[ProjectResponse])
def list_projects_route(
    status: ProjectStatus | None = None,
    context: AuthenticatedContext = Depends(require_permission("projects.read")),
    db: Session = Depends(get_db),
) -> list[ProjectResponse]:
    return list_projects(
        db,
        company_id=context.company.id,
        status_filter=status,
        employee_id=_project_read_employee_id(context),
    )


@router.post("", response_model=ProjectResponse, status_code=status.HTTP_201_CREATED)
def create_project_route(
    payload: ProjectDraftPayload,
    context: AuthenticatedContext = Depends(require_permission("projects.create")),
    db: Session = Depends(get_db),
) -> ProjectResponse:
    return create_project(db, company_id=context.company.id, payload=payload, actor_user_id=context.user.id)


@router.get("/{project_id}", response_model=ProjectResponse)
def get_project_route(
    project_id: str,
    context: AuthenticatedContext = Depends(require_permission("projects.read")),
    db: Session = Depends(get_db),
) -> ProjectResponse:
    return get_project(
        db,
        company_id=context.company.id,
        project_id=project_id,
        employee_id=_project_read_employee_id(context),
    )


@router.put("/{project_id}", response_model=ProjectResponse)
@router.patch("/{project_id}", response_model=ProjectResponse)
def update_project_route(
    project_id: str,
    payload: ProjectDraftPayload,
    context: AuthenticatedContext = Depends(require_permission("projects.update")),
    db: Session = Depends(get_db),
) -> ProjectResponse:
    return update_project(db, company_id=context.company.id, project_id=project_id, payload=payload, actor_user_id=context.user.id)


@router.delete("/{project_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_project_route(
    project_id: str,
    context: AuthenticatedContext = Depends(require_permission("projects.delete")),
    db: Session = Depends(get_db),
) -> Response:
    delete_project(db, company_id=context.company.id, project_id=project_id, actor_user_id=context.user.id)
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.get("/{project_id}/members", response_model=list[ProjectMemberSummary])
def list_project_members_route(
    project_id: str,
    context: AuthenticatedContext = Depends(require_permission("projects.read")),
    db: Session = Depends(get_db),
) -> list[ProjectMemberSummary]:
    return list_project_members(
        db,
        company_id=context.company.id,
        project_id=project_id,
        employee_id=_project_read_employee_id(context),
    )


@router.post("/{project_id}/members", response_model=ProjectMemberSummary, status_code=status.HTTP_201_CREATED)
def assign_project_member_route(
    project_id: str,
    payload: ProjectMemberPayload,
    response: Response,
    context: AuthenticatedContext = Depends(require_permission("projects.assign")),
    db: Session = Depends(get_db),
) -> ProjectMemberSummary:
    member, created = assign_project_member(
        db,
        company_id=context.company.id,
        project_id=project_id,
        employee_id=payload.employee_id,
    )
    if not created:
        response.status_code = status.HTTP_200_OK
    return member


@router.delete("/{project_id}/members/{employee_id}", status_code=status.HTTP_204_NO_CONTENT)
def remove_project_member_route(
    project_id: str,
    employee_id: str,
    context: AuthenticatedContext = Depends(require_permission("projects.assign")),
    db: Session = Depends(get_db),
) -> Response:
    remove_project_member(
        db,
        company_id=context.company.id,
        project_id=project_id,
        employee_id=employee_id,
    )
    return Response(status_code=status.HTTP_204_NO_CONTENT)
