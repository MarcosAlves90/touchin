"""Work-log retention, manual reconciliation and bounded time-clock transitions."""

from __future__ import annotations

from concurrent.futures import ThreadPoolExecutor
from datetime import datetime, timedelta, timezone
from os import getenv
from threading import Barrier, Event

import pytest
from sqlalchemy import create_engine, delete, event, inspect, insert, select, text
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app.config import get_settings
from app.crypto import FieldCipher
from app.db import Base, ensure_utc
from app.database_schema import upgrade_database_schema
from app.errors import DomainError
from app.models import Company, Employee, EmployeeProject, KanbanColumn, Project, Punch, Task, WorkLog, WorkLogTask
from app.schemas.punch import CreatePunchRequest, ManagePunchRequest, PunchType, UpdateManagedPunchRequest, WorkLogPayload
from app.seed import seed_database
from app.services.employees import delete_employee
from app.services.projects import remove_project_member
from app.services.time_clock import create_managed_punch, create_punch, delete_managed_punch, update_managed_punch


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


def test_historical_report_allows_former_member_only_their_company_project_and_work(sqlite_fk):
    from app.domain.project_read import generate_monthly_work_logs_report

    factory, _ = sqlite_fk
    with factory() as db:
        cipher = FieldCipher(get_settings().encryption_secret or "")
        project = Project(company_id="company-touchin", name_ciphertext=cipher.encrypt("Original") or "")
        unrelated = Project(company_id="company-touchin", name_ciphertext=cipher.encrypt("Other") or "")
        db.add_all([project, unrelated])
        db.flush()
        link = EmployeeProject(project_id=project.id, employee_id="emp-04")
        db.add(link)
        db.commit()
        _, _, historical_id = _punch_with_log(db, project_id=project.id)
        foreign_employee_log = WorkLog(
            company_id="company-touchin", employee_id="emp-05", employee_id_snapshot="emp-05",
            project_id=project.id, punch_id=None,
            start_time=datetime(2026, 6, 1, 10, tzinfo=timezone.utc),
            end_time=datetime(2026, 6, 1, 12, tzinfo=timezone.utc), duration_seconds=7200,
            description_ciphertext=cipher.encrypt("other-person") or "",
            task_snapshots_ciphertext=cipher.encrypt("[]") or "",
        )
        db.add(foreign_employee_log)
        # A malformed legacy row must never bridge the project/company boundary.
        company = db.get(Company, "company-touchin")
        foreign_company = Company(
            id="foreign-company", legal_name_ciphertext=company.legal_name_ciphertext,
            trade_name_ciphertext=company.trade_name_ciphertext,
            cnpj_ciphertext=company.cnpj_ciphertext, cnpj_hash="foreign-cnpj",
            contact_email_ciphertext=company.contact_email_ciphertext,
            contact_email_hash="foreign-email", contact_phone_ciphertext=company.contact_phone_ciphertext,
            consented_at=company.consented_at,
        )
        db.add(foreign_company)
        db.flush()
        db.add(WorkLog(
            company_id=foreign_company.id, employee_id_snapshot="emp-04", project_id=project.id,
            start_time=datetime(2026, 6, 1, 10, tzinfo=timezone.utc),
            end_time=datetime(2026, 6, 1, 12, tzinfo=timezone.utc), duration_seconds=7200,
            description_ciphertext=cipher.encrypt("foreign-company-secret") or "",
            task_snapshots_ciphertext=cipher.encrypt("[]") or "",
        ))
        db.commit()
        remove_project_member(db, company_id="company-touchin", project_id=project.id,
                              employee_id="emp-04")

        def report(*, company_id="company-touchin", project_id=project.id, employee_id=None):
            return generate_monthly_work_logs_report(
                db, company_id=company_id, project_id=project_id, year=2026, month=6,
                timezone_name="America/Sao_Paulo", employee_id=employee_id,
            )

        own = report(employee_id="emp-04")
        assert [item.description for item in own.records] == ["Trabalho comprovado"]
        assert db.get(WorkLog, historical_id).duration_seconds == 7200
        assert {item.description for item in report().records} == {
            "Trabalho comprovado", "other-person",
        }
        for kwargs in (
            {"employee_id": "emp-03"},
            {"employee_id": "emp-04", "project_id": unrelated.id},
            {"employee_id": "emp-04", "company_id": "foreign-company"},
        ):
            with pytest.raises(DomainError) as denied:
                report(**kwargs)
            assert denied.value.kind.value == "not_found"

        delete_employee(db, company_id="company-touchin", employee_id="emp-04")
        db.expire_all()
        retained = db.get(WorkLog, historical_id)
        assert retained.employee_id is None
        assert retained.employee_id_snapshot == "emp-04"
        assert retained.duration_seconds == 7200
        assert {item.description for item in report().records} == {
            "Trabalho comprovado", "other-person",
        }


