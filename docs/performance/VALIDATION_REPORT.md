# TouchIn — final validation of performance fixes

Date: 2026-10-10
Branch: `perf/optimization-findings`
Scope: read-only behavior for point history/last punch and monthly WorkLog report; model and schema upgrade of the composite WorkLog index.
Environment: macOS, Python 3.14, SQLite tests; **isolated local PostgreSQL 18.6**. No staging or production profiling performed.

## Decision

**Merge: ready, subject to normal review of this branch's uncommitted changes.**
The changed read paths have passed the affected and full regression suites, a pre-existing-data upgrade test, and PostgreSQL query/plan comparison. No load-time architectural changes are recommended.

**Deployment to an existing PostgreSQL database: conditional.**
Before deploying, ensure the index exists with the expected definition. For a large live table, create it in a planned migration step using `CREATE INDEX CONCURRENTLY` outside a transaction and verify its validity; the application's `CREATE INDEX IF NOT EXISTS` fallback is a blocking operation. Staging application and real-data performance are **not yet verified**. If startup schema initialization is disabled, run the upgrade explicitly.

## Implementation and correctness

- `backend/app/domain/time_clock_read.py`: managed punches are counted and paged with SQL `COUNT` / `LIMIT` / `OFFSET`, ordered by timestamp and ID. Clock state selects the last punch using `ORDER BY timestamp DESC, id DESC LIMIT 1`, without loading full history. Day-only pagination still uses records already loaded for the day's calculations.
- `backend/app/domain/project_read.py`: iterates with `yield_per(200)`, preserving the full response structure. Monthly filtering uses a half-open range on `start_time`. The bounds are **naive timestamps** intentionally: PostgreSQL interprets these in the current session timezone, just as the old `EXTRACT(YEAR/MONTH FROM timestamptz)` did. This fixed a demonstrable regression caused by explicitly UTC-bound comparisons. SQLite retains its previous wall-clock behavior. Invalid months/years return an empty report, as the old filter did; December 9999 needs no unrepresentable upper bound.
- `backend/app/models.py`: declares `ix_work_logs_company_project_start_time` over `(company_id, project_id, start_time)` for fresh schema creation.
- `backend/app/database_schema.py`: `upgrade_database_schema()` creates the same index with `IF NOT EXISTS` if the table already exists. The invocation chain is `lifespan → init_database → Base.metadata.create_all → upgrade_database_schema`, **when** `bootstrap_database_on_startup` or `seed_on_startup` is enabled. Other configurations need an explicit initialization/upgrade step (e.g., the existing `create_postgres` workflow).

The monthly report still uses the original company/project predicates and optional employee predicate. `project_or_404` enforces company and employee project visibility. The route retains `projects.read` authorization, schema and stable order by `start_time`. Tests cover an unrelated project, another employee, a nonexistent company, and nonmember access.

The report's meaning of a month remains tied to the **DB session timezone** on PostgreSQL, as before this optimization; it is not independently guaranteed to use each company's configured timezone. Do not change that rule without a product/contract decision. Non-UTC input timestamps in the application write flow must be normalized before storage; tests exercise an offset-normalized timestamp.

## New tests and regressions

- `backend/tests/test_db_schema.py`: fresh SQLite DB index definition; existing DB missing the index, nonempty table preserved, repeated `init_database()` installs it exactly once.
- `backend/tests/test_work_logs.py`: December 31 / January 1 / February 1, year crossing, UTC and `-03:00` timestamps normalized before insertion, ordering, comparison with the old SQLite `EXTRACT` query, project/employee/company access, unauthorized nonmember, invalid month/year and upper year bound.
- `backend/tests/test_api.py`: last punch from a previous day still sets the status and timestamp when today's record list is empty. Existing managed/history pagination regressions also run.

Commands (from `/touchin/backend`):

```bash
./.venv/bin/pytest -q tests/test_db_schema.py tests/test_work_logs.py \
  tests/test_api.py::test_clock_state_uses_latest_punch_even_when_no_records_today \
  tests/test_api.py::test_time_clock_state_paginates_records \
  tests/test_api.py::test_manager_paginates_employee_punches
./.venv/bin/pytest -q
```

Observed: **11 targeted passed**, **104 total passed**, four pre-existing dependency/SQLite deprecation warnings, zero failures. `git diff --check` passes.

## PostgreSQL reproducible evidence

The local test database `touchin_perf_validation_20261010` was explicitly created for this benchmark; it contains **1,000,001 synthetic WorkLogs**. The test fixture is not production data. Three versions of the same SQL predicate were evaluated using `EXPLAIN (ANALYZE, BUFFERS, FORMAT JSON)`, with all sessions fixed to UTC and identical matching rows (42,471). The no-index trials temporarily dropped the index **inside a transaction subsequently rolled back**.

| Scenario | Run 1 | Run 2 | Run 3 | Median | Plan |
|---|---:|---:|---:|---:|---|
| `EXTRACT`, no index | 117.303 ms | 102.904 ms | 120.355 ms | **117.303 ms** | full/parallel scan |
| Range, no index | 69.481 ms | 67.776 ms | 69.773 ms | **69.481 ms** | full/parallel scan |
| Range, with index | 7.804 ms | 7.071 ms | 7.161 ms | **7.161 ms** | indexed access |

Median ratios: **1.69×** from the range filter alone; **9.70×** additional improvement after index access; **16.38×** combined in this synthetic SQL-level benchmark. These are not HTTP latency, throughput, or production improvements. Differences from previous ~36× measurements are expected: datasets, selected columns, predicates, cache state and session timezones differ. This run controlled timezone and result equivalence.

