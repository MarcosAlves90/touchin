"""Replay report on the isolated profiling database under two PostgreSQL timezones."""
import os
from sqlalchemy import event, text

DB_NAME = os.environ.get("TOUCHIN_BENCH_DB", "touchin_perf_validation_20261010")
if not DB_NAME.startswith("touchin_perf_validation_"):
    raise RuntimeError("Use an explicitly isolated touchin_perf_validation_* database.")
os.environ["TOUCHIN_DATABASE_URL"] = f"postgresql+psycopg2:///{DB_NAME}"
os.environ["TOUCHIN_ENCRYPTION_SECRET"] = "isolated-performance-test-secret"
os.environ["TOUCHIN_TOKEN_SECRET"] = "isolated-performance-test-token"
os.environ["TOUCHIN_SEED_ADMIN_PASSWORD"] = "isolated-performance-test-password"

from app.db import engine, SessionLocal
from app.domain.project_read import generate_monthly_work_logs_report

assert engine.url.database == DB_NAME and engine.url.host in (None, "", "localhost")
captured = []


def collect(conn, cursor, statement, parameters, context, executemany):
    if not captured and "FROM work_logs" in statement and "work_logs.start_time >=" in statement:
        captured.append((statement, parameters))


event.listen(engine, "before_cursor_execute", collect)
for zone in ("UTC", "America/Sao_Paulo"):
    with SessionLocal() as db:
        db.execute(text("SET TIME ZONE :zone"), {"zone": zone})
        old_rows = db.execute(text("""
            SELECT count(*) FROM work_logs
            WHERE project_id = 'bench-project' AND company_id='bench-company'
            AND EXTRACT(YEAR FROM start_time) = 2026
            AND EXTRACT(MONTH FROM start_time) = 1
        """)).scalar_one()
        mismatch = db.execute(text("""
            WITH old_ids AS (
                SELECT id FROM work_logs
                WHERE project_id='bench-project' AND company_id='bench-company'
                  AND EXTRACT(YEAR FROM start_time AT TIME ZONE 'America/Sao_Paulo')=2026
                  AND EXTRACT(MONTH FROM start_time AT TIME ZONE 'America/Sao_Paulo')=1
            ), new_ids AS (
                SELECT id FROM work_logs
                WHERE project_id='bench-project' AND company_id='bench-company'
                  AND start_time >= (TIMESTAMP '2026-01-01 00:00:00' AT TIME ZONE 'America/Sao_Paulo')
                  AND start_time < (TIMESTAMP '2026-02-01 00:00:00' AT TIME ZONE 'America/Sao_Paulo')
            )
            SELECT
                (SELECT count(*) FROM (SELECT id FROM old_ids EXCEPT SELECT id FROM new_ids) s)
                + (SELECT count(*) FROM (SELECT id FROM new_ids EXCEPT SELECT id FROM old_ids) s)
        """)).scalar_one()
        old_boundary = db.execute(text("""
            SELECT EXTRACT(YEAR FROM start_time AT TIME ZONE 'America/Sao_Paulo') = 2026
                   AND EXTRACT(MONTH FROM start_time AT TIME ZONE 'America/Sao_Paulo') = 1
            FROM work_logs WHERE id='boundary-log'
        """)).scalar_one()
        actual = generate_monthly_work_logs_report(
            db, company_id="bench-company", project_id="bench-project",
            year=2026, month=1, timezone_name="America/Sao_Paulo",
        )
        new_rows = len(actual.records)
        new_boundary = any(row.description == "boundary" for row in actual.records)
        print(
            "ZONE", zone, "EXTRACT_ROWS", old_rows, "APPLICATION_ROWS", new_rows,
            "OLD_BOUNDARY", old_boundary, "NEW_BOUNDARY", new_boundary,
            "SYMMETRIC_DIFFERENCE", mismatch,
            "EQUIVALENT", old_rows == new_rows and old_boundary == new_boundary and mismatch == 0,
            flush=True,
        )
        assert old_rows == new_rows and old_boundary == new_boundary and mismatch == 0
event.remove(engine, "before_cursor_execute", collect)
print("EMITTED_SQL", captured[0][0], flush=True)
print("EMITTED_PARAMS", captured[0][1], flush=True)
with engine.connect() as conn:
    plan = conn.exec_driver_sql(
        "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + captured[0][0],
        captured[0][1],
    ).scalar_one()
    if isinstance(plan, str):
        import json
        plan = json.loads(plan)
    print(
        "ACTUAL_QUERY_EXPLAIN_MS", plan[0]["Execution Time"],
        "ROOT", plan[0]["Plan"]["Node Type"],
        "BUFFERS", {
            key: value for key, value in plan[0]["Plan"].items() if "Blocks" in key
        }, flush=True,
    )
