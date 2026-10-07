from __future__ import annotations

from datetime import datetime
from enum import Enum

from pydantic import Field, field_validator
from pydantic import model_validator

from app.schemas.base import CamelModel


class ShiftStatus(str, Enum):
    checked_out = "checkedOut"
    working = "working"
    on_break = "onBreak"


class PunchType(str, Enum):
    check_in = "checkIn"
    break_start = "breakStart"
    break_end = "breakEnd"
    check_out = "checkOut"


class PunchLocationSnapshotPayload(CamelModel):
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    accuracy_meters: float = Field(gt=0)
    captured_at: datetime


class PunchRecordResponse(CamelModel):
    type: PunchType
    timestamp: datetime
    detail: str
    project_id: str | None = None
    location: PunchLocationSnapshotPayload | None = None


class WorkLogPayload(CamelModel):
    description: str = Field(min_length=1)
    task_ids: list[str] = Field(min_length=1)


class CreatePunchRequest(CamelModel):
    type: PunchType
    project_id: str | None = None
    location: PunchLocationSnapshotPayload | None = None
    work_log: WorkLogPayload | None = None

    @field_validator("location")
    @classmethod
    def validate_location_snapshot(
        cls,
        value: PunchLocationSnapshotPayload | None,
    ) -> PunchLocationSnapshotPayload | None:
        return value


class ManagedPunchRecordResponse(PunchRecordResponse):
    id: str
    employee_id: str


class ManagedPunchPageResponse(CamelModel):
    records: list[ManagedPunchRecordResponse]
    records_page: int = Field(ge=1)
    records_page_size: int = Field(ge=1)
    records_total: int = Field(ge=0)
    records_total_pages: int = Field(ge=1)
    records_has_previous: bool
    records_has_next: bool


class ManagePunchRequest(CamelModel):
    type: PunchType
    timestamp: datetime | None = None
    detail: str = Field(default="Ajuste manual de ponto.", min_length=1, max_length=500)
    project_id: str | None = None
    location: PunchLocationSnapshotPayload | None = None


class UpdateManagedPunchRequest(CamelModel):
    type: PunchType | None = None
    timestamp: datetime | None = None
    detail: str | None = Field(default=None, min_length=1, max_length=500)
    project_id: str | None = None
    location: PunchLocationSnapshotPayload | None = None

    @model_validator(mode="after")
    def validate_has_update(self) -> "UpdateManagedPunchRequest":
        if not self.model_fields_set:
            raise ValueError("At least one punch field must be provided.")
        return self


class TimeClockEmployeeSummary(CamelModel):
    id: str
    name: str
    unit: str
    status: str
    work_mode: str
    requires_location_on_punch: bool
    trusted_device_required: bool


class TimeClockStateResponse(CamelModel):
    employee: TimeClockEmployeeSummary
    current_status: ShiftStatus
    today_worked_minutes: int
    today_break_minutes: int
    first_check_in_at: datetime | None
    last_punch_at: datetime | None
    records: list[PunchRecordResponse]
    records_page: int = Field(ge=1)
    records_page_size: int = Field(ge=1)
    records_total: int = Field(ge=0)
    records_total_pages: int = Field(ge=1)
    records_has_previous: bool
    records_has_next: bool
