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
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Kanban',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'v${board.kanbanVersion}',
              style: theme.textTheme.bodySmall,
            ),
            if (canManageStructure) ...<Widget>[
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: isBusy ? null : onCreateColumn,
                icon: const Icon(Icons.add),
                label: const Text('Coluna'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Expanded(child: _buildColumnSurface()),
      ],
    );
  }

  Widget _buildColumnSurface() {
    if (board.columns.length <= 1) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final column in board.columns)
            Expanded(
              child: Align(
                alignment: Alignment.topLeft,
                child: _buildColumnPanel(
                  column,
                  trailingPadding: 0,
                ),
              ),
            ),
        ],
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          for (final column in board.columns) _buildColumnPanel(column),
        ],
      ),
    );
  }

  Widget _buildColumnPanel(
    KanbanColumn column, {
    double trailingPadding = 16,
  }) {
    return Padding(
      key: ValueKey<String>('kanban-column-${column.id}'),
      padding: EdgeInsets.only(right: trailingPadding),
      child: SizedBox(
        width: 320,
        child: Align(
          alignment: Alignment.topLeft,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text('${column.name} (${column.cards.length})'),
          ),
        ),
      ),
    );
  }
}