@pytest.mark.parametrize("punch_type,hour", [
    (PunchType.check_in, 9),
    (PunchType.check_in, 11),
    (PunchType.check_out, 13),
])
def test_managed_insertion_rejects_invalid_full_transition_and_retains_7200s(sqlite_fk, punch_type, hour):
    factory, _ = sqlite_fk
    with factory() as db:
        first_id, end_id, log_id = _punch_with_log(db)
        existing = set(db.scalars(select(Punch.id).where(Punch.employee_id == "emp-04")).all())
        with pytest.raises(DomainError) as failure:
            create_managed_punch(
                db, company_id="company-touchin", employee_id="emp-04",
                payload=ManagePunchRequest(type=punch_type,
                                           timestamp=datetime(2026, 6, 1, hour, tzinfo=timezone.utc)),
            )
        assert failure.value.kind.value == "conflict"
        db.rollback()
        assert set(db.scalars(select(Punch.id).where(Punch.employee_id == "emp-04")).all()) == existing
        assert db.get(Punch, first_id).type == "checkIn"
        assert db.get(Punch, end_id).type == "checkOut"
        assert db.get(WorkLog, log_id).duration_seconds == 7200


def test_managed_move_and_type_edit_reject_invalid_neighbors_without_rewriting_history(sqlite_fk):
    factory, _ = sqlite_fk
    with factory() as db:
        # Keep this history isolated from the seeded employee's current shift.
        db.execute(delete(Punch).where(Punch.employee_id == "emp-04"))
        db.commit()
        _, end_id, log_id = _punch_with_log(db)
        next_in = create_managed_punch(
            db, company_id="company-touchin", employee_id="emp-04",
            payload=ManagePunchRequest(type=PunchType.check_in,
                                       timestamp=datetime(2026, 6, 1, 14, tzinfo=timezone.utc)),
        )
        create_managed_punch(
            db, company_id="company-touchin", employee_id="emp-04",
            payload=ManagePunchRequest(type=PunchType.check_out,
                                       timestamp=datetime(2026, 6, 1, 16, tzinfo=timezone.utc)),
        )
        for payload in (
            UpdateManagedPunchRequest(timestamp=datetime(2026, 6, 1, 11, tzinfo=timezone.utc)),
            UpdateManagedPunchRequest(type=PunchType.break_end),
        ):
            with pytest.raises(DomainError) as failure:
                update_managed_punch(db, company_id="company-touchin", employee_id="emp-04",
                                     punch_id=next_in.id, payload=payload)
            assert failure.value.kind.value == "conflict"
            db.rollback()
            assert db.get(Punch, next_in.id).type == "checkIn"
            assert ensure_utc(db.get(Punch, next_in.id).timestamp) == datetime(2026, 6, 1, 14, tzinfo=timezone.utc)
            assert db.get(Punch, end_id).type == "checkOut"
            assert db.get(WorkLog, log_id).duration_seconds == 7200


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


