import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/features/projects/presentation/project_kanban_page.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/project_kanban_board.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/task_editor_dialog.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_editor_dialog.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_instant_select_field.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

void main() {
  testWidgets('Kanban uses persistent desktop nav and mobile drawer', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1079, 760));
    await tester.pumpWidget(
      MaterialApp(home: ProjectKanbanPage(api: _FakeKanbanApi())),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('workspace-desktop-destinations')),
      findsNothing,
    );
    expect(find.byTooltip('Abrir menu'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('kanban-topbar')),
      findsNothing,
      reason: 'kanban_idle_sync_badge',
    );
    expect(find.text('Sincronizado'), findsNothing,
        reason: 'kanban_idle_sync_badge');

    await tester.binding.setSurfaceSize(const Size(1080, 760));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('workspace-desktop-destinations')),
      findsOneWidget,
    );
    expect(find.byTooltip('Abrir menu'), findsNothing);
    for (final label in <String>[
      'Bater Ponto',
      'Administrar Equipe',
      'Trilha de Auditoria',
      'Projetos e tarefas',
      'Kanban',
      'Configurações',
      'Sair do Sistema',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.byKey(const ValueKey<String>('kanban-topbar')), findsNothing);
    expect(find.text('Sincronizado'), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  for (final inBacklog in <bool>[false, true]) {
    testWidgets(
        '${inBacklog ? 'Backlog' : 'Kanban'} create retains draft on 403/500 and retries',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1650, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _DelayedCreateKanbanApi();
      await tester.pumpWidget(MaterialApp(home: ProjectKanbanPage(api: api)));
      await tester.pumpAndSettle();

      if (inBacklog) {
        await tester.tap(find.text('Backlog'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Novo card'));
      } else {
        await tester.tap(find.byTooltip('Adicionar card em Concluído'));
      }
      await tester.pumpAndSettle();

      await tester.enterText(
          find.widgetWithText(TextFormField, 'Nome'), 'Card recuperável');
      await tester.enterText(find.widgetWithText(TextFormField, 'Descrição'),
          'Detalhes que não podem sumir');
      final expectedColumnId = inBacklog ? 'column-01' : 'column-02';

      for (final status in <int>[403, 500]) {
        await tester.tap(find.text('Criar tarefa').last);
        await tester.pump();
        expect(find.byType(ProjectTaskEditorDialog), findsOneWidget);
        expect(api.drafts.last.columnId, expectedColumnId);
        final attempts = api.drafts.length;

        await tester.tap(find.text('Criar tarefa').last);
        await tester.tap(find.text('Cancelar').last);
        await tester.pump();
        expect(api.drafts.length, attempts);
        expect(find.byType(ProjectTaskEditorDialog), findsOneWidget);

        api.gates.last.completeError(
          ApiException('Erro de criação $status', statusCode: status),
        );
        await tester.pumpAndSettle();
        expect(find.byType(ProjectTaskEditorDialog), findsOneWidget);
        expect(find.text('Card recuperável'), findsOneWidget);
        expect(find.text('Detalhes que não podem sumir'), findsOneWidget);
        expect(find.text('Erro de criação $status'), findsOneWidget);
        expect(find.textContaining('Card criado em'), findsNothing);
      }

      await tester.tap(find.text('Criar tarefa').last);
      await tester.pump();
      expect(api.drafts.length, 3);
      expect(api.drafts.every((draft) => draft.columnId == expectedColumnId),
          isTrue);
      expect(api.drafts.first.creationKey, isNotNull);
      expect(
          api.drafts.every(
              (draft) => draft.creationKey == api.drafts.first.creationKey),
          isTrue);
      expect(find.byType(ProjectTaskEditorDialog), findsOneWidget);
      api.gates.last.complete();
      await tester.pumpAndSettle();

      expect(find.byType(ProjectTaskEditorDialog), findsNothing);
      expect(
          find.text('Card criado em ${inBacklog ? 'A fazer' : 'Concluído'}.'),
          findsOneWidget);
      final persisted = (await api.getKanbanBoard('project-01'))
          .columns
          .firstWhere((column) => column.id == expectedColumnId)
          .cards;
      expect(persisted.any((card) => card.name == 'Card recuperável'), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('conflicting Backlog edit retains the typed draft for recovery',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1650, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _ConflictEditKanbanApi();
    await tester.pumpWidget(MaterialApp(home: ProjectKanbanPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Detalhes de #1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'),
        'Rascunho que não pode sumir');
    await tester.enterText(find.widgetWithText(TextFormField, 'Descrição'),
        'Detalhe que precisa permanecer');
    await tester.tap(find.text('Salvar').last);
    await tester.pumpAndSettle();
    expect(api.attempts, 1);
    expect(find.text('Rascunho que não pode sumir'), findsOneWidget);
    expect(find.text('Detalhe que precisa permanecer'), findsOneWidget);
    expect(find.textContaining('alterado em outra sessão'), findsWidgets);
    expect(find.text('Card atualizado.'), findsNothing);
  });

  testWidgets('pending Backlog save submits once and preserves draft on 409',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1650, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _DelayedConflictEditKanbanApi();
    await tester.pumpWidget(MaterialApp(home: ProjectKanbanPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Detalhes de #1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome'), 'Rascunho em voo');
    await tester.tap(find.text('Salvar').last);
    await tester.tap(find.text('Salvar').last);
    expect(api.attempts, 1);
    api.pending.completeError(ApiException(
      'Conflito de revisão',
      statusCode: 409,
      code: 'task_version_conflict',
    ));
    await tester.pumpAndSettle();
    expect(api.attempts, 1);
    expect(find.text('Rascunho em voo'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('task-editor-copy-draft')), findsOneWidget);
    expect(find.text('Card atualizado.'), findsNothing);
  });
  testWidgets('pending Backlog edit cannot discard or modify draft before 409',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1650, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _DelayedConflictEditKanbanApi();
    await tester.pumpWidget(MaterialApp(home: ProjectKanbanPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Detalhes de #1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar').last);
    await tester.pumpAndSettle();
    final nameField = find.widgetWithText(TextFormField, 'Nome');
    await tester.enterText(nameField, 'Rascunho enviado ao servidor');
    await tester.tap(find.text('Salvar').last);
    await tester.pump();
    expect(api.attempts, 1);
    expect(
        tester
            .widget<TextField>(find.descendant(
              of: nameField,
              matching: find.byType(TextField),
            ))
            .readOnly,
        isTrue);
    await tester.tap(find.text('Cancelar').last);
    await tester.pump();
    expect(find.byType(ProjectTaskEditorDialog), findsOneWidget);
    await tester.tap(find.byTooltip('Fechar').last);
    await tester.pump();
    expect(find.byType(ProjectTaskEditorDialog), findsOneWidget);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(find.byType(ProjectTaskEditorDialog), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(ProjectTaskEditorDialog), findsOneWidget);
    expect(find.text('Rascunho enviado ao servidor'), findsOneWidget);
    api.pending.completeError(ApiException('Conflito de revisão',
        statusCode: 409, code: 'task_version_conflict'));
    await tester.pumpAndSettle();
    expect(find.text('Rascunho enviado ao servidor'), findsOneWidget);
    expect(
        find.byKey(const ValueKey('task-editor-copy-draft')), findsOneWidget);
    await tester.tap(find.text('Cancelar').last);
    await tester.pumpAndSettle();
    expect(find.byType(ProjectTaskEditorDialog), findsNothing);
  });
  testWidgets('successful pending Backlog edit closes after server response',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1650, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _DelayedConflictEditKanbanApi();
    await tester.pumpWidget(MaterialApp(home: ProjectKanbanPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Detalhes de #1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Nome'),
        'Edição confirmada pelo servidor');
    await tester.tap(find.text('Salvar').last);
    await tester.pump();
    expect(find.byType(ProjectTaskEditorDialog), findsOneWidget);
    api.pending.complete((await api.listTasks('project-01')).first);
    await tester.pumpAndSettle();
    expect(find.byType(ProjectTaskEditorDialog), findsNothing);
    expect(find.text('Card atualizado.'), findsOneWidget);
  });
  test('fake API invalidates old reordering versions after task CRUD',
      () async {
    final api = _FakeKanbanApi(columnCount: 2);
    const projectId = 'project-01';
    final created = await api.createTask(
        projectId,
        const TaskDraft(
          name: 'Nova tarefa',
          description: 'Teste de versão',
          type: TaskType.feature,
          columnId: 'column-01',
        ));
    expect(api.boardVersion, 2);
    await expectLater(
      api.reorderKanbanCards(projectId, expectedVersion: 1, columnTaskIds: {
        'column-01': ['task-01', created.id],
      }),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 409)),
    );
    await api.updateTask(
        projectId,
        created.id,
        const TaskDraft(
          name: 'Atualizada',
          description: 'Versão seguinte',
          type: TaskType.feature,
        ));
    expect(api.boardVersion, 3);
    await api.addKanbanAssignee(projectId, created.id, 'emp-01');
    expect(api.boardVersion, 4);
    await api.removeKanbanAssignee(projectId, created.id, 'emp-01');
    expect(api.boardVersion, 5);
    await api.deleteTask(projectId, created.id);
    expect(api.boardVersion, 6);
    expect(
        (await api.getKanbanBoard(projectId))
            .columns
            .first
            .cards
            .map((card) => card.id),
        ['task-01']);
  });

  test('fake API persists created and reordered columns across reads',
      () async {
    final api = _FakeKanbanApi();
    final created = await api.createKanbanColumn('project-01',
        name: 'Em revisão', expectedVersion: 1);
    expect(created.columns.map((column) => column.name),
        ['A fazer', 'Em revisão']);
    final newId = created.columns.last.id;
    await api.reorderKanbanColumns('project-01',
        expectedVersion: 2, columnIds: [newId, created.columns.first.id]);
    final reloaded = await api.getKanbanBoard('project-01');
    expect(reloaded.kanbanVersion, 3);
    expect(reloaded.columns.map((column) => column.id),
        [newId, created.columns.first.id]);
    expect(reloaded.columns.first.name, 'Em revisão');
  });

  testWidgets('non-member employee cannot reorder or edit cards in Backlog',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1700, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: ProjectKanbanPage(api: _OutsiderKanbanApi()),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Mover #2 para cima no Kanban'), findsNothing);
    expect(find.byTooltip('Editar #1'), findsNothing);
    expect(find.byTooltip('Responsáveis de #1'), findsNothing);
    expect(find.text('Novo card'), findsNothing);
    await tester.tap(find.byTooltip('Detalhes de #1'));
    await tester.pumpAndSettle();
    expect(find.text('Editar'), findsNothing);
    expect(
        tester
            .widget<WorkspaceInstantSelectField<String>>(
              find.byKey(const ValueKey('card-dialog-status')),
            )
            .onChanged,
        isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      '409 reorder conflict shows refreshed board without success toast',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeKanbanApi(cardsPerColumn: 3);
    await tester.pumpWidget(MaterialApp(home: ProjectKanbanPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    api.boardVersion += 1; // A different session changed the board.
    await tester.tap(find.byTooltip('Mover #2 para cima no Kanban'));
    await tester.pumpAndSettle();
    expect(find.textContaining('outra sessão'), findsWidgets);
    expect(find.text('Card movido.'), findsNothing);
    expect(api.lastCardOrdering, isNull);
    expect(find.text('#1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'employee views shared card modal without protected edit controls',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: ProjectKanbanPage(api: _EmployeeKanbanApi())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Detalhes de #1'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectTaskEditorDialog), findsOneWidget);
    expect(find.text('Editar'), findsNothing);
    expect(find.text('Salvar'), findsNothing);
    expect(
        tester
            .widgetList<TextField>(find.descendant(
                of: find.byType(ProjectTaskEditorDialog),
                matching: find.byType(TextField)))
            .every((field) => field.readOnly),
        isTrue);
    expect(
        tester
            .widget<WorkspaceInstantSelectField<String>>(
                find.byKey(const ValueKey('card-dialog-status')))
            .onChanged,
        isNotNull);
  });

  testWidgets(
      'explicit card editing saves through the shared API and keeps identity',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeKanbanApi();
    await tester.pumpWidget(MaterialApp(home: ProjectKanbanPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Detalhes de #1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Título atualizado');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(api.updatedDrafts.keys.toList(), <String>['task-01']);
    expect(find.text('Título atualizado'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    await tester.tap(find.text('Kanban').last);
    await tester.pumpAndSettle();
    expect(find.text('Título atualizado'), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'Backlog reorders through versioned API and survives switching and reloading',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeKanbanApi(columnCount: 2, cardsPerColumn: 3);
    await tester.pumpWidget(MaterialApp(home: ProjectKanbanPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('backlog-status-task-01')))
            .data,
        'A fazer');
    await tester.tap(find.byTooltip('Mover #2 para cima no Kanban'));
    await tester.pumpAndSettle();

    expect(api.lastExpectedCardVersion, 1);
    expect(api.boardVersion, 2);
    expect(api.lastCardOrdering?['column-01'],
        <String>['task-1-2', 'task-01', 'task-1-3']);
    expect(find.text('#2'), findsOneWidget);

    await tester.tap(find.text('Kanban').last);
    await tester.pumpAndSettle();
    var cards = tester
        .widget<ProjectKanbanBoard>(find.byType(ProjectKanbanBoard))
        .board
        .columns
        .first
        .cards;
    expect(
        cards.map((card) => (card.id, card.cardNumber, card.kanbanPosition)),
        <(String, int, int)>[
          ('task-1-2', 2, 0),
          ('task-01', 1, 1),
          ('task-1-3', 3, 2),
        ]);

    await tester.tap(find.byTooltip('Atualizar quadro'));
    await tester.pumpAndSettle();
    cards = tester
        .widget<ProjectKanbanBoard>(find.byType(ProjectKanbanBoard))
        .board
        .columns
        .first
        .cards;
    expect(cards.first.id, 'task-1-2');

    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(
        table.rows.first.key, const ValueKey<String>('backlog-card-task-1-2'));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'status changed from Backlog appears in Kanban and remains after reload',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeKanbanApi(columnCount: 2);
    await tester.pumpWidget(MaterialApp(home: ProjectKanbanPage(api: api)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Detalhes de #1'));
    await tester.pumpAndSettle();
    final status = find.byKey(const ValueKey('card-dialog-status'));
    await tester.ensureVisible(status);
    await tester.tap(status);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Concluído').last);
    await tester.pumpAndSettle();
    expect(api.lastCardOrdering?['column-02'], contains('task-01'));
    expect(api.lastExpectedCardVersion, 1);

    await tester.tap(find.text('Fechar').last);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('backlog-status-task-01')))
            .data,
        'Concluído');

    await tester.tap(find.text('Kanban').last);
    await tester.pumpAndSettle();
    var columns = tester
        .widget<ProjectKanbanBoard>(find.byType(ProjectKanbanBoard))
        .board
        .columns;
    expect(columns.first.cards, isEmpty);
    expect(columns.last.cards.any((card) => card.id == 'task-01'), isTrue);
    expect(
        columns.last.cards
            .firstWhere((card) => card.id == 'task-01')
            .cardNumber,
        1);

    await tester.tap(find.byTooltip('Atualizar quadro'));
    await tester.pumpAndSettle();
    columns = tester
        .widget<ProjectKanbanBoard>(find.byType(ProjectKanbanBoard))
        .board
        .columns;
    expect(columns.last.cards.any((card) => card.id == 'task-01'), isTrue);
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('backlog-status-task-01')))
            .data,
        'Concluído');
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kanban movement updates Backlog without changing card identity',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeKanbanApi(columnCount: 2);
    await tester.pumpWidget(MaterialApp(home: ProjectKanbanPage(api: api)));
    await tester.pumpAndSettle();

    final kanban =
        tester.widget<ProjectKanbanBoard>(find.byType(ProjectKanbanBoard));
    await kanban.onMoveCard('task-01', 'column-02', 1);
    await tester.pumpAndSettle();
    expect(api.lastExpectedCardVersion, 1);

    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<Text>(find.byKey(const ValueKey('backlog-status-task-01')))
            .data,
        'Concluído');
    expect(find.text('#1'), findsOneWidget);
    expect(find.byTooltip('Detalhes de #1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Backlog creates, assigns, deletes and retains card-number gaps',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeKanbanApi();
    await tester.pumpWidget(MaterialApp(home: ProjectKanbanPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Novo card'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Nova entrega');
    await tester.enterText(
        find.byType(TextFormField).last, 'Criada pelo Backlog');
    await tester.tap(find.text('Criar tarefa'));
    await tester.pumpAndSettle();
    expect(find.text('Nova entrega'), findsOneWidget);
    expect(find.text('#2'), findsOneWidget);

    await tester.tap(find.byTooltip('Responsáveis de #2'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(CheckboxListTile, 'Gestor TouchIn'));
    await tester.pumpAndSettle();
    expect(find.text('Gestor TouchIn'), findsOneWidget);

    await tester.tap(find.text('Kanban').last);
    await tester.pumpAndSettle();
    final cards = tester
        .widget<ProjectKanbanBoard>(find.byType(ProjectKanbanBoard))
        .board
        .columns
        .first
        .cards;
    expect(cards.last.id, 'created-1');
    expect(cards.last.cardNumber, 2);
    expect(cards.last.assignees.single.employeeId, 'emp-01');

    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Detalhes de #2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Nova entrega revisada');
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();
    expect(find.text('Nova entrega revisada'), findsOneWidget);
    expect(api.updatedDrafts['created-1']?.name, 'Nova entrega revisada');

    await tester.tap(find.text('Kanban').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Atualizar quadro'));
    await tester.pumpAndSettle();
    final editedCard = tester
        .widget<ProjectKanbanBoard>(find.byType(ProjectKanbanBoard))
        .board
        .columns
        .first
        .cards
        .last;
    expect(editedCard.id, 'created-1');
    expect(editedCard.name, 'Nova entrega revisada');
    expect(editedCard.cardNumber, 2);

    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Excluir #2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Excluir').last);
    await tester.pumpAndSettle();
    expect(find.text('Nova entrega revisada'), findsNothing);

    await tester.tap(find.text('Novo card'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byType(TextFormField).first, 'Entrega seguinte');
    await tester.enterText(
        find.byType(TextFormField).last, 'Número sem reutilização');
    await tester.tap(find.text('Criar tarefa'));
    await tester.pumpAndSettle();
    expect(find.text('#2'), findsNothing);
    expect(find.text('#3'), findsOneWidget);
    await tester.tap(find.text('Kanban').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Atualizar quadro'));
    await tester.pumpAndSettle();
    final reloadedCards = tester
        .widget<ProjectKanbanBoard>(find.byType(ProjectKanbanBoard))
        .board
        .columns
        .first
        .cards;
    expect(reloadedCards.map((card) => (card.id, card.cardNumber)),
        <(String, int)>[('task-01', 1), ('created-2', 3)]);
    expect(tester.takeException(), isNull);
  });

  for (final status in <int>[403, 409]) {
    testWidgets(
        'status failure $status reports feedback without unhandled errors',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1600, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
          MaterialApp(home: ProjectKanbanPage(api: _FailedMoveApi(status))));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Backlog'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Detalhes de #1'));
      await tester.pumpAndSettle();
      final select = find.byKey(const ValueKey('card-dialog-status'));
      await tester.ensureVisible(select);
      await tester.pumpAndSettle();
      await tester.tap(select);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Concluído').last);
      await tester.pumpAndSettle();
      expect(find.textContaining('Movimento rejeitado'), findsOneWidget);
      expect(find.text('Status do card atualizado.'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'column creation closes safely and sends exactly one versioned request',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeKanbanApi();
    await tester.pumpWidget(MaterialApp(home: ProjectKanbanPage(api: api)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Novo status'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '  Em revisão  ');
    await tester.tap(find.text('Criar coluna'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(api.createdColumnNames, <String>['Em revisão']);
    expect(api.boardVersion, 2);
    await tester.tap(find.text('Novo status'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    await tester.pumpAndSettle();
    expect(api.createdColumnNames.length, 1);
  });

  testWidgets(
      'card details reuse the Kanban editor and require explicit edit activation',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1600, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
        MaterialApp(home: ProjectKanbanPage(api: _FakeKanbanApi())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Detalhes de #1'));
    await tester.pumpAndSettle();
    expect(find.byType(ProjectTaskEditorDialog), findsOneWidget);
    expect(find.byType(WorkspaceEditorDialog), findsOneWidget);
    expect(
        tester
            .widgetList<TextField>(find.descendant(
                of: find.byType(ProjectTaskEditorDialog),
                matching: find.byType(TextField)))
            .every((field) => field.readOnly),
        isTrue);
    await tester.tap(find.text('Editar'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widgetList<TextField>(find.descendant(
                of: find.byType(ProjectTaskEditorDialog),
                matching: find.byType(TextField)))
            .every((field) => !field.readOnly),
        isTrue);
    expect(find.text('Salvar'), findsOneWidget);
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Responsáveis de #1'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceEditorDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders Backlog for the selected project', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: ProjectKanbanPage(api: _FakeKanbanApi())),
    );
    await tester.pumpAndSettle();

    final overview = find.byKey(
      const ValueKey<String>('kanban-project-overview'),
    );
    final viewSwitch = find.descendant(
      of: overview,
      matching: find.byType(ToggleButtons),
    );
    expect(viewSwitch, findsOneWidget);
    expect(
      tester.widget<ToggleButtons>(viewSwitch).borderRadius,
      BorderRadius.zero,
    );

    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();

    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Implementar tela'), findsOneWidget);
    expect(find.text('Descrição da tarefa'), findsOneWidget);
    expect(find.text('A fazer'), findsOneWidget);
    expect(find.text('Projeto principal'), findsWidgets);
    expect(find.textContaining('Criado'), findsOneWidget);
    expect(find.textContaining('Atualizado'), findsWidgets);
    await tester.tap(find.text('Gerenciar colunas'));
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceEditorDialog), findsOneWidget);
    expect(find.byTooltip('Renomear status'), findsOneWidget);
    await tester.tap(find.text('Fechar').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'builds Kanban without redundant page titles and keeps board bounded', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectKanbanPage(api: _FakeKanbanApi(includeCard: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(AppBar), findsNothing);
    final topBar = find.byKey(const ValueKey<String>('kanban-topbar'));
    expect(
      topBar,
      findsNothing,
      reason: 'desktop_kanban_topbar_hidden',
    );
    expect(find.text('Kanban do projeto'), findsNothing);
    expect(
      find.text('Acompanhe e mova os cards do projeto selecionado.'),
      findsNothing,
    );
    expect(find.byType(ProjectKanbanBoard), findsOneWidget);
    expect(find.text('A fazer'), findsOneWidget);
    expect(find.text('Nenhum card nesta coluna'), findsOneWidget);

    final overviewRect = tester.getRect(
      find.byKey(const ValueKey<String>('kanban-project-overview')),
    );
    final boardRect = tester.getRect(find.byType(ProjectKanbanBoard));

    expect(overviewRect.height, lessThan(80));
    expect(boardRect.top, greaterThan(overviewRect.bottom));
    expect(boardRect.width, greaterThan(0));
    expect(boardRect.height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets('shows static board skeletons while the project snapshot loads', (
    tester,
  ) async {
    final boardGate = Completer<void>();
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: ProjectKanbanPage(
          api: _FakeKanbanApi(boardGate: boardGate),
        ),
      ),
    );

    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('kanban-board-skeleton')),
      findsOneWidget,
    );
    expect(find.byType(ProjectKanbanBoard), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    boardGate.complete();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('kanban-board-skeleton')),
      findsNothing,
    );
    expect(find.byType(ProjectKanbanBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'intrinsic layout regression keeps the board on finite flex constraints',
      (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: ProjectKanbanPage(api: _FakeKanbanApi(includeCard: false)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProjectKanbanBoard), findsOneWidget);

    final boardRect = tester.getRect(find.byType(ProjectKanbanBoard));
    expect(boardRect.width, greaterThan(0));
    expect(boardRect.height, greaterThan(0));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'production theme keeps the board header button finitely constrained', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: ProjectKanbanPage(api: _FakeKanbanApi(includeCard: false)),
      ),
    );
    await tester.pumpAndSettle();

    final createColumn = find.widgetWithText(FilledButton, 'Coluna');
    expect(createColumn, findsOneWidget);
    expect(tester.getRect(createColumn).width, greaterThan(0));
    expect(tester.getRect(createColumn).width, lessThan(300));
    expect(tester.takeException(), isNull);
  });

  testWidgets('presents compact project context and board guidance', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: ProjectKanbanPage(api: _FakeKanbanApi()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Kanban do projeto'), findsNothing);
    expect(find.text('PROJETO ATUAL'), findsNothing);
    expect(find.text('Colunas'), findsOneWidget);
    expect(find.text('Cards'), findsOneWidget);
    expect(find.text('Equipe'), findsOneWidget);
    expect(find.byTooltip('Atualizar quadro'), findsOneWidget);
    final metrics = find.byKey(
      const ValueKey<String>('kanban-project-metrics'),
    );
    expect(metrics, findsOneWidget);
    expect(tester.getRect(metrics).height, 52);
    final overview = find.byKey(
      const ValueKey<String>('kanban-project-overview'),
    );
    final viewSwitch = find.descendant(
      of: overview,
      matching: find.byKey(const ValueKey<String>('project-view-switch')),
    );
    final projectSelector = find.descendant(
      of: overview,
      matching: find.byType(WorkspaceInstantSelectField<String>),
    );
    expect(tester.getSize(viewSwitch).height, 52);
    expect(tester.getSize(projectSelector).height, 52);
    expect(find.text('Quadro'), findsOneWidget);
    expect(find.text('v1'), findsNothing);
    expect(
      find.text('Arraste pelo ícone para mover cards entre etapas.'),
      findsNothing,
    );
    expect(find.text('Feature'), findsOneWidget);
    expect(find.text('Adicionar card'), findsOneWidget);
    expect(find.text('Sem responsáveis'), findsOneWidget);
    expect(overview, findsOneWidget);
    expect(tester.getRect(overview).height, lessThan(80));
    expect(tester.takeException(), isNull);
  });

  testWidgets('kanban toolbar shares the surface and 48-pixel control height', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ProjectKanbanPage(api: _FakeKanbanApi(columnCount: 2)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      tester.getSize(find.byTooltip('Atualizar quadro')).height,
      52,
      reason: 'workspace_overview_control_height',
    );
    final toolbar = find.byKey(const ValueKey<String>('kanban-board-toolbar'));
    expect(toolbar, findsOneWidget, reason: 'workspace_toolbar_shared_surface');
    final toolbarMaterial = tester.widget<Material>(toolbar);
    expect(toolbarMaterial.color, AppTheme.darkTheme.colorScheme.surface);
    final toolbarPadding = tester.widget<Padding>(
      find
          .descendant(
            of: toolbar,
            matching: find.byType(Padding),
          )
          .first,
    );
    expect(toolbarPadding.padding, const EdgeInsets.all(12));

    for (final tooltip in <String>[
      'Ver colunas anteriores',
      'Ver próximas colunas',
    ]) {
      expect(tester.getSize(find.byTooltip(tooltip)).height, 48);
    }
    final createColumn = find.ancestor(
      of: find.text('Coluna'),
      matching: find.byType(FilledButton),
    );
    expect(tester.getSize(createColumn).height, 48);
    expect(tester.takeException(), isNull);
  });

  testWidgets('project overview controls match at compact and desktop widths',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final size in <Size>[const Size(360, 800), const Size(1440, 900)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ProjectKanbanPage(api: _FakeKanbanApi()),
        ),
      );
      await tester.pumpAndSettle();

      for (final control in <Finder>[
        find.byType(WorkspaceInstantSelectField<String>),
        find.byKey(const ValueKey<String>('project-view-switch')),
        find.byKey(const ValueKey<String>('kanban-project-metrics')),
        find.byTooltip('Atualizar quadro'),
      ]) {
        expect(
          tester.getSize(control).height,
          52,
          reason: 'workspace_overview_control_height at $size',
        );
      }
      expect(
        tester
            .widget<WorkspaceInstantSelectField<String>>(
              find.byType(WorkspaceInstantSelectField<String>),
            )
            .decoration
            .constraints
            ?.minHeight,
        52,
        reason: 'workspace_overview_control_height at $size',
      );
      expect(
        tester
            .widget<WorkspaceInstantSelectField<String>>(
              find.byType(WorkspaceInstantSelectField<String>),
            )
            .decoration
            .constraints
            ?.maxHeight,
        52,
        reason: 'workspace_overview_control_height at $size',
      );
      expect(
        tester
            .getSize(find
                .descendant(
                  of: find.byType(WorkspaceInstantSelectField<String>),
                  matching: find.byType(InputDecorator),
                )
                .first)
            .height,
        52,
        reason: 'workspace_overview_control_height at $size',
      );

      final viewSwitch = tester.widget<ToggleButtons>(
        find.byKey(const ValueKey<String>('project-view-switch')),
      );
      expect(
        viewSwitch.constraints!.minWidth,
        size.width < 980 ? 48 : 94,
        reason: 'workspace_overview_control_width at $size',
      );
      if (size.width >= 980) {
        final metricCellWidth = (tester
                    .getSize(find.byKey(const ValueKey<String>(
                      'kanban-project-metrics',
                    )))
                    .width -
                2) /
            3;
        expect(
          (tester
                          .getSize(find.byKey(const ValueKey<String>(
                            'project-view-switch',
                          )))
                          .width /
                      2 -
                  metricCellWidth)
              .abs(),
          lessThanOrEqualTo(2),
          reason: 'workspace_overview_control_width at $size',
        );
      }

      final metricWidths = <double>[
        for (final label in <String>['Colunas', 'Cards', 'Equipe'])
          tester
              .getSize(find
                  .ancestor(
                    of: find.text(label),
                    matching: find.byType(Row),
                  )
                  .first)
              .width,
      ];
      expect(
        metricWidths.reduce((a, b) => a > b ? a : b) -
            metricWidths.reduce((a, b) => a < b ? a : b),
        lessThanOrEqualTo(1),
        reason: 'workspace_overview_control_height at $size',
      );
      expect(tester.takeException(), isNull, reason: 'viewport $size');
    }
  });

  testWidgets('Kanban primary action matches Backlog toolbar style',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ProjectKanbanPage(api: _FakeKanbanApi(columnCount: 2)),
      ),
    );
    await tester.pumpAndSettle();

    final projectSelector =
        find.byType(WorkspaceInstantSelectField<String>).first;
    final projectSelectorWidget =
        tester.widget<WorkspaceInstantSelectField<String>>(projectSelector);
    expect(
      projectSelectorWidget.decoration.isDense ?? false,
      isFalse,
      reason: 'workspace_overview_control_height',
    );
    final projectSelectorBorder = find.descendant(
      of: projectSelector,
      matching: find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.foregroundPainter != null,
      ),
    );
    expect(
      tester.getSize(projectSelectorBorder.first).height,
      52,
      reason: 'workspace_overview_control_height',
    );

    final kanbanButton = find.widgetWithText(FilledButton, 'Coluna');
    final kanbanWidget = tester.widget<FilledButton>(kanbanButton);
    final kanbanStyle = kanbanWidget.style!;
    final kanbanMaterial = tester.widget<Material>(find
        .descendant(
          of: kanbanButton,
          matching: find.byType(Material),
        )
        .first);
    final kanbanTextStyle = tester
        .element(find.text('Coluna'))
        .getInheritedWidgetOfExactType<DefaultTextStyle>()!
        .style;
    final kanbanIconSize = tester
        .widget<Icon>(find
            .descendant(
              of: kanbanButton,
              matching: find.byType(Icon),
            )
            .first)
        .size;

    await tester.tap(find.text('Backlog'));
    await tester.pumpAndSettle();
    final backlogButton = find.widgetWithText(FilledButton, 'Novo card');
    final backlogWidget = tester.widget<FilledButton>(backlogButton);
    final backlogStyle = backlogWidget.style!;
    final backlogMaterial = tester.widget<Material>(find
        .descendant(
          of: backlogButton,
          matching: find.byType(Material),
        )
        .first);
    final backlogTextStyle = tester
        .element(find.text('Novo card'))
        .getInheritedWidgetOfExactType<DefaultTextStyle>()!
        .style;
    final backlogIconSize = tester
        .widget<Icon>(find
            .descendant(
              of: backlogButton,
              matching: find.byType(Icon),
            )
            .first)
        .size;

    final searchField = tester.widget<TextField>(
      find.byKey(const ValueKey<String>('backlog-search')),
    );
    expect(
      searchField.decoration?.isDense ?? false,
      isFalse,
      reason: 'workspace_search_control_height',
    );

    for (final key in <String>[
      'backlog-search',
      'backlog-status-filter',
      'backlog-assignee-filter',
      'backlog-sort',
    ]) {
      final paintedBorder = find.descendant(
        of: find.byKey(ValueKey<String>(key)),
        matching: find.byWidgetPredicate(
          (widget) => widget is CustomPaint && widget.foregroundPainter != null,
        ),
      );
      expect(
        tester.getSize(paintedBorder.first).height,
        48,
        reason: 'workspace_search_control_height',
      );
    }

    expect(kanbanMaterial.color, backlogMaterial.color,
        reason: 'workspace_toolbar_button_style');
    expect(kanbanTextStyle, backlogTextStyle,
        reason: 'workspace_toolbar_button_style');
    expect(kanbanStyle.minimumSize?.resolve(const <WidgetState>{}),
        backlogStyle.minimumSize?.resolve(const <WidgetState>{}),
        reason: 'workspace_toolbar_button_style');
    expect(kanbanStyle.padding?.resolve(const <WidgetState>{}),
        backlogStyle.padding?.resolve(const <WidgetState>{}),
        reason: 'workspace_toolbar_button_style');
    expect(kanbanIconSize, backlogIconSize,
        reason: 'workspace_toolbar_button_style');
  });

  testWidgets('accepted board updates preserve horizontal and lane scroll', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(720, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _FakeKanbanApi(columnCount: 5, cardsPerColumn: 8);

    await tester.pumpWidget(
      MaterialApp(home: ProjectKanbanPage(api: api)),
    );
    await tester.pumpAndSettle();

    const boardScrollKey = ValueKey<String>('kanban-board-scroll');
    await tester.drag(find.byKey(boardScrollKey), const Offset(-360, 0));
    await tester.pumpAndSettle();
    final boardOffsetBefore = _scrollOffset(tester, boardScrollKey);
    expect(boardOffsetBefore, greaterThan(0));

    const laneScrollKey = ValueKey<String>(
      'kanban-column-scroll-column-02',
    );
    final laneScroll = find.byKey(laneScrollKey);
    await tester.drag(laneScroll, const Offset(0, -360));
    await tester.pumpAndSettle();
    final laneOffsetBefore = _scrollOffset(tester, laneScrollKey);
    expect(laneOffsetBefore, greaterThan(0));

    await tester.tap(find.byTooltip('Opções da coluna').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover para a direita'));
    await tester.pumpAndSettle();

    expect(api.lastColumnOrdering, isNotNull);
    expect(api.boardVersion, 2);
    expect(_scrollOffset(tester, boardScrollKey), boardOffsetBefore);
    expect(_scrollOffset(tester, laneScrollKey), laneOffsetBefore);
    expect(tester.takeException(), isNull);
  });

  testWidgets('column editor reuses the workspace editor dialog',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: ProjectKanbanPage(api: _FakeKanbanApi()),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Coluna'));
    await tester.pumpAndSettle();

    expect(find.byType(WorkspaceEditorDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Nova coluna'), findsOneWidget);
    expect(find.text('Crie uma nova etapa para organizar o fluxo.'),
        findsOneWidget);
    final nameField = tester.widget<InputDecorator>(
      find.byWidgetPredicate(
        (widget) =>
            widget is InputDecorator &&
            widget.decoration.labelText == 'Nome da coluna',
      ),
    );
    expect(nameField.decoration.prefixIcon, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reconstructed page stays bounded on a narrow viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: ProjectKanbanPage(api: _FakeKanbanApi())),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProjectKanbanBoard), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'mobile Kanban toolbar keeps heading and actions in one scrollable row',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final size in <Size>[const Size(320, 568), const Size(360, 800)]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: ProjectKanbanPage(api: _FakeKanbanApi(columnCount: 2)),
        ),
      );
      await tester.pumpAndSettle();

      final toolbar =
          find.byKey(const ValueKey<String>('kanban-board-toolbar'));
      final scrollView = find.descendant(
        of: toolbar,
        matching: find.byWidgetPredicate(
          (widget) =>
              widget is SingleChildScrollView &&
              widget.scrollDirection == Axis.horizontal,
        ),
      );
      expect(scrollView, findsOneWidget,
          reason: 'kanban_mobile_toolbar_single_row');
      final heading = find.descendant(
        of: scrollView,
        matching: find.text('Quadro'),
      );
      expect(heading, findsOneWidget,
          reason: 'kanban_mobile_toolbar_single_row');

      for (final action in <Finder>[
        find.byTooltip('Ver colunas anteriores'),
        find.byTooltip('Ver próximas colunas'),
        find.widgetWithText(FilledButton, 'Coluna'),
      ]) {
        final actionScrollView = find.ancestor(
          of: action,
          matching: find.byWidgetPredicate(
            (widget) =>
                widget is SingleChildScrollView &&
                widget.scrollDirection == Axis.horizontal,
          ),
        );
        expect(action, findsOneWidget,
            reason: 'kanban_mobile_toolbar_single_row');
        expect(actionScrollView, findsOneWidget,
            reason: 'kanban_mobile_toolbar_single_row');
        expect(
          (tester.getCenter(heading).dy - tester.getCenter(action).dy).abs(),
          lessThanOrEqualTo(1),
          reason: 'kanban_mobile_toolbar_single_row',
        );
      }
      expect(tester.takeException(), isNull, reason: 'viewport $size');
    }
  });

  testWidgets(
      'mobile Kanban toolbar aligns title left and actions right when they fit',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    const size = Size(390, 844);
    await tester.binding.setSurfaceSize(size);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: ProjectKanbanPage(api: _FakeKanbanApi(columnCount: 2)),
      ),
    );
    await tester.pumpAndSettle();

    final toolbar = find.byKey(const ValueKey<String>('kanban-board-toolbar'));
    final scrollView = find.descendant(
      of: toolbar,
      matching: find.byWidgetPredicate(
        (widget) =>
            widget is SingleChildScrollView &&
            widget.scrollDirection == Axis.horizontal,
      ),
    );
    final title = find.descendant(
      of: scrollView,
      matching: find.text('Quadro'),
    );
    final createAction = find.widgetWithText(FilledButton, 'Coluna');
    expect(scrollView, findsOneWidget,
        reason: 'kanban_mobile_toolbar_right_alignment');
    expect(title, findsOneWidget,
        reason: 'kanban_mobile_toolbar_right_alignment');
    expect(createAction, findsOneWidget,
        reason: 'kanban_mobile_toolbar_right_alignment');

    final toolbarBounds = tester.getRect(scrollView);
    expect(
      tester.getRect(title).left,
      closeTo(toolbarBounds.left, 1),
      reason: 'kanban_mobile_toolbar_right_alignment',
    );
    expect(
      tester.getRect(createAction).right,
      closeTo(toolbarBounds.right, 1),
      reason: 'kanban_mobile_toolbar_right_alignment',
    );
    expect(tester.takeException(), isNull, reason: 'viewport $size');
  });

  testWidgets('compact cards and responsive chrome remain bounded',
      (tester) async {
    for (final size in <Size>[
      const Size(320, 568),
      const Size(360, 800),
      const Size(390, 844),
      const Size(768, 1024),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeMode.dark,
          home: ProjectKanbanPage(api: _FakeKanbanApi()),
        ),
      );
      await tester.pumpAndSettle();

      final board = find.byType(ProjectKanbanBoard);
      final card = find.byKey(const ValueKey<String>('kanban-card-task-01'));
      expect(board, findsOneWidget);
      expect(card, findsOneWidget);
      expect(tester.getRect(board).width, lessThanOrEqualTo(size.width));
      expect(tester.getRect(card).height, lessThanOrEqualTo(144));
      expect(find.text('Atualizado'), findsNothing);
      expect(find.text('Sincronizado'), findsNothing,
          reason: 'kanban_idle_sync_badge');
      expect(tester.takeException(), isNull, reason: 'viewport $size');
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('keeps the static chrome outside controller-driven rebuilds', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(home: ProjectKanbanPage(api: _FakeKanbanApi())),
    );
    await tester.pumpAndSettle();

    final topBar = find.byKey(const ValueKey<String>('kanban-topbar'));
    expect(topBar, findsNothing);
    expect(find.text('TOUCHIN'), findsOneWidget);
    expect(find.descendant(of: topBar, matching: find.text('Kanban')),
        findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('instant menus and compact column actions stay responsive', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: ThemeMode.dark,
        home: ProjectKanbanPage(api: _FakeKanbanApi()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey<String>('kanban-topbar')), findsNothing);
    expect(find.text('Sincronizado'), findsNothing);
    expect(find.text('Arraste pelo ícone para mover cards entre etapas.'),
        findsNothing);
    expect(find.byTooltip('Adicionar card em A fazer'), findsOneWidget);

    final counter = find.byKey(
      const ValueKey<String>('kanban-column-count-column-01'),
    );
    expect(counter, findsOneWidget);
    final counterRect = tester.getRect(counter);
    expect(counterRect.width, 22);
    expect(counterRect.height, 22);

    final board = find.byType(ProjectKanbanBoard);
    final popupMenus = tester.widgetList<PopupMenuButton<String>>(
      find.descendant(
          of: board, matching: find.byType(PopupMenuButton<String>)),
    );
    expect(popupMenus, isNotEmpty);
    expect(
      popupMenus.every(
        (menu) => menu.popUpAnimationStyle == AnimationStyle.noAnimation,
      ),
      isTrue,
    );

    final projectSelect = find.byType(WorkspaceInstantSelectField<String>);
    expect(projectSelect, findsOneWidget);
    await tester.tap(projectSelect);
    await tester.pump();
    expect(find.byType(PopupMenuItem<String>), findsWidgets);
    await tester.tapAt(const Offset(2, 2));
    await tester.pump();

    await tester.tap(find.byTooltip('Adicionar card em A fazer'));
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<TaskType>), findsNothing);
    expect(find.byType(WorkspaceInstantSelectField<TaskType>), findsOneWidget);
    expect(find.byType(WorkspaceInstantSelectField<String>), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(Dialog),
        matching: find.byType(WorkspaceInstantSelectField<String>),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('page loading keeps the workspace shell and renders skeletons', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final api = _DelayedProjectsKanbanApi();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        home: ProjectKanbanPage(api: api),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('kanban-page-skeleton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('workspace-desktop-destinations')),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);

    api.projectsGate.complete();
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey<String>('kanban-page-skeleton')),
      findsNothing,
    );
    expect(find.byType(ProjectKanbanBoard), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _DelayedProjectsKanbanApi extends _FakeKanbanApi {
  final Completer<void> projectsGate = Completer<void>();

  @override
  Future<List<ProjectSummary>> listProjects({ProjectStatus? status}) async {
    await projectsGate.future;
    return super.listProjects(status: status);
  }
}

class _FakeKanbanApi extends TouchInApi {
  _FakeKanbanApi({
    this.includeCard = true,
    this.boardGate,
    this.columnCount = 1,
    this.cardsPerColumn = 1,
  });

  final bool includeCard;
  final Completer<void>? boardGate;
  final int columnCount;
  final int cardsPerColumn;
  int boardVersion = 1;
  List<String>? lastColumnOrdering;
  final List<String> createdColumnNames = <String>[];
  List<String>? _persistedColumnIds;
  final Map<String, TaskDraft> updatedDrafts = <String, TaskDraft>{};
  final Map<String, List<String>> _cardOrdering = <String, List<String>>{};
  final Map<String, TaskRecord> _createdTasks = <String, TaskRecord>{};
  final Set<String> _deletedTasks = <String>{};
  final Map<String, Set<String>> _assigneesByCard = <String, Set<String>>{};
  int _createdCount = 0;
  Map<String, List<String>>? lastCardOrdering;
  int? lastExpectedCardVersion;

  @override
  Future<TaskRecord> createTask(String projectId, TaskDraft draft) async {
    _createdCount += 1;
    final taskId = 'created-$_createdCount';
    final columnId = draft.columnId ?? _columnId(0);
    final task = TaskRecord(
      id: taskId,
      projectId: projectId,
      parentTaskId: draft.parentTaskId,
      cardNumber: columnCount * cardsPerColumn + _createdCount,
      kanbanColumnId: columnId,
      kanbanPosition: _cardsForColumn(projectId, columnId).length,
      name: draft.name,
      description: draft.description,
      type: draft.type,
      createdAt: DateTime(2026, 10, 12),
      updatedAt: DateTime(2026, 10, 12),
    );
    _createdTasks[taskId] = task;
    _cardOrdering
        .putIfAbsent(columnId, () => _defaultCardIds(columnId))
        .add(taskId);
    boardVersion += 1;
    return task;
  }

  @override
  Future<void> deleteTask(String projectId, String taskId) async {
    _deletedTasks.add(taskId);
    _createdTasks.remove(taskId);
    for (final cardIds in _cardOrdering.values) {
      cardIds.remove(taskId);
    }
    boardVersion += 1;
  }

  @override
  Future<KanbanCard> addKanbanAssignee(
      String projectId, String taskId, String employeeId) async {
    if (!_assigneesByCard
        .putIfAbsent(taskId, () => <String>{})
        .add(employeeId)) {
      throw ApiException('Responsável já adicionado', statusCode: 409);
    }
    boardVersion += 1;
    return _findCard(projectId, taskId);
  }

  @override
  Future<KanbanCard> removeKanbanAssignee(
      String projectId, String taskId, String employeeId) async {
    if (_assigneesByCard[taskId]?.remove(employeeId) == true) {
      boardVersion += 1;
    }
    return _findCard(projectId, taskId);
  }

  KanbanCard _findCard(String projectId, String taskId) =>
      _buildBoard(projectId)
          .columns
          .expand((column) => column.cards)
          .firstWhere((card) => card.id == taskId);

  @override
  Future<TaskRecord> updateTask(
      String projectId, String taskId, TaskDraft draft,
      {DateTime? expectedUpdatedAt, int? expectedRevision}) async {
    final old =
        (await listTasks(projectId)).firstWhere((task) => task.id == taskId);
    updatedDrafts[taskId] = draft;
    final updated = TaskRecord(
        id: old.id,
        projectId: old.projectId,
        parentTaskId: draft.parentTaskId,
        cardNumber: old.cardNumber,
        kanbanColumnId: old.kanbanColumnId,
        kanbanPosition: old.kanbanPosition,
        name: draft.name,
        description: draft.description,
        type: draft.type,
        createdAt: old.createdAt,
        updatedAt: DateTime(2026, 10, 11));
    if (_createdTasks.containsKey(taskId)) {
      _createdTasks[taskId] = updated;
    }
    boardVersion += 1;
    return updated;
  }

  @override
  Future<KanbanBoard> createKanbanColumn(
    String projectId, {
    required String name,
    required int expectedVersion,
  }) async {
    if (expectedVersion != boardVersion) {
      throw ApiException(
        'Kanban version conflict: expected $expectedVersion, current $boardVersion.',
        statusCode: 409,
        code: 'kanban_version_conflict',
      );
    }
    createdColumnNames.add(name);
    _persistedColumnIds ??= [
      for (var index = 0; index < columnCount; index++) _columnId(index)
    ];
    _persistedColumnIds!
        .add(_columnId(columnCount + createdColumnNames.length - 1));
    boardVersion += 1;
    return _buildBoard(projectId);
  }

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
        email: 'gestor@touchin.com',
        role: 'manager',
        employeeId: 'emp-01',
      ),
    );
  }

  @override
  Future<List<ProjectSummary>> listProjects({ProjectStatus? status}) async {
    return <ProjectSummary>[
      ProjectSummary(
        id: 'project-01',
        name: 'Projeto principal',
        description: 'Projeto usado pelo Kanban',
        taskEmployeeLimit: 3,
        status: ProjectStatus.active,
        createdAt: DateTime(2026, 9, 9),
        updatedAt: DateTime(2026, 9, 9),
      ),
    ];
  }

  @override
  Future<List<ProjectMemberSummary>> listProjectMembers(
      String projectId) async {
    return <ProjectMemberSummary>[
      ProjectMemberSummary(
        employeeId: 'emp-01',
        projectId: projectId,
        employeeName: 'Gestor TouchIn',
        createdAt: DateTime(2026, 9, 9),
      ),
    ];
  }

  @override
  Future<List<TaskRecord>> listTasks(String projectId) async {
    return _buildBoard(projectId).taskRecords;
  }

  @override
  Future<KanbanBoard> getKanbanBoard(String projectId) async {
    if (boardGate != null) {
      await boardGate!.future;
    }
    return _buildBoard(projectId);
  }

  @override
  Future<KanbanBoard> reorderKanbanColumns(
    String projectId, {
    required int expectedVersion,
    required List<String> columnIds,
  }) async {
    if (expectedVersion != boardVersion) {
      throw ApiException(
        'Kanban version conflict: expected $expectedVersion, current $boardVersion.',
        statusCode: 409,
        code: 'kanban_version_conflict',
      );
    }
    final existing =
        _buildBoard(projectId).columns.map((column) => column.id).toSet();
    if (columnIds.length != existing.length ||
        columnIds.toSet().length != existing.length ||
        !columnIds.toSet().containsAll(existing)) {
      throw ApiException('Ordem de colunas inválida', statusCode: 400);
    }
    _persistedColumnIds = List<String>.of(columnIds);
    boardVersion += 1;
    lastColumnOrdering = List<String>.from(columnIds);
    return _buildBoard(projectId);
  }

  @override
  Future<KanbanBoard> reorderKanbanCards(
    String projectId, {
    required int expectedVersion,
    required Map<String, List<String>> columnTaskIds,
  }) async {
    if (expectedVersion != boardVersion) {
      throw ApiException(
        'Kanban version conflict: expected $expectedVersion, current $boardVersion.',
        statusCode: 409,
        code: 'kanban_version_conflict',
      );
    }
    final affectedColumns = _buildBoard(projectId)
        .columns
        .where((column) => columnTaskIds.containsKey(column.id))
        .toList();
    final expectedIds = affectedColumns
        .expand((column) => column.cards)
        .map((card) => card.id)
        .toSet();
    final requestedIds = columnTaskIds.values.expand((ids) => ids).toList();
    if (affectedColumns.length != columnTaskIds.length ||
        requestedIds.length != requestedIds.toSet().length ||
        requestedIds.toSet().length != expectedIds.length ||
        !requestedIds.toSet().containsAll(expectedIds)) {
      throw ApiException('Ordem de cards inválida', statusCode: 400);
    }
    lastExpectedCardVersion = expectedVersion;
    lastCardOrdering = <String, List<String>>{
      for (final entry in columnTaskIds.entries)
        entry.key: List<String>.of(entry.value),
    };
    for (final entry in columnTaskIds.entries) {
      _cardOrdering[entry.key] = List<String>.of(entry.value);
    }
    boardVersion += 1;
    return _buildBoard(projectId);
  }

  KanbanBoard _buildBoard(String projectId, {List<String>? columnIds}) {
    final orderedColumnIds = columnIds ??
        _persistedColumnIds ??
        <String>[
          for (var index = 0; index < columnCount; index++) _columnId(index),
        ];
    return KanbanBoard(
      projectId: projectId,
      kanbanVersion: boardVersion,
      columns: <KanbanColumn>[
        for (var position = 0; position < orderedColumnIds.length; position++)
          KanbanColumn(
            id: orderedColumnIds[position],
            projectId: projectId,
            name: _columnName(_columnIndex(orderedColumnIds[position])),
            position: position,
            cards: includeCard
                ? _cardsForColumn(projectId, orderedColumnIds[position])
                : <KanbanCard>[],
            createdAt: DateTime(2026, 9, 9),
            updatedAt: DateTime(2026, 9, 9),
          ),
      ],
    );
  }

  List<KanbanCard> _cardsForColumn(String projectId, String columnId) {
    final cardIds = _cardOrdering[columnId] ?? _defaultCardIds(columnId);
    return <KanbanCard>[
      for (var position = 0; position < cardIds.length; position++)
        _makeCard(projectId, columnId, cardIds[position], position),
    ];
  }

  List<String> _defaultCardIds(String columnId) => <String>[
        for (var index = 0;
            index < (_columnIndex(columnId) < columnCount ? cardsPerColumn : 0);
            index++)
          if (!_deletedTasks.contains(_cardId(_columnIndex(columnId), index)))
            _cardId(_columnIndex(columnId), index),
      ];

  KanbanCard _makeCard(
      String projectId, String columnId, String cardId, int position) {
    final created = _createdTasks[cardId];
    if (created != null) {
      return KanbanCard(
        id: cardId,
        projectId: projectId,
        parentTaskId: created.parentTaskId,
        cardNumber: created.cardNumber,
        kanbanColumnId: columnId,
        kanbanPosition: position,
        name: created.name,
        description: created.description,
        type: created.type,
        assignees: _cardAssignees(cardId),
        createdAt: created.createdAt,
        updatedAt: created.updatedAt,
      );
    }
    final parts = cardId.split('-');
    final originalColumn = cardId == 'task-01' ? 0 : int.parse(parts[1]) - 1;
    final originalPosition = cardId == 'task-01' ? 0 : int.parse(parts[2]) - 1;
    return KanbanCard(
      id: cardId,
      projectId: projectId,
      parentTaskId: null,
      cardNumber: originalColumn * cardsPerColumn + originalPosition + 1,
      kanbanColumnId: columnId,
      kanbanPosition: position,
      name: _cardName(originalColumn, originalPosition),
      description: updatedDrafts[cardId]?.description ?? 'Descrição da tarefa',
      type: updatedDrafts[cardId]?.type ?? TaskType.feature,
      assignees: _cardAssignees(cardId),
      createdAt: DateTime(2026, 9, 9),
      updatedAt: DateTime(2026, 9, 9),
    );
  }

  List<TaskMemberSummary> _cardAssignees(String cardId) => <TaskMemberSummary>[
        for (final employeeId in _assigneesByCard[cardId] ?? <String>{})
          TaskMemberSummary(
            employeeId: employeeId,
            taskId: cardId,
            employeeName:
                employeeId == 'emp-01' ? 'Gestor TouchIn' : employeeId,
            createdAt: DateTime(2026, 10, 12),
          ),
      ];

  String _columnId(int index) =>
      'column-${(index + 1).toString().padLeft(2, '0')}';

  int _columnIndex(String id) => int.parse(id.split('-').last) - 1;

  String _columnName(int index) {
    if (index >= columnCount &&
        index - columnCount < createdColumnNames.length) {
      return createdColumnNames[index - columnCount];
    }
    if (index == 0) {
      return 'A fazer';
    }
    if (index == 1) {
      return 'Concluído';
    }
    return 'Etapa ${index + 1}';
  }

  String _cardId(int columnIndex, int cardIndex) {
    if (columnIndex == 0 && cardIndex == 0) {
      return 'task-01';
    }
    return 'task-${columnIndex + 1}-${cardIndex + 1}';
  }

  String _cardName(int columnIndex, int cardIndex) {
    final draft = updatedDrafts[_cardId(columnIndex, cardIndex)];
    if (draft != null) return draft.name;
    if (columnIndex == 0 && cardIndex == 0) {
      return 'Implementar tela';
    }
    return 'Card ${columnIndex * cardsPerColumn + cardIndex + 1}';
  }
}

double _scrollOffset(WidgetTester tester, Key scrollViewKey) {
  final scrollable = find
      .descendant(
        of: find.byKey(scrollViewKey),
        matching: find.byType(Scrollable),
      )
      .first;
  return tester.state<ScrollableState>(scrollable).position.pixels;
}

class _DelayedCreateKanbanApi extends _FakeKanbanApi {
  _DelayedCreateKanbanApi() : super(columnCount: 2);

  final List<TaskDraft> drafts = <TaskDraft>[];
  final List<Completer<void>> gates = <Completer<void>>[];

  @override
  Future<TaskRecord> createTask(String projectId, TaskDraft draft) async {
    drafts.add(draft);
    final gate = Completer<void>();
    gates.add(gate);
    await gate.future;
    return super.createTask(projectId, draft);
  }
}

class _EmployeeKanbanApi extends _FakeKanbanApi {
  @override
  Future<AuthContext> getAuthContext() async {
    final auth = await super.getAuthContext();
    return AuthContext(
        company: auth.company,
        user: const AuthUserSummary(
            id: 'user-employee',
            email: 'employee@example.test',
            role: 'employee',
            employeeId: 'emp-01'));
  }
}

class _OutsiderKanbanApi extends _FakeKanbanApi {
  _OutsiderKanbanApi() : super(cardsPerColumn: 3);

  @override
  Future<AuthContext> getAuthContext() async {
    final auth = await super.getAuthContext();
    return AuthContext(
      company: auth.company,
      user: const AuthUserSummary(
        id: 'user-external',
        email: 'external@example.test',
        role: 'employee',
        employeeId: 'emp-not-member',
      ),
    );
  }
}

class _ConflictEditKanbanApi extends _FakeKanbanApi {
  int attempts = 0;

  @override
  Future<TaskRecord> updateTask(
      String projectId, String taskId, TaskDraft draft,
      {DateTime? expectedUpdatedAt, int? expectedRevision}) async {
    attempts++;
    throw ApiException('Este card foi alterado em outra sessão.',
        statusCode: 409, code: 'task_version_conflict');
  }
}

class _DelayedConflictEditKanbanApi extends _FakeKanbanApi {
  final Completer<TaskRecord> pending = Completer<TaskRecord>();
  int attempts = 0;

  @override
  Future<TaskRecord> updateTask(
      String projectId, String taskId, TaskDraft draft,
      {DateTime? expectedUpdatedAt, int? expectedRevision}) {
    attempts++;
    return pending.future;
  }
}

class _FailedMoveApi extends _FakeKanbanApi {
  _FailedMoveApi(this.status) : super(columnCount: 2);
  final int status;
  @override
  Future<KanbanBoard> reorderKanbanCards(
    String projectId, {
    required int expectedVersion,
    required Map<String, List<String>> columnTaskIds,
  }) async =>
      throw ApiException('Movimento rejeitado', statusCode: status);
}
