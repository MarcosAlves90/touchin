import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/kanban.dart';

class KanbanBoardView extends StatelessWidget {
  const KanbanBoardView({
    super.key,
    required this.board,
    required this.isBusy,
    required this.canMoveCards,
    required this.canManageStructure,
    required this.canManageCards,
    required this.canManageAssignees,
    required this.onMoveCard,
    required this.onReorderColumns,
    required this.onCreateColumn,
    required this.onRenameColumn,
    required this.onDeleteColumn,
    required this.onCreateCard,
    required this.onEditCard,
    required this.onDeleteCard,
    required this.onManageAssignees,
  });

  final KanbanBoard board;
  final bool isBusy;
  final bool canMoveCards;
  final bool canManageStructure;
  final bool canManageCards;
  final bool canManageAssignees;
  final Future<void> Function(String taskId, String columnId, int index)
      onMoveCard;
  final Future<void> Function(int oldIndex, int newIndex) onReorderColumns;
  final VoidCallback onCreateColumn;
  final void Function(KanbanColumn column) onRenameColumn;
  final void Function(KanbanColumn column) onDeleteColumn;
  final void Function(KanbanColumn column) onCreateCard;
  final void Function(KanbanCard card) onEditCard;
  final void Function(KanbanCard card) onDeleteCard;
  final void Function(KanbanCard card) onManageAssignees;

  @override
  Widget build(BuildContext context) {
    final cardCount = board.columns.fold<int>(
      0,
      (total, column) => total + column.cards.length,
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('KanbanBoardView'),
            Text('Versão: ${board.kanbanVersion}'),
            Text('Colunas: ${board.columns.length}'),
            Text('Cards: $cardCount'),
          ],
        ),
      ),
    );
  }
}