@pytest.mark.parametrize("database_fixture", ["sqlite_fk", "pg_read_committed"])
def test_replacement_checkout_cannot_double_count_detached_work_log(
    request, monkeypatch, database_fixture,
):
    factory, engine = request.getfixturevalue(database_fixture)
    start = datetime(2026, 6, 1, 10, tzinfo=timezone.utc)
    first_end = start + timedelta(hours=2)
    replacement_end = start + timedelta(hours=3)
    with factory() as db:
        cipher = FieldCipher(get_settings().encryption_secret or "")
        project = Project(company_id="company-touchin", name_ciphertext=cipher.encrypt("Jornada") or "")
        db.add(project)
        db.flush()
        db.add(EmployeeProject(project_id=project.id, employee_id="emp-04"))
        column = KanbanColumn(project_id=project.id, name_ciphertext=cipher.encrypt("A Fazer") or "", position=0)
        db.add(column)
        db.flush()
        task = Task(project_id=project.id, kanban_column_id=column.id, card_number=1,
                    kanban_position=0, name_ciphertext=cipher.encrypt("Atividade") or "",
                    description_ciphertext="", type="feature")
        db.add(task)
        db.commit()

        # Seeded punches may be newer than this historical scenario; isolate
        # the employee's shift so the next operational punch is truly checkOut.
        db.execute(delete(Punch).where(Punch.employee_id == "emp-04"))
        db.commit()
        check_in_id, check_out_id, log_id = _punch_with_log(db, project_id=project.id)
        delete_managed_punch(db, company_id="company-touchin", employee_id="emp-04", punch_id=check_out_id)
        db.expire_all()
        retained = db.get(WorkLog, log_id)
        assert retained.punch_id is None
        assert (ensure_utc(retained.start_time), ensure_utc(retained.end_time), retained.duration_seconds) == (
            start, first_end, 7200,
        )
        assert db.get(Punch, check_in_id) is not None

        monkeypatch.setattr("app.services.time_clock.utcnow", lambda: replacement_end)
        try:
            create_punch(db, employee=db.get(Employee, "emp-04"),
                         payload=CreatePunchRequest(type=PunchType.check_out, project_id=project.id,
                                                    work_log=WorkLogPayload(description="Saida substituta",
                                                                            task_ids=[task.id])),
                         timezone_name="America/Sao_Paulo")
        except DomainError as failure:
            assert failure.kind.value == "conflict"
        else:
            db.expire_all()
            duplicates = db.scalars(select(WorkLog).where(
                WorkLog.company_id == "company-touchin", WorkLog.employee_id == "emp-04",
                WorkLog.start_time < replacement_end, WorkLog.end_time > start,
            )).all()
            pytest.fail("Overlapping WorkLogs after replacement checkout: "
                        f"durations={[log.duration_seconds for log in duplicates]}, "
                        f"total={sum(log.duration_seconds for log in duplicates)} seconds")
        db.rollback()
        db.expire_all()
        logs = db.scalars(select(WorkLog).where(
            WorkLog.company_id == "company-touchin", WorkLog.employee_id == "emp-04",
            WorkLog.start_time < replacement_end, WorkLog.end_time > start,
        )).all()
        assert [log.id for log in logs] == [log_id]
        assert sum(log.duration_seconds for log in logs) == 7200
        assert db.get(WorkLog, log_id).punch_id is None
        assert db.get(Punch, check_out_id) is None
        assert db.get(Punch, check_in_id).type == PunchType.check_in.value

    if engine.dialect.name == "sqlite":
        with engine.connect() as conn:
            assert conn.exec_driver_sql("PRAGMA foreign_keys").scalar() == 1
            assert conn.exec_driver_sql("PRAGMA foreign_key_check").all() == []


