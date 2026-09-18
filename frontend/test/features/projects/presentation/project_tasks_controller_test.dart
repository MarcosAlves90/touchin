import 'dart:async';

import 'package:bunchin_flutter/contracts/auth.dart';
import 'package:bunchin_flutter/contracts/project.dart';
import 'package:bunchin_flutter/contracts/task.dart';
import 'package:bunchin_flutter/core/network/bunchin_api.dart';
import 'package:bunchin_flutter/features/projects/presentation/project_tasks_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('requests only active projects during startup', () async {
    final api = _ControlledProjectApi();
    final controller = ProjectTasksController(api: api);

    await controller.start();

    expect(api.requestedProjectStatus, ProjectStatus.active);
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
    await controller.start();

    expect(controller.tasks, isNotEmpty);
    api.controlProjectMembers = true;

    final switching = controller.selectProject('project-b');
    await Future<void>.delayed(Duration.zero);

    expect(controller.selectedProjectId, 'project-b');
    expect(controller.tasks, isEmpty);
    expect(controller.tasksError, isNull);

    api.projectMemberCompleters['project-b']!.complete(<ProjectMemberSummary>[
      _projectMember('project-b', 'emp-04'),
    ]);
    await switching;
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

}

class _ControlledProjectApi extends BunchinApi {
  ProjectStatus? requestedProjectStatus;
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
    return const AuthContext(
      company: AuthCompanySummary(
        id: 'company-01',
        legalName: 'Bunchin Tecnologia LTDA',
        tradeName: 'Bunchin',
        cnpjMasked: '12.***.***/****-90',
        emailMasked: 'co*****@bunchin.com',
        phoneMasked: '11*****0000',
      ),
      user: AuthUserSummary(
        id: 'user-01',
        email: 'employee@bunchin.com',
        role: 'employee',
        employeeId: 'emp-04',
      ),
    );
  }

  @override
  Future<List<ProjectSummary>> listProjects({ProjectStatus? status}) async {
    requestedProjectStatus = status;
    return <ProjectSummary>[
      _project('project-a'),
      _project('project-b'),
    ];
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
