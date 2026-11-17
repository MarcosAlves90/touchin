# Team directory icon radius — POLIS evidence

PR #137 rounded the remaining workspace corners, but the leading employee icon in the wide Team directory (`_EmployeeListTile` in `admin_employees_page_widgets.dart`) kept a `BoxDecoration` without `borderRadius`. This change applies the same 8 px radius used by the equivalent project-list icon tile. Size, fill, border, selection and high-contrast colors are unchanged, and compact layouts still omit the icon.

## Retained artifacts

- [Locked POLIS v6 contract](../../../.polis/artifacts/contracts/team-directory-icon-radius-v6.json), SHA-256 `01b5698aad32a6446a2ebd7443eee6444ea66040419d1f46cf5752d6583da374`, locked with `polis start` against base commit `eec9284206ca938cafe9de78af7c82f015061f7d` (tree `d1e08610597ca30a2e20b3a17638fe8817554e55`).
- Regression test `employee directory leading icon radius dark=false|true` in `frontend/test/admin_employees_page_test.dart` (1440 px, light and dark themes).

## Red proof

`polis check-red-scope` accepted `frontend/test/admin_employees_page_test.dart`. With only the test delta applied to the locked baseline, the contract regression command

```bash
cd frontend
flutter test test/admin_employees_page_test.dart --plain-name "employee directory leading icon radius"
```

exited with code 1 for both themes, matching the locked oracle (`employee_list_icon_radius_8`):

```text
Expected: BorderRadius:<BorderRadius.circular(8.0)>
  Actual: <null>
employee_list_icon_radius_8
Some tests failed.
```

`polis capture-red` could not record this proof on the Windows workstation used for the change. It stages the worktree with `git add -A -- . ':(exclude).polis/artifacts/**'`, and Git 2.56.0.windows.4 rejects that exclusion because `.polis/artifacts/` is ignored while containing tracked contracts (`The following paths are ignored by one of your .gitignore files: .polis/artifacts`). The same command succeeds without the exclusion. As a result, `red-regression.patch` and the `polis workspace validate` report listed in the contract scope are not retained for this change; the oracle and the test were not altered to work around the failure.

## Gate validation

`polis gates --repo . --gate test.complete --gate lint --gate build --gate smoke` (POLIS 6.12.0, Windows 11, Flutter stable 3.47.7, Python 3.12) recorded `PASS` for all four enabled gates on the implementation tree (run `d539e4e03bc1aab713da7c515388458e522db4fbc3e12387f6727bc0a8512ae8`). The smoke gate used Microsoft Edge through `TOUCHIN_CHROME`. This is local gate validation, not package delivery (`delivery_artifact_built: false`, `delivery_artifact_verified: false`). The evidence files in this directory and the retained contract were added after the gate run and do not change application or test code.

## Re-run

On an environment where `polis capture-red` works, the full strict flow can be replayed from the retained contract:

```bash
polis capture-red --repo . \
  --contract .polis/artifacts/contracts/team-directory-icon-radius-v6.json \
  --out /path/outside/the/repository/red-regression.patch
polis workspace validate --repo . \
  --contract .polis/artifacts/contracts/team-directory-icon-radius-v6.json \
  --regression-patch /path/outside/the/repository/red-regression.patch \
  --out-report /path/outside/the/repository/workspace-validation.json --format json
```

Red capture must run against the locked baseline with only the test delta applied.