@pytest.mark.parametrize("database_fixture", ["sqlite_fk", "pg_read_committed"])
def test_consecutive_nonoverlapping_shifts_still_account_real_work(
    request, monkeypatch, database_fixture,
):
    factory, engine = request.getfixturevalue(database_fixture)
    end_first = datetime(2026, 6, 1, 12, tzinfo=timezone.utc)
    start_second = end_first + timedelta(minutes=1)
    end_second = start_second + timedelta(hours=1)
    with factory() as db:
        cipher = FieldCipher(get_settings().encryption_secret or "")
        project = Project(company_id="company-touchin", name_ciphertext=cipher.encrypt("Turnos") or "")
        db.add(project)
        db.flush()
        db.add(EmployeeProject(project_id=project.id, employee_id="emp-04"))
        column = KanbanColumn(project_id=project.id, name_ciphertext="Coluna", position=0)
        db.add(column)
        db.flush()
        task = Task(project_id=project.id, kanban_column_id=column.id, card_number=1,
                    kanban_position=0, name_ciphertext=cipher.encrypt("Atividade") or "",
                    description_ciphertext="", type="feature")
        db.add(task)
        db.commit()

        db.execute(delete(Punch).where(Punch.employee_id == "emp-04"))
        db.commit()
        _, _, log_a_id = _punch_with_log(db, project_id=project.id)
        # Give adjacent shifts distinct timestamps: equal-time punches are
        # ordered by UUID id and do not encode a chronological transition.
        monkeypatch.setattr("app.services.time_clock.utcnow", lambda: start_second)
        create_punch(db, employee=db.get(Employee, "emp-04"),
                     payload=CreatePunchRequest(type=PunchType.check_in, project_id=project.id),
                     timezone_name="America/Sao_Paulo")
        monkeypatch.setattr("app.services.time_clock.utcnow", lambda: end_second)
        create_punch(db, employee=db.get(Employee, "emp-04"),
                     payload=CreatePunchRequest(type=PunchType.check_out, project_id=project.id,
                                                work_log=WorkLogPayload(description="Turno adicional",
                                                                        task_ids=[task.id])),
                     timezone_name="America/Sao_Paulo")
        rows = db.scalars(select(WorkLog).where(
            WorkLog.company_id == "company-touchin", WorkLog.employee_id == "emp-04",
            WorkLog.start_time < end_second,
            WorkLog.end_time > end_first - timedelta(hours=2),
        )).all()
        assert sorted((ensure_utc(log.start_time), ensure_utc(log.end_time), log.duration_seconds)
                      for log in rows) == [
            (end_first - timedelta(hours=2), end_first, 7200),
            (start_second, end_second, 3600),
        ]
        assert sum(log.duration_seconds for log in rows) == 10800
        assert db.get(WorkLog, log_a_id).duration_seconds == 7200
    if engine.dialect.name == "sqlite":
        with engine.connect() as conn:
            assert conn.exec_driver_sql("PRAGMA foreign_key_check").all() == []


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
    with factory() as db:
        initial_ids = set(db.scalars(select(Punch.id).where(
            Punch.employee_id == "emp-04", Punch.type == "checkIn",
        )).all())
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
        final_ids = set(db.scalars(select(Punch.id).where(
            Punch.employee_id == "emp-04", Punch.type == "checkIn",
        )).all())
        assert len(final_ids - initial_ids) == 1


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


