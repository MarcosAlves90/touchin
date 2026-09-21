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
          child: board.columns.isEmpty
              ? const Center(child: Text('Nenhuma coluna disponível'))
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      for (var index = 0; index < board.columns.length; index++)
                        Padding(
                          key: ValueKey<String>(
                            'kanban-column-${board.columns[index].id}',
                          ),
                          padding: EdgeInsets.only(
                            right: index == board.columns.length - 1 ? 0 : 16,
                          ),
                          child: SizedBox(
                            width: 320,
                            child: _KanbanColumnPanel(
                              column: board.columns[index],
                              columnIndex: index,
                              columnCount: board.columns.length,
                              isBusy: isBusy,
                              canMoveCards: canMoveCards,
                              canManageStructure: canManageStructure,
                              canManageCards: canManageCards,
                              canManageAssignees: canManageAssignees,
                              onMoveCard: _moveCardToSlot,
                              onReorderColumns: onReorderColumns,
                              onRenameColumn: onRenameColumn,
                              onDeleteColumn: onDeleteColumn,
                              onCreateCard: onCreateCard,
                              onEditCard: onEditCard,
                              onDeleteCard: onDeleteCard,
                              onManageAssignees: onManageAssignees,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Future<void> _moveCardToSlot(
    KanbanCard card,
    KanbanColumn targetColumn,
    int visualSlot,
  ) async {
    var targetIndex = visualSlot;
    if (card.kanbanColumnId == targetColumn.id) {
      final sourceIndex = targetColumn.cards.indexWhere(
        (candidate) => candidate.id == card.id,
      );
      if (sourceIndex < 0) {
        return;
      }
      if (sourceIndex < visualSlot) {
        targetIndex -= 1;
      }
      if (sourceIndex == targetIndex) {
        return;
      }
    }

    await onMoveCard(card.id, targetColumn.id, targetIndex);
  }
}

class _KanbanColumnPanel extends StatelessWidget {
  const _KanbanColumnPanel({
    required this.column,
    required this.columnIndex,
    required this.columnCount,
    required this.isBusy,
    required this.canMoveCards,
    required this.canManageStructure,
    required this.canManageCards,
    required this.canManageAssignees,
    required this.onMoveCard,
    required this.onReorderColumns,
    required this.onRenameColumn,
    required this.onDeleteColumn,
    required this.onCreateCard,
    required this.onEditCard,
    required this.onDeleteCard,
    required this.onManageAssignees,
  });

  final KanbanColumn column;
  final int columnIndex;
  final int columnCount;
  final bool isBusy;
  final bool canMoveCards;
  final bool canManageStructure;
  final bool canManageCards;
  final bool canManageAssignees;
  final Future<void> Function(
    KanbanCard card,
    KanbanColumn targetColumn,
    int visualSlot,
  ) onMoveCard;
  final Future<void> Function(int oldIndex, int newIndex) onReorderColumns;
  final void Function(KanbanColumn column) onRenameColumn;
  final void Function(KanbanColumn column) onDeleteColumn;
  final void Function(KanbanColumn column) onCreateCard;
  final void Function(KanbanCard card) onEditCard;
  final void Function(KanbanCard card) onDeleteCard;
  final void Function(KanbanCard card) onManageAssignees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
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
                if (canManageStructure && columnCount > 1) ...<Widget>[
                  IconButton(
                    tooltip: 'Mover coluna para a esquerda',
                    visualDensity: VisualDensity.compact,
                    onPressed: isBusy || columnIndex == 0
                        ? null
                        : () => onReorderColumns(
                              columnIndex,
                              columnIndex - 1,
                            ),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  IconButton(
                    tooltip: 'Mover coluna para a direita',
                    visualDensity: VisualDensity.compact,
                    onPressed: isBusy || columnIndex == columnCount - 1
                        ? null
                        : () => onReorderColumns(
                              columnIndex,
                              columnIndex + 2,
                            ),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
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
            child: _KanbanCardList(
              column: column,
              isBusy: isBusy,
              canMoveCards: canMoveCards,
              canManageCards: canManageCards,
              canManageAssignees: canManageAssignees,
              onMoveCard: onMoveCard,
              onEditCard: onEditCard,
              onDeleteCard: onDeleteCard,
              onManageAssignees: onManageAssignees,
            ),
          ),
        ],
      ),
    );
  }
}

