import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/projects/presentation/kanban_controller.dart';

void main() {
  test('loads one authoritative project snapshot on startup', () async {
    final api = _KanbanApi();
    final controller = ProjectKanbanController(api: api);

    await controller.start();

    expect(api.requestedStatus, ProjectStatus.active);
    expect(controller.selectedProjectId, 'project-a');
    expect(controller.board?.projectId, 'project-a');
    expect(controller.tasks.map((task) => task.projectId), everyElement('project-a'));
    expect(controller.projectMembers.map((member) => member.projectId), everyElement('project-a'));
    expect(controller.canManageStructure, isTrue);
  });

  test('successful card creation survives a failed board refresh', () async {
    final api = _KanbanApi();
    final controller = ProjectKanbanController(api: api);
    await controller.start();
    api.failNextBoardRead = true;

    final created = await controller.createCard(
      const TaskDraft(
        name: 'Novo card',
        description: 'Descrição do card',
        type: TaskType.feature,
      ),
    );

    expect(created.id, 'task-new');
    expect(api.createTaskCalls, 1);
    expect(controller.board?.projectId, 'project-a');
    expect(
      controller.boardError,
      contains(
          'A alteração foi aplicada, mas o quadro não pôde ser atualizado'),
    );

    await controller.reload();
    expect(controller.boardError, isNull);
    expect(api.createTaskCalls, 1);
  });

  test('reuses immutable snapshot lists between unchanged reads', () async {
    final api = _KanbanApi();
    final controller = ProjectKanbanController(api: api);

    await controller.start();

    expect(identical(controller.projects, controller.projects), isTrue);
    expect(identical(controller.projectMembers, controller.projectMembers), isTrue);
    expect(identical(controller.tasks, controller.tasks), isTrue);
    expect(() => controller.projects.clear(), throwsUnsupportedError);
    expect(() => controller.projectMembers.clear(), throwsUnsupportedError);
    expect(() => controller.tasks.clear(), throwsUnsupportedError);
  });

  test('discards stale board snapshots after project selection changes', () async {
    final api = _KanbanApi();
    final controller = ProjectKanbanController(api: api);
    await controller.start();

    api.controlBoards = true;
    final stale = controller.selectProject('project-b');
    await Future<void>.delayed(Duration.zero);
    expect(api.boardCompleters.containsKey('project-b'), isTrue);

    final current = controller.selectProject('project-a');
    await Future<void>.delayed(Duration.zero);
    expect(api.boardCompleters.containsKey('project-a'), isTrue);

    api.boardCompleters['project-a']!.complete(
      _board('project-a', version: 3, cardColumnId: 'column-a'),
    );
    await current;

    api.boardCompleters['project-b']!.complete(
      _board('project-b', version: 2, cardColumnId: 'column-a'),
    );
    await stale;

    expect(controller.selectedProjectId, 'project-a');
    expect(controller.board?.projectId, 'project-a');
    expect(controller.board?.kanbanVersion, 3);
  });

  test('card move remains server-authoritative until accepted response arrives', () async {
    final api = _KanbanApi();
    final controller = ProjectKanbanController(api: api);
    await controller.start();

    final completer = Completer<KanbanBoard>();
    api.reorderCardsCompleter = completer;

    final moving = controller.moveCard(
      taskId: 'task-01',
      toColumnId: 'column-b',
      toIndex: 0,
    );
    await Future<void>.delayed(Duration.zero);

    expect(controller.board!.columns.first.cards.single.id, 'task-01');
    expect(controller.board!.columns.last.cards, isEmpty);
    expect(api.lastExpectedVersion, 1);
    expect(api.lastCardOrdering, <String, List<String>>{
      'column-a': <String>[],
      'column-b': <String>['task-01'],
    });

    completer.complete(
      _board('project-a', version: 2, cardColumnId: 'column-b'),
    );
    await moving;

    expect(controller.board?.kanbanVersion, 2);
    expect(controller.board!.columns.first.cards, isEmpty);
    expect(controller.board!.columns.last.cards.single.id, 'task-01');
  });

  test('409 conflict reloads latest authoritative board', () async {
    final api = _KanbanApi();
    final controller = ProjectKanbanController(api: api);
    await controller.start();

    api.throwConflictOnReorder = true;
    api.boards['project-a'] = _board(
      'project-a',
      version: 7,
      cardColumnId: 'column-b',
    );

    await controller.moveCard(
      taskId: 'task-01',
      toColumnId: 'column-b',
      toIndex: 0,
    );

    expect(controller.board?.kanbanVersion, 7);
    expect(controller.board!.columns.last.cards.single.id, 'task-01');
    expect(controller.boardError, contains('outra sessão'));
  });
  test('queued move intent cannot cross a project selection boundary',
      () async {
    final api = _KanbanApi();
    final controller = ProjectKanbanController(api: api);
    await controller.start();

    final firstResponse = Completer<KanbanBoard>();
    api.reorderCardsCompleter = firstResponse;

    final first = controller.moveCard(
      taskId: 'task-01',
      toColumnId: 'column-b',
      toIndex: 0,
    );
    await Future<void>.delayed(Duration.zero);

    final queued = controller.moveCard(
      taskId: 'task-01',
      toColumnId: 'column-b',
      toIndex: 0,
    );
    await controller.selectProject('project-b');

    firstResponse.complete(
      _board('project-a', version: 2, cardColumnId: 'column-b'),
    );
    await first;
    await queued;

    expect(controller.selectedProjectId, 'project-b');
    expect(api.reorderCardProjects, <String>['project-a']);
  });

  test('column movement is expressed with stable column identity', () async {
    final api = _KanbanApi();
    final controller = ProjectKanbanController(api: api);
    await controller.start();

    await controller.moveColumn(columnId: 'column-a', toIndex: 1);

    expect(api.lastColumnOrdering, <String>['column-b', 'column-a']);
    expect(api.lastExpectedVersion, 1);
  });
}

