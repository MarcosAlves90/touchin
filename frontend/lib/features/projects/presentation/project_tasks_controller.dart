import 'package:bunchin_flutter/contracts/auth.dart';
import 'package:bunchin_flutter/contracts/employee.dart';
import 'package:bunchin_flutter/contracts/project.dart';
import 'package:bunchin_flutter/contracts/task.dart';
import 'package:bunchin_flutter/core/network/api_client.dart';
import 'package:bunchin_flutter/core/network/bunchin_api.dart';
import 'package:flutter/foundation.dart';

class ProjectTasksController extends ChangeNotifier {
  ProjectTasksController({BunchinApi? api}) : _api = api ?? BunchinApi();

  final BunchinApi _api;

  AuthContext? authContext;
  List<ProjectSummary> projects = <ProjectSummary>[];
  List<TaskRecord> tasks = <TaskRecord>[];
  List<ProjectMemberSummary> projectMembers = <ProjectMemberSummary>[];
  List<TaskMemberSummary> taskMembers = <TaskMemberSummary>[];
  List<EmployeeProfile> employees = <EmployeeProfile>[];
  String? selectedProjectId;
  String? selectedTaskId;
  bool isLoading = true;
  bool isLoadingTasks = false;
  bool isLoadingProjectMembers = false;
  bool isLoadingMembers = false;
  bool isMutating = false;
  String? loadError;
  String? tasksError;
  String? projectMembersError;
  String? membersError;

  int _projectMembersRequestVersion = 0;
  int _tasksRequestVersion = 0;
  int _taskMembersRequestVersion = 0;

  bool get canManageProjects {
    final user = authContext?.user;
    return user?.isManager == true ||
        user?.isAdmin == true ||
        user?.isSuperAdmin == true;
  }

  bool get canManageTasks => canManageProjects;

  bool get canManageMembership => canManageProjects;

  bool get canManageOwnTaskMembership =>
      authContext?.user.hasEmployeeProfile == true &&
      currentEmployeeIsProjectMember;

  String? get currentEmployeeId => authContext?.user.employeeId;

  ProjectSummary? get selectedProject {
    for (final project in projects) {
      if (project.id == selectedProjectId) {
        return project;
      }
    }
    return null;
  }

  TaskRecord? get selectedTask {
    for (final task in tasks) {
      if (task.id == selectedTaskId) {
        return task;
      }
    }
    return null;
  }

  bool get currentEmployeeIsProjectMember {
    final employeeId = currentEmployeeId;
    if (employeeId == null) {
      return false;
    }
    return projectMembers.any((member) => member.employeeId == employeeId);
  }

  bool get currentEmployeeIsMember {
    final employeeId = currentEmployeeId;
    if (employeeId == null) {
      return false;
    }
    return taskMembers.any((member) => member.employeeId == employeeId);
  }

  bool get selectedTaskHasCapacity {
    final project = selectedProject;
    if (project == null) {
      return false;
    }
    return taskMembers.length < project.taskEmployeeLimit;
  }

  bool get canJoinSelectedTask =>
      canManageOwnTaskMembership &&
      !currentEmployeeIsMember &&
      !isLoadingMembers &&
      membersError == null &&
      selectedTaskHasCapacity;

