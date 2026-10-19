from __future__ import annotations

from datetime import datetime, timezone
from typing import overload

from sqlalchemy import create_engine, text
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
if database_url.drivername == "postgresql":
    # SQLAlchemy 2.1 changes the implicit PostgreSQL driver to psycopg 3.
    # Our declared dependency and existing deployment contract use psycopg2.
    database_url = database_url.set(drivername="postgresql+psycopg2")
elif database_url.drivername == "postgresql+psycopg":
    raise RuntimeError(
        "TOUCHIN_DATABASE_URL selects psycopg 3, but this backend uses psycopg2. "
        "Use postgresql+psycopg2:// or postgresql://."
    )

engine = create_engine(database_url, **engine_kwargs)
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
