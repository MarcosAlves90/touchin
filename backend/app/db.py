from __future__ import annotations

from datetime import datetime, timezone
from typing import overload

from sqlalchemy import create_engine, event, text
from sqlalchemy.engine import make_url
from sqlalchemy.pool import StaticPool
from sqlalchemy.orm import DeclarativeBase, sessionmaker

from app.config import get_settings
from app.database_schema import upgrade_database_schema


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


@overload
def ensure_utc(value: datetime) -> datetime: ...
@overload
def ensure_utc(value: None) -> None: ...


def ensure_utc(value: datetime | None) -> datetime | None:
    if value is None:
        return None
    if value.tzinfo is None:
        return value.replace(tzinfo=timezone.utc)
    return value.astimezone(timezone.utc)


class Base(DeclarativeBase):
    pass


settings = get_settings()
is_sqlite = settings.database_url.startswith("sqlite")
is_memory_sqlite = settings.database_url in {"sqlite://", "sqlite:///:memory:"}
connect_args = {"check_same_thread": False} if is_sqlite else {}
engine_kwargs = {
    "future": True,
    "pool_pre_ping": True,
    "connect_args": connect_args,
}
if is_memory_sqlite:
    engine_kwargs["poolclass"] = StaticPool

database_url = make_url(settings.database_url)
if database_url.drivername in {"postgres", "postgresql"}:
    # SQLAlchemy 2.1 changes the implicit PostgreSQL driver to psycopg 3.
    # Our declared dependency and existing deployment contract use psycopg2.
    database_url = database_url.set(drivername="postgresql+psycopg2")
elif database_url.drivername == "postgresql+psycopg":
    raise RuntimeError(
        "TOUCHIN_DATABASE_URL selects psycopg 3, but this backend uses psycopg2. "
        "Use postgresql+psycopg2://, postgresql:// or postgres://."
    )
elif database_url.drivername.startswith("postgresql+") and database_url.drivername != "postgresql+psycopg2":
    raise RuntimeError(
        "TOUCHIN_DATABASE_URL selects an unsupported PostgreSQL driver. "
        "Use postgresql+psycopg2://, postgresql:// or postgres://."
    )

engine = create_engine(database_url, **engine_kwargs)
if is_sqlite:
    @event.listens_for(engine, "connect")
    def _enable_sqlite_foreign_keys(dbapi_connection, connection_record) -> None:
        # SQLite defaults to unenforced FKs on many installations. Activating
        # enforcement at connect makes cascade/detach semantics enforceable in
        # the actual application as well as in database-specific tests.
        cursor = dbapi_connection.cursor()
        try:
            cursor.execute("PRAGMA foreign_keys=ON")
        finally:
            cursor.close()

SessionLocal = sessionmaker(
    bind=engine,
    autoflush=False,
    autocommit=False,
    expire_on_commit=False,
)


def begin_serialized_write(db: Session) -> None:
    if db.bind is None or db.bind.dialect.name != "sqlite":
        return
    if db.in_transaction():
        if db.new or db.dirty or db.deleted:
            raise RuntimeError("Cannot restart a SQLite transaction with pending changes.")
        db.rollback()
    db.execute(text("BEGIN IMMEDIATE"))


def init_database() -> None:
    from app import models  # noqa: F401

    Base.metadata.create_all(bind=engine)
    upgrade_database_schema(engine)