def test_postgres_legacy_work_log_schema_migrates_without_losing_history(pg_read_committed):
    factory, engine = pg_read_committed
    with factory() as db:
        _, punch_id, log_id = _punch_with_log(db)

    # Reproduce the original mandatory live references on a dedicated PG DB.
    legacy_fks = inspect(engine).get_foreign_keys("work_logs")
    quote = engine.dialect.identifier_preparer.quote
    with engine.begin() as conn:
        for fk in legacy_fks:
            if "employee_id" in fk["constrained_columns"] or "punch_id" in fk["constrained_columns"]:
                conn.execute(text(f"ALTER TABLE work_logs DROP CONSTRAINT {quote(fk['name'])}"))
        conn.execute(text("ALTER TABLE work_logs ALTER COLUMN employee_id SET NOT NULL"))
        conn.execute(text("ALTER TABLE work_logs ALTER COLUMN punch_id SET NOT NULL"))
        conn.execute(text("ALTER TABLE work_logs DROP COLUMN employee_id_snapshot"))
        conn.execute(text("ALTER TABLE work_logs ADD CONSTRAINT legacy_worklog_employee "
                          "FOREIGN KEY (employee_id) REFERENCES employees(id)"))
        conn.execute(text("ALTER TABLE work_logs ADD CONSTRAINT legacy_worklog_punch "
                          "FOREIGN KEY (punch_id) REFERENCES punches(id)"))

    upgrade_database_schema(engine)
    upgrade_database_schema(engine)
    columns = {item["name"]: item for item in inspect(engine).get_columns("work_logs")}
    assert columns["employee_id"]["nullable"]
    assert columns["punch_id"]["nullable"]
    assert "employee_id_snapshot" in columns
    actions = {
        column: (fk.get("options") or {}).get("ondelete", "").upper()
        for fk in inspect(engine).get_foreign_keys("work_logs")
        for column in fk["constrained_columns"]
    }
    assert actions["employee_id"] == actions["punch_id"] == "SET NULL"
    with factory() as db:
        log = db.get(WorkLog, log_id)
        assert log.employee_id_snapshot == "emp-04"
        delete_managed_punch(db, company_id="company-touchin", employee_id="emp-04", punch_id=punch_id)
        db.expire_all()
        assert db.get(WorkLog, log_id).punch_id is None


def test_postgres_parallel_password_reset_confirmation_is_single_use(pg_read_committed):
    from app.crypto import lookup_digest
    from app.models import PasswordResetToken, UserAccount
    from app.security import verify_password
    from app.services.password_reset import request_password_reset, confirm_password_reset

    factory, _ = pg_read_committed
    email = "marina.costa@touchin.com"
    with factory() as db:
        issued = request_password_reset(db, email=email, client_ip="192.0.2.201")
        assert issued is not None
        token = issued[2]

    barrier = Barrier(2)

    def attempt(password):
        with factory() as db:
            barrier.wait(timeout=10)
            try:
                confirm_password_reset(db, token=token, new_password=password,
                                       client_ip="192.0.2.201")
                return "accepted", password
            except DomainError:
                db.rollback()
                return "rejected", password

    passwords = ("PostgresConcurrentA!123", "PostgresConcurrentB!123")
    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(attempt, passwords))
    assert sorted(status for status, _ in results) == ["accepted", "rejected"]
    accepted_password = next(password for status, password in results if status == "accepted")
    with factory() as db:
        email_hash = lookup_digest(email, get_settings().encryption_secret or "")
        user = db.scalar(select(UserAccount).where(UserAccount.email_hash == email_hash))
        assert user is not None and verify_password(accepted_password, user.password_hash)
        assert db.scalar(select(PasswordResetToken)).consumed_at is not None


def test_postgres_admin_punch_write_waits_for_employee_lock(pg_read_committed):
    from app.services.time_clock import create_managed_punch

    factory, engine = pg_read_committed
    about_to_lock = Event()
    with factory() as db:
        last = db.scalar(select(Punch).where(
            Punch.employee_id == "emp-04",
        ).order_by(Punch.timestamp.desc(), Punch.id.desc()).limit(1))
        assert last is not None and last.type == PunchType.check_out.value
        # Preserve a valid checkOut -> checkIn edge: this test isolates the
        # employee row lock, not rejection of invalid punch sequences.
        new_timestamp = ensure_utc(last.timestamp) + timedelta(hours=1)

    def observe(conn, cursor, statement, parameters, context, many):
        if "FROM employees" in statement and "FOR UPDATE" in statement:
            about_to_lock.set()

    def administrative_write():
        with factory() as db:
            return create_managed_punch(
                db, company_id="company-touchin", employee_id="emp-04",
                payload=ManagePunchRequest(
                    type=PunchType.check_in,
                    timestamp=new_timestamp,
                ),
            )

    with factory() as blocker:
        blocker.scalar(select(Employee).where(Employee.id == "emp-04").with_for_update())
        event.listen(engine, "before_cursor_execute", observe)
        try:
            with ThreadPoolExecutor(max_workers=1) as pool:
                pending = pool.submit(administrative_write)
                assert about_to_lock.wait(timeout=10), "admin never reached employee row lock"
                assert not pending.done(), "admin write bypassed the employee lock"
                blocker.commit()
                result = pending.result(timeout=10)
                assert result.employee_id == "emp-04"
        finally:
            event.remove(engine, "before_cursor_execute", observe)


