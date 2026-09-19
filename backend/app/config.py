from __future__ import annotations

try:
    from dotenv import load_dotenv
    load_dotenv()
except Exception:
    pass

import os
from functools import lru_cache


def _parse_bool(value: str | None, *, default: bool) -> bool:
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def _parse_csv(value: str | None, *, default: list[str]) -> list[str]:
    if value is None or not value.strip():
        return default
    return [item.strip() for item in value.split(",") if item.strip()]


class Settings:
    def __init__(self) -> None:
        self.app_name = os.getenv("TOUCHIN_APP_NAME", "TouchIn Backend")
        self.environment = os.getenv("TOUCHIN_ENV", "development")
        self.database_url = os.getenv(
            "TOUCHIN_DATABASE_URL",
            "sqlite:///./touchin.db",
        )
        self.timezone = os.getenv("TOUCHIN_TIMEZONE", "America/Sao_Paulo")
        self.token_secret = os.getenv("TOUCHIN_TOKEN_SECRET")
        self.encryption_secret = os.getenv("TOUCHIN_ENCRYPTION_SECRET")
        self.token_ttl_hours = int(os.getenv("TOUCHIN_TOKEN_TTL_HOURS", "12"))
        self.remember_me_ttl_days = int(
            os.getenv("TOUCHIN_REMEMBER_ME_TTL_DAYS", "30"),
        )
        self.enforce_https = _parse_bool(
            os.getenv("TOUCHIN_ENFORCE_HTTPS"),
            default=False,
        )
        seed_on_startup_default = self.environment in {"development", "test"}
        self.seed_on_startup = _parse_bool(
            os.getenv("TOUCHIN_SEED_ON_STARTUP"),
            default=seed_on_startup_default,
        )
        self.bootstrap_database_on_startup = _parse_bool(
            os.getenv("TOUCHIN_BOOTSTRAP_DATABASE_ON_STARTUP"),
            default=seed_on_startup_default,
        )
        self.allowed_origins = _parse_csv(
            os.getenv("TOUCHIN_ALLOWED_ORIGINS"),
            default=[
                "http://localhost",
                "http://localhost:3000",
                "http://localhost:5173",
                "http://localhost:8080",
            ],
        )
        self.seed_admin_password = os.getenv("TOUCHIN_SEED_ADMIN_PASSWORD")
        self.brevo_api_key = os.getenv("TOUCHIN_BREVO_API_KEY")
        self.brevo_sender_email = os.getenv("TOUCHIN_BREVO_SENDER_EMAIL")
        self.brevo_sender_name = os.getenv(
            "TOUCHIN_BREVO_SENDER_NAME",
            self.app_name,
        )
        self.brevo_welcome_enabled = _parse_bool(
            os.getenv("TOUCHIN_BREVO_WELCOME_ENABLED"),
            default=True,
        )

        missing = [
            name
            for name, value in {
                "TOUCHIN_TOKEN_SECRET": self.token_secret,
                "TOUCHIN_ENCRYPTION_SECRET": self.encryption_secret,
                "TOUCHIN_SEED_ADMIN_PASSWORD": self.seed_admin_password,
            }.items()
            if not value
        ]
        if missing:
            missing_list = ", ".join(missing)
            raise RuntimeError(
                "Missing required environment variables: "
                f"{missing_list}. Configure them before starting the backend.",
            )


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