  Future<void> start() async {
    isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      authContext = await _api.getAuthContext();
      projects = await _api.listProjects(status: ProjectStatus.active);
      if (canManageProjects) {
        employees = await _api.listEmployees();
      }

      if (projects.isNotEmpty) {
        selectedProjectId = projects.first.id;
        await _loadProjectMembersForSelectedProject(notifyLoading: false);
        await _loadTasksForSelectedProject(notifyLoading: false);
      } else {
        selectedProjectId = null;
        selectedTaskId = null;
        tasks = <TaskRecord>[];
        projectMembers = <ProjectMemberSummary>[];
        taskMembers = <TaskMemberSummary>[];
      }
      isLoading = false;
      notifyListeners();
    } catch (error) {
      isLoading = false;
      loadError = _errorMessage(error, 'Não foi possível carregar os projetos.');
      notifyListeners();
    }
  }

  Future<void> retry() => start();

  Future<void> selectProject(String projectId) async {
    if (selectedProjectId == projectId &&
        tasksError == null &&
        projectMembersError == null) {
      return;
    }
    _invalidateProjectScopedRequests();
    selectedProjectId = projectId;
    selectedTaskId = null;
    tasks = <TaskRecord>[];
    projectMembers = <ProjectMemberSummary>[];
    taskMembers = <TaskMemberSummary>[];
    tasksError = null;
    projectMembersError = null;
    membersError = null;
    notifyListeners();
    await _loadProjectMembersForSelectedProject();
    if (selectedProjectId != projectId) {
      return;
    }
    await _loadTasksForSelectedProject();
  }

  Future<void> reloadProjectMembers() =>
      _loadProjectMembersForSelectedProject();

  Future<void> _loadProjectMembersForSelectedProject({
    bool notifyLoading = true,
  }) async {
    final projectId = selectedProjectId;
    final requestVersion = ++_projectMembersRequestVersion;
    if (projectId == null) {
      projectMembers = <ProjectMemberSummary>[];
      isLoadingProjectMembers = false;
      return;
    }

    isLoadingProjectMembers = true;
    projectMembersError = null;
    if (notifyLoading) {
      notifyListeners();
    }

    try {
      final loadedMembers = await _api.listProjectMembers(projectId);
      if (requestVersion != _projectMembersRequestVersion ||
          selectedProjectId != projectId) {
        return;
      }
      projectMembers = loadedMembers;
      isLoadingProjectMembers = false;
      notifyListeners();
    } catch (error) {
      if (requestVersion != _projectMembersRequestVersion ||
          selectedProjectId != projectId) {
        return;
      }
      isLoadingProjectMembers = false;
      projectMembersError = _errorMessage(
        error,
        'Não foi possível carregar os acessos do projeto.',
      );
      notifyListeners();
    }
  }

  Future<void> reloadTasks() => _loadTasksForSelectedProject();

  Future<void> _loadTasksForSelectedProject({bool notifyLoading = true}) async {
    final projectId = selectedProjectId;
    final requestVersion = ++_tasksRequestVersion;
    if (projectId == null) {
      tasks = <TaskRecord>[];
      selectedTaskId = null;
      taskMembers = <TaskMemberSummary>[];
      isLoadingTasks = false;
      _invalidateTaskMemberRequests();
      return;
    }

    isLoadingTasks = true;
    tasksError = null;
    if (notifyLoading) {
      notifyListeners();
    }

    try {
      final loadedTasks = await _api.listTasks(projectId);
      if (requestVersion != _tasksRequestVersion ||
          selectedProjectId != projectId) {
        return;
      }
      tasks = loadedTasks;
      if (tasks.isEmpty) {
        selectedTaskId = null;
        taskMembers = <TaskMemberSummary>[];
        _invalidateTaskMemberRequests();
      } else {
        final currentSelectionStillExists =
            tasks.any((task) => task.id == selectedTaskId);
        if (!currentSelectionStillExists) {
          _invalidateTaskMemberRequests();
          selectedTaskId = tasks.first.id;
        }
        await _loadMembersForSelectedTask(notifyLoading: false);
      }
      if (requestVersion != _tasksRequestVersion ||
          selectedProjectId != projectId) {
        return;
      }
      isLoadingTasks = false;
      notifyListeners();
    } catch (error) {
      if (requestVersion != _tasksRequestVersion ||
          selectedProjectId != projectId) {
        return;
      }
      isLoadingTasks = false;
      tasksError = _errorMessage(error, 'Não foi possível carregar as tarefas.');
      notifyListeners();
    }
  }

  Future<void> selectTask(String taskId) async {
    if (selectedTaskId == taskId && membersError == null) {
      return;
    }
    _invalidateTaskMemberRequests();
    selectedTaskId = taskId;
    notifyListeners();
    await _loadMembersForSelectedTask();
  }

  Future<void> reloadMembers() => _loadMembersForSelectedTask();

  Future<void> _loadMembersForSelectedTask({bool notifyLoading = true}) async {
    final projectId = selectedProjectId;
    final taskId = selectedTaskId;
    final requestVersion = ++_taskMembersRequestVersion;
    if (projectId == null || taskId == null) {
      taskMembers = <TaskMemberSummary>[];
      isLoadingMembers = false;
      return;
    }

    isLoadingMembers = true;
    membersError = null;
    if (notifyLoading) {
      notifyListeners();
    }

    try {
      final loadedMembers = await _api.listTaskMembers(projectId, taskId);
      if (requestVersion != _taskMembersRequestVersion ||
          selectedProjectId != projectId ||
          selectedTaskId != taskId) {
        return;
      }
      taskMembers = loadedMembers;
      isLoadingMembers = false;
      notifyListeners();
    } catch (error) {
      if (requestVersion != _taskMembersRequestVersion ||
          selectedProjectId != projectId ||
          selectedTaskId != taskId) {
        return;
      }
      isLoadingMembers = false;
      membersError = _errorMessage(
        error,
        'Não foi possível carregar os membros da tarefa.',
      );
      notifyListeners();
    }
  }

  Future<ProjectSummary> createProject(ProjectDraft draft) async {
    return _mutate(() async {
      final created = await _api.createProject(draft);
      if (created.status == ProjectStatus.active) {
        projects = <ProjectSummary>[created, ...projects];
        _invalidateProjectScopedRequests();
        selectedProjectId = created.id;
        selectedTaskId = null;
        tasks = <TaskRecord>[];
        projectMembers = <ProjectMemberSummary>[];
        taskMembers = <TaskMemberSummary>[];
        tasksError = null;
        projectMembersError = null;
        membersError = null;
        await _loadProjectMembersForSelectedProject(notifyLoading: false);
        await _loadTasksForSelectedProject(notifyLoading: false);
      }
      return created;
    });
  }

  Future<ProjectSummary> updateProject(
    ProjectSummary project,
    ProjectDraft draft,
  ) async {
    return _mutate(() async {
      final updated = await _api.updateProject(project.id, draft);
      if (updated.status == ProjectStatus.inactive) {
        projects = projects.where((current) => current.id != updated.id).toList();
        if (selectedProjectId == updated.id) {
          _invalidateProjectScopedRequests();
          selectedProjectId = projects.isEmpty ? null : projects.first.id;
          selectedTaskId = null;
          tasks = <TaskRecord>[];
          projectMembers = <ProjectMemberSummary>[];
          taskMembers = <TaskMemberSummary>[];
          tasksError = null;
          projectMembersError = null;
          membersError = null;
          if (selectedProjectId != null) {
            await _loadProjectMembersForSelectedProject(notifyLoading: false);
            await _loadTasksForSelectedProject(notifyLoading: false);
          }
        }
      } else {
        projects = projects
            .map((current) => current.id == updated.id ? updated : current)
            .toList();
      }
      return updated;
    });
  }

  Future<void> deleteProject(ProjectSummary project) async {
    await _mutate(() async {
      await _api.deleteProject(project.id);
      projects = projects.where((current) => current.id != project.id).toList();
      if (selectedProjectId == project.id) {
        _invalidateProjectScopedRequests();
        selectedProjectId = projects.isEmpty ? null : projects.first.id;
        selectedTaskId = null;
        tasks = <TaskRecord>[];
        projectMembers = <ProjectMemberSummary>[];
        taskMembers = <TaskMemberSummary>[];
        if (selectedProjectId != null) {
          await _loadProjectMembersForSelectedProject(notifyLoading: false);
          await _loadTasksForSelectedProject(notifyLoading: false);
        }
      }
    });
  }

  Future<void> addMemberToSelectedProject(String employeeId) async {
    final projectId = selectedProjectId;
    if (projectId == null) {
      return;
    }
    await _mutate(() async {
      await _api.addProjectMember(projectId, employeeId);
      await _loadProjectMembersForSelectedProject(notifyLoading: false);
    });
  }

  Future<void> removeMemberFromSelectedProject(String employeeId) async {
    final projectId = selectedProjectId;
    if (projectId == null) {
      return;
    }
    await _mutate(() async {
      await _api.removeProjectMember(projectId, employeeId);
      await _loadProjectMembersForSelectedProject(notifyLoading: false);
      await _loadMembersForSelectedTask(notifyLoading: false);
    });
  }

  Future<TaskRecord> createTask(TaskDraft draft) async {
    final projectId = selectedProjectId;
    if (projectId == null) {
      throw StateError('Nenhum projeto selecionado.');
    }

    return _mutate(() async {
      final created = await _api.createTask(projectId, draft);
      if (selectedProjectId != projectId) {
        return created;
      }
      tasks = <TaskRecord>[created, ...tasks];
      selectedTaskId = created.id;
      taskMembers = <TaskMemberSummary>[];
      await _loadMembersForSelectedTask(notifyLoading: false);
      return created;
    });
  }

  Future<TaskRecord> updateTask(TaskRecord task, TaskDraft draft) async {
    return _mutate(() async {
      final updated = await _api.updateTask(task.projectId, task.id, draft);
      tasks = tasks
          .map((current) => current.id == updated.id ? updated : current)
          .toList();
      return updated;
    });
  }

  Future<void> joinSelectedTask() async {
    final projectId = selectedProjectId;
    final taskId = selectedTaskId;
    if (projectId == null || taskId == null) {
      return;
    }
    await _mutate(() async {
      await _api.joinTask(projectId, taskId);
      await _loadMembersForSelectedTask(notifyLoading: false);
    });
  }

  Future<void> leaveSelectedTask() async {
    final projectId = selectedProjectId;
    final taskId = selectedTaskId;
    if (projectId == null || taskId == null) {
      return;
    }
    await _mutate(() async {
      await _api.leaveTask(projectId, taskId);
      await _loadMembersForSelectedTask(notifyLoading: false);
    });
  }

  Future<void> addMemberToSelectedTask(String employeeId) async {
    final projectId = selectedProjectId;
    final taskId = selectedTaskId;
    if (projectId == null || taskId == null) {
      return;
    }
    await _mutate(() async {
      await _api.addTaskMember(projectId, taskId, employeeId);
      await _loadMembersForSelectedTask(notifyLoading: false);
    });
  }

  Future<void> removeMemberFromSelectedTask(String employeeId) async {
    final projectId = selectedProjectId;
    final taskId = selectedTaskId;
    if (projectId == null || taskId == null) {
      return;
    }
    await _mutate(() async {
      await _api.removeTaskMember(projectId, taskId, employeeId);
      await _loadMembersForSelectedTask(notifyLoading: false);
    });
  }

  Future<T> _mutate<T>(Future<T> Function() action) async {
    isMutating = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      isMutating = false;
      notifyListeners();
    }
  }

  void _invalidateProjectScopedRequests() {
    _projectMembersRequestVersion += 1;
    _tasksRequestVersion += 1;
    _taskMembersRequestVersion += 1;
    isLoadingProjectMembers = false;
    isLoadingTasks = false;
    isLoadingMembers = false;
  }

  void _invalidateTaskMemberRequests() {
    _taskMembersRequestVersion += 1;
    isLoadingMembers = false;
  }

  String _errorMessage(Object error, String fallback) {
    if (error is ApiException) {
      return error.message;
    }
    return fallback;
  }
}
