import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/task.dart';

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
  static const double _laneWidth = 320;
  static const double _laneGap = 12;
  static const double _cardExtent = 144;

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
        final isCompact = constraints.maxWidth < 560;
        final laneWidth = isCompact
            ? math.max(240.0, constraints.maxWidth - 2)
            : math.min(
                _laneWidth,
                math.max(280.0, constraints.maxWidth - 16),
              );
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _BoardHeader(
                  version: widget.board.kanbanVersion,
                  columnCount: widget.board.columns.length,
                  isBusy: widget.isBusy,
                  canMoveCards: widget.canMoveCards,
                  canManageStructure: widget.canManageStructure,
                  onCreateColumn: widget.onCreateColumn,
                  onScrollPrevious: () => _scrollBoard(-laneWidth),
                  onScrollNext: () => _scrollBoard(laneWidth),
                ),
                SizedBox(height: isCompact ? 10 : 14),
                Expanded(
                  child: widget.board.columns.isEmpty
                      ? _EmptyBoardState(
                          canCreateColumn: widget.canManageStructure,
                          isBusy: widget.isBusy,
                          onCreateColumn: widget.onCreateColumn,
                        )
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

  void _scrollBoard(double delta) {
    if (!_boardScrollController.hasClients) {
      return;
    }
    final position = _boardScrollController.position;
    final target = (_boardScrollController.offset + delta)
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    _boardScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _buildDragPreview(ThemeData theme, _PointerDragSession drag) {
    return Positioned(
      left: drag.pointer.dx - 108,
      top: drag.pointer.dy - 28,
      child: IgnorePointer(
        child: Material(
          elevation: 10,
          color: theme.colorScheme.surface,
          shadowColor: theme.colorScheme.shadow,
          shape: RoundedRectangleBorder(
            side: BorderSide(
              color: theme.colorScheme.primary,
              width: 1.5,
            ),
          ),
          child: SizedBox(
            width: 216,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Movendo #${drag.card.cardNumber}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    drag.card.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
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

    return AnimatedContainer(
      key: ValueKey<String>('kanban-column-${column.id}'),
      duration: const Duration(milliseconds: 140),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        border: Border.all(
          color: isDropTarget
              ? colorScheme.primary
              : colorScheme.outlineVariant,
          width: isDropTarget ? 2 : 1,
        ),
        boxShadow: isDropTarget
            ? <BoxShadow>[
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.12),
                  blurRadius: 18,
                  spreadRadius: 1,
                ),
              ]
            : const <BoxShadow>[],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: <Widget>[
            Container(
              height: 3,
              color: isDropTarget
                  ? colorScheme.primary
                  : colorScheme.primary.withValues(alpha: 0.34),
            ),
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
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _EmptyLaneState(
                            canCreateCard: widget.canManageCards,
                          ),
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
                                    key: ValueKey<String>(
                                      'kanban-card-${card.id}',
                                    ),
                                    card: card,
                                    isBusy: widget.isBusy,
                                    isDragging:
                                        _dragSession?.card.id == card.id,
                                    canMove: widget.canMoveCards,
                                    canManageCards: widget.canManageCards,
                                    canManageAssignees:
                                        widget.canManageAssignees,
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
                              vertical: 7,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Icon(
                                  Icons.vertical_align_center_rounded,
                                  size: 16,
                                  color: colorScheme.onPrimaryContainer,
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    'Solte aqui · posição ${(_dragSession?.targetIndex ?? 0) + 1}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: theme.textTheme.labelMedium?.copyWith(
                                      color: colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.canManageCards) ...<Widget>[
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 5, 8, 7),
                child: SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      minimumSize: const Size(0, 38),
                      alignment: Alignment.centerLeft,
                    ),
                    onPressed: widget.isBusy
                        ? null
                        : () => widget.onCreateCard(column),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Adicionar card'),
                  ),
                ),
              ),
            ],
          ],
        ),
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
      final scrollOffset =
          controller?.hasClients == true ? controller!.offset : 0.0;
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
    required this.columnCount,
    required this.isBusy,
    required this.canMoveCards,
    required this.canManageStructure,
    required this.onCreateColumn,
    required this.onScrollPrevious,
    required this.onScrollNext,
  });

  final int version;
  final int columnCount;
  final bool isBusy;
  final bool canMoveCards;
  final bool canManageStructure;
  final VoidCallback onCreateColumn;
  final VoidCallback onScrollPrevious;
  final VoidCallback onScrollNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          'Quadro',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              canMoveCards ? Icons.drag_indicator_rounded : Icons.visibility_outlined,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                canMoveCards
                    ? 'Arraste cards pelo ícone para reorganizar o fluxo.'
                    : 'Visualize o fluxo atual do projeto.',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    );

    final actionItems = <Widget>[
      _BoardMetaChip(
        icon: isBusy ? Icons.sync_rounded : Icons.cloud_done_outlined,
        label: isBusy ? 'Salvando' : 'Sincronizado',
        emphasized: isBusy,
      ),
      const SizedBox(width: 8),
      _BoardMetaChip(
        icon: Icons.tag_rounded,
        label: 'v$version',
      ),
      if (columnCount > 1) ...<Widget>[
        const SizedBox(width: 6),
        IconButton(
          tooltip: 'Ver colunas anteriores',
          visualDensity: VisualDensity.compact,
          onPressed: onScrollPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          tooltip: 'Ver próximas colunas',
          visualDensity: VisualDensity.compact,
          onPressed: onScrollNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
      if (canManageStructure) ...<Widget>[
        const SizedBox(width: 6),
        FilledButton.tonalIcon(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 42),
            padding: const EdgeInsets.symmetric(horizontal: 12),
          ),
          onPressed: isBusy ? null : onCreateColumn,
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Coluna'),
        ),
      ],
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 700) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              heading,
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const ClampingScrollPhysics(),
                child: Row(children: actionItems),
              ),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Expanded(child: heading),
            const SizedBox(width: 16),
            Wrap(
              spacing: 0,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actionItems,
            ),
          ],
        );
      },
    );
  }
}

