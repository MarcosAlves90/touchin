import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/project_kanban_board.dart';

void main() {
  testWidgets('a member can move cards between columns using a focusable menu',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    String? taskId;
    String? targetColumn;
    int? targetIndex;
    await tester.pumpWidget(_boardHost(
      _board(),
      canManageCards: false,
      onMove: (task, column, index) async {
        taskId = task;
        targetColumn = column;
        targetIndex = index;
      },
    ));

    final actions = find.byTooltip('Ações do card #1');
    expect(actions, findsOneWidget);
    expect(
      find.byWidgetPredicate(
        (widget) =>
            widget is Semantics &&
            widget.properties.label ==
                'Arrastar card #1. Para mover com teclado, use ações do card.',
      ),
      findsOneWidget,
    );

    await tester.tap(actions);
    await tester.pumpAndSettle();
    expect(find.text('Editar card'), findsNothing);
    expect(find.text('Excluir card'), findsNothing);
    await tester.tap(find.text('Mover para Concluído'));
    await tester.pump();

    expect(taskId, 'task-1');
    expect(targetColumn, 'done');
    expect(targetIndex, 0);
  });

  testWidgets('menu exposes valid relative move positions and disables at ends',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final moves = <(String, String, int)>[];
    await tester.pumpWidget(_boardHost(
      _board(withSecondCard: true),
      onMove: (task, column, index) async {
        moves.add((task, column, index));
      },
    ));

    await tester.tap(find.byTooltip('Ações do card #1'));
    await tester.pumpAndSettle();
    expect(find.text('Mover card para cima'), findsNothing);
    await tester.tap(find.text('Mover card para baixo'));
    await tester.pumpAndSettle();
    expect(moves.single, ('task-1', 'todo', 2));

    await tester.tap(find.byTooltip('Ações do card #2'));
    await tester.pumpAndSettle();
    expect(find.text('Mover card para baixo'), findsNothing);
    await tester.tap(find.text('Mover card para cima'));
    await tester.pump();
    expect(moves.last, ('task-2', 'todo', 0));
  });

  testWidgets('board actions use accessible 48 pixel targets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_boardHost(
      _board(),
      canManageAssignees: true,
    ));

    for (final tooltip in <String>[
      'Adicionar card em A fazer',
      'Ações do card #1',
      'Gerenciar responsáveis',
    ]) {
      final target = find.byTooltip(tooltip);
      expect(target, findsOneWidget);
      final size = tester.getSize(target);
      expect(size.width, greaterThanOrEqualTo(48),
          reason: 'board_target_minimum_48px');
      expect(size.height, greaterThanOrEqualTo(48),
          reason: 'board_target_minimum_48px');
    }
  });

  testWidgets('non-moving viewer gets no misleading move controls',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_boardHost(
      _board(),
      canMove: false,
      canManageCards: false,
    ));

    expect(find.byIcon(Icons.drag_indicator_rounded), findsNothing);
    expect(find.byTooltip('Ações do card #1'), findsNothing);
  });
}

Widget _boardHost(
  KanbanBoard board, {
  bool canMove = true,
  bool canManageCards = true,
  bool canManageAssignees = false,
  Future<void> Function(String, String, int)? onMove,
}) =>
    MaterialApp(
      home: Scaffold(
        body: SizedBox.expand(
          child: ProjectKanbanBoard(
            board: board,
            isBusy: false,
            canMoveCards: canMove,
            canManageStructure: false,
            canManageCards: canManageCards,
            canManageAssignees: canManageAssignees,
            onMoveCard: onMove ?? (_, __, ___) async {},
            onMoveColumn: (_, __) async {},
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
    );

KanbanBoard _board({bool withSecondCard = false}) {
  final date = DateTime(2026, 9, 21);
  KanbanCard card(int number) => KanbanCard(
        id: 'task-$number',
        projectId: 'project',
        parentTaskId: null,
        cardNumber: number,
        kanbanColumnId: 'todo',
        kanbanPosition: number - 1,
        name: 'Tarefa $number',
        description: 'Descrição da tarefa',
        type: TaskType.feature,
        assignees: const <TaskMemberSummary>[],
        createdAt: date,
        updatedAt: date,
      );
  return KanbanBoard(
    projectId: 'project',
    kanbanVersion: 1,
    columns: [
      KanbanColumn(
        id: 'todo',
        projectId: 'project',
        name: 'A fazer',
        position: 0,
        cards: [card(1), if (withSecondCard) card(2)],
        createdAt: date,
        updatedAt: date,
      ),
      KanbanColumn(
        id: 'done',
        projectId: 'project',
        name: 'Concluído',
        position: 1,
        cards: const <KanbanCard>[],
        createdAt: date,
        updatedAt: date,
      ),
    ],
  );
}
