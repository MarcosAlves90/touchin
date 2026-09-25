from __future__ import annotations

from datetime import datetime
from uuid import uuid4

from sqlalchemy import (
    Boolean,
    CheckConstraint,
    DateTime,
    event,
    ForeignKey,
    Integer,
    String,
    Text,
    UniqueConstraint,
)
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.db import Base, utcnow

_CASCADE_ALL_DELETE_ORPHAN = "all, delete-orphan"
_COL_COMPANIES_ID = "companies.id"
_COL_EMPLOYEES_ID = "employees.id"
_COL_PROJECTS_ID = "projects.id"


def generate_id() -> str:
    return str(uuid4())


class Company(Base):
    __tablename__ = "companies"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=generate_id)
    legal_name_ciphertext: Mapped[str] = mapped_column(Text)
    trade_name_ciphertext: Mapped[str] = mapped_column(Text)
    cnpj_ciphertext: Mapped[str] = mapped_column(Text)
    cnpj_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    contact_email_ciphertext: Mapped[str] = mapped_column(Text)
    contact_email_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    contact_phone_ciphertext: Mapped[str] = mapped_column(Text)
    consented_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    timezone: Mapped[str] = mapped_column(String(64), default="America/Sao_Paulo")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
    )

    users: Mapped[list["UserAccount"]] = relationship(
        back_populates="company",
        cascade=_CASCADE_ALL_DELETE_ORPHAN,
    )
    employees: Mapped[list["Employee"]] = relationship(
        back_populates="company",
        cascade=_CASCADE_ALL_DELETE_ORPHAN,
    )
    punches: Mapped[list["Punch"]] = relationship(
        back_populates="company",
        cascade=_CASCADE_ALL_DELETE_ORPHAN,
    )
    projects: Mapped[list["Project"]] = relationship(
        back_populates="company",
        cascade=_CASCADE_ALL_DELETE_ORPHAN,
    )


class Employee(Base):
    __tablename__ = "employees"
    __table_args__ = (
        UniqueConstraint("company_id", "email_hash", name="uq_employee_email_per_company"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=generate_id)
    company_id: Mapped[str] = mapped_column(ForeignKey(_COL_COMPANIES_ID), index=True)
    name_ciphertext: Mapped[str] = mapped_column(Text)
    role_ciphertext: Mapped[str] = mapped_column(Text)
    department_ciphertext: Mapped[str] = mapped_column(Text)
    email_ciphertext: Mapped[str] = mapped_column(Text)
    email_hash: Mapped[str] = mapped_column(String(64), index=True)
    phone_ciphertext: Mapped[str] = mapped_column(Text)
    unit_ciphertext: Mapped[str] = mapped_column(Text)
    expected_shift_ciphertext: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(String(32))
    work_mode: Mapped[str] = mapped_column(String(32))
    role_level: Mapped[str] = mapped_column(String(32))
    requires_location_on_punch: Mapped[bool] = mapped_column(Boolean, default=False)
    trusted_device_required: Mapped[bool] = mapped_column(Boolean, default=False)
    pending_adjustments: Mapped[int] = mapped_column(Integer, default=0)
    notes_ciphertext: Mapped[str] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
    )

    company: Mapped[Company] = relationship(back_populates="employees")
    account: Mapped["UserAccount | None"] = relationship(back_populates="employee")
    punches: Mapped[list["Punch"]] = relationship(
        back_populates="employee",
        cascade=_CASCADE_ALL_DELETE_ORPHAN,
    )
    project_links: Mapped[list["EmployeeProject"]] = relationship(
        back_populates="employee",
        cascade=_CASCADE_ALL_DELETE_ORPHAN,
    )
    task_links: Mapped[list["TaskEmployee"]] = relationship(
        back_populates="employee",
        cascade=_CASCADE_ALL_DELETE_ORPHAN,
    )