def test_postgres_latest_punch_query_uses_bounded_index_access(pg_read_committed):
    factory, engine = pg_read_committed
    with engine.begin() as conn:
        history = [
            {
                "company_id": "company-touchin", "employee_id": "emp-04",
                "type": "checkOut", "detail_ciphertext": "historic",
                "timestamp": datetime(2022, 1, 1, tzinfo=timezone.utc) + timedelta(minutes=n),
            }
            for n in range(5000)
        ]
        conn.execute(insert(Punch), history)
        conn.execute(text("ANALYZE punches"))
        plan = conn.execute(text(
            "EXPLAIN (ANALYZE, FORMAT JSON) SELECT id FROM punches "
            "WHERE employee_id = 'emp-04' "
            "ORDER BY timestamp DESC, id DESC LIMIT 1"
        )).scalar()
    root = plan[0]["Plan"]
    assert root["Node Type"] == "Limit"
    index_step = root["Plans"][0]
    assert index_step["Node Type"] in {"Index Scan", "Index Only Scan"}, root
    assert index_step["Index Name"] == "ix_punches_employee_timestamp_id"
    assert index_step["Actual Rows"] == 1

    captured = []

    def observe(conn, cursor, statement, parameters, context, many):
        if "FROM punches" in statement and "WHERE punches.employee_id" in statement:
            captured.append(statement.upper())

    event.listen(engine, "before_cursor_execute", observe)
    try:
        with factory() as db:
            employee = db.get(Employee, "emp-04")
            create_punch(db, employee=employee,
                         payload=CreatePunchRequest(type=PunchType.check_in),
                         timezone_name="America/Sao_Paulo")
    finally:
        event.remove(engine, "before_cursor_execute", observe)
    assert captured and all("LIMIT" in sql for sql in captured), captured


def test_postgres_invalid_manual_edit_rolls_back_work_log(pg_read_committed):
    factory, _ = pg_read_committed
    with factory() as db:
        first_id, _, log_id = _punch_with_log(db)
        with pytest.raises(DomainError):
            update_managed_punch(
                db, company_id="company-touchin", employee_id="emp-04",
                punch_id=first_id,
                payload=UpdateManagedPunchRequest(type=PunchType.break_start),
            )
        db.rollback()
        db.expire_all()
        assert db.get(Punch, first_id).type == "checkIn"
        assert db.get(WorkLog, log_id).duration_seconds == 7200


def test_postgres_concurrent_reset_requests_leave_only_newest_token_valid(pg_read_committed):
    from app.models import PasswordResetToken, UserAccount
    from app.services.password_reset import request_password_reset

    factory, _ = pg_read_committed
    barrier = Barrier(2)

    def request():
        with factory() as db:
            barrier.wait(timeout=10)
            return request_password_reset(
                db, email="marina.costa@touchin.com", client_ip="198.51.100.80"
            )

    with ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(lambda _: request(), range(2)))
    assert all(item is not None for item in results)
    with factory() as db:
        user = db.scalar(select(UserAccount).where(UserAccount.role == "admin"))
        assert user is not None
        issued = db.scalars(select(PasswordResetToken).where(
            PasswordResetToken.user_id == user.id,
        )).all()
        assert len(issued) == 2
        assert sum(item.consumed_at is None for item in issued) == 1
