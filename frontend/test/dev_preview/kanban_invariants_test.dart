import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/dev_preview/preview_api.dart';
import 'package:touchin_flutter/dev_preview/preview_controller.dart';
import 'package:touchin_flutter/dev_preview/preview_fixtures.dart';

const _task = TaskDraft(
  name: 'Card fictício',
  description: 'Regressão dos invariantes do Kanban local.',
  type: TaskType.feature,
);
const _project = ProjectDraft(
  name: 'Projeto fictício novo',
  description: 'Isolado dos projetos semeados.',
  taskEmployeeLimit: 3,
);

void main() {
  late PreviewController controller;
  late PreviewFixtures fixtures;
  late PreviewApi api;

  setUp(() {
    controller = PreviewController();
    fixtures = PreviewFixtures();
    api = PreviewApi(
        controller, fixtures, PreviewTokenStorage(controller, fixtures));
  });
  tearDown(() => controller.dispose());

  final conflict = throwsA(isA<ApiException>()
      .having((error) => error.statusCode, 'statusCode', 409));

  test('last Kanban column cannot be deleted and task operations remain usable',
      () async {
    final project = await api.createProject(_project);
    final before = await api.getKanbanBoard(project.id);
    final columns = fixtures.columns.map((column) => Map.of(column)).toList();
    expect(before.columns, hasLength(1));

    await expectLater(
        api.deleteKanbanColumn(project.id, before.columns.single.id,
            expectedVersion: before.kanbanVersion),
        conflict);

    final after = await api.getKanbanBoard(project.id);
    expect(after.kanbanVersion, before.kanbanVersion);
    expect(after.columns.single.id, before.columns.single.id);
    expect(fixtures.columns, columns);
    expect(await api.listTasks(project.id), isEmpty);
    final task = await api.createTask(project.id, _task);
    expect(task.cardNumber, 1);
    expect(task.kanbanColumnId, before.columns.single.id);
    expect((await api.listTasks(project.id)).single.id, task.id);
    expect(
        (await api.getKanbanBoard(project.id)).taskRecords.single.id, task.id);
  });

  test('card numbers remain unique and increasing within every project',
      () async {
    final projects = await api.listProjects();
    final newProject = await api.createProject(_project);
    // Start with project 2, whose seed already includes cards 201, 202 and 203.
    for (final project in [
      projects[1],
      projects[0],
      projects[2],
      newProject,
    ]) {
      final seeded = await api.listTasks(project.id);
      final maximum = seeded.fold<int>(
          0,
          (maximum, task) =>
              task.cardNumber > maximum ? task.cardNumber : maximum);
      final created = <TaskRecord>[];
      for (var index = 0; index < 4; index++) {
        created.add(await api.createTask(project.id, _task));
      }
      final listed = await api.listTasks(project.id);
      expect(listed.map((task) => task.cardNumber).toSet(),
          hasLength(seeded.length + created.length),
          reason: project.id);
      expect(created.map((task) => task.cardNumber),
          [for (var index = 1; index <= 4; index++) maximum + index],
          reason: project.id);
      expect(
          (await api.getKanbanBoard(project.id))
              .taskRecords
              .map((task) => task.cardNumber)
              .toSet(),
          listed.map((task) => task.cardNumber).toSet());
    }
  });

  test('project card sequence survives deletion and resets deterministically',
      () async {
    final project = (await api.listProjects())[1];
    final seeded = await api.listTasks(project.id);
    final maximum = seeded.fold<int>(
        0,
        (maximum, task) =>
            task.cardNumber > maximum ? task.cardNumber : maximum);
    final first = await api.createTask(project.id, _task);
    expect(first.cardNumber, maximum + 1);
    await api.createProject(_project); // Unrelated global ID allocation.
    final second = await api.createTask(project.id, _task);
    expect(second.cardNumber, first.cardNumber + 1);
    await api.deleteTask(project.id, second.id);
    final third = await api.createTask(project.id, _task);
    expect(third.cardNumber, second.cardNumber + 1);

    fixtures.reset();
    controller.reset();
    final reset = await api.createTask(project.id, _task);
    expect(reset.cardNumber, first.cardNumber);
    expect(await api.listTasks(project.id), hasLength(seeded.length + 1));
  });

  test('empty non-final columns remain deletable and occupied columns conflict',
      () async {
    final project = await api.createProject(_project);
    var board = await api.getKanbanBoard(project.id);
    final originalColumn = board.columns.single.id;
    board = await api.createKanbanColumn(project.id,
        name: 'Outra coluna', expectedVersion: board.kanbanVersion);
    final extraColumn = board.columns.last.id;
    final versionBeforeDelete = board.kanbanVersion;
    board = await api.deleteKanbanColumn(project.id, extraColumn,
        expectedVersion: board.kanbanVersion);
    expect(board.columns.single.id, originalColumn);
    expect(board.kanbanVersion, versionBeforeDelete + 1);

    board = await api.createKanbanColumn(project.id,
        name: 'Outra coluna', expectedVersion: board.kanbanVersion);
    final task = await api.createTask(project.id, _task);
    board = await api.getKanbanBoard(project.id);
    await expectLater(
        api.deleteKanbanColumn(project.id, task.kanbanColumnId,
            expectedVersion: board.kanbanVersion),
        conflict);
    expect((await api.getKanbanBoard(project.id)).kanbanVersion,
        board.kanbanVersion);
    expect((await api.listTasks(project.id)).single.id, task.id);
  });
}
