import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/kanban.dart';

class ProjectKanbanBoard extends StatefulWidget {
  const ProjectKanbanBoard({
    super.key,
    required this.board,
    required this.isBusy,
    required this.canMoveCards,
    required this.canManageStructure,
    required this.canManageCards,
    required this.canManageAssignees,
    required this.onMoveCard,
    required this.onMoveColumn,
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
  final Future<void> Function(String columnId, int index) onMoveColumn;
  final VoidCallback onCreateColumn;
  final void Function(KanbanColumn column) onRenameColumn;
  final void Function(KanbanColumn column) onDeleteColumn;
  final void Function(KanbanColumn column) onCreateCard;
  final void Function(KanbanCard card) onEditCard;
  final void Function(KanbanCard card) onDeleteCard;
  final void Function(KanbanCard card) onManageAssignees;

  @override
  State<ProjectKanbanBoard> createState() => _ProjectKanbanBoardState();
}

class _ProjectKanbanBoardState extends State<ProjectKanbanBoard> {
  static const double _laneWidth = 340;
  static const double _laneGap = 12;
  static const double _cardExtent = 156;

  final ScrollController _boardScrollController = ScrollController();
  final Map<String, ScrollController> _laneScrollControllers =
      <String, ScrollController>{};
  final Map<String, GlobalKey> _laneBodyKeys = <String, GlobalKey>{};

  _PointerDragSession? _dragSession;

  @override
  void didUpdateWidget(covariant ProjectKanbanBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final liveColumnIds = widget.board.columns.map((column) => column.id).toSet();
    final staleControllers = _laneScrollControllers.keys
        .where((columnId) => !liveColumnIds.contains(columnId))
        .toList();
    for (final columnId in staleControllers) {
      _laneScrollControllers.remove(columnId)?.dispose();
      _laneBodyKeys.remove(columnId);
    }
    if (widget.isBusy && _dragSession != null) {
      _dragSession = null;
    }
  }

  @override
  void dispose() {
    _boardScrollController.dispose();
    for (final controller in _laneScrollControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth = math.min(
          _laneWidth,
          math.max(260.0, constraints.maxWidth - 24),
        );
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _BoardHeader(
                  version: widget.board.kanbanVersion,
                  isBusy: widget.isBusy,
                  canManageStructure: widget.canManageStructure,
                  onCreateColumn: widget.onCreateColumn,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: widget.board.columns.isEmpty
                      ? const Center(child: Text('Nenhuma coluna disponível'))
                      : Scrollbar(
                          controller: _boardScrollController,
                          thumbVisibility: constraints.maxWidth >= 760,
                          child: CustomScrollView(
                            key: const ValueKey<String>('kanban-board-scroll'),
                            controller: _boardScrollController,
                            scrollDirection: Axis.horizontal,
                            physics: const ClampingScrollPhysics(),
                            slivers: <Widget>[
                              SliverPadding(
                                padding: const EdgeInsets.only(right: _laneGap),
                                sliver: SliverFixedExtentList(
                                  itemExtent: laneWidth + _laneGap,
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final column = widget.board.columns[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: _laneGap,
                                        ),
                                        child: _buildLane(
                                          context,
                                          column,
                                          index,
                                          laneWidth,
                                        ),
                                      );
                                    },
                                    childCount: widget.board.columns.length,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            if (_dragSession != null)
              _buildDragPreview(theme, _dragSession!),
          ],
        );
      },
    );
  }

  Widget _buildDragPreview(ThemeData theme, _PointerDragSession drag) {
    return Positioned(
      left: drag.pointer.dx - 112,
      top: drag.pointer.dy - 28,
      child: IgnorePointer(
        child: Material(
          elevation: 8,
          color: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: theme.colorScheme.primary),
          ),
          child: SizedBox(
            width: 224,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '#${drag.card.cardNumber} ${drag.card.name}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLane(
    BuildContext context,
    KanbanColumn column,
    int columnIndex,
    double laneWidth,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDropTarget = _dragSession?.targetColumnId == column.id;
    final laneController = _laneScrollControllers.putIfAbsent(
      column.id,
      ScrollController.new,
    );
    final laneKey = _laneBodyKeys.putIfAbsent(column.id, GlobalKey.new);

    return Material(
      key: ValueKey<String>('kanban-column-${column.id}'),
      color: colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: isDropTarget ? colorScheme.primary : colorScheme.outlineVariant,
          width: isDropTarget ? 2 : 1,
        ),
      ),
      child: Column(
        children: <Widget>[
          _LaneHeader(
            column: column,
            columnIndex: columnIndex,
            columnCount: widget.board.columns.length,
            isBusy: widget.isBusy,
            canManageStructure: widget.canManageStructure,
            canManageCards: widget.canManageCards,
            onMoveColumn: widget.onMoveColumn,
            onRenameColumn: widget.onRenameColumn,
            onDeleteColumn: widget.onDeleteColumn,
            onCreateCard: widget.onCreateCard,
          ),
          const Divider(height: 1),
          Expanded(
            child: Stack(
              key: laneKey,
              children: <Widget>[
                CustomScrollView(
                  key: ValueKey<String>('kanban-column-scroll-${column.id}'),
                  controller: laneController,
                  physics: const ClampingScrollPhysics(),
                  slivers: <Widget>[
                    if (column.cards.isEmpty)
                      const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(child: Text('Nenhum card nesta coluna')),
                      )
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(10),
                        sliver: SliverFixedExtentList(
                          itemExtent: _cardExtent,
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final card = column.cards[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: _KanbanCardTile(
                                  key: ValueKey<String>('kanban-card-${card.id}'),
                                  card: card,
                                  isBusy: widget.isBusy,
                                  canMove: widget.canMoveCards,
                                  canManageCards: widget.canManageCards,
                                  canManageAssignees: widget.canManageAssignees,
                                  onPointerDown: (event) =>
                                      _startDrag(card, event),
                                  onPointerMove: _updateDrag,
                                  onPointerUp: _finishDrag,
                                  onPointerCancel: _cancelDrag,
                                  onEdit: () => widget.onEditCard(card),
                                  onDelete: () => widget.onDeleteCard(card),
                                  onManageAssignees: () =>
                                      widget.onManageAssignees(card),
                                ),
                              );
                            },
                            childCount: column.cards.length,
                          ),
                        ),
                      ),
                  ],
                ),
                if (isDropTarget)
                  Positioned(
                    left: 8,
                    right: 8,
                    top: 8,
                    child: IgnorePointer(
                      child: Material(
                        color: colorScheme.primaryContainer,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: colorScheme.primary),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          child: Text(
                            'Soltar na posição ${(_dragSession?.targetIndex ?? 0) + 1}',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _startDrag(KanbanCard card, PointerDownEvent event) {
    if (!widget.canMoveCards || widget.isBusy) {
      return;
    }
    final localPointer = _globalToLocal(event.position);
    final target = _resolveTarget(event.position, card);
    setState(() {
      _dragSession = _PointerDragSession(
        card: card,
        pointer: localPointer,
        targetColumnId: target?.columnId,
        targetIndex: target?.index ?? card.kanbanPosition,
      );
    });
  }

  void _updateDrag(PointerMoveEvent event) {
    final current = _dragSession;
    if (current == null) {
      return;
    }
    final target = _resolveTarget(event.position, current.card);
    setState(() {
      _dragSession = current.copyWith(
        pointer: _globalToLocal(event.position),
        targetColumnId: target?.columnId,
        targetIndex: target?.index,
      );
    });
  }

  void _finishDrag(PointerUpEvent event) {
    final current = _dragSession;
    if (current == null) {
      return;
    }
    final target = _resolveTarget(event.position, current.card);
    setState(() {
      _dragSession = null;
    });
    if (target != null) {
      widget.onMoveCard(current.card.id, target.columnId, target.index);
    }
  }

  void _cancelDrag(PointerCancelEvent event) {
    if (_dragSession == null) {
      return;
    }
    setState(() {
      _dragSession = null;
    });
  }

  _DropTarget? _resolveTarget(Offset globalPosition, KanbanCard card) {
    for (final column in widget.board.columns) {
      final key = _laneBodyKeys[column.id];
      final renderBox = key?.currentContext?.findRenderObject();
      if (renderBox is! RenderBox || !renderBox.hasSize) {
        continue;
      }
      final local = renderBox.globalToLocal(globalPosition);
      if (local.dx < 0 ||
          local.dy < 0 ||
          local.dx > renderBox.size.width ||
          local.dy > renderBox.size.height) {
        continue;
      }

      final controller = _laneScrollControllers[column.id];
      final scrollOffset = controller?.hasClients == true ? controller!.offset : 0.0;
      final contentY = math.max(0.0, local.dy + scrollOffset - 10);
      final visualIndex = (contentY / _cardExtent).round();
      return _DropTarget(
        columnId: column.id,
        index: visualIndex.clamp(0, column.cards.length).toInt(),
      );
    }
    return null;
  }

  Offset _globalToLocal(Offset globalPosition) {
    final renderObject = context.findRenderObject();
    if (renderObject is RenderBox) {
      return renderObject.globalToLocal(globalPosition);
    }
    return globalPosition;
  }
}

class _BoardHeader extends StatelessWidget {
  const _BoardHeader({
    required this.version,
    required this.isBusy,
    required this.canManageStructure,
    required this.onCreateColumn,
  });

  final int version;
  final bool isBusy;
  final bool canManageStructure;
  final VoidCallback onCreateColumn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: <Widget>[
        Expanded(
          child: Text(
            'Quadro',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text('v$version', style: theme.textTheme.bodySmall),
        if (canManageStructure) ...<Widget>[
          const SizedBox(width: 8),
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
            ),
            onPressed: isBusy ? null : onCreateColumn,
            icon: const Icon(Icons.add),
            label: const Text('Coluna'),
          ),
        ],
      ],
    );
  }
}

class _LaneHeader extends StatelessWidget {
  const _LaneHeader({
    required this.column,
    required this.columnIndex,
    required this.columnCount,
    required this.isBusy,
    required this.canManageStructure,
    required this.canManageCards,
    required this.onMoveColumn,
    required this.onRenameColumn,
    required this.onDeleteColumn,
    required this.onCreateCard,
  });

  final KanbanColumn column;
  final int columnIndex;
  final int columnCount;
  final bool isBusy;
  final bool canManageStructure;
  final bool canManageCards;
  final Future<void> Function(String columnId, int index) onMoveColumn;
  final void Function(KanbanColumn column) onRenameColumn;
  final void Function(KanbanColumn column) onDeleteColumn;
  final void Function(KanbanColumn column) onCreateCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
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
                  : () => onMoveColumn(column.id, columnIndex - 1),
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton(
              tooltip: 'Mover coluna para a direita',
              visualDensity: VisualDensity.compact,
              onPressed: isBusy || columnIndex == columnCount - 1
                  ? null
                  : () => onMoveColumn(column.id, columnIndex + 1),
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
                PopupMenuItem(value: 'rename', child: Text('Renomear')),
                PopupMenuItem(value: 'delete', child: Text('Excluir')),
              ],
            ),
        ],
      ),
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
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.onEdit,
    required this.onDelete,
    required this.onManageAssignees,
  });

  final KanbanCard card;
  final bool isBusy;
  final bool canMove;
  final bool canManageCards;
  final bool canManageAssignees;
  final void Function(PointerDownEvent event) onPointerDown;
  final void Function(PointerMoveEvent event) onPointerMove;
  final void Function(PointerUpEvent event) onPointerUp;
  final void Function(PointerCancelEvent event) onPointerCancel;
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
                  Tooltip(
                    message: 'Arraste para mover',
                    child: MouseRegion(
                      cursor: SystemMouseCursors.grab,
                      child: Listener(
                        onPointerDown: onPointerDown,
                        onPointerMove: onPointerMove,
                        onPointerUp: onPointerUp,
                        onPointerCancel: onPointerCancel,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
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
                      PopupMenuItem(value: 'edit', child: Text('Editar card')),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Excluir card'),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              card.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (card.description.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                card.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
            const Spacer(),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: <Widget>[
                for (final assignee in card.assignees.take(2))
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text(assignee.employeeName),
                  ),
                if (canManageAssignees)
                  ActionChip(
                    avatar: const Icon(Icons.group_add_outlined, size: 16),
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

class _DropTarget {
  const _DropTarget({required this.columnId, required this.index});

  final String columnId;
  final int index;
}

class _PointerDragSession {
  const _PointerDragSession({
    required this.card,
    required this.pointer,
    required this.targetColumnId,
    required this.targetIndex,
  });

  final KanbanCard card;
  final Offset pointer;
  final String? targetColumnId;
  final int targetIndex;

  _PointerDragSession copyWith({
    Offset? pointer,
    String? targetColumnId,
    int? targetIndex,
  }) {
    return _PointerDragSession(
      card: card,
      pointer: pointer ?? this.pointer,
      targetColumnId: targetColumnId,
      targetIndex: targetIndex ?? this.targetIndex,
    );
  }
}
