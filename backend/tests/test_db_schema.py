from sqlalchemy import create_engine, inspect, text

from app.database_schema import upgrade_database_schema
from app.db import Base
from app import models  # noqa: F401


WORK_LOG_INDEX = "ix_work_logs_company_project_start_time"


def test_new_database_creates_work_log_index(tmp_path):
    bind = create_engine(f"sqlite:///{tmp_path / 'fresh.db'}")
    try:
        Base.metadata.create_all(bind)
        indexes = {index["name"]: index for index in inspect(bind).get_indexes("work_logs")}
        assert indexes[WORK_LOG_INDEX]["column_names"] == [
            "company_id", "project_id", "start_time",
        ]
    finally:
        bind.dispose()


def test_upgrade_restores_index_on_existing_work_logs_without_changing_data(tmp_path, monkeypatch):
    from app import db as db_module

    bind = create_engine(f"sqlite:///{tmp_path / 'existing.db'}")
    try:
        Base.metadata.create_all(bind)
        with bind.begin() as connection:
            connection.execute(text(f"DROP INDEX {WORK_LOG_INDEX}"))
            connection.execute(text(
                "INSERT INTO work_logs "
                "(id, company_id, employee_id, project_id, punch_id, start_time, end_time, "
                "duration_seconds, description_ciphertext, task_snapshots_ciphertext, created_at) "
                "VALUES ('existing-log', 'company', 'employee', 'project', 'punch', "
                "'2026-01-01 00:00:00', '2026-01-01 00:01:00', 60, 'cipher', '[]', "
                "'2026-01-01 00:00:00')"
            ))
        monkeypatch.setattr(db_module, "engine", bind)
        # Exercita o caminho real de inicialização usado pelo lifespan e por create_postgres.
        db_module.init_database()
        db_module.init_database()
        indexes = {index["name"]: index for index in inspect(bind).get_indexes("work_logs")}
        assert indexes[WORK_LOG_INDEX]["column_names"] == [
            "company_id", "project_id", "start_time",
        ]
        with bind.connect() as connection:
            assert connection.execute(
                text("SELECT id, duration_seconds FROM work_logs")
            ).all() == [("existing-log", 60)]
    finally:
        bind.dispose()


def test_upgrade_database_schema_adds_project_id_to_legacy_punches_table(tmp_path):
    database_path = tmp_path / "legacy.db"
    engine = create_engine(f"sqlite:///{database_path}", future=True)
    with engine.begin() as connection:
        connection.execute(
            text(
                "CREATE TABLE punches ("
                "id VARCHAR(64) PRIMARY KEY, "
                "company_id VARCHAR(64) NOT NULL, "
                "employee_id VARCHAR(64) NOT NULL, "
                "type VARCHAR(32) NOT NULL, "
                "timestamp DATETIME NOT NULL, "
                "detail_ciphertext TEXT NOT NULL, "
                "location_payload_ciphertext TEXT, "
                "created_at DATETIME NOT NULL"
                ")",
            ),
        )

    upgrade_database_schema(engine)

    inspector = inspect(engine)
    columns = {column["name"] for column in inspector.get_columns("punches")}
    indexes = {index["name"] for index in inspector.get_indexes("punches")}
    assert "project_id" in columns
    assert "ix_punches_project_id" in indexes


def test_upgrade_database_schema_adds_task_employee_limit_to_legacy_projects(tmp_path):
    database_path = tmp_path / "legacy-projects.db"
    engine = create_engine(f"sqlite:///{database_path}", future=True)
    with engine.begin() as connection:
        connection.execute(
            text(
                "CREATE TABLE projects ("
                "id VARCHAR(64) PRIMARY KEY, "
                "company_id VARCHAR(64) NOT NULL, "
                "name_ciphertext TEXT NOT NULL, "
                "description_ciphertext TEXT, "
                "status VARCHAR(32) NOT NULL, "
                "created_at DATETIME NOT NULL, "
                "updated_at DATETIME NOT NULL"
                ")",
            ),
        )
        connection.execute(
            text(
                "INSERT INTO projects "
                "(id, company_id, name_ciphertext, description_ciphertext, status, created_at, updated_at) "
                "VALUES ('project-legacy', 'company-legacy', 'name', 'description', 'active', "
                "'2026-01-01', '2026-01-01')"
            ),
        )

    upgrade_database_schema(engine)

    columns = {column["name"]: column for column in inspect(engine).get_columns("projects")}
    assert "task_employee_limit" in columns
    assert columns["task_employee_limit"]["nullable"] is False
    with engine.connect() as connection:
        default_value = connection.execute(
            text("select task_employee_limit from projects where id = 'project-legacy'"),
        ).scalar_one()
        assert default_value == 1


def test_upgrade_adds_creation_request_ledger_to_existing_project_database(tmp_path):
    engine = create_engine(f"sqlite:///{tmp_path / 'legacy-idempotency.db'}")
    try:
        with engine.begin() as connection:
            connection.execute(text(
                "CREATE TABLE projects ("
                "id VARCHAR(64) PRIMARY KEY, "
                "company_id VARCHAR(64) NOT NULL)"
            ))
        upgrade_database_schema(engine)
        upgrade_database_schema(engine)
        inspector = inspect(engine)
        assert "task_creation_requests" in inspector.get_table_names()
        assert inspector.get_pk_constraint("task_creation_requests")["constrained_columns"] == [
            "project_id", "actor_user_id", "request_key",
        ]
    finally:
        engine.dispose()