class _KanbanApi extends TouchInApi {
  ProjectStatus? requestedStatus;
  bool controlBoards = false;
  bool throwConflictOnReorder = false;
  bool failNextBoardRead = false;
  int createTaskCalls = 0;
  Completer<KanbanBoard>? reorderCardsCompleter;
  int? lastExpectedVersion;
  Map<String, List<String>>? lastCardOrdering;
  List<String>? lastColumnOrdering;
  final List<String> reorderCardProjects = <String>[];

  final Map<String, Completer<KanbanBoard>> boardCompleters =
      <String, Completer<KanbanBoard>>{};
  final Map<String, KanbanBoard> boards = <String, KanbanBoard>{
    'project-a': _board('project-a', version: 1, cardColumnId: 'column-a'),
    'project-b': _board('project-b', version: 1, cardColumnId: 'column-a'),
  };

  @override
  Future<AuthContext> getAuthContext() async {
    return const AuthContext(
      company: AuthCompanySummary(
        id: 'company-01',
        legalName: 'TouchIn Tecnologia LTDA',
        tradeName: 'TouchIn',
        cnpjMasked: '12.***.***/****-90',
        emailMasked: 'co*****@touchin.com',
        phoneMasked: '11*****0000',
      ),
      user: AuthUserSummary(
        id: 'user-01',
        email: 'manager@touchin.com',
        role: 'manager',
        employeeId: 'emp-01',
      ),
    );
  }

  @override
  Future<List<ProjectSummary>> listProjects({ProjectStatus? status}) async {
    requestedStatus = status;
    return <ProjectSummary>[
      _project('project-a'),
      _project('project-b'),
    ];
  }

  @override
  Future<List<ProjectMemberSummary>> listProjectMembers(String projectId) async {
    return <ProjectMemberSummary>[
      ProjectMemberSummary(
        employeeId: 'emp-01',
        projectId: projectId,
        employeeName: 'Manager',
        createdAt: DateTime(2026, 9, 21),
      ),
    ];
  }

