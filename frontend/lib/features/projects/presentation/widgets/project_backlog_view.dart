import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_instant_select_field.dart';

class ProjectBacklogView extends StatefulWidget {
  const ProjectBacklogView({
    super.key,
    required this.board,
    required this.projectName,
    required this.projectMembers,
    required this.canManageStructure,
    required this.canManageCards,
    required this.canManageAssignees,
    required this.canMoveCards,
    required this.isBusy,
    required this.onManageColumns,
    required this.onCreateColumn,
    required this.onCreateCard,
    required this.onMoveCard,
    required this.onEditCard,
    required this.onDeleteCard,
    required this.onManageAssignees,
    required this.onOpenDetails,
  });

  final KanbanBoard board;
  final String projectName;
  final List<ProjectMemberSummary> projectMembers;
  final bool canManageStructure;
  final bool canManageCards;
  final bool canManageAssignees;
  final bool canMoveCards;
  final bool isBusy;
  final VoidCallback onManageColumns;
  final VoidCallback onCreateColumn;
  final ValueChanged<KanbanColumn> onCreateCard;
  final void Function(String taskId, String columnId, int index) onMoveCard;
  final ValueChanged<KanbanCard> onEditCard;
  final ValueChanged<KanbanCard> onDeleteCard;
  final ValueChanged<KanbanCard> onManageAssignees;
  final ValueChanged<KanbanCard> onOpenDetails;

  @override
  State<ProjectBacklogView> createState() => _ProjectBacklogViewState();
}

class _ProjectBacklogViewState extends State<ProjectBacklogView> {
  String _query = '';
  String _status = '';
  String _assignee = '';
  String _sort = 'kanban';

