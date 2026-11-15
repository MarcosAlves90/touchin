# Intelligent task search — POLIS evidence

This feature adds deterministic shared task search to Project Backlog and Kanban.

## Retained artifacts

- [Locked POLIS v6 contract](../../../.polis/artifacts/contracts/intelligent-task-search-v6.json), locked against base commit `6a55d638`.
- [Captured Red proof](polis/red-regression.patch), SHA-256 `c8fbced6…21a0c3`; captured with `polis capture-red` against the locked baseline.
- [Workspace validation report](polis/workspace-validation.json), a fresh `polis workspace validate` result for target tree `dbb36335` (implementation commit `acb2466`).

## Validation result

The report records `PASS` for `test.complete`, `lint`, `build`, and `smoke`. It also records `delivery_artifact_built: false` and `delivery_artifact_verified: false`: this was local workspace validation, not package delivery.

The report intentionally describes the implementation tree before this evidence-only documentation update. The follow-up changes retain the contract, proof, report, and documentation; they do not change the validated application code.

## Re-run

From the repository root, run `polis workspace validate` with the retained contract and Red proof. The report path must be a new regular file outside the worktree:

```bash
polis workspace validate \
  --repo . \
  --contract .polis/artifacts/contracts/intelligent-task-search-v6.json \
  --regression-patch docs/validation/intelligent-task-search/polis/red-regression.patch \
  --out-report /path/outside/the/repository/intelligent-task-search-validation.json \
  --format json
```
