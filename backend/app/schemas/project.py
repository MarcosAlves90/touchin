from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import Field, field_validator

from app.schemas.base import CamelModel


class ProjectStatus(str, Enum):
    active = "active"
    inactive = "inactive"


class ProjectDraftPayload(CamelModel):
    name: str = Field(min_length=1, max_length=160)
    description: str = Field(min_length=1, max_length=2000)
    task_employee_limit: int | None = Field(default=None, ge=1, le=2_147_483_647)
    status: ProjectStatus = ProjectStatus.active

    @field_validator("name", "description")
    @classmethod
    def validate_non_empty_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Value must not be empty.")
        return value


class ProjectResponse(CamelModel):
    id: str
    name: str
    description: str | None = None
    task_employee_limit: int
    status: ProjectStatus
    created_at: datetime
    updated_at: datetime


class ProjectMemberPayload(CamelModel):
    employee_id: str = Field(min_length=1)


class ProjectMemberSummary(CamelModel):
    employee_id: str
    project_id: str
    employee_name: str
    created_at: datetime
