"""Work-log retention, manual reconciliation and bounded time-clock transitions."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from os import getenv
from threading import Barrier

import pytest
from sqlalchemy import create_engine, event, inspect, select, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.config import get_settings
from app.crypto import FieldCipher
from app.db import Base, ensure_utc
from app.database_schema import upgrade_database_schema
from app.errors import DomainError
from app.models import Employee, KanbanColumn, Project, Punch, Task, WorkLog, WorkLogTask
from app.schemas.punch import CreatePunchRequest, ManagePunchRequest, PunchType, UpdateManagedPunchRequest
from app.seed import seed_database
from app.services.employees import delete_employee
from app.services.time_clock import create_punch, delete_managed_punch, update_managed_punch


@pytest.fixture
def sqlite_fk():
    engine = create_engine("sqlite://", poolclass=StaticPool, connect_args={"check_same_thread": False})

    @event.listens_for(engine, "connect")
    def enforce_foreign_keys(connection, record):
        connection.execute("PRAGMA foreign_keys=ON")

    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, expire_on_commit=False, autoflush=False)
    with factory() as db:
        seed_database(db)
    yield factory, engine
    engine.dispose()


def _punch_with_log(db, *, employee_id="emp-04", project_id=None):
    cipher = FieldCipher(get_settings().encryption_secret or "")
    end = datetime(2026, 6, 1, 12, tzinfo=timezone.utc)
    start = end - timedelta(hours=2)
    first = Punch(company_id="company-touchin", employee_id=employee_id,
                  project_id=project_id,
                  type="checkIn", timestamp=start,
                  detail_ciphertext=cipher.encrypt("start") or "")
    end_punch = Punch(company_id="company-touchin", employee_id=employee_id,
                      project_id=project_id,
                      type="checkOut", timestamp=end,
                      detail_ciphertext=cipher.encrypt("end") or "")
    db.add_all([first, end_punch])
    db.flush()
    log = WorkLog(company_id="company-touchin", employee_id=employee_id,
                  project_id=project_id,
                  punch_id=end_punch.id, start_time=start, end_time=end,
                  duration_seconds=7200,
                  description_ciphertext=cipher.encrypt("Trabalho comprovado") or "",
                  task_snapshots_ciphertext=cipher.encrypt('["Tarefa histórica"]') or "")
    db.add(log)
    db.commit()
    return first.id, end_punch.id, log.id


def test_application_sqlite_connections_enforce_foreign_keys():
    from app.db import engine

    with engine.connect() as connection:
        assert connection.exec_driver_sql("PRAGMA foreign_keys").scalar() == 1


def test_deleting_punch_retains_history_with_foreign_keys_on(sqlite_fk):
    factory, engine = sqlite_fk
    with factory() as db:
        _, punch_id, log_id = _punch_with_log(db)
        delete_managed_punch(db, company_id="company-touchin", employee_id="emp-04", punch_id=punch_id)
        db.expire_all()
        log = db.get(WorkLog, log_id)
        assert log is not None and log.punch_id is None
        assert log.employee_id == "emp-04"
        assert log.duration_seconds == 7200
        assert db.get(Punch, punch_id) is None
    with engine.connect() as connection:
        assert connection.exec_driver_sql("PRAGMA foreign_key_check").all() == []


def test_deleting_employee_retains_work_logs_and_removes_live_punches(sqlite_fk):
    factory, engine = sqlite_fk
    with factory() as db:
        _, punch_id, log_id = _punch_with_log(db)
        delete_employee(db, company_id="company-touchin", employee_id="emp-04")
        db.expire_all()
        assert db.get(Employee, "emp-04") is None
        assert db.get(Punch, punch_id) is None
        log = db.get(WorkLog, log_id)
        assert log is not None
        assert log.employee_id is None and log.punch_id is None
        assert log.employee_id_snapshot == "emp-04"
        assert log.duration_seconds == 7200
    with engine.connect() as connection:
        assert connection.exec_driver_sql("PRAGMA foreign_key_check").all() == []


def test_legacy_sqlite_work_log_migration_retains_data_and_enables_fk_actions(tmp_path):
    engine = create_engine(f"sqlite:///{tmp_path / 'retention.db'}")

    @event.listens_for(engine, "connect")
    def enforce_foreign_keys(connection, record):
        connection.execute("PRAGMA foreign_keys=ON")

    try:
        Base.metadata.create_all(engine)
        factory = sessionmaker(bind=engine, expire_on_commit=False)
        with factory() as db:
            seed_database(db)
            _, end_id, log_id = _punch_with_log(db)
            project = Project(company_id="company-touchin", name_ciphertext="project")
            db.add(project)
            db.flush()
            column = KanbanColumn(project_id=project.id, name_ciphertext="column", position=0)
            db.add(column)
            db.flush()
            task = Task(project_id=project.id, kanban_column_id=column.id,
                        card_number=1, kanban_position=0, name_ciphertext="task",
                        description_ciphertext="task", type="feature")
            db.add(task)
            db.flush()
            db.add(WorkLogTask(work_log_id=log_id, task_id=task.id))
            task_id = task.id
            db.commit()

        raw = engine.raw_connection()
        cursor = raw.cursor()
        try:
            cursor.execute("PRAGMA foreign_keys=OFF")
            cursor.execute("BEGIN IMMEDIATE")
            cursor.execute("""
                CREATE TABLE work_logs_old (
                    id VARCHAR(64) PRIMARY KEY NOT NULL,
                    company_id VARCHAR(64) NOT NULL REFERENCES companies(id),
                    employee_id VARCHAR(64) NOT NULL REFERENCES employees(id),
                    project_id VARCHAR(64) REFERENCES projects(id),
                    punch_id VARCHAR(64) NOT NULL REFERENCES punches(id),
                    start_time DATETIME NOT NULL, end_time DATETIME NOT NULL,
                    duration_seconds INTEGER NOT NULL,
                    description_ciphertext TEXT NOT NULL,
                    task_snapshots_ciphertext TEXT NOT NULL,
                    created_at DATETIME NOT NULL
                )
            """)
            columns = ("id", "company_id", "employee_id", "project_id", "punch_id",
                       "start_time", "end_time", "duration_seconds",
                       "description_ciphertext", "task_snapshots_ciphertext", "created_at")
            names = ", ".join(columns)
            cursor.execute(f"INSERT INTO work_logs_old ({names}) SELECT {names} FROM work_logs")
            cursor.execute("DROP TABLE work_logs")
            cursor.execute("ALTER TABLE work_logs_old RENAME TO work_logs")
            raw.commit()
            cursor.execute("PRAGMA foreign_keys=ON")
        finally:
            cursor.close()
            raw.close()

        with engine.begin() as conn:
            conn.exec_driver_sql("DROP INDEX ix_punches_employee_timestamp_id")

        upgrade_database_schema(engine)
        upgrade_database_schema(engine)  # migrations must be idempotent
        reflection = inspect(engine)
        columns = {row["name"]: row for row in reflection.get_columns("work_logs")}
        assert columns["employee_id"]["nullable"]
        assert columns["punch_id"]["nullable"]
        assert "employee_id_snapshot" in columns
        assert "ix_punches_employee_timestamp_id" in {
            index["name"] for index in reflection.get_indexes("punches")
        }
        with engine.connect() as connection:
            fk_actions = {row[3]: row[6] for row in connection.exec_driver_sql(
                "PRAGMA foreign_key_list('work_logs')"
            )}
        for name in ("employee_id", "punch_id"):
            assert fk_actions[name] == "SET NULL", fk_actions
        with factory() as db:
            assert db.get(WorkLog, log_id).employee_id_snapshot == "emp-04"
            assert [task.id for task in db.get(WorkLog, log_id).tasks] == [task_id]
            delete_managed_punch(db, company_id="company-touchin", employee_id="emp-04", punch_id=end_id)
            assert db.get(WorkLog, log_id).punch_id is None
            assert [task.id for task in db.get(WorkLog, log_id).tasks] == [task_id]
        with engine.connect() as connection:
            assert connection.exec_driver_sql("PRAGMA foreign_keys").scalar() == 1
            assert connection.exec_driver_sql("PRAGMA foreign_key_check").all() == []
    finally:
        engine.dispose()


def test_manual_edit_recalculates_linked_duration_and_explicit_null_clears_punch_project(sqlite_fk):
    factory, _ = sqlite_fk
    with factory() as db:
        cipher = FieldCipher(get_settings().encryption_secret or "")
        project = Project(company_id="company-touchin", name_ciphertext=cipher.encrypt("Histórico") or "")
        db.add(project)
        db.flush()
        first_id, punch_id, log_id = _punch_with_log(db, project_id=project.id)
        updated = update_managed_punch(db, company_id="company-touchin", employee_id="emp-04", punch_id=punch_id,
                                       payload=UpdateManagedPunchRequest.model_validate({"timestamp": "2026-06-01T11:00:00Z", "projectId": None}))
        assert updated.project_id is None
        log = db.get(WorkLog, log_id)
        assert log.project_id == project.id  # historical task/project attribution
        assert ensure_utc(log.end_time) == datetime(2026, 6, 1, 11, tzinfo=timezone.utc)
        assert log.duration_seconds == 3600
        update_managed_punch(db, company_id="company-touchin", employee_id="emp-04", punch_id=first_id,
                             payload=UpdateManagedPunchRequest.model_validate({"timestamp": "2026-06-01T10:30:00Z"}))
        db.refresh(log)
        assert log.duration_seconds == 1800
        assert ensure_utc(log.start_time) == datetime(2026, 6, 1, 10, 30, tzinfo=timezone.utc)


def test_manual_changes_that_would_count_break_as_work_are_rejected_atomically(sqlite_fk):
    factory, _ = sqlite_fk
    with factory() as db:
        first_id, punch_id, log_id = _punch_with_log(db)
        with pytest.raises(DomainError) as failure:
            update_managed_punch(
                db, company_id="company-touchin", employee_id="emp-04", punch_id=first_id,
                payload=UpdateManagedPunchRequest(type=PunchType.break_start),
            )
        assert failure.value.kind.value == "conflict"
        db.rollback()
        assert db.get(Punch, first_id).type == "checkIn"
        assert db.get(WorkLog, log_id).duration_seconds == 7200

        with pytest.raises(DomainError):
            from app.services.time_clock import create_managed_punch
            create_managed_punch(
                db, company_id="company-touchin", employee_id="emp-04",
                payload=ManagePunchRequest(type=PunchType.break_start,
                                           timestamp=datetime(2026, 6, 1, 11, tzinfo=timezone.utc)),
            )
        db.rollback()
        assert db.get(WorkLog, log_id).duration_seconds == 7200
        assert db.get(Punch, punch_id) is not None


def test_deleting_opening_punch_detaches_preserved_work_log(sqlite_fk):
    factory, _ = sqlite_fk
    with factory() as db:
        first_id, punch_id, log_id = _punch_with_log(db)
        delete_managed_punch(db, company_id="company-touchin", employee_id="emp-04", punch_id=first_id)
        db.expire_all()
        log = db.get(WorkLog, log_id)
        assert log.punch_id is None
        assert log.duration_seconds == 7200
        assert db.get(Punch, punch_id) is not None


def test_create_punch_reads_only_latest_event_for_large_history(sqlite_fk):
    factory, engine = sqlite_fk
    with factory() as db:
        employee = db.get(Employee, "emp-04")
        db.add_all([
            Punch(company_id="company-touchin", employee_id="emp-04", type="checkOut",
                  timestamp=datetime(2025, 1, 1, tzinfo=timezone.utc) + timedelta(minutes=n),
                  detail_ciphertext="old")
            for n in range(1300)
        ])
        db.commit()
    statements = []

    def observe(conn, cursor, sql, parameters, context, many):
        if "FROM punches" in sql and "WHERE punches.employee_id" in sql:
            statements.append(sql.upper())

    event.listen(engine, "before_cursor_execute", observe)
    try:
        with factory() as db:
            employee = db.get(Employee, "emp-04")
            create_punch(db, employee=employee, payload=CreatePunchRequest(type=PunchType.check_in), timezone_name="America/Sao_Paulo")
    finally:
        event.remove(engine, "before_cursor_execute", observe)
    assert statements
    assert all("LIMIT" in sql for sql in statements), statements
    with engine.connect() as connection:
        plan = connection.exec_driver_sql(
            "EXPLAIN QUERY PLAN SELECT id FROM punches WHERE employee_id = ? "
            "ORDER BY timestamp DESC, id DESC LIMIT 1", ("emp-04",),
        ).all()
    assert any("ix_punches_employee_timestamp_id" in row[3] for row in plan), plan
    assert not any("TEMP B-TREE" in row[3].upper() for row in plan)


@pytest.fixture
def pg_read_committed():
    url = getenv("TOUCHIN_TIME_CLOCK_PG_URL", "")
    if not url:
        pytest.skip("TOUCHIN_TIME_CLOCK_PG_URL: isolated PostgreSQL required")
    engine = create_engine(url, isolation_level="READ COMMITTED", pool_size=8, connect_args={"connect_timeout": 4})
    with engine.connect() as conn:
        database_name = conn.scalar(text("SELECT current_database()"))
        isolation = conn.scalar(text("SHOW transaction_isolation"))
    if not database_name.startswith("touchin_time_clock_test_") or isolation != "read committed":
        engine.dispose()
        pytest.fail("Refusing to alter an unidentified/non-READ COMMITTED PostgreSQL database")
    Base.metadata.drop_all(engine)
    Base.metadata.create_all(engine)
    factory = sessionmaker(bind=engine, expire_on_commit=False, autoflush=False)
    with factory() as db:
        seed_database(db)
    yield factory, engine
    engine.dispose()


def test_postgres_parallel_checkins_are_serialized(pg_read_committed):
    factory, _ = pg_read_committed
    barrier = Barrier(2)

    def attempt():
        with factory() as db:
            employee = db.get(Employee, "emp-04")
            barrier.wait(timeout=10)
            try:
                create_punch(db, employee=employee, payload=CreatePunchRequest(type=PunchType.check_in), timezone_name="America/Sao_Paulo")
                return "ok"
            except DomainError:
                db.rollback()
                return "conflict"

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: attempt(), range(2)))
    assert sorted(results) == ["conflict", "ok"]
    with factory() as db:
        assert len(db.scalars(select(Punch).where(Punch.employee_id == "emp-04", Punch.type == "checkIn")).all()) == 1


def test_postgres_work_logs_survive_employee_and_punch_deletions(pg_read_committed):
    factory, engine = pg_read_committed
    with factory() as db:
        _, punch_id, log_id = _punch_with_log(db)
        delete_managed_punch(db, company_id="company-touchin", employee_id="emp-04", punch_id=punch_id)
        db.expire_all()
        assert db.get(WorkLog, log_id).punch_id is None

        _, _, second_log_id = _punch_with_log(db)
        delete_employee(db, company_id="company-touchin", employee_id="emp-04")
        db.expire_all()
        for id_ in (log_id, second_log_id):
            log = db.get(WorkLog, id_)
            assert log.employee_id is None and log.punch_id is None
            assert log.employee_id_snapshot == "emp-04"
        assert db.get(Employee, "emp-04") is None
