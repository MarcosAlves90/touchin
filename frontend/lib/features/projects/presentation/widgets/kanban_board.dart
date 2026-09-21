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
        Expanded(
          child: ReorderableListView.builder(
            scrollDirection: Axis.horizontal,
            buildDefaultDragHandles: false,
            itemCount: board.columns.length,
            onReorder: canManageStructure && !isBusy
                ? (oldIndex, newIndex) {
                    onReorderColumns(oldIndex, newIndex);
                  }
                : (_, __) {},
            itemBuilder: (context, columnIndex) {
              final column = board.columns[columnIndex];
              return Padding(
                key: ValueKey<String>('kanban-column-${column.id}'),
                padding: const EdgeInsets.only(right: 16),
                child: SizedBox(
                  width: 320,
                  child: _KanbanColumnPanel(
                    column: column,
                    isBusy: isBusy,
                    canMoveCards: canMoveCards,
                    canManageStructure: canManageStructure,
                    canManageCards: canManageCards,
                    canManageAssignees: canManageAssignees,
                    onMoveCard: onMoveCard,
                    onRenameColumn: onRenameColumn,
                    onDeleteColumn: onDeleteColumn,
                    onCreateCard: onCreateCard,
                    onEditCard: onEditCard,
                    onDeleteCard: onDeleteCard,
                    onManageAssignees: onManageAssignees,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _KanbanColumnPanel extends StatelessWidget {
  const _KanbanColumnPanel({
    required this.column,
    required this.isBusy,
    required this.canMoveCards,
    required this.canManageStructure,
    required this.canManageCards,
    required this.canManageAssignees,
    required this.onMoveCard,
    required this.onRenameColumn,
    required this.onDeleteColumn,
    required this.onCreateCard,
    required this.onEditCard,
    required this.onDeleteCard,
    required this.onManageAssignees,
  });

  final KanbanColumn column;
  final bool isBusy;
  final bool canMoveCards;
  final bool canManageStructure;
  final bool canManageCards;
  final bool canManageAssignees;
  final Future<void> Function(String taskId, String columnId, int index)
      onMoveCard;
  final void Function(KanbanColumn column) onRenameColumn;
  final void Function(KanbanColumn column) onDeleteColumn;
  final void Function(KanbanColumn column) onCreateCard;
  final void Function(KanbanCard card) onEditCard;
  final void Function(KanbanCard card) onDeleteCard;
  final void Function(KanbanCard card) onManageAssignees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DragTarget<KanbanCard>(
      onWillAccept: canMoveCards && !isBusy
          ? (card) => card != null
          : null,
      onAccept: canMoveCards && !isBusy
          ? (card) {
              onMoveCard(card.id, column.id, column.cards.length);
            }
          : null,
      builder: (context, candidates, rejected) {
        return Card(
          clipBehavior: Clip.antiAlias,
          child: Container(
            decoration: candidates.isEmpty
                ? null
                : BoxDecoration(
                    border: Border.all(
                      color: theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
            child: Column(
              children: <Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 8, 10),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '${column.name} (${column.cards.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (canManageCards)
                        IconButton(
                          tooltip: 'Novo card',
                          onPressed: isBusy ? null : () => onCreateCard(column),
                          icon: const Icon(Icons.add_task_outlined),
                        ),
                      if (canManageStructure)
                        PopupMenuButton<String>(
                          enabled: !isBusy,
                          onSelected: (value) {
                            if (value == 'rename') {
                              onRenameColumn(column);
                            } else if (value == 'delete') {
                              onDeleteColumn(column);
                            }
                          },
                          itemBuilder: (_) => const <PopupMenuEntry<String>>[
                            PopupMenuItem(
                              value: 'rename',
                              child: Text('Renomear'),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text('Excluir'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: column.cards.isEmpty
                      ? Center(
                          child: Text(
                            'Solte um card aqui',
                            style: theme.textTheme.bodyMedium,
                          ),
                        )
                      : ReorderableListView.builder(
                          padding: const EdgeInsets.all(10),
                          buildDefaultDragHandles: false,
                          itemCount: column.cards.length,
                          onReorder: canMoveCards && !isBusy
                              ? (oldIndex, newIndex) {
                                  if (newIndex > oldIndex) {
                                    newIndex -= 1;
                                  }
                                  final card = column.cards[oldIndex];
                                  onMoveCard(card.id, column.id, newIndex);
                                }
                              : (_, __) {},
                          itemBuilder: (context, index) {
                            final card = column.cards[index];
                            return _KanbanCardTile(
                              key: ValueKey<String>('kanban-card-${card.id}'),
                              card: card,
                              index: index,
                              isBusy: isBusy,
                              canMove: canMoveCards,
                              canDelete: canManageCards,
                              canManageAssignees: canManageAssignees,
                              onEdit: () => onEditCard(card),
                              onDelete: () => onDeleteCard(card),
                              onManageAssignees: () =>
                                  onManageAssignees(card),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KanbanCardTile extends StatelessWidget {
  const _KanbanCardTile({
    super.key,
    required this.card,
    required this.index,
    required this.isBusy,
    required this.canMove,
    required this.canDelete,
    required this.canManageAssignees,
    required this.onEdit,
    required this.onDelete,
    required this.onManageAssignees,
  });

  final KanbanCard card;
  final int index;
  final bool isBusy;
  final bool canMove;
  final bool canDelete;
  final bool canManageAssignees;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onManageAssignees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  '#${card.cardNumber}',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (canMove && !isBusy)
                  LongPressDraggable<KanbanCard>(
                    data: card,
                    feedback: Material(
                      elevation: 8,
                      child: SizedBox(
                        width: 280,
                        child: Card(
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text('#${card.cardNumber} ${card.name}'),
                          ),
                        ),
                      ),
                    ),
                    child: const Icon(Icons.open_with, size: 20),
                  ),
                if (canMove && !isBusy)
                  ReorderableDragStartListener(
                    index: index,
                    child: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(Icons.drag_handle, size: 20),
                    ),
                  ),
                if (canDelete)
                  PopupMenuButton<String>(
                    enabled: !isBusy,
                    onSelected: (value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (_) => const <PopupMenuEntry<String>>[
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Editar card'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Excluir card'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              card.name,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                for (final assignee in card.assignees)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(assignee.employeeName),
                  ),
                if (canManageAssignees)
                  ActionChip(
                    avatar: const Icon(Icons.group_add_outlined, size: 18),
                    label: const Text('Responsáveis'),
                    onPressed: isBusy ? null : onManageAssignees,
                  ),
              ],
            ),
          ],
        ),
      ),
    );

    return content;
  }
}
