"""Read-only application profiling plus isolated DDL verification.

Only operates on the specifically named, locally-created scratch database.
Do not point this script at production or a shared database.
"""
import datetime as dt
import json
import os
import time

DB_NAME = os.environ.get("TOUCHIN_BENCH_DB", "touchin_perf_validation_20261010")
if not DB_NAME.startswith("touchin_perf_validation_"):
    raise RuntimeError("Use an explicitly isolated touchin_perf_validation_* database.")
os.environ["TOUCHIN_DATABASE_URL"] = f"postgresql+psycopg2:///{DB_NAME}"
os.environ["TOUCHIN_ENCRYPTION_SECRET"] = "isolated-performance-test-secret"
os.environ["TOUCHIN_TOKEN_SECRET"] = "isolated-performance-test-token"
os.environ["TOUCHIN_SEED_ADMIN_PASSWORD"] = "isolated-performance-test-password"

from sqlalchemy import event, inspect, text
from app.crypto import FieldCipher
from app.db import engine, init_database, SessionLocal
from app.domain.project_read import generate_monthly_work_logs_report


def say(*args):
    print(*args, flush=True)


assert engine.url.database == DB_NAME and engine.url.host in (None, "", "localhost")
with engine.connect() as conn:
    if conn.execute(text("SELECT to_regclass('public.work_logs')")).scalar():
        if conn.execute(text("SELECT EXISTS(SELECT 1 FROM public.work_logs)")).scalar():
            raise RuntimeError("Scratch database is not empty; create a fresh dedicated database.")
init_database()
say("FRESH_INDEX", inspect(engine).get_indexes("work_logs"))
with engine.begin() as conn:
    conn.execute(text("""
        INSERT INTO companies
            (id, legal_name_ciphertext, trade_name_ciphertext, cnpj_ciphertext,
             cnpj_hash, contact_email_ciphertext, contact_email_hash,
             contact_phone_ciphertext, consented_at, timezone, is_active, created_at, updated_at)
        VALUES ('bench-company','x','x','x','bench-cnpj','x','bench-email','x',
                now(),'America/Sao_Paulo',true,now(),now())
    """))
    conn.execute(text("""
        INSERT INTO employees
            (id, company_id, name_ciphertext, role_ciphertext, department_ciphertext,
             email_ciphertext, email_hash, phone_ciphertext, unit_ciphertext,
             expected_shift_ciphertext, status, work_mode, role_level,
             requires_location_on_punch, trusted_device_required, pending_adjustments,
             notes_ciphertext, created_at, updated_at)
        VALUES ('bench-employee','bench-company','x','x','x','x','employee-hash','x','x',
                'x','active','onsite','staff',false,false,0,'x',now(),now())
    """))
    conn.execute(text("""
        INSERT INTO projects
            (id,company_id,name_ciphertext,task_employee_limit,next_card_number,
             kanban_version,status,created_at,updated_at)
        VALUES ('bench-project','bench-company','x',1,1,0,'active',now(),now())
    """))
    conn.execute(text("""
        INSERT INTO punches
            (id,company_id,employee_id,type,timestamp,detail_ciphertext,created_at)
        VALUES ('bench-punch','bench-company','bench-employee','checkIn',
                now(),'x',now())
    """))

field_cipher = FieldCipher("isolated-performance-test-secret")
now_start = time.perf_counter()
with engine.begin() as conn:
    conn.execute(text("""
       INSERT INTO work_logs
           (id, company_id, employee_id, project_id, punch_id,
            start_time, end_time, duration_seconds,
            description_ciphertext, task_snapshots_ciphertext, created_at)
       SELECT 'bench-log-' || n::text, 'bench-company','bench-employee',
              'bench-project','bench-punch',
              TIMESTAMPTZ '2025-01-01 00:00:00+00' + ((n % 730) * INTERVAL '1 day'),
              TIMESTAMPTZ '2025-01-01 00:15:00+00' + ((n % 730) * INTERVAL '1 day'),
              900, :description, :tasks, now()
       FROM generate_series(1,1000000) n
    """), {"description": field_cipher.encrypt("synthetic"), "tasks": field_cipher.encrypt("[]")})
    # One UTC January record that belongs to December in America/Sao_Paulo.
    conn.execute(text("""
        INSERT INTO work_logs
            (id, company_id, employee_id, project_id, punch_id, start_time,
             end_time, duration_seconds, description_ciphertext, task_snapshots_ciphertext, created_at)
        VALUES ('boundary-log','bench-company','bench-employee','bench-project',
                'bench-punch','2026-01-01 01:00+00','2026-01-01 01:15+00',
                900,:description,:tasks,now())
    """), {"description": field_cipher.encrypt("boundary"), "tasks": field_cipher.encrypt("[]")})
say("SEED_SECONDS", round(time.perf_counter()-now_start,3))

with engine.begin() as conn:
    conn.execute(text("ANALYZE work_logs"))
    count = conn.execute(text("SELECT count(*) FROM work_logs")).scalar_one()
    zone = conn.execute(text("SHOW TIME ZONE")).scalar_one()
    say("POSTGRES_ZONE", zone, "ROWS", count)
    # isolate the two predicate costs before restoring the actual index
    conn.execute(text("DROP INDEX ix_work_logs_company_project_start_time"))