class _KanbanCardList extends StatelessWidget {
  const _KanbanCardList({
    required this.column,
    required this.isBusy,
    required this.canMoveCards,
    required this.canManageCards,
    required this.canManageAssignees,
    required this.onMoveCard,
    required this.onEditCard,
    required this.onDeleteCard,
    required this.onManageAssignees,
  });

  final KanbanColumn column;
  final bool isBusy;
  final bool canMoveCards;
  final bool canManageCards;
  final bool canManageAssignees;
  final Future<void> Function(
    KanbanCard card,
    KanbanColumn targetColumn,
    int visualSlot,
  ) onMoveCard;
  final void Function(KanbanCard card) onEditCard;
  final void Function(KanbanCard card) onDeleteCard;
  final void Function(KanbanCard card) onManageAssignees;

  @override
  Widget build(BuildContext context) {
    if (column.cards.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(10),
        child: _KanbanDropZone(
          expanded: true,
          enabled: canMoveCards && !isBusy,
          onAccept: (card) => onMoveCard(card, column, 0),
          child: const Center(child: Text('Solte um card aqui')),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(10),
      child: Column(
        children: <Widget>[
          _KanbanDropZone(
            enabled: canMoveCards && !isBusy,
            onAccept: (card) => onMoveCard(card, column, 0),
          ),
          for (var index = 0; index < column.cards.length; index++) ...<Widget>[
            _KanbanCardTile(
              key: ValueKey<String>('kanban-card-${column.cards[index].id}'),
              card: column.cards[index],
              isBusy: isBusy,
              canMove: canMoveCards,
              canManageCards: canManageCards,
              canManageAssignees: canManageAssignees,
              onEdit: () => onEditCard(column.cards[index]),
              onDelete: () => onDeleteCard(column.cards[index]),
              onManageAssignees: () =>
                  onManageAssignees(column.cards[index]),
            ),
            _KanbanDropZone(
              enabled: canMoveCards && !isBusy,
              onAccept: (card) => onMoveCard(card, column, index + 1),
            ),
          ],
        ],
      ),
    );
  }
}

class _KanbanDropZone extends StatelessWidget {
  const _KanbanDropZone({
    required this.enabled,
    required this.onAccept,
    this.expanded = false,
    this.child,
  });

  final bool enabled;
  final Future<void> Function(KanbanCard card) onAccept;
  final bool expanded;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DragTarget<KanbanCard>(
      onWillAccept: enabled ? (card) => card != null : null,
      onAccept: enabled ? (card) => onAccept(card) : null,
      builder: (context, candidates, rejected) {
        final isActive = candidates.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: double.infinity,
          height: expanded ? 112 : (isActive ? 28 : 8),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primaryContainer.withValues(alpha: 0.5)
                : Colors.transparent,
            border: isActive
                ? Border.all(color: colorScheme.primary, width: 1.5)
                : null,
          ),
          child: child,
        );
      },
    );
  }
}

class _KanbanCardTile extends StatelessWidget {
  const _KanbanCardTile({
    super.key,
    required this.card,
    required this.isBusy,
    required this.canMove,
    required this.canManageCards,
    required this.canManageAssignees,
    required this.onEdit,
    required this.onDelete,
    required this.onManageAssignees,
  });

  final KanbanCard card;
  final bool isBusy;
  final bool canMove;
  final bool canManageCards;
  final bool canManageAssignees;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onManageAssignees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
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
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text('#${card.cardNumber} ${card.name}'),
                        ),
                      ),
                    ),
                    childWhenDragging: const Opacity(
                      opacity: 0.35,
                      child: Icon(Icons.open_with, size: 20),
                    ),
                    child: const Tooltip(
                      message: 'Mover card',
                      child: Icon(Icons.open_with, size: 20),
                    ),
                  ),
                if (canManageCards)
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
            if (card.description.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                card.description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
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
  }
}
