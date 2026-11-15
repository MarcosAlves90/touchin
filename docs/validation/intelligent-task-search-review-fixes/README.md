# Intelligent task search review fixes — POLIS evidence

This change addresses the four inline Lavender Town review comments on PR #138:

- `r4576913764` — retain the Backlog-local query and intersect it with shared search and manual filters.
- `r4576913768` — report the unfiltered card count when connector-only input parses as inactive.
- `r4576913771` — keep ambiguous bare type/status text literal while preserving explicit `type:bug`.
- `r4576913774` — reset Backlog pagination when the shared query or match set changes.

## Retained artifacts

- [Locked POLIS v6 contract](../../../.polis/artifacts/contracts/intelligent-task-search-review-fixes-v2.json), SHA-256 `831baa8e301f96b21e9c8b516ed0ebb9cc83780ef189098316981d538b376b27`, locked against base commit `c01955aaca43018b4da239ba2faae0a5e13380ca`.
- [Captured Red regression proof](polis/red-regression.patch), SHA-256 `96fab2893887969d0e00bc35960e805a948e9016e46bb67ae3c43ae80927fa05`. It adds the bare `bug` ambiguity regression test; the locked baseline fails with the expected type-filter result.
- [Workspace validation report](polis/workspace-validation.json), SHA-256 `87b6c30e86f0ed69cc40589709240cc405571079e3f53f9bd95ad42efdb00309`.

## Validation result

The report records `PASS` for `test.complete`, `lint`, `build`, and `smoke`, with base commit `c01955aaca43018b4da239ba2faae0a5e13380ca` and target tree `6878dcde6ccfb552f154ac800a7223763f424e20` (implementation commit `fc5ce70f0235d63fec280fe2fd99741616a38b3d`). Delivery-artifact build and verification are both `false`; this is local workspace validation, not package delivery.

The report validates the implementation tree before these evidence files were added. The evidence-only follow-up commit retains the contract, proof, report, and this documentation without changing application or test code. The original feature contract remains unchanged.

## Re-run

From the repository root, run the command below. The `PATH` prefix makes the backend virtual environment available to the isolated workspace used by POLIS; choose a new report path outside the repository:

```bash
PATH="$PWD/backend/.venv/bin:$PATH" polis workspace validate \
  --repo . \
  --contract .polis/artifacts/contracts/intelligent-task-search-review-fixes-v2.json \
  --regression-patch docs/validation/intelligent-task-search-review-fixes/polis/red-regression.patch \
  --out-report /path/outside/the/repository/intelligent-task-search-review-fixes-validation.json \
  --format json
```
