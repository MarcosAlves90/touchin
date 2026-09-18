from __future__ import annotations

import json
from pathlib import Path
import re

from test_api import login_headers


REPO_ROOT = Path(__file__).resolve().parents[2]
CONTROLLER_PATH = (
    REPO_ROOT
    / "frontend/lib/features/projects/presentation/project_tasks_controller.dart"
)
PROJECT_PAGE_PATH = (
    REPO_ROOT
    / "frontend/lib/features/projects/presentation/project_tasks_page.dart"
)
API_CLIENT_PATH = REPO_ROOT / "frontend/lib/core/network/api_client.dart"
APP_THEME_PATH = REPO_ROOT / "frontend/lib/theme/app_theme.dart"
LOCKED_CONTRACT_PATH = (
    REPO_ROOT / "docs/contracts/project-task-management-bugfixes-v2.polis.json"
)
NEW_LOCKED_CONTRACT_PATH = (
    REPO_ROOT / "docs/contracts/project-management-ui-standardization-v1.polis.json"
)
UI_STANDARDIZATION_V2_CONTRACT_PATH = (
    REPO_ROOT / "docs/contracts/project-management-ui-standardization-v2.polis.json"
)
BASE_COMMIT = "573e1b4f6867a586da7d2d3bf3733e6bff5d287a"


def _controller_source() -> str:
    return CONTROLLER_PATH.read_text(encoding="utf-8")


def test_project_task_management_controller_requests_only_active_projects():
    source = _controller_source()

    assert "projects = await _api.listProjects(status: ProjectStatus.active);" in source


def test_project_task_management_controller_discards_stale_async_loads():
    source = _controller_source()

    for request_version in (
        "_projectMembersRequestVersion",
        "_tasksRequestVersion",
        "_taskMembersRequestVersion",
    ):
        assert request_version in source

    assert re.search(
        r"requestVersion\s*!=\s*_projectMembersRequestVersion\s*\|\|\s*"
        r"selectedProjectId\s*!=\s*projectId",
        source,
    )
    assert re.search(
        r"requestVersion\s*!=\s*_tasksRequestVersion\s*\|\|\s*"
        r"selectedProjectId\s*!=\s*projectId",
        source,
    )
    assert re.search(
        r"requestVersion\s*!=\s*_taskMembersRequestVersion\s*\|\|\s*"
        r"selectedProjectId\s*!=\s*projectId\s*\|\|\s*"
        r"selectedTaskId\s*!=\s*taskId",
        source,
    )


def test_project_task_employee_limit_rejects_values_outside_postgres_integer(client):
    headers = login_headers(client)

    response = client.post(
        "/api/v1/projects",
        headers=headers,
        json={
            "name": "Limite fora do banco",
            "description": "O schema deve rejeitar antes da persistência.",
            "taskEmployeeLimit": 2_147_483_648,
        },
    )

    assert response.status_code == 422, response.text


def test_locked_polis_change_contract_is_versioned_semantically_and_eol_independent():
    assert LOCKED_CONTRACT_PATH.is_file()

    source = LOCKED_CONTRACT_PATH.read_text(encoding="utf-8")
    crlf_source = source.replace("\r\n", "\n").replace("\n", "\r\n")
    contract = json.loads(crlf_source)

    assert contract["schema_version"] == 4
    assert contract["kind"] == "defect"
    assert contract["baseline_lock"]["base_commit"] == BASE_COMMIT
    assert {
        requirement["id"]
        for requirement in contract["specification"]["requirements"]
    } == {
        "REQ-001",
        "REQ-002",
        "REQ-003",
        "REQ-004",
        "REQ-005",
    }


def test_project_management_page_matches_admin_workspace_structure():
    source = PROJECT_PAGE_PATH.read_text(encoding="utf-8")

    assert "title: 'Administrar projetos'" in source
    assert "Widget _buildMetricGrid(bool isWide)" in source
    assert "Widget _buildProjectsSection(bool isWide)" in source
    assert "Widget _buildTaskWorkspace(bool isWide)" in source
    assert "class _ProjectMetricItem extends StatelessWidget" in source
    assert "class _ProjectListTile extends StatelessWidget" in source
    assert "isWide ? 32 : 24" in source
    assert "const SizedBox(height: 16)" in source


