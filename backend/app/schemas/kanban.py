from __future__ import annotations

from datetime import datetime

from pydantic import Field, field_validator

from app.schemas.base import CamelModel
from app.schemas.task import TaskMemberSummary, TaskType


class KanbanCardResponse(CamelModel):
    id: str
    project_id: str
    parent_task_id: str | None
    card_number: int
    kanban_column_id: str
    kanban_position: int
    name: str
    description: str
    type: TaskType
    assignees: list[TaskMemberSummary]
    created_at: datetime
    updated_at: datetime


class KanbanColumnResponse(CamelModel):
    id: str
    project_id: str
    name: str
    position: int
    cards: list[KanbanCardResponse]
    created_at: datetime
    updated_at: datetime


class KanbanBoardResponse(CamelModel):
    project_id: str
    kanban_version: int
    columns: list[KanbanColumnResponse]


class KanbanColumnMutation(CamelModel):
    name: str = Field(min_length=1, max_length=160)
    expected_version: int = Field(ge=0)

    @field_validator("name")
    @classmethod
    def validate_name(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Value must not be empty.")
        return value


class KanbanColumnOrderPayload(CamelModel):
    expected_version: int = Field(ge=0)
    column_ids: list[str] = Field(min_length=1)


class KanbanCardOrderColumn(CamelModel):
    column_id: str = Field(min_length=1)
    task_ids: list[str]


class KanbanCardOrderPayload(CamelModel):
    expected_version: int = Field(ge=0)
    columns: list[KanbanCardOrderColumn] = Field(min_length=1)