The real SQLAlchemy report query was captured through `before_cursor_execute` and uses:

```sql
SELECT work_logs.id, work_logs.company_id, work_logs.employee_id,
       work_logs.project_id, work_logs.punch_id, work_logs.start_time,
       work_logs.end_time, work_logs.duration_seconds,
       work_logs.description_ciphertext, work_logs.task_snapshots_ciphertext,
       work_logs.created_at
FROM work_logs
WHERE work_logs.project_id = :project_id
  AND work_logs.company_id = :company_id
  AND work_logs.start_time >= :month_start
  AND work_logs.start_time < :next_month_start
ORDER BY work_logs.start_time
```

The actual DBAPI parameters had **naive** Python `datetime(2026, 1, 1, 0, 0)` and `datetime(2026, 2, 1, 0, 0)` values, preserving session timezone semantics on PostgreSQL. An `EXPLAIN (ANALYZE, BUFFERS)` of this actual statement returned **Index Scan, 19.862 ms** (full-width columns, not directly comparable with the narrow two-column plans). The Python report construction produced **42,471 rows**, about **1.34 s** in the preceding run; it performs decryption and response materialization in addition to SQL work.

PostgreSQL timezone comparison against the **actual application function**:

| Session timezone | Legacy `EXTRACT` count | New range count | Symmetric difference of matching IDs |
|---|---:|---:|---:|
| UTC | 42,471 | 42,471 | 0 |
| America/Sao_Paulo | 42,470 | 42,470 | 0 |

The index appeared in the PostgreSQL catalog on a fresh schema, and after rebuilding via `init_database` on the existing table; its definition is `btree (company_id, project_id, start_time)`. Two calls to `init_database` completed, and the record count remained **1,000,001**. A separate SQLite regression test checks preserved row contents.

### Reproduction

Use a **new, local, dedicated, empty** PostgreSQL database. The benchmark script refuses databases outside the `touchin_perf_validation_*` namespace, and refuses to seed nonempty `work_logs` tables. It deliberately performs scratch-only DDL, including index removal/recreation.

```bash
# From /touchin; change the suffix for each fresh run.
createdb touchin_perf_validation_20261010_replay
TOUCHIN_BENCH_DB=touchin_perf_validation_20261010_replay \
  PYTHONPATH=backend backend/.venv/bin/python docs/performance/pg_index_benchmark.py
TOUCHIN_BENCH_DB=touchin_perf_validation_20261010_replay \
  PYTHONPATH=backend backend/.venv/bin/python docs/performance/pg_semantics_check.py
TOUCHIN_BENCH_DB=touchin_perf_validation_20261010_replay \
  PYTHONPATH=backend backend/.venv/bin/python docs/performance/pg_equivalent_comparison.py
```

Do not use the scripts with a shared database, production credentials or real customer data. The suite does not drop the scratch database automatically; clean up only after confirming it is the exact database created for this purpose.

## Index creation / deploy risk

The existing updater executes `CREATE INDEX IF NOT EXISTS` inside a transaction. On a busy PostgreSQL table, normal index creation takes a lock that conflicts with writers. A controlled isolated test held a writer lock and attempted index creation with `lock_timeout=500ms`: index creation failed with an `OperationalError` after **577.1 ms**. On the 1M-row scratch database, the successful restoration path took **0.778 s**; this does **not** bound lock duration on a live database.

To deploy with low write disruption, run the following as a dedicated PostgreSQL migration **outside a transaction**, in a maintenance-approved environment:

```sql
CREATE INDEX CONCURRENTLY IF NOT EXISTS ix_work_logs_company_project_start_time
ON public.work_logs (company_id, project_id, start_time);
```

Then verify the definition and `pg_index.indisvalid`, query plans and representative read/write latencies, and execute the normal schema upgrade to confirm idempotency. `IF NOT EXISTS` checks the name only, not a matching column definition; a same-named incorrect or invalid index requires separate diagnosis. Concurrent index creation can fail and leave an invalid index, which must be addressed under a controlled migration procedure. No index was deployed to staging or production.

## Remaining findings and limits

| Finding | Outcome | Recommendation |
|---|---|---|
| SQL pagination and latest punch | Implemented; regressions passed | Keep |
| Monthly WorkLog `EXTRACT` filter | Fixed; comparable PostgreSQL plans measured | Keep the range filter with preserved timezone interpretation |
| Index missing on existing databases | Fixed in upgrade; new/legacy/idempotence verified | Use planned nonblocking rollout for large PostgreSQL tables |
| Employee last-punch aggregation/index | Earlier local plans did not show material gain | Do not introduce index without a better measured workload |
| Employee listing sort | Small potential cost in large companies | Await production distribution and latency |
| Full report memory | Report still grows with response size | Await workload/heap measurements before changing API |
| Fernet/PII CPU | Cost visible in previous synthetic profiles | Do not cache plaintext PII; measure selective use before any change |
| Email delivery latency | No controlled provider test | Do not add queues/retries on present evidence |
| Concurrent HTTP, pool and p95/p99 | No representative staging load test | Keep as missing deployment evidence |

**Outstanding deployment approval checks:** staging startup/upgrade with actual role privileges and bootstrap settings, index validity and catalog definition, PostgreSQL query plans on representative volumes, lock/wait observation during index rollout, read/write tail latency, and confirmation of the intended calendar timezone contract. This review does not claim those checks passed.
