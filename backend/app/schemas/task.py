from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import Field, field_validator

from app.schemas.base import CamelModel


class TaskType(str, Enum):
    bug = "bug"
    improvement = "improvement"
    feature = "feature"


class TaskDraftPayload(CamelModel):
    name: str = Field(min_length=1, max_length=160)
    description: str = Field(min_length=1, max_length=2000)
    type: TaskType
    parent_task_id: str | None = Field(default=None, min_length=1)

    @field_validator("name", "description")
    @classmethod
    def validate_non_empty_text(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Value must not be empty.")
        return value

    @field_validator("parent_task_id")
    @classmethod
    def validate_parent_task_id(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if not value:
            raise ValueError("Value must not be empty.")
        return value


class TaskResponse(CamelModel):
    id: str
    project_id: str
    parent_task_id: str | None
    name: str
    description: str
    type: TaskType
    created_at: datetime
    updated_at: datetime


class TaskMemberPayload(CamelModel):
    employee_id: str = Field(min_length=1)

    @field_validator("employee_id")
    @classmethod
    def validate_employee_id(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Value must not be empty.")
        return value


class TaskMemberSummary(CamelModel):
    employee_id: str
    task_id: str
    employee_name: str
    created_at: datetime
