import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/project_kanban_board.dart';

void main() {
  testWidgets('uses native slivers and no legacy drag/reorder primitives', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    String? movedTaskId;
    String? movedColumnId;
    int? movedIndex;

    await tester.pumpWidget(
      _host(
        _board(),
        onMoveCard: (taskId, columnId, index) async {
          movedTaskId = taskId;
          movedColumnId = columnId;
          movedIndex = index;
        },
      ),
    );

    final handle = find.byIcon(Icons.drag_indicator_rounded);
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

  testWidgets('column reorder action reports the column identity', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

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

Widget _host(
  KanbanBoard board, {
  Future<void> Function(String taskId, String columnId, int index)? onMoveCard,
  Future<void> Function(String columnId, int index)? onMoveColumn,
}) {
  return MaterialApp(
    home: Scaffold(
      body: SizedBox.expand(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ProjectKanbanBoard(
            board: board,
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

KanbanBoard _board() {
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

  return KanbanBoard(
    projectId: 'project-01',
    kanbanVersion: 4,
    columns: <KanbanColumn>[
      KanbanColumn(
        id: 'column-a',
        projectId: 'project-01',
        name: 'A fazer',
        position: 0,
        cards: <KanbanCard>[card],
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
