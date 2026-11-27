import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/theme/workspace_menu_style.dart';

class ProjectKanbanBoard extends StatefulWidget {
  static const double laneGap = 12;

  static double laneWidthFor(double maxWidth) {
    if (maxWidth < 560) return math.max(240.0, maxWidth - 2).toDouble();
    return math.min(320.0, math.max(280.0, maxWidth - 16)).toDouble();
  }

  const ProjectKanbanBoard({
    super.key,
    required this.board,
    this.visibleCardIds,
    this.matchedCardIds = const <String>{},
    this.isSearchActive = false,
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
  final Set<String>? visibleCardIds;
  final Set<String> matchedCardIds;
  final bool isSearchActive;
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
  State<ProjectKanbanBoard> createState() => ProjectKanbanBoardState();
}

class ProjectKanbanBoardState extends State<ProjectKanbanBoard> {
  double get _cardExtent {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    return 136 + math.max(0, textScale - 1) * 60;
  }

  double _laneWidth(double width) {
    final textScale = MediaQuery.textScalerOf(context).scale(1);
    final balancedWidth = widget.board.columns.length == 3
        ? math.min(480.0, (width - 4 * ProjectKanbanBoard.laneGap) / 3)
        : 0.0;
    return math.max(
      math.max(ProjectKanbanBoard.laneWidthFor(width), balancedWidth),
      280 + math.max(0, textScale - 1) * 80,
    );
  }

  final ScrollController _boardScrollController = ScrollController();
  final Map<String, ScrollController> _laneScrollControllers =
      <String, ScrollController>{};
  final Map<String, GlobalKey> _laneBodyKeys = <String, GlobalKey>{};
  final ValueNotifier<Offset> _dragPointer = ValueNotifier<Offset>(Offset.zero);

  _PointerDragSession? _dragSession;

  @override
  void didUpdateWidget(covariant ProjectKanbanBoard oldWidget) {
    super.didUpdateWidget(oldWidget);
    final liveColumnIds =
        widget.board.columns.map((column) => column.id).toSet();
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
    _dragPointer.dispose();
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
        final laneWidth = _laneWidth(constraints.maxWidth);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
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
                            cacheExtent: laneWidth,
                            slivers: <Widget>[
                              SliverPadding(
                                padding: const EdgeInsets.only(
                                  right: ProjectKanbanBoard.laneGap,
                                ),
                                sliver: SliverFixedExtentList(
                                  itemExtent:
                                      laneWidth + ProjectKanbanBoard.laneGap,
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final column =
                                          widget.board.columns[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: ProjectKanbanBoard.laneGap,
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
                                    addAutomaticKeepAlives: false,
                                    addRepaintBoundaries: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ),
            if (_dragSession != null) _buildDragPreview(theme, _dragSession!),
          ],
        );
      },
    );
  }

  void scrollColumns(int direction) {
    final width = context.size?.width;
    if (width == null) return;
    _scrollBoard(direction * _laneWidth(width));
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
    final preview = RepaintBoundary(
      child: IgnorePointer(
        child: Material(
          elevation: 10,
          color: theme.colorScheme.surface,
          shadowColor: theme.colorScheme.shadow,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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

    return ValueListenableBuilder<Offset>(
      valueListenable: _dragPointer,
      child: preview,
      builder: (context, pointer, child) {
        return Positioned(
          left: pointer.dx - 108,
          top: pointer.dy - 28,
          child: child!,
        );
      },
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
    final visibleCards = column.cards
        .where((card) =>
            widget.visibleCardIds == null ||
            widget.visibleCardIds!.contains(card.id))
        .toList();

    return RepaintBoundary(
      child: AnimatedContainer(
        key: ValueKey<String>('kanban-column-${column.id}'),
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(10),
          border: isDropTarget
              ? Border.all(color: colorScheme.primary, width: 2)
              : Border.all(color: colorScheme.outlineVariant),
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
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(10),
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
              if (widget.canManageCards)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.isBusy
                        ? null
                        : () => widget.onCreateCard(column),
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Adicionar card'),
                  ),
                ),
              Expanded(
                child: Stack(
                  key: laneKey,
                  children: <Widget>[
                    CustomScrollView(
                      key:
                          ValueKey<String>('kanban-column-scroll-${column.id}'),
                      controller: laneController,
                      physics: const ClampingScrollPhysics(),
                      cacheExtent: _cardExtent * 2,
                      slivers: <Widget>[
                        if (visibleCards.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: widget.visibleCardIds != null &&
                                    column.cards.isNotEmpty
                                ? const Center(
                                    child: Text(
                                        'Nenhuma tarefa corresponde aos filtros'))
                                : _EmptyLaneState(
                                    canCreateCard: widget.canManageCards),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                            sliver: SliverFixedExtentList(
                              itemExtent: _cardExtent,
                              delegate: SliverChildBuilderDelegate(
                                (context, index) {
                                  final card = visibleCards[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: _KanbanCardTile(
                                      key: ValueKey<String>(
                                        'kanban-card-${card.id}',
                                      ),
                                      card: card,
                                      column: column,
                                      isSearchActive: widget.isSearchActive ||
                                          widget.matchedCardIds.isNotEmpty,
                                      isSearchMatch: widget.matchedCardIds
                                          .contains(card.id),
                                      position: column.cards.indexOf(card),
                                      columns: widget.board.columns,
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
                                      onMove: (columnId, index) => widget
                                          .onMoveCard(card.id, columnId, index),
                                    ),
                                  );
                                },
                                childCount: visibleCards.length,
                                addAutomaticKeepAlives: false,
                                addRepaintBoundaries: false,
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
                              borderRadius: BorderRadius.circular(8),
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
                                      style:
                                          theme.textTheme.labelMedium?.copyWith(
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
            ],
          ),
        ),
      ),
    );
  }

  void _startDrag(KanbanCard card, PointerDownEvent event) {
    if (!widget.canMoveCards || widget.isBusy) {
      return;
    }
    _dragPointer.value = _globalToLocal(event.position);
    final target = _resolveTarget(event.position, card);
    setState(() {
      _dragSession = _PointerDragSession(
        card: card,
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

    _dragPointer.value = _globalToLocal(event.position);
    final target = _resolveTarget(event.position, current.card);
    final nextColumnId = target?.columnId;
    final nextIndex = target?.index ?? current.targetIndex;
    if (nextColumnId == current.targetColumnId &&
        nextIndex == current.targetIndex) {
      return;
    }

    setState(() {
      _dragSession = _PointerDragSession(
        card: current.card,
        targetColumnId: nextColumnId,
        targetIndex: nextIndex,
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
    if (target != null && !target.noOp) {
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
      final visibleCards = column.cards
          .where((item) =>
              widget.visibleCardIds == null ||
              widget.visibleCardIds!.contains(item.id))
          .toList();
      final targetIndex = visualIndex.clamp(0, visibleCards.length).toInt();
      final sourceVisibleIndex = visibleCards.indexOf(card);
      final staysInVisibleSlot = sourceVisibleIndex >= 0 &&
          (targetIndex == sourceVisibleIndex ||
              targetIndex == sourceVisibleIndex + 1);
      final sourceIndex = column.cards.indexOf(card);
      return _DropTarget(
        columnId: column.id,
        index: staysInVisibleSlot
            ? (sourceIndex >= 0 ? sourceIndex : card.kanbanPosition)
            : targetIndex < visibleCards.length
                ? column.cards.indexOf(visibleCards[targetIndex])
                : column.cards.length,
        noOp: staysInVisibleSlot,
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

    final laneTone = switch (columnIndex % 3) {
      0 => colorScheme.primary,
      1 => colorScheme.tertiary,
      _ => colorScheme.secondary,
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 3),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Row(
              children: <Widget>[
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: laneTone,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Flexible(
                  child: Text(
                    column.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  key: ValueKey<String>('kanban-column-count-${column.id}'),
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: laneTone.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${column.cards.length}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: laneTone,
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
              visualDensity: VisualDensity.standard,
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                maximumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              onPressed: isBusy ? null : () => onCreateCard(column),
              icon: const Icon(Icons.add_task_outlined, size: 18),
            ),
          if (canManageStructure)
            PopupMenuButton<String>(
              popUpAnimationStyle: AnimationStyle.noAnimation,
              tooltip: 'Opções da coluna',
              color: WorkspaceMenuStyle.surface(colorScheme),
              shape: WorkspaceMenuStyle.shape(colorScheme),
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                maximumSize: const Size(48, 48),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
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
    required this.column,
    required this.isSearchActive,
    required this.isSearchMatch,
    required this.position,
    required this.columns,
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
    required this.onMove,
  });

  final KanbanCard card;
  final KanbanColumn column;
  final bool isSearchActive;
  final bool isSearchMatch;
  final int position;
  final List<KanbanColumn> columns;
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
  final void Function(String columnId, int index) onMove;

  @override
  State<_KanbanCardTile> createState() => _KanbanCardTileState();
}

class _KanbanCardTileState extends State<_KanbanCardTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final canMoveWithMenu = widget.canMove &&
        (widget.column.cards.length > 1 || widget.columns.length > 1);

    return RepaintBoundary(
      child: MouseRegion(
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
                  ? Color.alphaBlend(
                      colorScheme.onSurface.withValues(alpha: 0.06),
                      colorScheme.surfaceContainerHighest,
                    )
                  : colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: widget.isSearchMatch
                  ? Border.all(color: colorScheme.primary, width: 2)
                  : Border.all(color: colorScheme.outlineVariant),
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
                padding: const EdgeInsets.fromLTRB(9, 5, 5, 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: Tooltip(
                            message: widget.card.name,
                            child: Text(
                              widget.card.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                height: 1.2,
                              ),
                            ),
                          ),
                        ),
                        if (widget.isSearchActive && widget.isSearchMatch)
                          Semantics(
                            label: 'Correspondência da busca',
                            child: Text('Encontrado',
                                style: theme.textTheme.labelSmall),
                          ),
                        const SizedBox(width: 4),
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
                            label: 'Arrastar card #${widget.card.cardNumber}. '
                                'Para mover com teclado, use ações do card.',
                            child: Tooltip(
                              message:
                                  'Arraste para mover ou use ações do card',
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
                        if (widget.canManageCards || canMoveWithMenu)
                          PopupMenuButton<String>(
                            popUpAnimationStyle: AnimationStyle.noAnimation,
                            tooltip: 'Ações do card #${widget.card.cardNumber}',
                            color: WorkspaceMenuStyle.surface(colorScheme),
                            shape: WorkspaceMenuStyle.shape(colorScheme),
                            padding: EdgeInsets.zero,
                            iconSize: 18,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              maximumSize: const Size(48, 48),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.padded,
                              visualDensity: VisualDensity.standard,
                            ),
                            enabled: !widget.isBusy,
                            onSelected: (value) {
                              if (value == 'edit') {
                                widget.onEdit();
                              } else if (value == 'delete') {
                                widget.onDelete();
                              } else if (value == 'up') {
                                widget.onMove(
                                    widget.column.id, widget.position - 1);
                              } else if (value == 'down') {
                                // The controller adjusts for the source removal.
                                widget.onMove(
                                    widget.column.id, widget.position + 2);
                              } else if (value.startsWith('column:')) {
                                final targetId =
                                    value.substring('column:'.length);
                                final target = widget.columns.firstWhere(
                                  (column) => column.id == targetId,
                                );
                                widget.onMove(target.id, target.cards.length);
                              }
                            },
                            itemBuilder: (_) => <PopupMenuEntry<String>>[
                              if (widget
                                  .canManageCards) ...<PopupMenuEntry<String>>[
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.edit_outlined),
                                    title: Text('Editar card'),
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.delete_outline_rounded),
                                    title: Text('Excluir card'),
                                  ),
                                ),
                              ],
                              if (widget.canManageCards && canMoveWithMenu)
                                const PopupMenuDivider(),
                              if (widget.canMove && widget.position > 0)
                                const PopupMenuItem(
                                  value: 'up',
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.arrow_upward_rounded),
                                    title: Text('Mover card para cima'),
                                  ),
                                ),
                              if (widget.canMove &&
                                  widget.position <
                                      widget.column.cards.length - 1)
                                const PopupMenuItem(
                                  value: 'down',
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.arrow_downward_rounded),
                                    title: Text('Mover card para baixo'),
                                  ),
                                ),
                              if (widget.canMove)
                                for (final target in widget.columns)
                                  if (target.id != widget.column.id)
                                    PopupMenuItem(
                                      value: 'column:${target.id}',
                                      child: ListTile(
                                        dense: true,
                                        leading: const Icon(
                                            Icons.arrow_forward_rounded),
                                        title:
                                            Text('Mover para ${target.name}'),
                                      ),
                                    ),
                            ],
                          ),
                      ],
                    ),
                    if (widget.card.description.trim().isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
                      Tooltip(
                        message: widget.card.description,
                        child: Text(
                          widget.card.description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.25,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    Row(
                      children: <Widget>[
                        _TaskTypeBadge(type: widget.card.type),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _AssigneeSummary(
                            assignees: widget.card.assignees,
                          ),
                        ),
                        if (widget.canManageAssignees)
                          IconButton(
                            tooltip: 'Gerenciar responsáveis',
                            visualDensity: VisualDensity.standard,
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              maximumSize: const Size(48, 48),
                              padding: EdgeInsets.zero,
                              tapTargetSize: MaterialTapTargetSize.padded,
                            ),
                            onPressed:
                                widget.isBusy ? null : widget.onManageAssignees,
                            icon:
                                const Icon(Icons.group_add_outlined, size: 17),
                          ),
                      ],
                    ),
                  ],
                ),
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
        borderRadius: BorderRadius.circular(5),
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
    final label =
        assignees.length == 1 ? first : '$first +${assignees.length - 1}';
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
      return parts.first
          .substring(0, math.min(2, parts.first.length))
          .toUpperCase();
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
              size: 26,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 6),
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
  const _DropTarget({
    required this.columnId,
    required this.index,
    this.noOp = false,
  });

  final String columnId;
  final int index;
  final bool noOp;
}

class _PointerDragSession {
  const _PointerDragSession({
    required this.card,
    required this.targetColumnId,
    required this.targetIndex,
  });

  final KanbanCard card;
  final String? targetColumnId;
  final int targetIndex;
}
