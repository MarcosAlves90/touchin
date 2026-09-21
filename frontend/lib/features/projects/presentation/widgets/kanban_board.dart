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
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (final column in board.columns)
                  Padding(
                    key: ValueKey<String>('kanban-column-${column.id}'),
                    padding: const EdgeInsets.only(right: 16),
                    child: SizedBox(
                      width: 320,
                      child: _StaticKanbanColumnPanel(
                        column: column,
                        isBusy: isBusy,
                        canManageStructure: canManageStructure,
                        canManageCards: canManageCards,
                        canManageAssignees: canManageAssignees,
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
}

class _StaticKanbanColumnPanel extends StatelessWidget {
  const _StaticKanbanColumnPanel({
    required this.column,
    required this.isBusy,
    required this.canManageStructure,
    required this.canManageCards,
    required this.canManageAssignees,
    required this.onRenameColumn,
    required this.onDeleteColumn,
    required this.onCreateCard,
    required this.onEditCard,
    required this.onDeleteCard,
    required this.onManageAssignees,
  });

  final KanbanColumn column;
  final bool isBusy;
  final bool canManageStructure;
  final bool canManageCards;
  final bool canManageAssignees;
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
                      'Nenhum card nesta coluna',
                      style: theme.textTheme.bodyMedium,
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: <Widget>[
                        for (final card in column.cards)
                          _StaticKanbanCardTile(
                            key: ValueKey<String>('kanban-card-${card.id}'),
                            card: card,
                            isBusy: isBusy,
                            canDelete: canManageCards,
                            canManageAssignees: canManageAssignees,
                            onEdit: () => onEditCard(card),
                            onDelete: () => onDeleteCard(card),
                            onManageAssignees: () => onManageAssignees(card),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StaticKanbanCardTile extends StatelessWidget {
  const _StaticKanbanCardTile({
    super.key,
    required this.card,
    required this.isBusy,
    required this.canDelete,
    required this.canManageAssignees,
    required this.onEdit,
    required this.onDelete,
    required this.onManageAssignees,
  });

  final KanbanCard card;
  final bool isBusy;
  final bool canDelete;
  final bool canManageAssignees;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onManageAssignees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
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
  }
}