class Project(Base):
    __tablename__ = "projects"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=generate_id)
    company_id: Mapped[str] = mapped_column(ForeignKey(_COL_COMPANIES_ID), index=True)
    name_ciphertext: Mapped[str] = mapped_column(Text)
    description_ciphertext: Mapped[str | None] = mapped_column(Text, nullable=True)
    task_employee_limit: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    next_card_number: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    kanban_version: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    status: Mapped[str] = mapped_column(String(32), default="active", index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
    )

    company: Mapped[Company] = relationship(back_populates="projects")
    employee_links: Mapped[list["EmployeeProject"]] = relationship(
        back_populates="project",
        cascade=_CASCADE_ALL_DELETE_ORPHAN,
    )
    punches: Mapped[list["Punch"]] = relationship(back_populates="project")
    tasks: Mapped[list["Task"]] = relationship(
        back_populates="project",
        cascade=_CASCADE_ALL_DELETE_ORPHAN,
    )
    kanban_columns: Mapped[list["KanbanColumn"]] = relationship(
        back_populates="project",
        cascade=_CASCADE_ALL_DELETE_ORPHAN,
    )


class EmployeeProject(Base):
    __tablename__ = "employee_projects"

    employee_id: Mapped[str] = mapped_column(
        ForeignKey(_COL_EMPLOYEES_ID),
        primary_key=True,
        index=True,
    )
    project_id: Mapped[str] = mapped_column(
        ForeignKey(_COL_PROJECTS_ID),
        primary_key=True,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    employee: Mapped[Employee] = relationship(back_populates="project_links")
    project: Mapped[Project] = relationship(back_populates="employee_links")


class KanbanColumn(Base):
    __tablename__ = "kanban_columns"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=generate_id)
    project_id: Mapped[str] = mapped_column(ForeignKey(_COL_PROJECTS_ID), index=True)
    name_ciphertext: Mapped[str] = mapped_column(Text)
    position: Mapped[int] = mapped_column(Integer)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
    )

    project: Mapped[Project] = relationship(back_populates="kanban_columns")
    tasks: Mapped[list["Task"]] = relationship(back_populates="kanban_column")


class Task(Base):
    __tablename__ = "tasks"
    __table_args__ = (
        CheckConstraint(
            "parent_task_id IS NULL OR parent_task_id <> id",
            name="ck_task_not_self_parent",
        ),
        UniqueConstraint("project_id", "card_number", name="uq_task_card_number_per_project"),
    )

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=generate_id)
    project_id: Mapped[str] = mapped_column(ForeignKey(_COL_PROJECTS_ID), index=True)
    parent_task_id: Mapped[str | None] = mapped_column(
        ForeignKey("tasks.id"),
        nullable=True,
        index=True,
    )
    card_number: Mapped[int] = mapped_column(Integer)
    kanban_column_id: Mapped[str] = mapped_column(ForeignKey("kanban_columns.id"), index=True)
    kanban_position: Mapped[int] = mapped_column(Integer)
    name_ciphertext: Mapped[str] = mapped_column(Text)
    description_ciphertext: Mapped[str] = mapped_column(Text)
    type: Mapped[str] = mapped_column(String(32), index=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
    )

    project: Mapped[Project] = relationship(back_populates="tasks")
    kanban_column: Mapped[KanbanColumn] = relationship(back_populates="tasks")
    parent: Mapped["Task | None"] = relationship(
        remote_side="Task.id",
        back_populates="children",
        foreign_keys=[parent_task_id],
    )
    children: Mapped[list["Task"]] = relationship(
        back_populates="parent",
        foreign_keys=[parent_task_id],
    )
    employee_links: Mapped[list["TaskEmployee"]] = relationship(
        back_populates="task",
        cascade=_CASCADE_ALL_DELETE_ORPHAN,
    )


class TaskEmployee(Base):
    __tablename__ = "task_employees"

    task_id: Mapped[str] = mapped_column(
        ForeignKey("tasks.id", ondelete="CASCADE"),
        primary_key=True,
        index=True,
    )
    employee_id: Mapped[str] = mapped_column(
        ForeignKey(_COL_EMPLOYEES_ID, ondelete="CASCADE"),
        primary_key=True,
        index=True,
    )
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    task: Mapped[Task] = relationship(back_populates="employee_links")
    employee: Mapped[Employee] = relationship(back_populates="task_links")


