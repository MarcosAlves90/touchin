import 'dart:async';

import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/projects/presentation/project_tasks_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requests only active projects during startup', () async {
    final api = _ControlledProjectApi();
    final controller = ProjectTasksController(api: api);

    await controller.start();

    expect(api.requestedProjectStatus, ProjectStatus.active);
  });

  test('manager sees projects first and 2000 tasks before either roster', () async {
    final api = _ControlledProjectApi()
      ..role = 'manager'
      ..controlProjectMembers = true
      ..controlTasks = true
      ..controlTaskMembers = true;
    final controller = ProjectTasksController(api: api);
    addTearDown(controller.dispose);

    final startup = controller.start();
    await Future<void>.delayed(Duration.zero);

    expect(controller.isLoading, isFalse);
    expect(controller.selectedProjectId, 'project-a');
    expect(controller.isLoadingProjectMembers, isTrue);
    expect(controller.isLoadingTasks, isTrue);
    expect(api.employeeRequests, 0);

    api.taskCompleters['project-a']!.complete(List.generate(
      2000, (i) => _task('project-a', 'project-a-$i'),
    ));
    await Future<void>.delayed(Duration.zero);

    expect(controller.tasks, hasLength(2000));
    expect(controller.isLoadingTasks, isFalse);
    expect(controller.isLoadingProjectMembers, isTrue);
    expect(controller.isLoadingMembers, isTrue);
    expect(controller.canJoinSelectedTask, isFalse);

    api.projectMemberCompleters['project-a']!.completeError(StateError('offline'));
    api.taskMemberCompleters['project-a-0']!.complete([]);
    await startup;
    expect(controller.projectMembersError, isNotNull);
    expect(controller.loadError, isNull);
    expect(controller.tasks, hasLength(2000));
    expect(controller.canJoinSelectedTask, isFalse);
    expect(api.employeeRequests, 0);

    await controller.listEmployeesForProjectAccess();
    expect(api.employeeRequests, 1);
  });

  test('ignores a first project response after a complete retry', () async {
    final a = Completer<List<ProjectSummary>>();
    final b = Completer<List<ProjectSummary>>();
    final api = _ControlledProjectApi()..projectResponses.addAll([a, b]);
    final controller = ProjectTasksController(api: api);
    addTearDown(controller.dispose);

    final first = controller.start();
    await Future<void>.delayed(Duration.zero);
    final retry = controller.retry();
    await Future<void>.delayed(Duration.zero);

    b.complete([_project('current')]);
    await retry;
    a.complete([_project('stale')]);
    await first;

    expect(controller.selectedProjectId, 'current');
    expect(controller.tasks.every((task) => task.projectId == 'current'), isTrue);
    expect(controller.loadError, isNull);
  });

  test('publishes tasks when member requests fail and isolates retry', () async {
    final api = _ControlledProjectApi()..controlTaskMembers = true;
    final controller = ProjectTasksController(api: api);
    addTearDown(controller.dispose);
    final startup = controller.start();
    await Future<void>.delayed(Duration.zero);
    final first = api.taskMemberCompleters.remove('project-a-task-a')!;
    first.completeError(StateError('offline'));
    await startup;
    expect(controller.membersError, isNotNull);
    expect(controller.tasksError, isNull);
    expect(controller.tasks, hasLength(2));

    final retry = controller.reloadMembers();
    api.taskMemberCompleters['project-a-task-a']!.complete([
      _taskMember('project-a-task-a', 'emp-current'),
    ]);
    await retry;

    expect(controller.membersError, isNull);
    expect(controller.taskMembers.single.employeeId, 'emp-current');
  });

  test('discards stale task member responses after task selection changes', () async {
    final api = _ControlledProjectApi();
    final controller = ProjectTasksController(api: api);
    await controller.start();

    api.controlTaskMembers = true;
    final stale = controller.selectTask('project-a-task-b');
    final current = controller.selectTask('project-a-task-a');

    api.taskMemberCompleters['project-a-task-a']!.complete(<TaskMemberSummary>[
      _taskMember('project-a-task-a', 'emp-current'),
    ]);
    await current;

    api.taskMemberCompleters['project-a-task-b']!.complete(<TaskMemberSummary>[
      _taskMember('project-a-task-b', 'emp-stale'),
    ]);
    await stale;

    expect(controller.selectedTaskId, 'project-a-task-a');
    expect(
      controller.taskMembers.map((member) => member.employeeId),
      <String>['emp-current'],
    );
  });

  test('discards stale project task responses after project selection changes', () async {
    final api = _ControlledProjectApi();
    final controller = ProjectTasksController(api: api);
    await controller.start();

    api.controlTasks = true;
    final stale = controller.selectProject('project-b');
    await Future<void>.delayed(Duration.zero);
    expect(api.taskCompleters.containsKey('project-b'), isTrue);

    final current = controller.selectProject('project-a');
    await Future<void>.delayed(Duration.zero);
    expect(api.taskCompleters.containsKey('project-a'), isTrue);

    api.taskCompleters['project-a']!.complete(<TaskRecord>[
      _task('project-a', 'project-a-task-a'),
    ]);
    await current;

    api.taskCompleters['project-b']!.complete(<TaskRecord>[
      _task('project-b', 'project-b-task-a'),
    ]);
    await stale;

    expect(controller.selectedProjectId, 'project-a');
    expect(
      controller.tasks.map((task) => task.projectId).toList(),
      <String>['project-a'],
    );
  });

  test('discards stale project member responses after project selection changes', () async {
    final api = _ControlledProjectApi();
    final controller = ProjectTasksController(api: api);
    await controller.start();

    api.controlProjectMembers = true;
    final stale = controller.selectProject('project-b');
    final current = controller.selectProject('project-a');

    api.projectMemberCompleters['project-a']!.complete(<ProjectMemberSummary>[
      _projectMember('project-a', 'emp-current'),
    ]);
    await current;

    api.projectMemberCompleters['project-b']!.complete(<ProjectMemberSummary>[
      _projectMember('project-b', 'emp-stale'),
    ]);
    await stale;

    expect(controller.selectedProjectId, 'project-a');
    expect(
      controller.projectMembers.map((member) => member.employeeId),
      <String>['emp-current'],
    );
  });

  test('clears previous task state immediately when project changes', () async {
    final api = _ControlledProjectApi();
    final controller = ProjectTasksController(api: api);
    addTearDown(controller.dispose);
    await controller.start();

    expect(controller.tasks, isNotEmpty);
    api.controlProjectMembers = true;

    // Record what widgets actually observe, including the first notification.
    final published = <({String? project, List<String> taskProjects, String? error})>[];
    controller.addListener(() {
      published.add((
        project: controller.selectedProjectId,
        taskProjects: [for (final task in controller.tasks) task.projectId],
        error: controller.tasksError,
      ));
    });
    final switching = controller.selectProject('project-b');
    expect(published.first.project, 'project-b');
    expect(published.first.taskProjects, isEmpty);
    expect(published.first.error, isNull);

    expect(controller.selectedProjectId, 'project-b');
    expect(controller.tasks, isEmpty);
    expect(controller.tasksError, isNull);
    await Future<void>.delayed(Duration.zero);
    expect(controller.tasks, hasLength(2));
    expect(controller.tasks.every((task) => task.projectId == 'project-b'), isTrue);
    expect(controller.isLoadingProjectMembers, isTrue);

    api.projectMemberCompleters['project-b']!.complete(<ProjectMemberSummary>[
      _projectMember('project-b', 'emp-04'),
    ]);
    await switching;
    expect(published.expand((state) => state.taskProjects), everyElement('project-b'));
  });

  test('does not keep inactive projects in the active management list', () async {
    final api = _ControlledProjectApi();
    final controller = ProjectTasksController(api: api);
    await controller.start();

    final created = await controller.createProject(
      const ProjectDraft(
        name: 'Inactive create',
        description: 'Should not enter active list',
        taskEmployeeLimit: 2,
        status: ProjectStatus.inactive,
      ),
    );
    expect(created.status, ProjectStatus.inactive);
    expect(controller.projects.any((project) => project.id == created.id), isFalse);

    final selected = controller.selectedProject!;
    await controller.updateProject(
      selected,
      ProjectDraft(
        name: selected.name,
        description: selected.description ?? '',
        taskEmployeeLimit: selected.taskEmployeeLimit,
        status: ProjectStatus.inactive,
      ),
    );

    expect(controller.projects.any((project) => project.id == selected.id), isFalse);
    expect(controller.selectedProjectId, isNot(selected.id));
  });

  test('discards a created task response after project selection changes', () async {
    final api = _ControlledProjectApi()..controlCreateTasks = true;
    final controller = ProjectTasksController(api: api);
    await controller.start();

    final creating = controller.createTask(
      const TaskDraft(
        name: 'Late task',
        description: 'Created for project A',
        type: TaskType.feature,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(api.createTaskCompleters.containsKey('project-a'), isTrue);

    await controller.selectProject('project-b');
    api.createTaskCompleters['project-a']!.complete(
      _task('project-a', 'project-a-task-late'),
    );
    final created = await creating;

    expect(created.projectId, 'project-a');
    expect(controller.selectedProjectId, 'project-b');
    expect(controller.tasks.every((task) => task.projectId == 'project-b'), isTrue);
    expect(controller.selectedTaskId, isNot('project-a-task-late'));
  });

  test('isMutating stays true until overlapping requests complete out of order', () async {
    final api = _ControlledProjectApi()..controlCreateTasks = true;
    final controller = ProjectTasksController(api: api);
    await controller.start();
    final creating = controller.createTask(
      const TaskDraft(
        name: 'Pending task',
        description: 'Waiting for network',
        type: TaskType.feature,
      ),
    );
    expect(controller.isMutating, isTrue);

    final selected = controller.selectedProject!;
    await controller.updateProject(
      selected,
      ProjectDraft(
        name: selected.name,
        description: selected.description ?? '',
        taskEmployeeLimit: selected.taskEmployeeLimit,
        status: selected.status,
      ),
    );
    expect(controller.isMutating, isTrue,
        reason: 'an earlier createTask request is still pending');

    api.createTaskCompleters['project-a']!.complete(
      _task('project-a', 'new-task'),
    );
    await creating;
    expect(controller.isMutating, isFalse);
  });


}

class _ControlledProjectApi extends TouchInApi {
  ProjectStatus? requestedProjectStatus;
  String role = 'employee';
  int employeeRequests = 0;
  final projectResponses = <Completer<List<ProjectSummary>>>[];
  bool controlTasks = false;
  bool controlProjectMembers = false;
  bool controlTaskMembers = false;
  bool controlCreateTasks = false;

  final Map<String, Completer<TaskRecord>> createTaskCompleters =
      <String, Completer<TaskRecord>>{};

  final Map<String, Completer<List<TaskRecord>>> taskCompleters =
      <String, Completer<List<TaskRecord>>>{};
  final Map<String, Completer<List<ProjectMemberSummary>>>
      projectMemberCompleters =
      <String, Completer<List<ProjectMemberSummary>>>{};
  final Map<String, Completer<List<TaskMemberSummary>>> taskMemberCompleters =
      <String, Completer<List<TaskMemberSummary>>>{};

  @override
  Future<AuthContext> getAuthContext() async {
    return AuthContext(
      company: const AuthCompanySummary(
        id: 'company-01',
        legalName: 'TouchIn Tecnologia LTDA',
        tradeName: 'TouchIn',
        cnpjMasked: '12.***.***/****-90',
        emailMasked: 'co*****@touchin.com',
        phoneMasked: '11*****0000',
      ),
      user: AuthUserSummary(
        id: 'user-01',
        email: 'employee@touchin.com',
        role: role,
        employeeId: 'emp-04',
      ),
    );
  }

  @override
  Future<List<ProjectSummary>> listProjects({ProjectStatus? status}) async {
    requestedProjectStatus = status;
    if (projectResponses.isNotEmpty) return projectResponses.removeAt(0).future;
    return <ProjectSummary>[
      _project('project-a'),
      _project('project-b'),
    ];
  }

  @override
  Future<List<EmployeeProfile>> listEmployees() async {
    employeeRequests++;
    return [];
  }

  @override
  Future<List<ProjectMemberSummary>> listProjectMembers(String projectId) {
    if (controlProjectMembers) {
      return projectMemberCompleters
          .putIfAbsent(
            projectId,
            () => Completer<List<ProjectMemberSummary>>(),
          )
          .future;
    }
    return Future<List<ProjectMemberSummary>>.value(<ProjectMemberSummary>[
      _projectMember(projectId, 'emp-04'),
    ]);
  }

  @override
  Future<ProjectSummary> createProject(ProjectDraft draft) async {
    return ProjectSummary(
      id: 'created-${draft.status.name}',
      name: draft.name,
      description: draft.description,
      taskEmployeeLimit: draft.taskEmployeeLimit,
      status: draft.status,
      createdAt: DateTime(2026, 9, 17),
      updatedAt: DateTime(2026, 9, 17),
    );
  }

  @override
  Future<ProjectSummary> updateProject(
    String projectId,
    ProjectDraft draft,
  ) async {
    return ProjectSummary(
      id: projectId,
      name: draft.name,
      description: draft.description,
      taskEmployeeLimit: draft.taskEmployeeLimit,
      status: draft.status,
      createdAt: DateTime(2026, 9, 15),
      updatedAt: DateTime(2026, 9, 17),
    );
  }

  @override
  Future<TaskRecord> createTask(String projectId, TaskDraft draft) {
    if (controlCreateTasks) {
      return createTaskCompleters
          .putIfAbsent(projectId, () => Completer<TaskRecord>())
          .future;
    }
    return Future<TaskRecord>.value(_task(projectId, '$projectId-task-created'));
  }

  @override
  Future<List<TaskRecord>> listTasks(String projectId) {
    if (controlTasks) {
      return taskCompleters
          .putIfAbsent(projectId, () => Completer<List<TaskRecord>>())
          .future;
    }
    return Future<List<TaskRecord>>.value(<TaskRecord>[
      _task(projectId, '$projectId-task-a'),
      _task(projectId, '$projectId-task-b'),
    ]);
  }

  @override
  Future<List<TaskMemberSummary>> listTaskMembers(
    String projectId,
    String taskId,
  ) {
    if (controlTaskMembers) {
      return taskMemberCompleters
          .putIfAbsent(taskId, () => Completer<List<TaskMemberSummary>>())
          .future;
    }
    return Future<List<TaskMemberSummary>>.value(<TaskMemberSummary>[]);
  }
}

ProjectSummary _project(String id) {
  return ProjectSummary(
    id: id,
    name: id,
    description: 'Descrição',
    taskEmployeeLimit: 2,
    status: ProjectStatus.active,
    createdAt: DateTime(2026, 9, 15),
    updatedAt: DateTime(2026, 9, 15),
  );
}

ProjectMemberSummary _projectMember(String projectId, String employeeId) {
  return ProjectMemberSummary(
    employeeId: employeeId,
    projectId: projectId,
    employeeName: employeeId,
    createdAt: DateTime(2026, 9, 15),
  );
}

TaskRecord _task(String projectId, String taskId) {
  return TaskRecord(
    id: taskId,
    projectId: projectId,
    parentTaskId: null,
    name: taskId,
    description: 'Descrição',
    type: TaskType.feature,
    createdAt: DateTime(2026, 9, 15),
    updatedAt: DateTime(2026, 9, 15),
  );
}

TaskMemberSummary _taskMember(String taskId, String employeeId) {
  return TaskMemberSummary(
    employeeId: employeeId,
    taskId: taskId,
    employeeName: employeeId,
    createdAt: DateTime(2026, 9, 15),
  );
}
