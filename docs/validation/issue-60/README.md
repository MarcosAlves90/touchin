# Issue #60 navigation access validation

## What changed

The desktop sidebar and the mobile drawer now list only the workspace
destinations the signed-in user can use. Both read one shared list,
[`workspace_destinations.dart`](../../../frontend/lib/core/navigation/workspace_destinations.dart),
which mirrors `ROLE_PERMISSIONS` in
[`backend/app/authorization.py`](../../../backend/app/authorization.py):

| Destination | Shown to | Backend rule it mirrors |
| --- | --- | --- |
| Bater Ponto | known roles with a linked employee profile | `time_clock.*`; `409` without an employee profile |
| Administrar Equipe | `manager`, `admin`, `super_admin` | `employees.read` |
| Trilha de Auditoria | `manager`, `admin`, `super_admin` | `audit.read` |
| Projetos e tarefas | every known role | `projects.read` |
| Kanban | every known role | `kanban.read` |
| Configurações | everyone | local theme screen, no API call |

A role the backend does not recognize receives no permission there, so it only
sees Configurações. The landing route after authentication is always one of
the user's destinations: only an `employee` without employee profile (now
Projetos e tarefas instead of Administrar Equipe) and unrecognized roles (now
Configurações) land somewhere new.

While a newly opened route revalidates its session (#115), the skeleton shell
shows the last verified user's destinations, so no item flashes in or out.
Signing out clears that user and a new sign-in replaces it.

## Decisions

- The filter only hides items. Route paths and deep links are unchanged, and
  the backend remains the authority: a hidden route opened by URL behaves as
  before (the page shows the API's 403/409 error).
- A shell rendered outside the workspace router (standalone widget harnesses)
  keeps the full list, because it has no verified user to filter by.
- Three existing `widget_test.dart` fixtures opened Bater Ponto from the menu
  with a `super_admin` lacking an employee profile. That item is now hidden for
  such an account, matching the backend `409`, so those fixtures received
  `employeeId: 'emp-01'`; what they test is unchanged.

## Evidence

- POLIS contract
  [`workspace-navigation-access-issue-60-v1.polis.json`](../../contracts/workspace-navigation-access-issue-60-v1.polis.json)
  locked on base `1024189` before any edit.
- Red proof captured with `polis capture-red` on the locked baseline (oracle
  `Some tests failed`). Running the same file on the baseline locally and in a
  clean checkout gave `+25 -14`: the 14 new tests failed on their assertions
  and every pre-existing test passed.
- The new `widget_test.dart` group drives the real app (`MyApp`) per role
  (employee with/without profile, manager, admin, super admin, unrecognized
  role) on desktop and in the mobile drawer, plus the route-verification
  skeleton, sign-out followed by a different user, and the landing route.
- After the change: `flutter test test/widget_test.dart` 39/39,
  `flutter test` 307/307, and `dart analyze lib test` reports the same 12
  pre-existing infos as the baseline and nothing new.
- POLIS artifacts retained in [`polis/`](polis/):
  [`red-regression.patch`](polis/red-regression.patch) is the captured Red
  proof (SHA-256 `14eb6456…5b16e`), and
  [`workspace-validation.json`](polis/workspace-validation.json) is the
  `polis workspace validate` report: `PASS` with `test.complete`, `lint`,
  `build` and `smoke` passing for tree `0860b05b`, the tree of commit
  `c99b91f`. Later commits only add these artifacts and this note.

## Running the POLIS proof on Windows

`polis capture-red` and `polis workspace validate` run Flutter in a fresh
checkout. There, `pub get` creates plugin symlinks, which Windows only allows
with Developer Mode enabled (Settings → System → For developers). Existing
checkouts with `.plugin_symlinks` already present do not show the error.

## Limits of this evidence

The navigation was verified through widget tests of the real app with a fake
API, not in a browser against a live backend, and the filter does not change
any screen layout beyond the number of menu items.
