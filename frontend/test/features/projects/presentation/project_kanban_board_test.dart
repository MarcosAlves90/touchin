import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/project_kanban_board.dart';

void main() {
  testWidgets('search highlights matching cards without removing board content',
      (tester) async {
    await _setUpBoardSurface(tester);
    await tester.pumpWidget(_host(_board(), matchedCardIds: const {'task-01'}));
    expect(find.byKey(const ValueKey<String>('kanban-column-column-a')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('kanban-card-task-01')),
        findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label == 'Correspondência da busca',
      ),
      findsOneWidget,
    );
    expect(find.text('Encontrado'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kanban card title geometry', (tester) async {
    await _setUpBoardSurface(tester);
    await tester.pumpWidget(_host(_board()));
    final card = find.byKey(const ValueKey<String>('kanban-card-task-01'));
    final title =
        find.descendant(of: card, matching: find.text('Implementar tela'));
    final type = find.descendant(of: card, matching: find.text('Feature'));
    expect(tester.getBottomLeft(title).dy,
        lessThanOrEqualTo(tester.getTopLeft(type).dy),
        reason: 'kanban_card_title_geometry');
    expect(tester.takeException(), isNull);
  });

  testWidgets('kanban redesign surfaces', (tester) async {
    await _setUpBoardSurface(tester);
    await tester.pumpWidget(_host(_board()));
    final lane = tester.widget<AnimatedContainer>(
      find.byKey(const ValueKey<String>('kanban-column-column-a')),
    );
    final card = find.byKey(const ValueKey<String>('kanban-card-task-01'));
    final surface = tester.widget<AnimatedContainer>(find
        .descendant(
          of: card,
          matching: find.byType(AnimatedContainer),
        )
        .first);
    expect((lane.decoration! as BoxDecoration).borderRadius, isNotNull,
        reason: 'kanban_redesign_surfaces lane');
    expect((surface.decoration! as BoxDecoration).borderRadius, isNotNull,
        reason: 'kanban_redesign_surfaces card');
    expect(find.text('Implementar tela'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('kanban cards remain compact and distinct from lanes',
      (tester) async {
    await _setUpBoardSurface(tester);
    await tester.pumpWidget(_host(_board()));
    final laneFinder =
        find.byKey(const ValueKey<String>('kanban-column-column-a'));
    final cardFinder =
        find.byKey(const ValueKey<String>('kanban-card-task-01'));
    final lane = tester.getSize(laneFinder);
    final card = tester.getSize(cardFinder);
    final laneDecoration = tester
        .widget<AnimatedContainer>(laneFinder)
        .decoration! as BoxDecoration;
    final cardDecoration = tester
        .widget<AnimatedContainer>(find
            .descendant(
                of: cardFinder, matching: find.byType(AnimatedContainer))
            .first)
        .decoration! as BoxDecoration;
    expect(lane.width, greaterThan(280));
    expect(card.height, lessThan(145));
    expect(laneDecoration.border, isNotNull);
    expect(cardDecoration.border, isNotNull);
    expect(cardDecoration.color, isNot(laneDecoration.color));
    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Descrição'), findsOneWidget);
    expect(find.byTooltip('Ações do card #1'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('card action menu has a contrasting surface', (tester) async {
    await _setUpBoardSurface(tester);
    await tester.pumpWidget(_host(_board(includeNonmatchingCard: true)));
    final button = tester.widget<PopupMenuButton<String>>(
      find.byWidgetPredicate((widget) =>
          widget is PopupMenuButton<String> &&
          widget.tooltip == 'Ações do card #1'),
    );
    final colors =
        Theme.of(tester.element(find.byType(ProjectKanbanBoard))).colorScheme;
    expect(button.color, colors.surfaceContainerHighest);
    final shape = button.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(10),
        reason: 'kanban_card_menu_radius_10');
    expect(shape.side.color, colors.outlineVariant,
        reason: 'kanban_card_menu_border');
    await tester.tap(find.byTooltip('Ações do card #1'));
    await tester.pumpAndSettle();
    expect(find.text('Editar card'), findsOneWidget);
    final move = find.ancestor(
      of: find.text('Mover card para baixo'),
      matching: find.byType(ListTile),
    );
    expect(
        find.descendant(
            of: move, matching: find.byIcon(Icons.arrow_downward_rounded)),
        findsOneWidget);
  });

  testWidgets('column action menu uses the shared popup surface',
      (tester) async {
    await _setUpBoardSurface(tester);
    await tester.pumpWidget(_host(_board()));
    final button = tester.widget<PopupMenuButton<String>>(
      find
          .byWidgetPredicate((widget) =>
              widget is PopupMenuButton<String> &&
              widget.tooltip == 'Opções da coluna')
          .first,
    );
    final colors =
        Theme.of(tester.element(find.byType(ProjectKanbanBoard))).colorScheme;
    expect(button.color, colors.surfaceContainerHighest,
        reason: 'kanban_column_menu_surface');
    final shape = button.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(10),
        reason: 'kanban_column_menu_radius_10');
    expect(shape.side.color, colors.outlineVariant,
        reason: 'kanban_column_menu_border');
  });

  testWidgets('uses native slivers and no legacy drag/reorder primitives', (
    tester,
  ) async {
    await _setUpBoardSurface(tester);

    await tester.pumpWidget(_host(_board()));

    final board = find.byType(ProjectKanbanBoard);
    expect(board, findsOneWidget);
    expect(
      find.descendant(of: board, matching: find.byType(CustomScrollView)),
      findsWidgets,
    );
    expect(
      find.descendant(of: board, matching: find.byType(SliverFixedExtentList)),
      findsWidgets,
    );
    expect(
      find.descendant(of: board, matching: find.byType(Draggable<KanbanCard>)),
      findsNothing,
    );
    expect(
      find.descendant(of: board, matching: find.byType(DragTarget<KanbanCard>)),
      findsNothing,
    );
    expect(
      find.descendant(of: board, matching: find.byType(ReorderableListView)),
      findsNothing,
    );
    expect(
      find.descendant(of: board, matching: find.byType(ListView)),
      findsNothing,
    );
  });

  testWidgets('raw pointer drag emits a stable card-to-column intent', (
    tester,
  ) async {
    await _setUpBoardSurface(tester);

    String? movedTaskId;
    String? movedColumnId;
    int? movedIndex;

    await tester.pumpWidget(
      _host(
        _board(includeNonmatchingCard: true),
        matchedCardIds: const <String>{'task-01'},
        onMoveCard: (taskId, columnId, index) async {
          movedTaskId = taskId;
          movedColumnId = columnId;
          movedIndex = index;
        },
      ),
    );

    final matchingCard =
        find.byKey(const ValueKey<String>('kanban-card-task-01'));
    final nonmatchingCard =
        find.byKey(const ValueKey<String>('kanban-card-task-02'));
    expect(matchingCard, findsOneWidget);
    expect(nonmatchingCard, findsOneWidget);
    expect(find.byKey(const ValueKey<String>('kanban-column-column-a')),
        findsOneWidget);
    expect(find.byKey(const ValueKey<String>('kanban-column-column-b')),
        findsOneWidget);
    expect(tester.getTopLeft(matchingCard).dy,
        lessThan(tester.getTopLeft(nonmatchingCard).dy));
    final handle = find.descendant(
      of: matchingCard,
      matching: find.byIcon(Icons.drag_indicator_rounded),
    );
    final emptyTarget = find.text('Nenhum card nesta coluna');
    expect(handle, findsOneWidget);
    expect(emptyTarget, findsOneWidget);

    final gesture = await tester.startGesture(tester.getCenter(handle));
    await gesture.moveTo(tester.getCenter(emptyTarget));
    await tester.pump();

    expect(find.text('Solte aqui · posição 1'), findsOneWidget);

    await gesture.up();
    await tester.pump();

    expect(movedTaskId, 'task-01');
    expect(movedColumnId, 'column-b');
    expect(movedIndex, 0);
  });

  testWidgets(
      'same-slot drop with a hidden card between visible cards is a no-op',
      (tester) async {
    await _setUpBoardSurface(tester);

    final moves = <(String, String, int)>[];
    await tester.pumpWidget(
      _host(
        _boardWithHiddenMiddleCard(),
        visibleCardIds: const <String>{'task-a', 'task-b'},
        onMoveCard: (taskId, columnId, index) async {
          moves.add((taskId, columnId, index));
        },
      ),
    );

    final cardA = find.byKey(const ValueKey<String>('kanban-card-task-a'));
    expect(cardA, findsOneWidget);
    expect(
        find.byKey(const ValueKey<String>('kanban-card-task-h')), findsNothing);
    final handle = find.descendant(
      of: cardA,
      matching: find.byIcon(Icons.drag_indicator_rounded),
    );
    final rect = tester.getRect(cardA);

    for (final fraction in <double>[0.25, 0.75]) {
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture
          .moveTo(Offset(rect.center.dx, rect.top + rect.height * fraction));
      await tester.pump();
      expect(find.text('Solte aqui · posição 1'), findsOneWidget);
      expect(find.text('Solte aqui · posição 3'), findsNothing);
      await gesture.up();
      await tester.pump();
    }

    expect(moves, isEmpty, reason: 'filtered_same_slot_drop_must_not_reorder');
  });

  for (final (sourceId, targetId, fraction, expectedIndex)
      in <(String, String, double, int)>[
    ('task-a', 'task-b', 0.75, 3),
    ('task-b', 'task-a', 0.25, 0),
  ]) {
    testWidgets(
        'intentional move from $sourceId toward $targetId keeps its index',
        (tester) async {
      await _setUpBoardSurface(tester);

      final moves = <(String, String, int)>[];
      await tester.pumpWidget(
        _host(
          _boardWithHiddenMiddleCard(),
          visibleCardIds: const <String>{'task-a', 'task-b'},
          onMoveCard: (taskId, columnId, index) async {
            moves.add((taskId, columnId, index));
          },
        ),
      );

      final handle = find.descendant(
        of: find.byKey(ValueKey<String>('kanban-card-$sourceId')),
        matching: find.byIcon(Icons.drag_indicator_rounded),
      );
      final targetRect =
          tester.getRect(find.byKey(ValueKey<String>('kanban-card-$targetId')));
      final gesture = await tester.startGesture(tester.getCenter(handle));
      await gesture.moveTo(Offset(
          targetRect.center.dx, targetRect.top + targetRect.height * fraction));
      await tester.pump();
      await gesture.up();
      await tester.pump();

      expect(moves,
          <(String, String, int)>[(sourceId, 'column-a', expectedIndex)]);
    });
  }

  testWidgets('column reorder action reports the column identity',
      (tester) async {
    await _setUpBoardSurface(tester);

    String? movedColumn;
    int? targetIndex;

    await tester.pumpWidget(
      _host(
        _board(),
        onMoveColumn: (columnId, index) async {
          movedColumn = columnId;
          targetIndex = index;
        },
      ),
    );

    await tester.tap(find.byTooltip('Opções da coluna').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mover para a direita'));
    await tester.pump();

    expect(movedColumn, 'column-a');
    expect(targetIndex, 1);
  });
}

Future<void> _setUpBoardSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(1000, 700));
  addTearDown(() async {
    // Unmount the board while the test binding is still active, disposing its
    // scroll controllers and animation listeners before the shell exits.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.binding.setSurfaceSize(null);
  });
}

Widget _host(
  KanbanBoard board, {
  Future<void> Function(String taskId, String columnId, int index)? onMoveCard,
  Future<void> Function(String columnId, int index)? onMoveColumn,
  Set<String> matchedCardIds = const <String>{},
  Set<String>? visibleCardIds,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ProjectKanbanBoard(
            board: board,
            visibleCardIds: visibleCardIds,
            matchedCardIds: matchedCardIds,
            isBusy: false,
            canMoveCards: true,
            canManageStructure: true,
            canManageCards: true,
            canManageAssignees: true,
            onMoveCard: onMoveCard ?? (_, __, ___) async {},
            onMoveColumn: onMoveColumn ?? (_, __) async {},
            onCreateColumn: () {},
            onRenameColumn: (_) {},
            onDeleteColumn: (_) {},
            onCreateCard: (_) {},
            onEditCard: (_) {},
            onDeleteCard: (_) {},
            onManageAssignees: (_) {},
          ),
        ),
      ),
    ),
  );
}

KanbanBoard _board({bool includeNonmatchingCard = false}) {
  final card = KanbanCard(
    id: 'task-01',
    projectId: 'project-01',
    parentTaskId: null,
    cardNumber: 1,
    kanbanColumnId: 'column-a',
    kanbanPosition: 0,
    name: 'Implementar tela',
    description: 'Descrição',
    type: TaskType.feature,
    assignees: const <TaskMemberSummary>[],
    createdAt: DateTime(2026, 9, 21),
    updatedAt: DateTime(2026, 9, 21),
  );
  final nonmatchingCard = KanbanCard(
    id: 'task-02',
    projectId: 'project-01',
    parentTaskId: null,
    cardNumber: 2,
    kanbanColumnId: 'column-a',
    kanbanPosition: 1,
    name: 'Revisar documentação',
    description: 'Atualizar instruções',
    type: TaskType.bug,
    assignees: const <TaskMemberSummary>[],
    createdAt: DateTime(2026, 9, 21),
    updatedAt: DateTime(2026, 9, 21),
  );

  return KanbanBoard(
    projectId: 'project-01',
    kanbanVersion: 4,
    columns: <KanbanColumn>[
      KanbanColumn(
        id: 'column-a',
        projectId: 'project-01',
        name: 'A fazer',
        position: 0,
        cards: <KanbanCard>[
          card,
          if (includeNonmatchingCard) nonmatchingCard,
        ],
        createdAt: DateTime(2026, 9, 21),
        updatedAt: DateTime(2026, 9, 21),
      ),
      KanbanColumn(
        id: 'column-b',
        projectId: 'project-01',
        name: 'Concluído',
        position: 1,
        cards: const <KanbanCard>[],
        createdAt: DateTime(2026, 9, 21),
        updatedAt: DateTime(2026, 9, 21),
      ),
    ],
  );
}

KanbanBoard _boardWithHiddenMiddleCard() {
  final date = DateTime(2026, 9, 21);
  KanbanCard card(String id, int number, int position, String name) =>
      KanbanCard(
        id: id,
        projectId: 'project-01',
        parentTaskId: null,
        cardNumber: number,
        kanbanColumnId: 'column-a',
        kanbanPosition: position,
        name: name,
        description: 'Descrição',
        type: TaskType.feature,
        assignees: const <TaskMemberSummary>[],
        createdAt: date,
        updatedAt: date,
      );

  return KanbanBoard(
    projectId: 'project-01',
    kanbanVersion: 4,
    columns: <KanbanColumn>[
      KanbanColumn(
        id: 'column-a',
        projectId: 'project-01',
        name: 'A fazer',
        position: 0,
        cards: <KanbanCard>[
          card('task-a', 1, 0, 'Card A'),
          card('task-h', 2, 1, 'Card oculto'),
          card('task-b', 3, 2, 'Card B'),
        ],
        createdAt: date,
        updatedAt: date,
      ),
    ],
  );
}
