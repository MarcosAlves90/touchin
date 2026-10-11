"""Controlled EXPLAIN comparison in an existing isolated PostgreSQL scratch DB.

The temporary DROP INDEX is rolled back; the original index remains installed.
"""
import json
import os
from statistics import median

db_name = os.environ.get("TOUCHIN_BENCH_DB", "touchin_perf_validation_20261010")
if not db_name.startswith("touchin_perf_validation_"):
    raise RuntimeError("Benchmark requires a dedicated scratch database.")
os.environ["TOUCHIN_DATABASE_URL"] = f"postgresql+psycopg2:///{db_name}"
os.environ["TOUCHIN_ENCRYPTION_SECRET"] = "isolated-performance-test-secret"
os.environ["TOUCHIN_TOKEN_SECRET"] = "isolated-performance-test-token"
os.environ["TOUCHIN_SEED_ADMIN_PASSWORD"] = "isolated-performance-test-password"

from sqlalchemy import text
from app.db import engine

assert engine.url.database == db_name and engine.url.host in (None, "", "localhost")

old = """
 SELECT id, start_time FROM work_logs
 WHERE company_id='bench-company' AND project_id='bench-project'
   AND EXTRACT(year FROM start_time)=2026 AND EXTRACT(month FROM start_time)=1
 ORDER BY start_time
"""
interval = """
 SELECT id, start_time FROM work_logs
 WHERE company_id='bench-company' AND project_id='bench-project'
   AND start_time >= TIMESTAMP '2026-01-01 00:00:00'
   AND start_time < TIMESTAMP '2026-02-01 00:00:00'
 ORDER BY start_time
"""


def compare(conn, label, query):
    times = []
    for _ in range(3):
        plan = conn.execute(text(
            "EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON) " + query
        )).scalar_one()
        if isinstance(plan, str):
            plan = json.loads(plan)
        item = plan[0]
        times.append(round(item["Execution Time"], 3))
    print(label, "runs_ms", times, "median_ms", median(times), flush=True)


with engine.connect() as conn:
    conn.execute(text("SET LOCAL TIME ZONE 'UTC'"))
    expected = conn.execute(text("SELECT count(*) FROM (" + old + ") x")).scalar_one()
    observed = conn.execute(text("SELECT count(*) FROM (" + interval + ") x")).scalar_one()
    assert expected == observed
    print("EQUIVALENT_ROWS_UTC", expected, observed, flush=True)
    conn.execute(text("DROP INDEX ix_work_logs_company_project_start_time"))
    compare(conn, "OLD_EXTRACT_WITHOUT_INDEX", old)
    compare(conn, "INTERVAL_WITHOUT_INDEX", interval)
    conn.rollback()  # restores index and discards all transaction-scoped changes

with engine.connect() as conn:
    conn.execute(text("SET LOCAL TIME ZONE 'UTC'"))
    compare(conn, "INTERVAL_WITH_INDEX", interval)
    assert conn.execute(text(
        "SELECT to_regclass('public.ix_work_logs_company_project_start_time') IS NOT NULL"
    )).scalar_one()
