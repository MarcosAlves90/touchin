from __future__ import annotations

from datetime import datetime, time
from enum import Enum

from pydantic import EmailStr, Field, field_validator

from app.schemas.base import CamelModel


class EmployeeStatus(str, Enum):
    active = "active"
    onboarding = "onboarding"
    on_leave = "onLeave"
    inactive = "inactive"


class EmployeeWorkMode(str, Enum):
    onsite = "onsite"
    hybrid = "hybrid"
    remote = "remote"


class RoleLevel(str, Enum):
    staff = "staff"
    specialist = "specialist"
    leadership = "leadership"


class EmployeeAccessRole(str, Enum):
    employee = "employee"
    manager = "manager"


class EmployeeDraftPayload(CamelModel):
    name: str = Field(min_length=3)
    role: str = Field(min_length=2)
    department: str = Field(min_length=2)
    email: EmailStr
    phone: str = Field(min_length=10, max_length=20)
    unit: str = Field(min_length=2)
    expected_shift_start: time
    expected_shift_end: time
    status: EmployeeStatus
    work_mode: EmployeeWorkMode
    role_level: RoleLevel
    access_role: EmployeeAccessRole | None = None
    requires_location_on_punch: bool
    trusted_device_required: bool
    notes: str = Field(default="", max_length=2_000)

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, value: str) -> str:
        digits = "".join(character for character in value if character.isdigit())
        if len(digits) < 10 or len(digits) > 11:
            raise ValueError("Phone must include a valid DDD and local number.")
        return value.strip()


class EmployeeProfileResponse(CamelModel):
    id: str
    # Nullable during rolling upgrades: legacy responses omit account metadata.
    has_account: bool | None = None
    access_role: str | None = None
    name: str
    role: str
    department: str
    email: str
    phone: str
    unit: str
    expected_shift_start: time
    expected_shift_end: time
    status: EmployeeStatus
    work_mode: EmployeeWorkMode
    role_level: RoleLevel
    requires_location_on_punch: bool
    trusted_device_required: bool
    today_worked_minutes: int
    pending_adjustments: int
    last_punch_at: datetime | None
    notes: str
