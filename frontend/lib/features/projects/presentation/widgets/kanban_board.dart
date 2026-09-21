import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/kanban.dart';

class KanbanBoardView extends StatefulWidget {
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
  State<KanbanBoardView> createState() => _KanbanBoardViewState();
}

class _KanbanBoardViewState extends State<KanbanBoardView> {
  final ScrollController _columnsController = ScrollController();

  @override
  void dispose() {
    _columnsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                'Quadro',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              'v${widget.board.kanbanVersion}',
              style: theme.textTheme.bodySmall,
            ),
            if (widget.canManageStructure) ...<Widget>[
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: widget.isBusy ? null : widget.onCreateColumn,
                icon: const Icon(Icons.add),
                label: const Text('Coluna'),
              ),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Expanded(
          child: widget.board.columns.isEmpty
              ? const Center(child: Text('Nenhuma coluna disponível'))
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final laneWidth = constraints.maxWidth < 360
                        ? constraints.maxWidth
                        : constraints.maxWidth < 760
                            ? 320.0
                            : 340.0;

                    return Scrollbar(
                      controller: _columnsController,
                      thumbVisibility: constraints.maxWidth >= 760,
                      child: ListView.separated(
                        key: const ValueKey<String>('kanban-column-list'),
                        controller: _columnsController,
                        primary: false,
                        scrollDirection: Axis.horizontal,
                        physics: const ClampingScrollPhysics(),
                        itemCount: widget.board.columns.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 12),
                        itemBuilder: (context, index) {
                          final column = widget.board.columns[index];
                          return SizedBox(
                            key: ValueKey<String>('kanban-column-${column.id}'),
                            width: laneWidth,
                            child: _KanbanColumnLane(
                              column: column,
                              columnIndex: index,
                              columnCount: widget.board.columns.length,
                              isBusy: widget.isBusy,
                              canMoveCards: widget.canMoveCards,
                              canManageStructure: widget.canManageStructure,
                              canManageCards: widget.canManageCards,
                              canManageAssignees: widget.canManageAssignees,
                              onMoveCard: _moveCardToSlot,
                              onReorderColumns: widget.onReorderColumns,
                              onRenameColumn: widget.onRenameColumn,
                              onDeleteColumn: widget.onDeleteColumn,
                              onCreateCard: widget.onCreateCard,
                              onEditCard: widget.onEditCard,
                              onDeleteCard: widget.onDeleteCard,
                              onManageAssignees: widget.onManageAssignees,
                            ),
                          );
                        },
                      ),
                    );
                  },
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

    await widget.onMoveCard(card.id, targetColumn.id, targetIndex);
  }
}

class _KanbanColumnLane extends StatelessWidget {
  const _KanbanColumnLane({
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
    final colorScheme = theme.colorScheme;

    return Material(
      clipBehavior: Clip.hardEdge,
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 8),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${column.name} (${column.cards.length})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                    visualDensity: VisualDensity.compact,
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
    final itemCount = column.cards.length * 2 + 1;

    return ListView.builder(
      key: ValueKey<String>('kanban-card-list-${column.id}'),
      primary: false,
      padding: const EdgeInsets.all(10),
      itemCount: itemCount,
      itemBuilder: (context, itemIndex) {
        if (itemIndex.isEven) {
          final slot = itemIndex ~/ 2;
          return _KanbanDropSlot(
            key: ValueKey<String>('kanban-drop-${column.id}-$slot'),
            expanded: column.cards.isEmpty,
            enabled: canMoveCards && !isBusy,
            onAccept: (card) => onMoveCard(card, column, slot),
            child: column.cards.isEmpty
                ? const Center(child: Text('Solte um card aqui'))
                : null,
          );
        }

        final cardIndex = itemIndex ~/ 2;
        final card = column.cards[cardIndex];
        return _KanbanCardTile(
          key: ValueKey<String>('kanban-card-${card.id}'),
          card: card,
          isBusy: isBusy,
          canMove: canMoveCards,
          canManageCards: canManageCards,
          canManageAssignees: canManageAssignees,
          onEdit: () => onEditCard(card),
          onDelete: () => onDeleteCard(card),
          onManageAssignees: () => onManageAssignees(card),
        );
      },
    );
  }
}

class _KanbanDropSlot extends StatelessWidget {
  const _KanbanDropSlot({
    super.key,
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
          duration: const Duration(milliseconds: 100),
          width: double.infinity,
          height: expanded ? 112 : (isActive ? 34 : 10),
          margin: const EdgeInsets.symmetric(vertical: 2),
          decoration: BoxDecoration(
            color: isActive
                ? colorScheme.primary.withValues(alpha: 0.12)
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
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.surface,
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
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (canMove && !isBusy)
                  Draggable<KanbanCard>(
                    data: card,
                    feedback: Material(
                      elevation: 8,
                      color: colorScheme.surface,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            '#${card.cardNumber} ${card.name}',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ),
                    ),
                    childWhenDragging: const Opacity(
                      opacity: 0.35,
                      child: Icon(Icons.drag_indicator, size: 20),
                    ),
                    child: const Tooltip(
                      message: 'Arraste para mover',
                      child: MouseRegion(
                        cursor: SystemMouseCursors.grab,
                        child: Padding(
                          padding: EdgeInsets.all(4),
                          child: Icon(Icons.drag_indicator, size: 20),
                        ),
                      ),
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
                  color: colorScheme.onSurfaceVariant,
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