class UserAccount(Base):
    __tablename__ = "user_accounts"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=generate_id)
    company_id: Mapped[str] = mapped_column(ForeignKey(_COL_COMPANIES_ID), index=True)
    employee_id: Mapped[str | None] = mapped_column(
        ForeignKey(_COL_EMPLOYEES_ID),
        nullable=True,
        unique=True,
    )
    email_ciphertext: Mapped[str] = mapped_column(Text)
    email_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(512))
    must_change_password: Mapped[bool] = mapped_column(Boolean, default=False)
    role: Mapped[str] = mapped_column(String(32), default="employee")
    is_active: Mapped[bool] = mapped_column(Boolean, default=True)
    last_login_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=utcnow,
        onupdate=utcnow,
    )

    company: Mapped[Company] = relationship(back_populates="users")
    employee: Mapped[Employee | None] = relationship(back_populates="account")
    sessions: Mapped[list["AuthSession"]] = relationship(
        back_populates="user",
        cascade=_CASCADE_ALL_DELETE_ORPHAN,
    )


class Punch(Base):
    __tablename__ = "punches"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=generate_id)
    company_id: Mapped[str] = mapped_column(ForeignKey(_COL_COMPANIES_ID), index=True)
    employee_id: Mapped[str] = mapped_column(ForeignKey(_COL_EMPLOYEES_ID), index=True)
    project_id: Mapped[str | None] = mapped_column(ForeignKey(_COL_PROJECTS_ID), nullable=True, index=True)
    type: Mapped[str] = mapped_column(String(32))
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow, index=True)
    detail_ciphertext: Mapped[str] = mapped_column(Text)
    location_payload_ciphertext: Mapped[str | None] = mapped_column(Text, nullable=True)
    created_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)

    company: Mapped[Company] = relationship(back_populates="punches")
    employee: Mapped[Employee] = relationship(back_populates="punches")
    project: Mapped[Project | None] = relationship(back_populates="punches")



class AuditEvent(Base):
    __tablename__ = 'audit_events'

    id: Mapped[str] = mapped_column(String, primary_key=True)
    timestamp: Mapped[datetime] = mapped_column(DateTime(timezone=True), index=True)
    company_id: Mapped[str] = mapped_column(ForeignKey('companies.id', ondelete='CASCADE'), index=True)
    actor_user_id: Mapped[str | None] = mapped_column(ForeignKey('user_accounts.id', ondelete='SET NULL'), nullable=True, index=True)
    project_id: Mapped[str | None] = mapped_column(ForeignKey('projects.id', ondelete='SET NULL'), nullable=True, index=True)
    action: Mapped[str] = mapped_column(String, index=True)
    entity_type: Mapped[str] = mapped_column(String)
    entity_id: Mapped[str] = mapped_column(String, index=True)
    result: Mapped[str] = mapped_column(String)
    metadata_payload: Mapped[str | None] = mapped_column(String, nullable=True)
    correlation_id: Mapped[str | None] = mapped_column(String, nullable=True)

class AuthSession(Base):
    __tablename__ = "auth_sessions"

    id: Mapped[str] = mapped_column(String(64), primary_key=True, default=generate_id)
    user_id: Mapped[str] = mapped_column(ForeignKey("user_accounts.id"), index=True)
    token_hash: Mapped[str] = mapped_column(String(64), unique=True, index=True)
    issued_at: Mapped[datetime] = mapped_column(DateTime(timezone=True), default=utcnow)
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    revoked_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)
    last_used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True), nullable=True)

    user: Mapped[UserAccount] = relationship(back_populates="sessions")

@event.listens_for(Project, "init")
def _initialize_project_kanban_column(
    project: Project,
    _args: tuple[object, ...],
    kwargs: dict[str, object],
) -> None:
    """Create the required initial Kanban column for newly constructed projects."""
    if kwargs.get("kanban_columns"):
        return

    from app.config import get_settings
    from app.crypto import FieldCipher

    secret = get_settings().encryption_secret
    if secret is None:
        raise RuntimeError("TOUCHIN_ENCRYPTION_SECRET is required.")
    field_cipher = FieldCipher(secret)
    project.kanban_columns.append(
        KanbanColumn(
            name_ciphertext=field_cipher.encrypt("A fazer") or "",
            position=0,
        ),
    )
