import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/project_backlog_view.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_instant_select_field.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

void main() {
  testWidgets('production themes keep backlog controls compact and responsive',
      (tester) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    for (final theme in <ThemeData>[AppTheme.darkTheme, AppTheme.lightTheme]) {
      for (final size in <Size>[
        const Size(1440, 900),
        const Size(768, 800),
        const Size(360, 800),
      ]) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: ProjectBacklogView(
              board: _board(),
              projectName: 'Projeto Alpha',
              projectMembers: const <ProjectMemberSummary>[],
              canManageStructure: true,
              canManageCards: true,
              canManageAssignees: true,
              canMoveCards: true,
              isBusy: false,
              onManageColumns: () {},
              onCreateColumn: () {},
              onCreateCard: (_) {},
              onMoveCard: (_, __, ___) {},
              onEditCard: (_) {},
              onDeleteCard: (_) {},
              onManageAssignees: (_) {},
              onOpenDetails: (_) {},
            ),
          ),
        ));
        await tester.pumpAndSettle();
        for (final label in <String>[
          'Gerenciar colunas', 'Novo status', 'Novo card',
        ]) {
          final button = find.ancestor(
            of: find.text(label),
            matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
          );
          expect(tester.getSize(button).width, lessThan(210));
          expect(tester.getSize(button).height, lessThanOrEqualTo(40));
          expect(tester.getRect(button).top,
              tester.getRect(find.byKey(const ValueKey('backlog-search'))).top);
        }
        expect(find.byType(WorkspaceInstantSelectField<String>), findsNWidgets(3));
        for (final key in <String>[
          'backlog-status-filter',
          'backlog-assignee-filter',
          'backlog-sort',
        ]) {
          final field = find.byKey(ValueKey<String>(key));
          expect(tester.getSize(field).height, 40);
          final select = tester.widget<WorkspaceInstantSelectField<String>>(field);
          expect(select.decoration.labelText, isNull);
          expect(select.decoration.prefixIcon, isNotNull);
          expect(select.semanticLabel, isNotEmpty);
          expect(tester.getRect(field).top,
              tester.getRect(find.byKey(const ValueKey('backlog-search'))).top);
        }
        expect(tester.getSize(find.byKey(const ValueKey('backlog-table'))).width,
            greaterThanOrEqualTo(size.width - 2));
        if (size.width >= 1440) {
          final toolbar = tester.getRect(find.byKey(const ValueKey('backlog-toolbar')));
          final lastAction = tester.getRect(find.ancestor(
            of: find.text('Novo card'), matching: find.byType(FilledButton),
          ));
          expect(lastAction.right, greaterThan(toolbar.right - 24));
        }
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('shows searchable cards and filters by number and status', (
    tester,
  ) async {
    final board = _board();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectBacklogView(
            board: board,
            projectName: 'Projeto Alpha',
            projectMembers: <ProjectMemberSummary>[
              ProjectMemberSummary(
                employeeId: 'emp-1',
                projectId: 'project-1',
                employeeName: 'Ana Souza',
                createdAt: DateTime(2026, 1, 1),
              ),
            ],
            canManageStructure: false,
            canManageCards: false,
            canManageAssignees: false,
            canMoveCards: false,
            isBusy: false,
            onManageColumns: () {},
            onCreateColumn: () {},
            onCreateCard: (_) {},
            onMoveCard: (_, __, ___) {},
            onEditCard: (_) {},
            onDeleteCard: (_) {},
            onManageAssignees: (_) {},
            onOpenDetails: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Preparar proposta'), findsOneWidget);
    expect(find.text('Descrição detalhada'), findsOneWidget);
    final table = tester.widget<DataTable>(find.byType(DataTable));
    expect(table.columns.where((column) => column.label is Text &&
        (column.label as Text).data == 'Status'), isEmpty);
    expect(find.text('Projeto: Projeto Alpha'), findsNWidgets(2));
    expect(find.text('Ana Souza'), findsOneWidget);
    expect(find.byTooltip('Editar #1'), findsNothing);
    expect(find.byTooltip('Excluir #1'), findsNothing);

    await tester.enterText(
      find.byKey(const ValueKey('backlog-search')),
      'proposta',
    );
    await tester.pumpAndSettle();
    expect(find.text('Preparar proposta'), findsOneWidget);
    expect(find.text('Corrigir defeito'), findsNothing);
    await tester.enterText(find.byKey(const ValueKey('backlog-search')), '#2');
    await tester.pumpAndSettle();
    expect(find.text('Corrigir defeito'), findsOneWidget);
    expect(find.text('Preparar proposta'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('backlog-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('A fazer').last);
    await tester.pumpAndSettle();
    expect(find.text('Corrigir defeito'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('backlog-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos os status'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('backlog-assignee-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ana Souza').last);
    await tester.pumpAndSettle();
    expect(find.text('Corrigir defeito'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('status changes and detail actions use existing card identities',
      (
    tester,
  ) async {
    String? movedTaskId;
    String? movedColumnId;
    var manageColumnsCalls = 0;
    var createColumnCalls = 0;
    KanbanCard? openedCard;
    final board = _board();

    await tester.binding.setSurfaceSize(const Size(1800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ProjectBacklogView(
            board: board,
            projectName: 'Projeto Alpha',
            projectMembers: const <ProjectMemberSummary>[],
            canManageStructure: true,
            canManageCards: true,
            canManageAssignees: true,
            canMoveCards: true,
            isBusy: false,
            onManageColumns: () => manageColumnsCalls += 1,
            onCreateColumn: () => createColumnCalls += 1,
            onCreateCard: (_) {},
            onMoveCard: (taskId, columnId, _) {
              movedTaskId = taskId;
              movedColumnId = columnId;
            },
            onEditCard: (_) {},
            onDeleteCard: (_) {},
            onManageAssignees: (_) {},
            onOpenDetails: (card) => openedCard = card,
          ),
        ),
      ),
    );

    expect(find.text('Gerenciar colunas'), findsOneWidget);
    expect(find.text('Novo card'), findsOneWidget);
    expect(find.byTooltip('Editar #1'), findsOneWidget);
    expect(find.byTooltip('Excluir #1'), findsOneWidget);
    expect(find.byTooltip('Mover #1 para cima'), findsNothing);
    expect(find.byTooltip('Mover #1 para baixo'), findsNothing);
    await tester.tap(find.text('Novo status'));
    await tester.tap(find.text('Gerenciar colunas'));
    expect(createColumnCalls, 1);
    expect(manageColumnsCalls, 1);
    await tester.tap(find.byTooltip('Detalhes de #1'));
    await tester.pump();
    expect(openedCard?.id, 'task-1');
    expect(openedCard?.cardNumber, 1);

    expect(movedTaskId, isNull);
    expect(movedColumnId, isNull);
  });

  testWidgets('headers filter and sort while children stay below parents', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1800, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProjectBacklogView(
      board: _board(hierarchical: true), projectName: 'Projeto Alpha',
      projectMembers: const <ProjectMemberSummary>[],
      canManageStructure: false, canManageCards: false,
      canManageAssignees: false, canMoveCards: false, isBusy: false,
      onManageColumns: () {}, onCreateColumn: () {}, onCreateCard: (_) {},
      onMoveCard: (_, __, ___) {}, onEditCard: (_) {}, onDeleteCard: (_) {},
      onManageAssignees: (_) {}, onOpenDetails: (_) {},
    ))));
    for (final field in <String>['number', 'title', 'description', 'assignees', 'project', 'created', 'updated']) {
      expect(find.byKey(ValueKey('backlog-header-$field')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('backlog-header-title')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ordenar crescente'));
    await tester.pumpAndSettle();
    final parent = tester.getRect(find.text('Preparar proposta'));
    final child = tester.getRect(find.text('Corrigir defeito'));
    expect(child.top, greaterThan(parent.top));
    expect(child.left, greaterThan(parent.left));
    expect(find.byTooltip('Subtarefa de Preparar proposta'), findsOneWidget);
    final childArrow = tester.getRect(
      find.byKey(const ValueKey('hierarchy-indicator-task-2')),
    );
    final grandchildArrow = tester.getRect(
      find.byKey(const ValueKey('hierarchy-indicator-task-3')),
    );
    expect(find.byTooltip('Subtarefa de Corrigir defeito'), findsOneWidget);
    expect(grandchildArrow.left, greaterThan(childArrow.left));
    expect(grandchildArrow.top, greaterThan(childArrow.top));
    await tester.tap(find.byKey(const ValueKey('backlog-header-description')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Filtrar coluna'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'formulário');
    await tester.tap(find.text('Aplicar filtro'));
    await tester.pumpAndSettle();
    expect(find.text('Corrigir defeito'), findsOneWidget);
    expect(find.text('Preparar proposta'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

KanbanBoard _board({bool hierarchical = false}) {
  final first = KanbanCard(
    id: 'task-1',
    projectId: 'project-1',
    parentTaskId: null,
    cardNumber: 1,
    kanbanColumnId: 'column-1',
    kanbanPosition: 0,
    name: 'Preparar proposta',
    description: 'Descrição detalhada',
    type: TaskType.feature,
    assignees: <TaskMemberSummary>[
      TaskMemberSummary(
        employeeId: 'emp-1',
        taskId: 'task-1',
        employeeName: 'Ana Souza',
        createdAt: DateTime(2026, 1, 2),
      ),
    ],
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 3),
  );
  final second = KanbanCard(
    id: 'task-2',
    projectId: 'project-1',
    parentTaskId: hierarchical ? 'task-1' : null,
    cardNumber: 2,
    kanbanColumnId: 'column-2',
    kanbanPosition: 0,
    name: 'Corrigir defeito',
    description: 'Falha no formulário',
    type: TaskType.bug,
    assignees: const <TaskMemberSummary>[],
    createdAt: DateTime(2026, 1, 4),
    updatedAt: DateTime(2026, 1, 5),
  );
  final third = KanbanCard(
    id: 'task-3',
    projectId: 'project-1',
    parentTaskId: 'task-2',
    cardNumber: 3,
    kanbanColumnId: 'column-2',
    kanbanPosition: 1,
    name: 'Revisar subtarefa',
    description: 'Detalhe da subtarefa',
    type: TaskType.improvement,
    assignees: const <TaskMemberSummary>[],
    createdAt: DateTime(2026, 1, 6),
    updatedAt: DateTime(2026, 1, 6),
  );
  return KanbanBoard(
    projectId: 'project-1',
    kanbanVersion: 0,
    columns: <KanbanColumn>[
      KanbanColumn(
        id: 'column-1',
        projectId: 'project-1',
        name: 'A fazer',
        position: 0,
        cards: <KanbanCard>[first],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      KanbanColumn(
        id: 'column-2',
        projectId: 'project-1',
        name: 'Em andamento',
        position: 1,
        cards: hierarchical ? <KanbanCard>[second, third] : <KanbanCard>[second],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ],
  );
}