old_sql = """
SELECT id, start_time FROM work_logs
WHERE company_id='bench-company' AND project_id='bench-project'
  AND EXTRACT(year FROM start_time AT TIME ZONE 'America/Sao_Paulo')=2026
  AND EXTRACT(month FROM start_time AT TIME ZONE 'America/Sao_Paulo')=1
ORDER BY start_time
"""
new_sql = """
SELECT id, start_time FROM work_logs
WHERE company_id='bench-company' AND project_id='bench-project'
  AND start_time >= (TIMESTAMP '2026-01-01 00:00:00' AT TIME ZONE 'America/Sao_Paulo')
  AND start_time < (TIMESTAMP '2026-02-01 00:00:00' AT TIME ZONE 'America/Sao_Paulo')
ORDER BY start_time
"""


def explain(conn, title, query, count=3):
    runs = []
    for _ in range(count):
        plan = conn.execute(text("EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + query)).scalar_one()
        if isinstance(plan, str):
            plan = json.loads(plan)
        report = plan[0]
        root = report["Plan"]
        runs.append(round(report["Execution Time"],3))
    say("PLAN", title, "MS", runs, "ROOT", root["Node Type"],
        "BUFFERS", {k: v for k,v in root.items() if "Blocks" in k},
        "DETAIL", json.dumps(root)[:1400])


with engine.connect() as conn:
    explain(conn, "OLD_EXTRACT_NO_INDEX", old_sql)
    explain(conn, "RANGE_NO_INDEX", new_sql)
    for zone in ("UTC", "America/Sao_Paulo"):
        conn.execute(text("SET TIME ZONE :zone"), {"zone": zone})
        old_has = conn.execute(text("SELECT EXISTS (" + old_sql.replace("ORDER BY start_time", "") + " AND id = 'boundary-log')")).scalar_one()
        new_has = conn.execute(text("SELECT EXISTS (" + new_sql.replace("ORDER BY start_time", "") + " AND id = 'boundary-log')")).scalar_one()
        say("ZONE_BOUNDARY", zone, "old", old_has, "new", new_has)
    conn.rollback()

# Demonstrate that plain CREATE INDEX on an existing table can wait for a concurrent writer.
with engine.connect() as writer:
    writer.execute(text("LOCK TABLE work_logs IN ROW EXCLUSIVE MODE"))
    try:
        with engine.connect() as index_conn:
            index_conn.execute(text("SET lock_timeout = '500ms'"))
            started = time.perf_counter()
            try:
                index_conn.execute(text(
                    "CREATE INDEX ix_work_logs_company_project_start_time "
                    "ON work_logs (company_id, project_id, start_time)"
                ))
                say("LOCK_TEST_UNEXPECTED_SUCCESS")
            except Exception as exc:
                say("LOCK_TEST", type(exc).__name__, "ELAPSED_MS",
                    round((time.perf_counter()-started)*1000,1))
                index_conn.rollback()
    finally:
        writer.rollback()

start = time.perf_counter()
init_database()  # proves upgrade on already-provisioned PostgreSQL
say("INDEX_RESTORED_SECONDS", round(time.perf_counter()-start,3))
init_database()  # idempotency on existing PostgreSQL
with engine.connect() as conn:
    say("INDEX_CATALOG", conn.execute(text("""
        SELECT indexname, indexdef FROM pg_indexes WHERE tablename='work_logs'
            AND indexname='ix_work_logs_company_project_start_time'
    """)).all())
    say("AFTER_UPGRADE_ROWS", conn.execute(text("SELECT count(*) FROM work_logs")).scalar_one())
    explain(conn, "RANGE_WITH_INDEX", new_sql)

captured = []


def record_sql(conn, cursor, statement, parameters, context, executemany):
    if "FROM work_logs" in statement and statement.lstrip().upper().startswith("SELECT"):
        if not captured:
            captured.append((statement, parameters))


event.listen(engine, "before_cursor_execute", record_sql)
with SessionLocal() as db:
    start = time.perf_counter()
    report = generate_monthly_work_logs_report(
        db, company_id="bench-company", project_id="bench-project", year=2026, month=1,
        timezone_name="America/Sao_Paulo",
    )
    say("APPLICATION_REPORT_ROWS", len(report.records),
        "DURATION_SECONDS", round(time.perf_counter()-start,3))
event.remove(engine, "before_cursor_execute", record_sql)
assert captured, "Did not capture the real WorkLog SQL query"
statement, parameters = captured[0]
say("ACTUAL_SQL", statement)
say("ACTUAL_SQL_PARAMS", {
    k: v.isoformat() if isinstance(v, dt.datetime) else v for k,v in parameters.items()
})
with engine.connect() as conn:
    # Feed the actual DBAPI statement and bound parameters into EXPLAIN.
    plan = conn.exec_driver_sql(
        "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + statement, parameters
    ).scalar_one()
    if isinstance(plan, str):
        plan = json.loads(plan)
    say("ACTUAL_SQL_EXPLAIN_MS", round(plan[0]["Execution Time"],3),
        "ROOT", plan[0]["Plan"]["Node Type"])
say("FINISHED")
