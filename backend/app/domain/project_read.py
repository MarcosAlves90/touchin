from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session, selectinload

from app.config import get_settings
from app.crypto import FieldCipher
from app.errors import DomainError, ErrorKind
from app.models import Employee, EmployeeProject, Project
from app.schemas.project import ProjectMemberSummary, ProjectResponse, ProjectStatus


def cipher() -> FieldCipher:
    settings = get_settings()
    return FieldCipher(settings.encryption_secret or "")


def project_or_404(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    employee_id: str | None = None,
) -> Project:
    query = select(Project).where(Project.company_id == company_id, Project.id == project_id)
    if employee_id is not None:
        query = query.join(EmployeeProject, EmployeeProject.project_id == Project.id).where(
            EmployeeProject.employee_id == employee_id,
        )
    project = db.scalar(query)
    if project is None:
        raise DomainError(ErrorKind.not_found, "Project not found.")
    return project


def employee_or_404(db: Session, *, company_id: str, employee_id: str) -> Employee:
    employee = db.scalar(
        select(Employee).where(Employee.company_id == company_id, Employee.id == employee_id),
    )
    if employee is None:
        raise DomainError(ErrorKind.not_found, "Employee not found.")
    return employee


def serialize_project(project: Project, *, cipher: FieldCipher) -> ProjectResponse:
    return ProjectResponse(
        id=project.id,
        name=cipher.decrypt(project.name_ciphertext) or "",
        description=cipher.decrypt(project.description_ciphertext),
        task_employee_limit=project.task_employee_limit,
        status=project.status,
        created_at=project.created_at,
        updated_at=project.updated_at,
    )


def serialize_member(link: EmployeeProject, *, cipher: FieldCipher) -> ProjectMemberSummary:
    return ProjectMemberSummary(
        employee_id=link.employee_id,
        project_id=link.project_id,
        employee_name=cipher.decrypt(link.employee.name_ciphertext) or "",
        created_at=link.created_at,
    )


def status_value(value: ProjectStatus | str) -> str:
    if isinstance(value, ProjectStatus):
        return value.value
    return value


def list_projects(
    db: Session,
    *,
    company_id: str,
    status_filter: ProjectStatus | None = None,
    employee_id: str | None = None,
) -> list[ProjectResponse]:
    field_cipher = cipher()
    query = select(Project).where(Project.company_id == company_id)
    if employee_id is not None:
        query = query.join(EmployeeProject, EmployeeProject.project_id == Project.id).where(
            EmployeeProject.employee_id == employee_id,
        )
    if status_filter is not None:
        query = query.where(Project.status == status_value(status_filter))
    projects = db.scalars(query.order_by(Project.created_at.desc(), Project.id.desc())).all()
    return [serialize_project(project, cipher=field_cipher) for project in projects]


def get_project(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    employee_id: str | None = None,
) -> ProjectResponse:
    field_cipher = cipher()
    project = project_or_404(
        db,
        company_id=company_id,
        project_id=project_id,
        employee_id=employee_id,
    )
    return serialize_project(project, cipher=field_cipher)


def list_project_members(
    db: Session,
    *,
    company_id: str,
    project_id: str,
    employee_id: str | None = None,
) -> list[ProjectMemberSummary]:
    field_cipher = cipher()
    project_or_404(
        db,
        company_id=company_id,
        project_id=project_id,
        employee_id=employee_id,
    )
    links = db.scalars(
        select(EmployeeProject)
        .join(Employee, Employee.id == EmployeeProject.employee_id)
        .options(selectinload(EmployeeProject.employee))
        .where(
            EmployeeProject.project_id == project_id,
            Employee.company_id == company_id,
        )
        .order_by(EmployeeProject.created_at, EmployeeProject.employee_id),
    ).all()
    return [serialize_member(link, cipher=field_cipher) for link in links]


def list_employee_projects(db: Session, *, company_id: str, employee_id: str) -> list[ProjectResponse]:
    field_cipher = cipher()
    employee_or_404(db, company_id=company_id, employee_id=employee_id)
    projects = db.scalars(
        select(Project)
        .join(EmployeeProject, EmployeeProject.project_id == Project.id)
        .where(
            Project.company_id == company_id,
            EmployeeProject.employee_id == employee_id,
        )
        .order_by(Project.created_at.desc(), Project.id.desc()),
    ).all()
    return [serialize_project(project, cipher=field_cipher) for project in projects]
