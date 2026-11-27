import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:flutter/foundation.dart';

class ProjectTasksController extends ChangeNotifier {
  ProjectTasksController({TouchInApi? api}) : _api = api ?? TouchInApi();

  final TouchInApi _api;
  bool _disposed = false;

  @override
  void notifyListeners() {
    if (!_disposed) super.notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  AuthContext? authContext;
  List<ProjectSummary> projects = <ProjectSummary>[];
  List<TaskRecord> tasks = <TaskRecord>[];
  List<ProjectMemberSummary> projectMembers = <ProjectMemberSummary>[];
  List<TaskMemberSummary> taskMembers = <TaskMemberSummary>[];
  String? selectedProjectId;
  String? selectedTaskId;
  bool isLoading = true;
  bool isLoadingTasks = false;
  bool isLoadingProjectMembers = false;
  bool isLoadingMembers = false;
  bool isMutating = false;
  int _pendingMutations = 0;
  String? loadError;
  String? tasksError;
  String? projectMembersError;
  String? membersError;

  int _startupRequestVersion = 0;
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
      !isLoadingProjectMembers &&
      projectMembersError == null &&
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
    if (_disposed) return;
    final version = ++_startupRequestVersion;
    _invalidateProjectScopedRequests();
    isLoading = true;
    loadError = null;
    notifyListeners();

    try {
      final context = await _api.getAuthContext();
      if (_disposed || version != _startupRequestVersion) return;
      final activeProjects = await _api.listProjects(status: ProjectStatus.active);
      if (_disposed || version != _startupRequestVersion) return;

      authContext = context;
      projects = activeProjects;
      _resetProjectSelection(projects.firstOrNull?.id);
      isLoading = false;
      await _loadProjectSections();
    } catch (error) {
      if (_disposed || version != _startupRequestVersion) return;
      isLoading = false;
      loadError =
          _errorMessage(error, 'Não foi possível carregar os projetos.');
      notifyListeners();
    }
  }

  Future<List<EmployeeProfile>> listEmployeesForProjectAccess() =>
      _api.listEmployees();

  Future<void> _loadProjectSections() {
    // Start both reads before publishing the selection. The project list can
    // render now, and each section leaves its skeleton independently.
    final members = _loadProjectMembersForSelectedProject(notifyLoading: false);
    final tasks = _loadTasksForSelectedProject(notifyLoading: false);
    notifyListeners();
    return Future.wait<void>([members, tasks]);
  }

  Future<void> retry() => start();

  Future<void> selectProject(String projectId) async {
    if (selectedProjectId == projectId &&
        tasksError == null &&
        projectMembersError == null) {
      return;
    }
    _resetProjectSelection(projectId);
    await _loadProjectSections();
  }

  void _resetProjectSelection(String? projectId) {
    _invalidateProjectScopedRequests();
    selectedProjectId = projectId;
    selectedTaskId = null;
    tasks = <TaskRecord>[];
    projectMembers = <ProjectMemberSummary>[];
    taskMembers = <TaskMemberSummary>[];
    tasksError = null;
    projectMembersError = null;
    membersError = null;
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
      isLoadingTasks = false;
      if (tasks.isEmpty) {
        selectedTaskId = null;
        taskMembers = <TaskMemberSummary>[];
        _invalidateTaskMemberRequests();
        notifyListeners();
      } else {
        final currentSelectionStillExists =
            tasks.any((task) => task.id == selectedTaskId);
        if (!currentSelectionStillExists) {
          _invalidateTaskMemberRequests();
          taskMembers = <TaskMemberSummary>[];
          selectedTaskId = tasks.first.id;
        }
        // Publish the task list without waiting for the selected task's roster.
        await _loadMembersForSelectedTask();
      }
    } catch (error) {
      if (requestVersion != _tasksRequestVersion ||
          selectedProjectId != projectId) {
        return;
      }
      isLoadingTasks = false;
      tasksError =
          _errorMessage(error, 'Não foi possível carregar as tarefas.');
      notifyListeners();
    }
  }

  Future<void> selectTask(String taskId) async {
    if (selectedTaskId == taskId && membersError == null) {
      return;
    }
    _invalidateTaskMemberRequests();
    selectedTaskId = taskId;
    taskMembers = <TaskMemberSummary>[];
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
        _resetProjectSelection(created.id);
        await _loadProjectSections();
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
        projects =
            projects.where((current) => current.id != updated.id).toList();
        if (selectedProjectId == updated.id) {
          _resetProjectSelection(projects.firstOrNull?.id);
          await _loadProjectSections();
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
        _resetProjectSelection(projects.firstOrNull?.id);
        await _loadProjectSections();
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
      TaskRecord updated;
      try {
        updated = await _api.updateTask(task.projectId, task.id, draft,
            expectedUpdatedAt: task.updatedAt, expectedRevision: task.revision);
      } on ApiException catch (error) {
        if (error.code == 'task_version_conflict' &&
            selectedProjectId == task.projectId) {
          await _loadTasksForSelectedProject(notifyLoading: false);
        }
        rethrow;
      }
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
    _pendingMutations += 1;
    isMutating = true;
    notifyListeners();
    try {
      return await action();
    } finally {
      _pendingMutations -= 1;
      isMutating = _pendingMutations > 0;
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