  @override
  Widget build(BuildContext context) {
    final rows = <({KanbanColumn column, KanbanCard card})>[
      for (final column in widget.board.columns)
        for (final card in column.cards)
          if (_matches(card, column)) (column: column, card: card),
    ]..sort(_compare);
    final total = widget.board.columns.fold<int>(
      0,
      (sum, column) => sum + column.cards.length,
    );

    return Column(
      key: const ValueKey<String>('project-backlog-view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _buildToolbar(rows.length, total),
        const SizedBox(height: 10),
        Expanded(
          child: rows.isEmpty
              ? Center(
                  child: Text(
                    widget.board.columns.isEmpty
                        ? 'Este projeto não possui colunas.'
                        : 'Nenhum card corresponde aos filtros.',
                  ),
                )
              : LayoutBuilder(builder: (context, constraints) {
                  final theme = Theme.of(context);
                  final colors = theme.colorScheme;
                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: colors.surface,
                      border: Border.all(color: colors.outlineVariant),
                    ),
                    child: SingleChildScrollView(
                      key: const ValueKey<String>('backlog-table-scroll'),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                              minWidth: constraints.maxWidth - 2),
                          child: DataTable(
                            key: const ValueKey<String>('backlog-table'),
                            horizontalMargin: 12,
                            columnSpacing: 16,
                            dataRowMinHeight: 48,
                            dataRowMaxHeight: 52,
                            headingRowHeight: 42,
                            headingRowColor: WidgetStatePropertyAll(
                                colors.surfaceContainerHighest),
                            headingTextStyle:
                                theme.textTheme.labelMedium?.copyWith(
                              color: colors.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                            dataTextStyle: theme.textTheme.bodySmall,
                            dividerThickness: 0.5,
                            columns: const <DataColumn>[
                              DataColumn(label: Text('#')),
                              DataColumn(label: Text('Título')),
                              DataColumn(label: Text('Descrição')),
                              DataColumn(label: Text('Status')),
                              DataColumn(label: Text('Responsáveis')),
                              DataColumn(label: Text('Projeto')),
                              DataColumn(label: Text('Criado')),
                              DataColumn(label: Text('Atualizado')),
                              DataColumn(label: Text('Ações')),
                            ],
                            rows: <DataRow>[
                              for (final row in rows)
                                DataRow(
                                  key: ValueKey<String>(
                                      'backlog-card-${row.card.id}'),
                                  cells: <DataCell>[
                                    DataCell(Text(
                                      '#${row.card.cardNumber}',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(color: colors.primary),
                                    )),
                                    DataCell(
                                      SizedBox(
                                        width: 190,
                                        child: Tooltip(
                                          message: row.card.name,
                                          child: Text(
                                            row.card.name,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                    fontWeight:
                                                        FontWeight.w600),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                      SizedBox(
                                        width: 220,
                                        child: Tooltip(
                                          message: row.card.description,
                                          child: Text(
                                            row.card.description,
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                    color: colors
                                                        .onSurfaceVariant),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                        _statusField(row.card, row.column)),
                                    DataCell(
                                      SizedBox(
                                        width: 150,
                                        child: Text(
                                          row.card.assignees.isEmpty
                                              ? 'Sem responsáveis'
                                              : row.card.assignees
                                                  .map((item) =>
                                                      item.employeeName)
                                                  .join(', '),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    DataCell(
                                        Text('Projeto: ${widget.projectName}')),
                                    DataCell(
                                        Text(_shortDate(row.card.createdAt))),
                                    DataCell(
                                        Text(_shortDate(row.card.updatedAt))),
                                    DataCell(
                                        _cardActions(row.card, row.column)),
                                  ],
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                }),
        ),
      ],
    );
  }

  Widget _buildToolbar(int visible, int total) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final buttonStyle = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 36)),
      maximumSize: const WidgetStatePropertyAll(Size(200, 36)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      iconSize: const WidgetStatePropertyAll(16),
      textStyle: WidgetStatePropertyAll(theme.textTheme.labelMedium?.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w600,
      )),
    );
    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        if (widget.canManageStructure)
          OutlinedButton.icon(
            style: buttonStyle,
            onPressed: widget.isBusy ? null : widget.onManageColumns,
            icon: const Icon(Icons.view_column_outlined),
            label: const Text('Gerenciar colunas',
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        if (widget.canManageStructure)
          OutlinedButton.icon(
            style: buttonStyle,
            onPressed: widget.isBusy ? null : widget.onCreateColumn,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo status',
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        if (widget.canManageCards && widget.board.columns.isNotEmpty)
          FilledButton.icon(
            style: buttonStyle,
            onPressed: widget.isBusy
                ? null
                : () => widget.onCreateCard(widget.board.columns.first),
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Novo card',
                maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
      ],
    );
    final summary = Text(
      '$visible de $total cards',
      style: theme.textTheme.labelMedium?.copyWith(
        color: colors.onSurfaceVariant,
      ),
    );
    return Material(
      color: colors.surface,
      shape: Border.all(color: colors.outlineVariant),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth >= 640) {
                return Row(children: <Widget>[
                  Expanded(child: summary),
                  actions,
                ]);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  summary,
                  const SizedBox(height: 8),
                  actions,
                ],
              );
            }),
            const SizedBox(height: 12),
            LayoutBuilder(builder: (context, constraints) {
              final narrow = constraints.maxWidth < 560;
              final filterWidth =
                  narrow ? (constraints.maxWidth - 8) / 2 : 180.0;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  SizedBox(
                    width: narrow ? constraints.maxWidth : 280,
                    child: TextField(
                      key: const ValueKey<String>('backlog-search'),
                      decoration: const InputDecoration(
                        hintText: 'Buscar por título ou #número',
                        prefixIcon: Icon(Icons.search_rounded, size: 18),
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) =>
                          setState(() => _query = value.trim()),
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: WorkspaceInstantSelectField<String>(
                      key: const ValueKey<String>('backlog-status-filter'),
                      value: _status,
                      decoration: _filterDecoration('Status'),
                      options: <WorkspaceSelectOption<String>>[
                        const WorkspaceSelectOption(
                            value: '', label: 'Todos os status'),
                        ...widget.board.columns.map((column) =>
                            WorkspaceSelectOption(
                                value: column.id, label: column.name)),
                      ],
                      onChanged: (value) =>
                          setState(() => _status = value ?? ''),
                    ),
                  ),
                  SizedBox(
                    width: filterWidth,
                    child: WorkspaceInstantSelectField<String>(
                      key: const ValueKey<String>('backlog-assignee-filter'),
                      value: _assignee,
                      decoration: _filterDecoration('Responsável'),
                      options: <WorkspaceSelectOption<String>>[
                        const WorkspaceSelectOption(value: '', label: 'Todos'),
                        ...widget.projectMembers
                            .map((member) => WorkspaceSelectOption(
                                  value: member.employeeId,
                                  label: member.employeeName,
                                )),
                      ],
                      onChanged: (value) =>
                          setState(() => _assignee = value ?? ''),
                    ),
                  ),
                  SizedBox(
                    width: narrow ? constraints.maxWidth : 210,
                    child: WorkspaceInstantSelectField<String>(
                      key: const ValueKey<String>('backlog-sort'),
                      value: _sort,
                      decoration: _filterDecoration('Ordenar'),
                      options: const <WorkspaceSelectOption<String>>[
                        WorkspaceSelectOption(
                            value: 'kanban', label: 'Ordem do Kanban'),
                        WorkspaceSelectOption(value: 'number', label: 'Número'),
                        WorkspaceSelectOption(value: 'title', label: 'Título'),
                        WorkspaceSelectOption(
                            value: 'updated', label: 'Atualização recente'),
                      ],
                      onChanged: (value) =>
                          setState(() => _sort = value ?? 'kanban'),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  InputDecoration _filterDecoration(String label) => InputDecoration(
        labelText: label,
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        suffixIconConstraints:
            const BoxConstraints(minWidth: 32, minHeight: 32),
      );

  Widget _statusField(KanbanCard card, KanbanColumn column) {
    if (!widget.canMoveCards) {
      return Text(column.name);
    }
    final theme = Theme.of(context);
    return Container(
      width: 150,
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: DropdownButton<String>(
        key: ValueKey<String>('backlog-card-status-${card.id}-${column.id}'),
        value: column.id,
        isExpanded: true,
        isDense: true,
        style: theme.textTheme.bodySmall,
        iconSize: 18,
        underline: const SizedBox.shrink(),
        items: widget.board.columns
            .map(
              (item) => DropdownMenuItem<String>(
                value: item.id,
                child: Text(item.name, overflow: TextOverflow.ellipsis),
              ),
            )
            .toList(),
        onChanged: widget.isBusy
            ? null
            : (columnId) {
                if (columnId == null || columnId == column.id) {
                  return;
                }
                final target = widget.board.columns.firstWhere(
                  (item) => item.id == columnId,
                );
                widget.onMoveCard(card.id, columnId, target.cards.length);
              },
      ),
    );
  }

  Widget _cardActions(KanbanCard card, KanbanColumn column) {
    final actionButtons = <Widget>[
      IconButton(
        tooltip: 'Detalhes de #${card.cardNumber}',
        visualDensity: VisualDensity.compact,
        onPressed: () => widget.onOpenDetails(card),
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
      ),
      if (widget.canManageCards) ...<Widget>[
        IconButton(
          tooltip: 'Editar #${card.cardNumber}',
          visualDensity: VisualDensity.compact,
          onPressed: widget.isBusy ? null : () => widget.onEditCard(card),
          icon: const Icon(Icons.edit_outlined, size: 18),
        ),
        IconButton(
          tooltip: 'Excluir #${card.cardNumber}',
          visualDensity: VisualDensity.compact,
          onPressed: widget.isBusy ? null : () => widget.onDeleteCard(card),
          icon: const Icon(Icons.delete_outline_rounded, size: 18),
        ),
      ],
      if (widget.canManageAssignees)
        IconButton(
          tooltip: 'Responsáveis de #${card.cardNumber}',
          visualDensity: VisualDensity.compact,
          onPressed:
              widget.isBusy ? null : () => widget.onManageAssignees(card),
          icon: const Icon(Icons.people_outline_rounded, size: 18),
        ),
      if (widget.canMoveCards) ...<Widget>[
        IconButton(
          tooltip: 'Mover #${card.cardNumber} para cima',
          visualDensity: VisualDensity.compact,
          onPressed: widget.isBusy || card.kanbanPosition <= 0
              ? null
              : () => widget.onMoveCard(
                    card.id,
                    column.id,
                    card.kanbanPosition - 1,
                  ),
          icon: const Icon(Icons.arrow_upward_rounded, size: 18),
        ),
        IconButton(
          tooltip: 'Mover #${card.cardNumber} para baixo',
          visualDensity: VisualDensity.compact,
          onPressed:
              widget.isBusy || card.kanbanPosition >= column.cards.length - 1
                  ? null
                  : () => widget.onMoveCard(
                        card.id,
                        column.id,
                        card.kanbanPosition + 2,
                      ),
          icon: const Icon(Icons.arrow_downward_rounded, size: 18),
        ),
      ],
    ];
    return IconButtonTheme(
      data: IconButtonThemeData(
          style: IconButton.styleFrom(
        minimumSize: const Size(32, 32),
        padding: const EdgeInsets.all(6),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
        shape: const RoundedRectangleBorder(),
      )),
      child: Row(mainAxisSize: MainAxisSize.min, children: actionButtons),
    );
  }

  bool _matches(KanbanCard card, KanbanColumn column) {
    if (_status.isNotEmpty && _status != column.id) {
      return false;
    }
    if (_assignee.isNotEmpty &&
        !card.assignees.any((item) => item.employeeId == _assignee)) {
      return false;
    }
    if (_query.isEmpty) {
      return true;
    }
    final query = _query.startsWith('#') ? _query.substring(1).trim() : _query;
    final number = int.tryParse(query);
    return card.name.toLowerCase().contains(query.toLowerCase()) ||
        (number != null
            ? card.cardNumber == number
            : card.cardNumber.toString().contains(query));
  }

  int _compare(
    ({KanbanColumn column, KanbanCard card}) a,
    ({KanbanColumn column, KanbanCard card}) b,
  ) {
    return switch (_sort) {
      'number' => a.card.cardNumber.compareTo(b.card.cardNumber),
      'title' => a.card.name.toLowerCase().compareTo(b.card.name.toLowerCase()),
      'updated' => b.card.updatedAt.compareTo(a.card.updatedAt),
      _ => a.column.position != b.column.position
          ? a.column.position.compareTo(b.column.position)
          : a.card.kanbanPosition.compareTo(b.card.kanbanPosition),
    };
  }

  String _shortDate(DateTime value) {
    final date = value.toLocal().toIso8601String();
    return date.length >= 16
        ? date.substring(0, 16).replaceFirst('T', ' ')
        : date;
  }
}