def test_project_limit_reduction_conflict_has_actionable_ptbr_treatment():
    page_source = PROJECT_PAGE_PATH.read_text(encoding="utf-8")
    api_source = API_CLIENT_PATH.read_text(encoding="utf-8")

    assert (
        "Ao reduzir, o limite não pode ficar abaixo da quantidade de "
        "funcionários já associada a nenhuma tarefa existente."
        in page_source
    )
    assert "Project task employee limit is below current task membership." in api_source
    assert (
        "O limite por tarefa não pode ser menor que a quantidade de funcionários "
        "já associados a uma tarefa. Remova participantes antes de reduzir o limite."
        in api_source
    )


def test_ui_standardization_polis_contract_is_versioned():
    assert NEW_LOCKED_CONTRACT_PATH.is_file()

    contract = json.loads(NEW_LOCKED_CONTRACT_PATH.read_text(encoding="utf-8"))
    assert contract["schema_version"] == 4
    assert contract["baseline_lock"]["base_commit"] == BASE_COMMIT
    requirement_ids = {
        requirement["id"]
        for requirement in contract["specification"]["requirements"]
    }
    assert {"REQ-006", "REQ-007", "REQ-008"}.issubset(requirement_ids)


def test_project_page_uses_dart_3_compatible_integer_literal():
    source = PROJECT_PAGE_PATH.read_text(encoding="utf-8")

    assert "2_147_483_647" not in source
    assert "parsed > 2147483647" in source


def test_ui_standardization_v2_polis_contract_is_versioned():
    assert UI_STANDARDIZATION_V2_CONTRACT_PATH.is_file()

    contract = json.loads(UI_STANDARDIZATION_V2_CONTRACT_PATH.read_text(encoding="utf-8"))
    assert contract["schema_version"] == 4
    assert contract["baseline_lock"]["base_commit"] == BASE_COMMIT
    requirement_ids = {
        requirement["id"]
        for requirement in contract["specification"]["requirements"]
    }
    assert "REQ-009" in requirement_ids


def test_project_task_buttons_use_square_global_button_shape():
    source = APP_THEME_PATH.read_text(encoding="utf-8")

    assert "filledButtonTheme: FilledButtonThemeData(" in source
    assert "textButtonTheme: TextButtonThemeData(" in source
    assert source.count("shape: const RoundedRectangleBorder(borderRadius: _radius)") >= 4


def test_project_switch_clears_previous_task_state_before_notifying():
    source = _controller_source()
    method = source.split("Future<void> selectProject(String projectId) async {", 1)[1].split(
        "Future<void> reloadProjectMembers()", 1
    )[0]

    notify_index = method.index("notifyListeners();")
    assert method.index("tasks = <TaskRecord>[];") < notify_index
    assert method.index("tasksError = null;") < notify_index


def test_inactive_projects_never_remain_in_active_controller_list():
    source = _controller_source()

    create_method = source.split("Future<ProjectSummary> createProject", 1)[1].split(
        "Future<ProjectSummary> updateProject", 1
    )[0]
    update_method = source.split("Future<ProjectSummary> updateProject", 1)[1].split(
        "Future<void> deleteProject", 1
    )[0]

    assert "created.status == ProjectStatus.active" in create_method
    assert "updated.status == ProjectStatus.inactive" in update_method
    assert "projects = projects.where((current) => current.id != updated.id).toList();" in update_method


def test_stale_task_creation_does_not_mutate_new_project_selection():
    source = _controller_source()
    method = source.split("Future<TaskRecord> createTask", 1)[1].split(
        "Future<TaskRecord> updateTask", 1
    )[0]

    create_index = method.index("await _api.createTask(projectId, draft)")
    guard_index = method.index("selectedProjectId != projectId")
    mutation_index = method.index("tasks = <TaskRecord>[created, ...tasks]")

    assert create_index < guard_index < mutation_index