  @override
  Future<List<TaskRecord>> listTasks(String projectId) async {
    return boards[projectId]!.taskRecords;
  }

  @override
  Future<KanbanBoard> getKanbanBoard(String projectId) {
    if (failNextBoardRead) {
      failNextBoardRead = false;
      return Future<KanbanBoard>.error(
          StateError('temporary board read failure'));
    }
    if (controlBoards) {
      return boardCompleters
          .putIfAbsent(projectId, Completer<KanbanBoard>.new)
          .future;
    }
    return Future<KanbanBoard>.value(boards[projectId]!);
  }

  @override
  Future<TaskRecord> createTask(String projectId, TaskDraft draft) async {
    createTaskCalls += 1;
    return TaskRecord(
      id: 'task-new',
      projectId: projectId,
      parentTaskId: draft.parentTaskId,
      cardNumber: 2,
      kanbanColumnId: draft.columnId ?? 'column-a',
      kanbanPosition: 1,
      name: draft.name,
      description: draft.description,
      type: draft.type,
      createdAt: DateTime(2026, 9, 22),
      updatedAt: DateTime(2026, 9, 22),
    );
  }

  @override
  Future<KanbanBoard> reorderKanbanCards(
    String projectId, {
    required int expectedVersion,
    required Map<String, List<String>> columnTaskIds,
  }) {
    reorderCardProjects.add(projectId);
    lastExpectedVersion = expectedVersion;
    lastCardOrdering = <String, List<String>>{
      for (final entry in columnTaskIds.entries)
        entry.key: List<String>.from(entry.value),
    };
    if (throwConflictOnReorder) {
      throw ApiException('Conflict', statusCode: 409);
    }
    final completer = reorderCardsCompleter;
    if (completer != null) {
      return completer.future;
    }
    return Future<KanbanBoard>.value(
      _board(projectId, version: expectedVersion + 1, cardColumnId: 'column-b'),
    );
  }

  @override
  Future<KanbanBoard> reorderKanbanColumns(
    String projectId, {
    required int expectedVersion,
    required List<String> columnIds,
  }) async {
    lastExpectedVersion = expectedVersion;
    lastColumnOrdering = List<String>.from(columnIds);
    return _board(projectId, version: expectedVersion + 1, cardColumnId: 'column-a');
  }
}

ProjectSummary _project(String id) {
  return ProjectSummary(
    id: id,
    name: id,
    description: 'Descrição',
    taskEmployeeLimit: 3,
    status: ProjectStatus.active,
    createdAt: DateTime(2026, 9, 21),
    updatedAt: DateTime(2026, 9, 21),
  );
}

KanbanBoard _board(
  String projectId, {
  required int version,
  required String cardColumnId,
}) {
  final card = KanbanCard(
    id: 'task-01',
    projectId: projectId,
    parentTaskId: null,
    cardNumber: 1,
    kanbanColumnId: cardColumnId,
    kanbanPosition: 0,
    name: 'Implementar tela',
    description: 'Descrição',
    type: TaskType.feature,
    assignees: const <TaskMemberSummary>[],
    createdAt: DateTime(2026, 9, 21),
    updatedAt: DateTime(2026, 9, 21),
  );

  return KanbanBoard(
    projectId: projectId,
    kanbanVersion: version,
    columns: <KanbanColumn>[
      KanbanColumn(
        id: 'column-a',
        projectId: projectId,
        name: 'A fazer',
        position: 0,
        cards: cardColumnId == 'column-a' ? <KanbanCard>[card] : <KanbanCard>[],
        createdAt: DateTime(2026, 9, 21),
        updatedAt: DateTime(2026, 9, 21),
      ),
      KanbanColumn(
        id: 'column-b',
        projectId: projectId,
        name: 'Concluído',
        position: 1,
        cards: cardColumnId == 'column-b' ? <KanbanCard>[card] : <KanbanCard>[],
        createdAt: DateTime(2026, 9, 21),
        updatedAt: DateTime(2026, 9, 21),
      ),
    ],
  );
}
