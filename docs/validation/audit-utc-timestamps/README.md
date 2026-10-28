# Audit UTC timestamps validation

## What changed

`GET /api/v1/audit-events` passed each stored timestamp through unchanged.
How that value is serialized depends on the database driver:

| Database | Before | After |
| --- | --- | --- |
| SQLite (local development) | `2026-10-27T22:34:21.527917` (no offset) | `2026-10-27T22:34:21.527917Z` |
| PostgreSQL, session timezone `UTC` | `…Z` | `…Z` |
| PostgreSQL, session timezone `America/Sao_Paulo` | `…-03:00` | `…Z` |

The frontend parses a value without offset as local time, so with SQLite the
audit screen's "Data/hora (local)" column showed the UTC wall clock (22:34 for
an event at 19:34 in São Paulo). With a non-UTC PostgreSQL session the instant
was right but the list and the CSV export used different offsets.

[`audit_read.py`](../../../backend/app/domain/audit_read.py) now passes the
timestamp through `ensure_utc`, as the other domain readers do. Stored values
are already UTC, so naive values are read as UTC and aware values are converted
to UTC. The CSV export already wrote `timestamp_utc` this way and is unchanged.

The frontend already converted offset-aware values to local time
(`requireDateTime` calls `toLocal()` and the audit formatters do the same), so
no frontend code changed.

## Evidence

- POLIS contract
  [`audit-utc-timestamps-v1.polis.json`](../../contracts/audit-utc-timestamps-v1.polis.json)
  locked on base `be5963c` before any edit.
- Red proof captured with `polis capture-red` on the locked baseline. Both
  tests in
  [`test_audit_timestamps.py`](../../../backend/tests/test_audit_timestamps.py)
  failed:
  - `test_audit_event_list_timestamps_carry_utc_offset`: the list timestamp had
    no UTC offset.
  - `test_audit_export_timestamp_matches_list_instant`: the naive list value
    did not equal the CSV instant.

  The frontend test
  [`audit_timestamp_test.dart`](../../../frontend/test/contracts/audit_timestamp_test.dart)
  passed on the baseline. It is a guard for the local-time rendering, not the
  Red proof.
- After the change both backend tests and the frontend test pass.
- PostgreSQL 16.15 in a disposable container, checked with the API before and
  after the change, gave the values in the table above. The list and the CSV
  export returned the same instant ending in `Z` in both session timezones
  after the change.
- POLIS artifacts retained in [`polis/`](polis/):
  [`red-regression.patch`](polis/red-regression.patch) is the captured Red
  proof (SHA-256 `1fc5fcec…a76cd`), and
  [`workspace-validation.json`](polis/workspace-validation.json) is the
  `polis workspace validate` report: `PASS` with `test.complete`, `lint`, `build` and `smoke` passing for tree `3e4ffc0a`, the tree of commit `df7539e`. Later commits only add these artifacts and this note.

## Limits of this evidence

- The frontend test checks the local-time rendering in the timezone of the
  machine that runs it. On a UTC machine, such as CI, local and UTC times are
  equal, so the test cannot tell them apart there; on a machine with a non-zero
  offset it also asserts that they differ.
- Other API responses were not audited for timezone-less timestamps in this
  change.
