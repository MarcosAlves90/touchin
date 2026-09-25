from __future__ import annotations

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.db import begin_serialized_write
from app.domain.project_policy import validate_project_for_punch as _validate_project_for_punch
from app.domain.project_read import (
    cipher,
    employee_or_404,
    project_or_404,
    serialize_member,
    serialize_project,
    status_value,
)
from app.errors import DomainError, ErrorKind
from app.models import EmployeeProject, Project, Task, TaskEmployee
from app.schemas.project import ProjectDraftPayload, ProjectMemberSummary, ProjectResponse, ProjectStatus


def _locked_project_or_404(db: Session, *, company_id: str, project_id: str) -> Project:
    query = select(Project).where(Project.company_id == company_id, Project.id == project_id)
    if db.bind is not None and db.bind.dialect.name != "sqlite":
        query = query.with_for_update()
    project = db.scalar(query)
    if project is None:
        raise DomainError(ErrorKind.not_found, "Project not found.")
    return project


def create_project(db: Session, *, company_id: str, payload: ProjectDraftPayload, actor_user_id: str | None = None) -> ProjectResponse:
    from app.services.audit import AuditService
    field_cipher = cipher()
    project = Project(
        company_id=company_id,
        name_ciphertext=field_cipher.encrypt(payload.name) or "",
        description_ciphertext=field_cipher.encrypt(payload.description),
        task_employee_limit=payload.task_employee_limit or 1,
        status=status_value(payload.status),
    )
    db.add(project)
    db.flush()
    AuditService.log_action(db, company_id=company_id, actor_user_id=actor_user_id, project_id=project.id, action="project.created", entity_type="project", entity_id=project.id)
    db.commit()
    db.refresh(project)
    return serialize_project(project, cipher=field_cipher)


def update_project(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    payload: ProjectDraftPayload,
    actor_user_id: str | None = None,
) -> ProjectResponse:
    from app.services.audit import AuditService
    begin_serialized_write(db)

    project = _locked_project_or_404(db, company_id=company_id, project_id=project_id)

    new_limit = payload.task_employee_limit
    if new_limit is None:
        new_limit = project.task_employee_limit

    if new_limit < project.task_employee_limit:
        counts = db.scalars(
            select(func.count(TaskEmployee.employee_id))
            .join(Task, Task.id == TaskEmployee.task_id)
            .where(Task.project_id == project.id)
            .group_by(TaskEmployee.task_id),
        ).all()
        if any(count > new_limit for count in counts):
            raise DomainError(
                ErrorKind.conflict,
                "Project task employee limit is below current task membership.",
            )

    field_cipher = cipher()
    project.name_ciphertext = field_cipher.encrypt(payload.name) or ""
    project.description_ciphertext = field_cipher.encrypt(payload.description)
    project.task_employee_limit = new_limit
    project.status = status_value(payload.status)
    AuditService.log_action(db, company_id=company_id, actor_user_id=actor_user_id, project_id=project.id, action="project.updated", entity_type="project", entity_id=project.id)
    db.commit()
    db.refresh(project)
    return serialize_project(project, cipher=field_cipher)


def delete_project(db: Session, *, company_id: str, project_id: str, actor_user_id: str | None = None) -> None:
    from app.services.audit import AuditService
    project = project_or_404(db, company_id=company_id, project_id=project_id)
    project.status = ProjectStatus.inactive.value
    AuditService.log_action(db, company_id=company_id, actor_user_id=actor_user_id, project_id=project.id, action="project.deleted", entity_type="project", entity_id=project.id)
    db.commit()


def assign_project_member(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    employee_id: str,
    actor_user_id: str | None = None,
) -> tuple[ProjectMemberSummary, bool]:
    from app.services.audit import AuditService
    begin_serialized_write(db)
    field_cipher = cipher()
    _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    employee = employee_or_404(db, company_id=company_id, employee_id=employee_id)
    link = db.scalar(
        select(EmployeeProject)
        .where(
            EmployeeProject.project_id == project_id,
            EmployeeProject.employee_id == employee_id,
        )
    )
    created = False
    if link is None:
        link = EmployeeProject(employee=employee, project_id=project_id)
        db.add(link)
        db.flush()
        AuditService.log_action(db, company_id=company_id, actor_user_id=actor_user_id, project_id=project_id, action="project.member_assigned", entity_type="project", entity_id=project_id, metadata={"employee_id": employee_id})
        db.commit()
        db.refresh(link)
        created = True
    elif link.employee is None:
        link.employee = employee
    return serialize_member(link, cipher=field_cipher), created


def remove_project_member(db: Session, *, company_id: str, project_id: str, employee_id: str, actor_user_id: str | None = None) -> None:
    from app.services.audit import AuditService
    begin_serialized_write(db)
    _locked_project_or_404(db, company_id=company_id, project_id=project_id)
    employee_or_404(db, company_id=company_id, employee_id=employee_id)
    link = db.scalar(
        select(EmployeeProject).where(
            EmployeeProject.project_id == project_id,
            EmployeeProject.employee_id == employee_id,
        ),
    )

    task_ids = select(Task.id).where(Task.project_id == project_id)
    db.execute(
        delete(TaskEmployee).where(
            TaskEmployee.employee_id == employee_id,
            TaskEmployee.task_id.in_(task_ids),
        ),
    )
    if link is not None:
        db.delete(link)
        AuditService.log_action(db, company_id=company_id, actor_user_id=actor_user_id, project_id=project_id, action="project.member_removed", entity_type="project", entity_id=project_id, metadata={"employee_id": employee_id})
    db.commit()


def validate_project_for_punch(
    db: Session,
    *,
    company_id: str,
    employee_id: str,
    project_id: str,
) -> Project:
    return _validate_project_for_punch(
        db,
        company_id=company_id,
        employee_id=employee_id,
        project_id=project_id,
    )
