import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_editor_dialog.dart';
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
  bool _sortAscending = true;
  final Map<String, String> _columnFilters = <String, String>{};

  @override
  void didUpdateWidget(covariant ProjectBacklogView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.board.columns.any((column) => column.id == _status)) _status = '';
    if (!widget.projectMembers.any((member) => member.employeeId == _assignee)) _assignee = '';
  }

  @override
  Widget build(BuildContext context) {
    final ordered = <({KanbanColumn column, KanbanCard card})>[
      for (final column in widget.board.columns)
        for (final card in column.cards) (column: column, card: card),
    ]..sort(_compare);
    final ids = ordered.map((row) => row.card.id).toSet();
    final children = <String, List<({KanbanColumn column, KanbanCard card})>>{};
    for (final row in ordered) {
      final parent = row.card.parentTaskId;
      if (parent != null && ids.contains(parent)) {
        children.putIfAbsent(parent, () => []).add(row);
      }
    }
    final rows = <({KanbanColumn column, KanbanCard card, int depth})>[];
    final visited = <String>{};
    void visit(({KanbanColumn column, KanbanCard card}) row, int depth) {
      if (!visited.add(row.card.id)) return;
      if (_matches(row.card, row.column)) {
        rows.add((column: row.column, card: row.card, depth: depth));
      }
      for (final child in children[row.card.id] ?? []) {
        visit(child, depth + 1);
      }
    }
    for (final row in ordered) {
      if (!ids.contains(row.card.parentTaskId)) visit(row, 0);
    }
    // Defensive fallback for legacy orphaned/cyclic hierarchy snapshots.
    for (final row in ordered) {
      if (!visited.contains(row.card.id)) visit(row, 0);
    }
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
                            columns: <DataColumn>[
                              for (final field in <(String, String)>[
                                ('number', '#'), ('title', 'Título'),
                                ('description', 'Descrição'), ('assignees', 'Responsáveis'),
                                ('project', 'Projeto'), ('created', 'Criado'), ('updated', 'Atualizado'),
                              ]) DataColumn(label: _header(field.$1, field.$2)),
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
                                    DataCell(SizedBox(
                                      width: 330,
                                      child: Row(children: <Widget>[
                                        Expanded(
                                          child: Padding(
                                            padding: EdgeInsets.only(left: row.depth * 14.0),
                                            child: Row(children: <Widget>[
                                              if (row.depth > 0)
                                                Padding(
                                                  padding: const EdgeInsets.only(right: 6),
                                                  child: Tooltip(
                                                    key: ValueKey<String>('hierarchy-indicator-${row.card.id}'),
                                                    message: 'Subtarefa de ${ordered.firstWhere((candidate) => candidate.card.id == row.card.parentTaskId).card.name}',
                                                    child: Icon(
                                                      Icons.subdirectory_arrow_right_rounded,
                                                      size: 17,
                                                      color: colors.primary,
                                                    ),
                                                  ),
                                                ),
                                              Expanded(child: Tooltip(
                                                message: row.card.name,
                                                child: InkWell(
                                                  onTap: () => widget.onOpenDetails(row.card),
                                                  child: Text(row.card.name, maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                                                  ),
                                                ),
                                              )),
                                            ]),
                                          ),
                                        ),
                                        _cardActions(row.card, row.column),
                                      ]),
                                    )),
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
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      iconSize: const WidgetStatePropertyAll(16),
      textStyle: WidgetStatePropertyAll(
        theme.textTheme.labelMedium?.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
    final controls = <({int flex, double width, Widget child})>[
      (
        flex: 2,
        width: 260,
        child: TextField(
          key: const ValueKey<String>('backlog-search'),
          decoration: const InputDecoration(
            hintText: 'Buscar por título ou #número',
            prefixIcon: Icon(Icons.search_rounded, size: 18),
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          ),
          onChanged: (value) => setState(() => _query = value.trim()),
        ),
      ),
      (
        flex: 1,
        width: 180,
        child: WorkspaceInstantSelectField<String>(
          key: const ValueKey<String>('backlog-status-filter'),
          value: _status,
          semanticLabel: 'Status',
          decoration: _filterDecoration(Icons.view_kanban_outlined),
          options: <WorkspaceSelectOption<String>>[
            const WorkspaceSelectOption(value: '', label: 'Todos os status'),
            ...widget.board.columns.map((column) => WorkspaceSelectOption(
                  value: column.id,
                  label: column.name,
                )),
          ],
          onChanged: (value) => setState(() => _status = value ?? ''),
        ),
      ),
      (
        flex: 1,
        width: 180,
        child: WorkspaceInstantSelectField<String>(
          key: const ValueKey<String>('backlog-assignee-filter'),
          value: _assignee,
          semanticLabel: 'Responsável',
          decoration: _filterDecoration(Icons.person_outline_rounded),
          options: <WorkspaceSelectOption<String>>[
            const WorkspaceSelectOption(value: '', label: 'Todos'),
            ...widget.projectMembers.map((member) => WorkspaceSelectOption(
                  value: member.employeeId,
                  label: member.employeeName,
                )),
          ],
          onChanged: (value) => setState(() => _assignee = value ?? ''),
        ),
      ),
      (
        flex: 1,
        width: 210,
        child: WorkspaceInstantSelectField<String>(
          key: const ValueKey<String>('backlog-sort'),
          value: _sort,
          semanticLabel: 'Ordenar',
          decoration: _filterDecoration(Icons.sort_rounded),
          options: const <WorkspaceSelectOption<String>>[
            WorkspaceSelectOption(value: 'kanban', label: 'Ordem do Kanban'),
            WorkspaceSelectOption(value: 'number', label: 'Número'),
            WorkspaceSelectOption(value: 'title', label: 'Título'),
            WorkspaceSelectOption(value: 'description', label: 'Descrição'),
            WorkspaceSelectOption(value: 'assignees', label: 'Responsáveis'),
            WorkspaceSelectOption(value: 'project', label: 'Projeto'),
            WorkspaceSelectOption(value: 'created', label: 'Criação'),
            WorkspaceSelectOption(value: 'updated', label: 'Atualização recente'),
          ],
          onChanged: (value) => setState(() {
            _sort = value ?? 'kanban';
            _sortAscending = _sort != 'updated';
          }),
        ),
      ),
      if (widget.canManageStructure)
        (
          flex: 1,
          width: 190,
          child: OutlinedButton.icon(
            style: buttonStyle,
            onPressed: widget.isBusy ? null : widget.onManageColumns,
            icon: const Icon(Icons.view_column_outlined),
            label: const Text('Gerenciar colunas', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      if (widget.canManageStructure)
        (
          flex: 1,
          width: 150,
          child: OutlinedButton.icon(
            style: buttonStyle,
            onPressed: widget.isBusy ? null : widget.onCreateColumn,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Novo status', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
      if (widget.canManageCards && widget.board.columns.isNotEmpty)
        (
          flex: 1,
          width: 140,
          child: FilledButton.icon(
            style: buttonStyle,
            onPressed: widget.isBusy ? null : () => widget.onCreateCard(widget.board.columns.first),
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('Novo card', maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
    ];

    return Material(
      key: const ValueKey<String>('backlog-toolbar'),
      color: colors.surface,
      shape: Border.all(color: colors.outlineVariant),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: LayoutBuilder(builder: (context, constraints) {
          final fillsWidth = constraints.maxWidth >= 1100;
          final row = Row(
            children: <Widget>[
              for (var index = 0; index < controls.length; index++) ...<Widget>[
                if (fillsWidth)
                  Expanded(
                    flex: controls[index].flex,
                    child: SizedBox.expand(child: controls[index].child),
                  )
                else
                  SizedBox(
                    width: controls[index].width,
                    height: 40,
                    child: controls[index].child,
                  ),
                if (index != controls.length - 1) const SizedBox(width: 8),
              ],
            ],
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              if (fillsWidth)
                SizedBox(height: 40, child: row)
              else
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(height: 40, child: row),
                ),
              const SizedBox(height: 8),
              Text(
                '$visible de $total cards',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  InputDecoration _filterDecoration(IconData icon) => InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    prefixIcon: Icon(icon, size: 17),
    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 40),
    suffixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 40),
  );

  Widget _header(String field, String label) => PopupMenuButton<String>(
    key: ValueKey<String>('backlog-header-$field'),
    tooltip: 'Filtrar ou ordenar $label',
    popUpAnimationStyle: AnimationStyle.noAnimation,
    onSelected: (action) {
      if (action == 'filter') {
        _filterColumn(field, label);
      } else {
        setState(() {
          if (action == 'clear') {
            _columnFilters.remove(field);
          } else {
            _sort = field;
            _sortAscending = action == 'asc';
          }
        });
      }
    },
    itemBuilder: (_) => <PopupMenuEntry<String>>[
      const PopupMenuItem(value: 'asc', child: Text('Ordenar crescente')),
      const PopupMenuItem(value: 'desc', child: Text('Ordenar decrescente')),
      const PopupMenuItem(value: 'filter', child: Text('Filtrar coluna')),
      if (_columnFilters.containsKey(field))
        const PopupMenuItem(value: 'clear', child: Text('Limpar filtro')),
    ],
    child: Row(mainAxisSize: MainAxisSize.min, children: <Widget>[
      Text(label), const SizedBox(width: 6),
      Icon(_sort == field ? (_sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded) : Icons.unfold_more_rounded, size: 14),
      if (_columnFilters.containsKey(field)) const Icon(Icons.filter_alt_outlined, size: 14),
    ]),
  );

  Future<void> _filterColumn(String field, String label) async {
    var value = _columnFilters[field] ?? '';
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => WorkspaceEditorDialog(
        title: 'Filtrar $label', subtitle: 'Filtre os cards por este campo.',
        icon: Icons.filter_alt_outlined, primaryLabel: 'Aplicar filtro',
        onPrimary: () => Navigator.of(dialogContext).pop(value.trim()),
        child: TextFormField(initialValue: value,
          decoration: const InputDecoration(labelText: 'Valor'),
          onChanged: (text) => value = text,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() {
      if (result.isEmpty) {
        _columnFilters.remove(field);
      } else {
        _columnFilters[field] = result;
      }
    });
  }

  String _fieldValue(KanbanCard card, String field) => switch (field) {
    'number' => '#${card.cardNumber}', 'title' => card.name,
    'description' => card.description,
    'assignees' => card.assignees.isEmpty ? 'Sem responsáveis' : card.assignees.map((item) => item.employeeName).join(', '),
    'project' => widget.projectName,
    'created' => _shortDate(card.createdAt), 'updated' => _shortDate(card.updatedAt),
    _ => '',
  };

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
    for (final filter in _columnFilters.entries) {
      final value = filter.value.toLowerCase();
      if (filter.key == 'number') {
        final number = int.tryParse(value.replaceFirst('#', '').trim());
        if (number != card.cardNumber) return false;
      } else if (!_fieldValue(card, filter.key).toLowerCase().contains(value)) {
        return false;
      }
    }
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
    final result = switch (_sort) {
      'number' => a.card.cardNumber.compareTo(b.card.cardNumber),
      'created' => a.card.createdAt.compareTo(b.card.createdAt),
      'updated' => a.card.updatedAt.compareTo(b.card.updatedAt),
      'title' || 'description' || 'assignees' || 'project' => _fieldValue(a.card, _sort).toLowerCase().compareTo(_fieldValue(b.card, _sort).toLowerCase()),
      _ => a.column.position != b.column.position
          ? a.column.position.compareTo(b.column.position)
          : a.card.kanbanPosition.compareTo(b.card.kanbanPosition),
    };
    return _sortAscending ? result : -result;
  }

  String _shortDate(DateTime value) {
    final date = value.toLocal().toIso8601String();
    return date.length >= 16
        ? date.substring(0, 16).replaceFirst('T', ' ')
        : date;
  }
}
