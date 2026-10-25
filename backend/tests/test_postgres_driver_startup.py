"""Regression: PostgreSQL driver selection must match declared dependencies."""

from __future__ import annotations

import os
import subprocess
import sys

import pytest


def _import_with_database_url(database_url: str) -> subprocess.CompletedProcess[str]:
    env = {key: value for key, value in os.environ.items() if not key.startswith("TOUCHIN_")}
    env.update(
        TOUCHIN_DATABASE_URL=database_url,
        TOUCHIN_TOKEN_SECRET="temporary-test-token-secret",
        TOUCHIN_ENCRYPTION_SECRET="temporary-test-encryption-secret",
        TOUCHIN_SEED_ADMIN_PASSWORD="temporary-test-seed-password",
        TOUCHIN_BOOTSTRAP_DATABASE_ON_STARTUP="false",
        TOUCHIN_SEED_ON_STARTUP="false",
    )
    return subprocess.run(
        [
            sys.executable,
            "-c",
            "from app.main import app; from app.db import engine; "
            "assert engine.dialect.name == 'postgresql'; "
            "print(engine.dialect.driver); "
            "assert app is not None",
        ],
        env=env,
        capture_output=True,
        text=True,
        check=False,
        timeout=30,
    )


@pytest.mark.parametrize(
    "database_url",
    [
        "postgres://unused:unused@localhost/unused",
        "postgresql://unused:unused@localhost/unused",
        "postgresql+psycopg2://unused:unused@localhost/unused",
    ],
)
def test_import_selects_declared_psycopg2_without_database_connection(database_url):
    result = _import_with_database_url(database_url)
    assert result.returncode == 0, result.stderr
    assert result.stdout.strip() == "psycopg2"


def test_explicit_psycopg3_url_reports_configuration_error():
    result = _import_with_database_url("postgresql+psycopg://unused:unused@localhost/unused")
    assert result.returncode != 0
    assert "TOUCHIN_DATABASE_URL selects psycopg 3" in result.stderr
    assert "ModuleNotFoundError" not in result.stderr


@pytest.mark.parametrize("driver", ["postgresql+asyncpg", "postgresql+pg8000"])
def test_unsupported_driver_fails_safely(driver):
    result = _import_with_database_url(f"{driver}://secret_user:secret_password@localhost/unused")
    assert result.returncode != 0
    assert "TOUCHIN_DATABASE_URL" in result.stderr
    assert "secret_password" not in result.stderr
    assert "ModuleNotFoundError" not in result.stderr
