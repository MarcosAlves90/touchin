import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/projects/presentation/project_kanban_page.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/project_kanban_board.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_editor_dialog.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_instant_select_field.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

void main() {
  testWidgets('builds Kanban without redundant page titles and keeps board bounded', (
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
    expect(topBar, findsOneWidget);
    expect(find.descendant(of: topBar, matching: find.text('Kanban')), findsNothing);
    expect(
      find.descendant(of: topBar, matching: find.text('Projeto principal')),
      findsNothing,
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

  testWidgets('intrinsic layout regression keeps the board on finite flex constraints', (
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

  testWidgets('production theme keeps the board header button finitely constrained', (
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
    expect(tester.getRect(metrics).height, 48);
    expect(find.text('Quadro'), findsOneWidget);
    expect(find.text('v1'), findsNothing);
    expect(
      find.text('Arraste pelo ícone para mover cards entre etapas.'),
      findsNothing,
    );
    expect(find.text('Feature'), findsOneWidget);
    expect(find.text('Adicionar card'), findsOneWidget);
    expect(find.text('Sem responsáveis'), findsOneWidget);
    final overview = find.byKey(
      const ValueKey<String>('kanban-project-overview'),
    );
    expect(overview, findsOneWidget);
    expect(tester.getRect(overview).height, lessThan(80));
    expect(tester.takeException(), isNull);
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

  testWidgets('column editor reuses the workspace editor dialog', (tester) async {
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
    expect(find.text('Crie uma nova etapa para organizar o fluxo.'), findsOneWidget);
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
  testWidgets('compact cards and responsive chrome remain bounded', (tester) async {
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
      expect(find.text('Sincronizado'), findsOneWidget);
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
    expect(topBar, findsOneWidget);
    expect(find.descendant(of: topBar, matching: find.text('TOUCHIN')), findsOneWidget);
    expect(find.descendant(of: topBar, matching: find.text('Kanban')), findsNothing);
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

    final topBar = find.byKey(const ValueKey<String>('kanban-topbar'));
    expect(
      find.descendant(of: topBar, matching: find.text('Sincronizado')),
      findsOneWidget,
    );
    expect(find.text('Arraste pelo ícone para mover cards entre etapas.'), findsNothing);
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
      find.descendant(of: board, matching: find.byType(PopupMenuButton<String>)),
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
  Future<List<ProjectMemberSummary>> listProjectMembers(String projectId) async {
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
    if (!includeCard) {
      return <TaskRecord>[];
    }
    return <TaskRecord>[
      for (var columnIndex = 0; columnIndex < columnCount; columnIndex++)
        for (var cardIndex = 0; cardIndex < cardsPerColumn; cardIndex++)
          TaskRecord(
            id: _cardId(columnIndex, cardIndex),
            projectId: projectId,
            parentTaskId: null,
            cardNumber: columnIndex * cardsPerColumn + cardIndex + 1,
            kanbanColumnId: _columnId(columnIndex),
            kanbanPosition: cardIndex,
            name: _cardName(columnIndex, cardIndex),
            description: 'Descrição da tarefa',
            type: TaskType.feature,
            createdAt: DateTime(2026, 9, 9),
            updatedAt: DateTime(2026, 9, 9),
          ),
    ];
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
    boardVersion = expectedVersion + 1;
    lastColumnOrdering = List<String>.from(columnIds);
    return _buildBoard(projectId, columnIds: columnIds);
  }

  KanbanBoard _buildBoard(String projectId, {List<String>? columnIds}) {
    final orderedColumnIds = columnIds ??
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
                ? <KanbanCard>[
                    for (var cardIndex = 0;
                        cardIndex < cardsPerColumn;
                        cardIndex++)
                      KanbanCard(
                        id: _cardId(
                          _columnIndex(orderedColumnIds[position]),
                          cardIndex,
                        ),
                        projectId: projectId,
                        parentTaskId: null,
                        cardNumber: _columnIndex(orderedColumnIds[position]) *
                                cardsPerColumn +
                            cardIndex +
                            1,
                        kanbanColumnId: orderedColumnIds[position],
                        kanbanPosition: cardIndex,
                        name: _cardName(
                          _columnIndex(orderedColumnIds[position]),
                          cardIndex,
                        ),
                        description: 'Descrição da tarefa',
                        type: TaskType.feature,
                        assignees: const <TaskMemberSummary>[],
                        createdAt: DateTime(2026, 9, 9),
                        updatedAt: DateTime(2026, 9, 9),
                      ),
                  ]
                : <KanbanCard>[],
            createdAt: DateTime(2026, 9, 9),
            updatedAt: DateTime(2026, 9, 9),
          ),
      ],
    );
  }

  String _columnId(int index) =>
      'column-${(index + 1).toString().padLeft(2, '0')}';

  int _columnIndex(String id) => int.parse(id.split('-').last) - 1;

  String _columnName(int index) {
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
