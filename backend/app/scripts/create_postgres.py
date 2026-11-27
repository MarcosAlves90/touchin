from __future__ import annotations

import re

from sqlalchemy import create_engine, text
from sqlalchemy.engine import make_url

from app.config import get_settings
from app.db import init_database


def create_postgres_database() -> tuple[str, bool]:
    settings = get_settings()
    url = make_url(settings.database_url)
    if not url.drivername.startswith("postgresql"):
        raise RuntimeError(
            "This create task only supports PostgreSQL. "
            f"Current database URL is '{settings.database_url}'.",
        )

    database_name = url.database
    if not database_name:
        raise RuntimeError("Database name is missing in TOUCHIN_DATABASE_URL.")

    if not re.fullmatch(r"\w+", database_name, flags=re.ASCII):
        raise RuntimeError(
            "Database name contains unsupported characters. "
            "Use only letters, numbers, and underscores.",
        )

    admin_url = url.set(database="postgres")
    admin_engine = create_engine(
        admin_url,
        future=True,
        isolation_level="AUTOCOMMIT",
        pool_pre_ping=True,
    )
    created = False
    with admin_engine.connect() as connection:
        exists = connection.execute(
            text("SELECT 1 FROM pg_database WHERE datname = :db_name"),
            {"db_name": database_name},
        ).scalar()
        if not exists:
            connection.execute(text(f'CREATE DATABASE "{database_name}"'))
            created = True
    admin_engine.dispose()

    init_database()

    return database_name, created


if __name__ == "__main__":
    db_name, created = create_postgres_database()
    status = "created" if created else "already existed"
    print(f"PostgreSQL database '{db_name}' {status} and schema initialized.")
