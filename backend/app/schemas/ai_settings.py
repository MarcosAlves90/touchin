from __future__ import annotations

from pydantic import Field, field_validator, model_validator

from app.schemas.base import CamelModel


class AISettingsResponse(CamelModel):
    enabled: bool = False
    provider_base_url: str = ""
    model_id: str = ""
    api_key_configured: bool = False
    privacy_acknowledged: bool = False
    updated_at: str | None = None


class AISettingsUpdate(CamelModel):
    enabled: bool = False
    provider_base_url: str = Field(min_length=1, max_length=2048)
    model_id: str = Field(min_length=1, max_length=200)
    api_key: str | None = Field(default=None, max_length=512)
    remove_api_key: bool = False
    privacy_acknowledged: bool = False

    @field_validator("provider_base_url", "model_id")
    @classmethod
    def reject_empty_values(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Value must not be empty.")
        return value

    @field_validator("api_key")
    @classmethod
    def normalize_api_key(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if value and (not value.isascii() or any(ord(char) < 33 or ord(char) > 126 for char in value)):
            raise ValueError("API key must contain printable ASCII characters only.")
        return value or None

    @model_validator(mode="after")
    def validate_key_actions(self) -> "AISettingsUpdate":
        if self.remove_api_key and self.api_key:
            raise ValueError("Cannot replace and remove the key in the same request.")
        return self


class ProviderTestPayload(CamelModel):
    provider_base_url: str = Field(min_length=1, max_length=2048)
    model_id: str = Field(min_length=1, max_length=200)
    api_key: str | None = Field(default=None, max_length=512)

    @field_validator("provider_base_url", "model_id")
    @classmethod
    def reject_empty_values(cls, value: str) -> str:
        value = value.strip()
        if not value:
            raise ValueError("Value must not be empty.")
        return value

    @field_validator("api_key")
    @classmethod
    def normalize_api_key(cls, value: str | None) -> str | None:
        if value is None:
            return None
        value = value.strip()
        if value and (not value.isascii() or any(ord(char) < 33 or ord(char) > 126 for char in value)):
            raise ValueError("API key must contain printable ASCII characters only.")
        return value or None


class ProviderTestResponse(CamelModel):
    success: bool
    message: str