class _BoardMetaChip extends StatelessWidget {
  const _BoardMetaChip({
    required this.icon,
    required this.label,
    this.emphasized = false,
  });

  final IconData icon;
  final String label;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tone = emphasized ? colorScheme.primary : colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
      decoration: BoxDecoration(
        color: emphasized
            ? colorScheme.primary.withValues(alpha: 0.12)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        border: Border.all(
          color: emphasized
              ? colorScheme.primary.withValues(alpha: 0.45)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: tone),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 4, 7),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Flexible(
                  child: Text(
                    column.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border.all(color: colorScheme.outlineVariant),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${column.cards.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (canManageCards)
            IconButton(
              tooltip: 'Adicionar card em ${column.name}',
              visualDensity: VisualDensity.compact,
              onPressed: isBusy ? null : () => onCreateCard(column),
              icon: const Icon(Icons.add_task_outlined),
            ),
          if (canManageStructure)
            PopupMenuButton<String>(
              tooltip: 'Opções da coluna',
              enabled: !isBusy,
              onSelected: (value) {
                if (value == 'left') {
                  onMoveColumn(column.id, columnIndex - 1);
                } else if (value == 'right') {
                  onMoveColumn(column.id, columnIndex + 1);
                } else if (value == 'rename') {
                  onRenameColumn(column);
                } else if (value == 'delete') {
                  onDeleteColumn(column);
                }
              },
              itemBuilder: (_) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'left',
                  enabled: columnIndex > 0,
                  child: const ListTile(
                    dense: true,
                    leading: Icon(Icons.arrow_back_rounded),
                    title: Text('Mover para a esquerda'),
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'right',
                  enabled: columnIndex < columnCount - 1,
                  child: const ListTile(
                    dense: true,
                    leading: Icon(Icons.arrow_forward_rounded),
                    title: Text('Mover para a direita'),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'rename',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.edit_outlined),
                    title: Text('Renomear coluna'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(
                    dense: true,
                    leading: Icon(Icons.delete_outline_rounded),
                    title: Text('Excluir coluna'),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _KanbanCardTile extends StatefulWidget {
  const _KanbanCardTile({
    super.key,
    required this.card,
    required this.isBusy,
    required this.isDragging,
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
  final bool isDragging;
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
  State<_KanbanCardTile> createState() => _KanbanCardTileState();
}

class _KanbanCardTileState extends State<_KanbanCardTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedOpacity(
        opacity: widget.isDragging ? 0.4 : 1,
        duration: const Duration(milliseconds: 120),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hovered
                ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.9)
                : colorScheme.surface,
            border: Border.all(
              color: _hovered
                  ? colorScheme.primary.withValues(alpha: 0.7)
                  : colorScheme.outlineVariant,
            ),
            boxShadow: _hovered
                ? <BoxShadow>[
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          child: Material(
            color: Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(9, 8, 7, 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      _TaskTypeBadge(type: widget.card.type),
                      const Spacer(),
                      Text(
                        '#${widget.card.cardNumber}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                      if (widget.canMove && !widget.isBusy) ...<Widget>[
                        const SizedBox(width: 4),
                        Semantics(
                          label: 'Arrastar card #${widget.card.cardNumber}',
                          button: true,
                          child: Tooltip(
                            message: 'Arraste para mover',
                            child: MouseRegion(
                              cursor: SystemMouseCursors.grab,
                              child: Listener(
                                onPointerDown: widget.onPointerDown,
                                onPointerMove: widget.onPointerMove,
                                onPointerUp: widget.onPointerUp,
                                onPointerCancel: widget.onPointerCancel,
                                child: const Padding(
                                  padding: EdgeInsets.all(3),
                                  child: Icon(
                                    Icons.drag_indicator_rounded,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                      if (widget.canManageCards)
                        PopupMenuButton<String>(
                          tooltip: 'Ações do card',
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(32, 32),
                            maximumSize: const Size(32, 32),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          enabled: !widget.isBusy,
                          onSelected: (value) {
                            if (value == 'edit') {
                              widget.onEdit();
                            } else if (value == 'delete') {
                              widget.onDelete();
                            }
                          },
                          itemBuilder: (_) => const <PopupMenuEntry<String>>[
                            PopupMenuItem(
                              value: 'edit',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.edit_outlined),
                                title: Text('Editar card'),
                              ),
                            ),
                            PopupMenuItem(
                              value: 'delete',
                              child: ListTile(
                                dense: true,
                                leading: Icon(Icons.delete_outline_rounded),
                                title: Text('Excluir card'),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.card.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                    ),
                  ),
                  if (widget.card.description.trim().isNotEmpty) ...<Widget>[
                    const SizedBox(height: 3),
                    Text(
                      widget.card.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.25,
                      ),
                    ),
                  ],
                  const Spacer(),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _AssigneeSummary(
                          assignees: widget.card.assignees,
                        ),
                      ),
                      if (widget.canManageAssignees)
                        IconButton(
                          tooltip: 'Gerenciar responsáveis',
                          visualDensity: VisualDensity.compact,
                          style: IconButton.styleFrom(
                            minimumSize: const Size(32, 32),
                            maximumSize: const Size(32, 32),
                            padding: EdgeInsets.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          onPressed:
                              widget.isBusy ? null : widget.onManageAssignees,
                          icon: const Icon(Icons.group_add_outlined, size: 17),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TaskTypeBadge extends StatelessWidget {
  const _TaskTypeBadge({required this.type});

  final TaskType type;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final (label, icon, tone) = switch (type) {
      TaskType.bug => ('Bug', Icons.bug_report_outlined, colorScheme.error),
      TaskType.improvement => (
          'Melhoria',
          Icons.auto_awesome_outlined,
          colorScheme.secondary,
        ),
      TaskType.feature => (
          'Feature',
          Icons.extension_outlined,
          colorScheme.primary,
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        border: Border.all(color: tone.withValues(alpha: 0.32)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 12, color: tone),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: tone,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssigneeSummary extends StatelessWidget {
  const _AssigneeSummary({required this.assignees});

  final List<TaskMemberSummary> assignees;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (assignees.isEmpty) {
      return Row(
        children: <Widget>[
          Icon(
            Icons.person_outline_rounded,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Sem responsáveis',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }

    final first = assignees.first.employeeName;
    final label = assignees.length == 1
        ? first
        : '$first +${assignees.length - 1}';
    return Row(
      children: <Widget>[
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.primary.withValues(alpha: 0.14),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.32),
            ),
          ),
          child: Text(
            _initials(first),
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.primary,
              fontWeight: FontWeight.w800,
              fontSize: 8,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '?';
    }
    if (parts.length == 1) {
      return parts.first.substring(0, math.min(2, parts.first.length)).toUpperCase();
    }
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _EmptyLaneState extends StatelessWidget {
  const _EmptyLaneState({required this.canCreateCard});

  final bool canCreateCard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.inbox_outlined,
              size: 28,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 7),
            Text(
              'Nenhum card nesta coluna',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              canCreateCard
                  ? 'Use “Adicionar card” para começar esta etapa.'
                  : 'Os cards aparecerão aqui quando entrarem nesta etapa.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyBoardState extends StatelessWidget {
  const _EmptyBoardState({
    required this.canCreateColumn,
    required this.isBusy,
    required this.onCreateColumn,
  });

  final bool canCreateColumn;
  final bool isBusy;
  final VoidCallback onCreateColumn;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.view_kanban_outlined,
                size: 42,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 14),
              Text(
                'O quadro ainda não tem colunas',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Crie a primeira etapa do fluxo para começar a organizar os cards.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              if (canCreateColumn) ...<Widget>[
                const SizedBox(height: 16),
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 48),
                  ),
                  onPressed: isBusy ? null : onCreateColumn,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Criar primeira coluna'),
                ),
              ],
            ],
          ),
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
      targetColumnId: targetColumnId ?? this.targetColumnId,
      targetIndex: targetIndex ?? this.targetIndex,
    );
  }
}
