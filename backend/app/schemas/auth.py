from __future__ import annotations

from datetime import datetime

from pydantic import EmailStr, Field, field_validator

from app.schemas.base import CamelModel


class CompanyRegisterRequest(CamelModel):
    company_name: str = Field(min_length=5, max_length=255)
    trade_name: str = Field(min_length=2, max_length=255)
    cnpj: str
    email: EmailStr
    phone: str = Field(min_length=10, max_length=20)
    password: str = Field(min_length=8, max_length=128)
    accept_terms: bool

    @field_validator("cnpj")
    @classmethod
    def validate_cnpj(cls, value: str) -> str:
        digits = "".join(character for character in value if character.isdigit())
        if len(digits) != 14:
            raise ValueError("CNPJ must contain exactly 14 digits.")
        return value.strip()

    @field_validator("phone")
    @classmethod
    def validate_phone(cls, value: str) -> str:
        digits = "".join(character for character in value if character.isdigit())
        if len(digits) < 10 or len(digits) > 11:
            raise ValueError("Phone must contain 10 or 11 digits.")
        return value.strip()

    @field_validator("accept_terms")
    @classmethod
    def validate_accept_terms(cls, value: bool) -> bool:
        if not value:
            raise ValueError("Terms must be accepted before registration.")
        return value


class LoginRequest(CamelModel):
    email: EmailStr
    password: str = Field(min_length=8, max_length=128)
    keep_connected: bool = True


class PasswordResetRequest(CamelModel):
    email: EmailStr


class PasswordChangeRequest(CamelModel):
    current_password: str = Field(min_length=8, max_length=128)
    new_password: str = Field(min_length=8, max_length=128)


class CompanySummary(CamelModel):
    id: str
    legal_name: str
    trade_name: str
    cnpj_masked: str
    email_masked: str
    phone_masked: str


class UserSummary(CamelModel):
    id: str
    email: str
    role: str
    employee_id: str | None = None


class AuthSessionResponse(CamelModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: datetime
    must_change_password: bool = False
    company: CompanySummary
    user: UserSummary


class AuthContextResponse(CamelModel):
    company: CompanySummary
    user: UserSummary
    must_change_password: bool = False
