import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/projects/presentation/kanban_controller.dart';
import 'package:touchin_flutter/features/projects/presentation/task_search_query.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/project_backlog_view.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/project_kanban_board.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/task_editor_dialog.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_editor_dialog.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_instant_select_field.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_skeleton.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_toolbar.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';

class ProjectKanbanPage extends StatefulWidget {
  const ProjectKanbanPage({super.key, this.api, this.controller});

  final TouchInApi? api;
  final ProjectKanbanController? controller;

  @override
  State<ProjectKanbanPage> createState() => _ProjectKanbanPageState();
}

class _ProjectKanbanPageState extends State<ProjectKanbanPage> {
  late final ProjectKanbanController _controller;
  late final bool _ownsController;
  bool _showBacklog = false;
  String _taskSearchText = '';
  String _kanbanStatus = '';
  String _kanbanAssignee = '';
  String? _searchProjectId;
  final TextEditingController _taskSearchController = TextEditingController();
  final GlobalKey<ProjectKanbanBoardState> _boardKey =
      GlobalKey<ProjectKanbanBoardState>();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? ProjectKanbanController(api: widget.api);
    _ownsController = widget.controller == null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _controller.start();
    });
  }

  @override
  void dispose() {
    _taskSearchController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WorkspaceScaffold(
      contentScrollable: false,
      contentBuilder: (context, isWide) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!isWide) _KanbanTopBar(controller: _controller),
          if (isWide)
            Padding(
              padding: const EdgeInsets.fromLTRB(32, 28, 32, 0),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) => Row(
                  children: [
                    const Expanded(
                        child: WorkspaceHeader(
                            title: 'Acompanhar tarefas',
                            description: '',
                            compact: true)),
                    if (_buildCreateTaskAction(compact: false)
                        case final action?)
                      action,
                  ],
                ),
              ),
            ),
          Expanded(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) => _buildPageBody(isWide),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageBody(bool pageIsWide) {
    Widget withMobileHeader(Widget child) {
      if (pageIsWide) return child;
      final minimumHeight =
          MediaQuery.textScalerOf(context).scale(1) > 1 ? 1200.0 : 928.0;
      return LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          child: SizedBox(
            height: constraints.maxHeight < minimumHeight
                ? minimumHeight
                : constraints.maxHeight,
            child: Column(children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(24, 28, 24, 0),
                child: WorkspaceHeader(
                    title: 'Acompanhar tarefas',
                    description: '',
                    compact: true),
              ),
              Expanded(child: child),
            ]),
          ),
        ),
      );
    }

    if (_controller.isLoading) {
      return withMobileHeader(LayoutBuilder(
        builder: (context, constraints) {
          final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1;
          final pageHeight =
              constraints.maxHeight < 700 ? 700.0 : constraints.maxHeight;
          return SingleChildScrollView(
            child: SizedBox(
              height: pageHeight + (enlarged ? 180 : 0),
              child: const _KanbanPageSkeleton(),
            ),
          );
        },
      ));
    }

    if (_controller.loadError != null) {
      return withMobileHeader(_KanbanPageMessage(
        title: 'Não foi possível carregar o Kanban',
        message: _controller.loadError!,
        actionLabel: 'Tentar novamente',
        onAction: _controller.retry,
      ));
    }

    if (_controller.projects.isEmpty) {
      return withMobileHeader(const _KanbanPageMessage(
        title: 'Nenhum projeto disponível',
        message: 'Crie ou obtenha acesso a um projeto antes de usar o Kanban.',
      ));
    }

    return withMobileHeader(LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final isWide = constraints.maxWidth >= 980;
        final horizontalPadding = isCompact ? 10.0 : (isWide ? 28.0 : 16.0);
        final verticalPadding = isCompact ? 8.0 : 14.0;
        const gap = 8.0;

        final textScale = MediaQuery.textScalerOf(context).scale(16) / 16;
        final minimumBodyHeight =
            600.0 + (textScale > 1 ? (textScale - 1) * 240 : 0);
        final body = Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            isCompact ? 4 : verticalPadding,
            horizontalPadding,
            isCompact ? 0 : verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildProjectOverview(compact: isCompact, pageIsWide: pageIsWide),
              SizedBox(height: gap),
              if (!_showBacklog || _controller.board == null)
                _buildTaskFilterSection(_controller.board, compact: isCompact),
              SizedBox(
                key: const ValueKey<String>('kanban-section-gap-before-board'),
                height: gap,
              ),
              Expanded(child: _buildBoardContent()),
            ],
          ),
        );
        return constraints.maxHeight < minimumBodyHeight
            ? SingleChildScrollView(
                child: SizedBox(height: minimumBodyHeight, child: body),
              )
            : body;
      },
    ));
  }

  Widget _buildProjectOverview(
      {required bool compact, required bool pageIsWide}) {
    final selectedProjectId = _controller.selectedProjectId;
    if (_searchProjectId != selectedProjectId) {
      _searchProjectId = selectedProjectId;
      _taskSearchText = '';
      _taskSearchController.clear();
      _kanbanStatus = '';
      _kanbanAssignee = '';
    }
    final board = _controller.board;
    final cardCount = board?.columns.fold<int>(
          0,
          (total, column) => total + column.cards.length,
        ) ??
        0;

    final selector = SizedBox(
      height: 52,
      child: WorkspaceInstantSelectField<String>(
        key: ValueKey<String?>(_controller.selectedProjectId),
        value: _controller.selectedProjectId,
        decoration: const InputDecoration(
          labelText: 'Projeto',
          constraints: BoxConstraints.tightFor(height: 52),
        ),
        options: _controller.projects
            .map(
              (project) => WorkspaceSelectOption<String>(
                value: project.id,
                label: project.name,
              ),
            )
            .toList(),
        onChanged: _controller.isMutating
            ? null
            : (projectId) {
                if (projectId != null &&
                    projectId != _controller.selectedProjectId) {
                  _controller.selectProject(projectId);
                }
              },
      ),
    );

    final metrics = _KanbanMetricsStrip(
      columns: board?.columns.length,
      cards: board == null ? null : cardCount,
      team: _controller.projectMembers.length,
    );

    final refresh = IconButton(
      tooltip: 'Atualizar quadro',
      constraints: const BoxConstraints.tightFor(width: 52, height: 52),
      visualDensity: VisualDensity.standard,
      onPressed: _controller.isMutating || _controller.isLoadingBoard
          ? null
          : () => _controller.reload(),
      icon: const Icon(Icons.refresh_rounded),
    );
    final createTask =
        !pageIsWide ? _buildCreateTaskAction(compact: compact) : null;
    final viewSwitch = _buildProjectViewSwitch(compact: compact);

    return LayoutBuilder(builder: (context, overviewConstraints) {
      final wideSummary = overviewConstraints.maxWidth >= 1000;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!wideSummary) ...<Widget>[
            metrics,
            const SizedBox(height: 8),
          ],
          Material(
            key: const ValueKey<String>('kanban-project-overview'),
            color: Colors.transparent,
            child: LayoutBuilder(builder: (context, constraints) {
              if (constraints.maxWidth >= 700) {
                return Row(children: <Widget>[
                  if (wideSummary) ...<Widget>[
                    SizedBox(width: 360, child: metrics),
                    const SizedBox(width: 16),
                  ],
                  Expanded(child: selector),
                  if (createTask != null) ...<Widget>[
                    const SizedBox(width: 8),
                    createTask,
                  ],
                  refresh,
                  const SizedBox(width: 12),
                  viewSwitch,
                ]);
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Row(children: <Widget>[
                    Expanded(child: selector),
                    if (createTask != null) createTask,
                    refresh,
                  ]),
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerLeft, child: viewSwitch),
                ],
              );
            }),
          ),
        ],
      );
    });
  }

  Widget? _buildCreateTaskAction({required bool compact}) {
    final board = _controller.board;
    return board?.columns.isNotEmpty == true && _controller.canManageCards
        ? compact
            ? IconButton.filled(
                key: const ValueKey<String>('kanban-create-task'),
                tooltip: 'Nova tarefa',
                constraints:
                    const BoxConstraints.tightFor(width: 48, height: 48),
                onPressed: _controller.isMutating
                    ? null
                    : () => _openCreateKanbanCard(board!.columns.first),
                icon: const Icon(Icons.add_rounded),
              )
            : FilledButton.icon(
                key: const ValueKey<String>('kanban-create-task'),
                style: workspaceToolbarActionStyle(Theme.of(context)),
                onPressed: _controller.isMutating
                    ? null
                    : () => _openCreateKanbanCard(board!.columns.first),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Nova tarefa'),
              )
        : null;
  }

  Widget _buildTaskFilterSection(KanbanBoard? board, {required bool compact}) {
    if (board != null && !board.columns.any((c) => c.id == _kanbanStatus)) {
      _kanbanStatus = '';
    }
    if (!_controller.projectMembers
        .any((m) => m.employeeId == _kanbanAssignee)) {
      _kanbanAssignee = '';
    }
    final showNavigation = (board?.columns.length ?? 0) > 1;
    final canCreateColumn = board != null && _controller.canManageStructure;
    final createColumnAction = canCreateColumn
        ? FilledButton.icon(
            style: workspaceToolbarActionStyle(Theme.of(context)),
            onPressed: _controller.isMutating ? null : _openCreateKanbanColumn,
            icon: const Icon(Icons.add_rounded),
            label: const Text('Coluna'),
          )
        : null;
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (compact && createColumnAction != null) createColumnAction,
        if (showNavigation) ...<Widget>[
          IconButton(
            tooltip: 'Ver colunas anteriores',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => _boardKey.currentState?.scrollColumns(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            tooltip: 'Ver próximas colunas',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            onPressed: () => _boardKey.currentState?.scrollColumns(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
        if (!compact && createColumnAction != null) createColumnAction,
      ],
    );
    return LayoutBuilder(
      key: const ValueKey<String>('workspace-task-filter-section'),
      builder: (context, constraints) {
        final search = _buildTaskSearch(board);
        final filters = Wrap(spacing: 8, runSpacing: 8, children: [
          SizedBox(
              width: 180,
              height: 48,
              child: WorkspaceInstantSelectField<String>(
                key: const ValueKey<String>('kanban-status-filter'),
                value: _kanbanStatus,
                semanticLabel: 'Status',
                decoration: _kanbanFilterDecoration(Icons.view_kanban_outlined),
                options: [
                  const WorkspaceSelectOption(
                      value: '', label: 'Todos os status'),
                  ...?board?.columns.map(
                      (c) => WorkspaceSelectOption(value: c.id, label: c.name)),
                ],
                onChanged: (value) =>
                    setState(() => _kanbanStatus = value ?? ''),
              )),
          SizedBox(
              width: 180,
              height: 48,
              child: WorkspaceInstantSelectField<String>(
                key: const ValueKey<String>('kanban-assignee-filter'),
                value: _kanbanAssignee,
                semanticLabel: 'Responsável',
                decoration:
                    _kanbanFilterDecoration(Icons.person_outline_rounded),
                options: [
                  const WorkspaceSelectOption(value: '', label: 'Todos'),
                  ..._controller.projectMembers.map((m) =>
                      WorkspaceSelectOption(
                          value: m.employeeId, label: m.employeeName)),
                ],
                onChanged: (value) =>
                    setState(() => _kanbanAssignee = value ?? ''),
              )),
        ]);
        return Column(
          key: const ValueKey<String>('kanban-filter-toolbar'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (constraints.maxWidth < 800) ...[search, actions] else
              Row(children: [
                Expanded(
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 420),
                            child: search))),
                if (constraints.maxWidth >= 1000) ...[
                  const SizedBox(width: 8),
                  filters
                ],
                const SizedBox(width: 8),
                actions,
              ]),
            if (constraints.maxWidth < 1000) ...[
              const SizedBox(height: 8),
              filters
            ],
          ],
        );
      },
    );
  }

  InputDecoration _kanbanFilterDecoration(IconData icon) => InputDecoration(
        isDense: true,
        visualDensity: VisualDensity.standard,
        constraints: const BoxConstraints.tightFor(height: 48),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        prefixIcon: Icon(icon, size: 17),
      );

  Widget _buildTaskSearch(KanbanBoard? board) {
    final columns = board?.columns ?? const <KanbanColumn>[];
    final query = TaskSearchQuery.parse(_taskSearchText, columns: columns);
    final matches = <String>{
      if (board != null && query.isActive)
        for (final column in board.columns)
          for (final card in column.cards)
            if (query.matches(card, column)) card.id,
    };
    final criteria = <String>[
      for (final type in query.types)
        'Tipo: ${switch (type) {
          TaskType.bug => 'Bug',
          TaskType.improvement => 'Melhoria',
          TaskType.feature => 'Funcionalidade',
        }}',
      for (final column
          in columns.where((column) => query.columnIds.contains(column.id)))
        'Status: ${column.name}',
      if (query.cardNumber case final number?) 'Número: #$number',
      if (query.textTerms.isNotEmpty) 'Texto: ${query.textTerms.join(' ')}',
    ];
    final active = _taskSearchText.trim().isNotEmpty;
    final matchCountValue = query.isActive
        ? matches.length
        : columns.fold<int>(0, (count, column) => count + column.cards.length);
    final matchCount =
        '$matchCountValue ${matchCountValue == 1 ? 'correspondência' : 'correspondências'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        TextField(
          key: const ValueKey<String>('task-search-shared'),
          controller: _taskSearchController,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            labelText: 'Buscar tarefas',
            hintText: 'Ex.: bugs de login em andamento',
            constraints: const BoxConstraints.tightFor(height: 48),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: active
                ? IconButton(
                    key: const ValueKey<String>('task-search-clear'),
                    tooltip: 'Limpar busca',
                    onPressed: () => setState(() {
                      _taskSearchText = '';
                      _taskSearchController.clear();
                    }),
                    icon: const Icon(Icons.clear_rounded),
                  )
                : null,
          ),
          onChanged: (value) => setState(() => _taskSearchText = value),
        ),
        if (active)
          Semantics(
            liveRegion: true,
            label: '$matchCount. '
                '${criteria.isEmpty ? 'Sem filtros reconhecidos.' : criteria.join('. ')}',
            child: Padding(
              padding: const EdgeInsets.only(top: 4, left: 12),
              child: Text(
                '$matchCount'
                '${criteria.isEmpty ? '' : ' · ${criteria.join(' · ')}'}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildProjectViewSwitch({required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    Widget tab(Widget child, bool selected) => Stack(
          alignment: Alignment.bottomCenter,
          children: <Widget>[
            Center(child: child),
            if (selected)
              Container(
                key: const ValueKey<String>('project-view-selected-indicator'),
                height: 2,
                width: compact ? 28 : 64,
                color: colors.primary,
              ),
          ],
        );
    return ToggleButtons(
      key: const ValueKey<String>('project-view-switch'),
      borderRadius: BorderRadius.circular(8),
      constraints: BoxConstraints(
        minWidth: compact ? 48 : 94,
        minHeight: 52,
      ),
      color: colors.onSurfaceVariant,
      selectedColor: colors.primary,
      fillColor: Colors.transparent,
      renderBorder: false,
      borderColor: colors.outlineVariant,
      selectedBorderColor: colors.primary,
      isSelected: <bool>[!_showBacklog, _showBacklog],
      onPressed: (index) => setState(() => _showBacklog = index == 1),
      children: <Widget>[
        tab(
            compact
                ? const Tooltip(
                    message: 'Kanban',
                    child: Icon(Icons.view_kanban_outlined, size: 18))
                : const Text('Kanban'),
            !_showBacklog),
        tab(
            compact
                ? const Tooltip(
                    message: 'Backlog',
                    child: Icon(Icons.view_list_outlined, size: 18))
                : const Text('Backlog'),
            _showBacklog),
      ],
    );
  }

  Widget _buildBoardContent() {
    if (_controller.isLoadingBoard && _controller.board == null) {
      return const RepaintBoundary(
        child: _KanbanBoardSkeleton(),
      );
    }

    final board = _controller.board;
    if (board == null) {
      return _KanbanPageMessage(
        title: 'Quadro indisponível',
        message:
            _controller.boardError ?? 'Não foi possível carregar o Kanban.',
        actionLabel: 'Recarregar',
        onAction: _controller.reload,
      );
    }

    if (_showBacklog) {
      final sharedSearchQuery = _taskSearchText;
      final query =
          TaskSearchQuery.parse(sharedSearchQuery, columns: board.columns);
      final matchedCardIds = query.isActive
          ? <String>{
              for (final column in board.columns)
                for (final card in column.cards)
                  if (query.matches(card, column)) card.id,
            }
          : null;
      final backlog = ProjectBacklogView(
        key: ValueKey<String>('project-backlog-${board.projectId}'),
        board: board,
        matchedCardIds: matchedCardIds,
        sharedSearchField: _buildTaskSearch(board),
        sharedSearchQuery: sharedSearchQuery,
        projectName: _controller.selectedProject?.name ?? '',
        projectMembers: _controller.projectMembers,
        canManageStructure: _controller.canManageStructure,
        canManageCards: _controller.canManageCards,
        canManageAssignees: _controller.canManageAssignees,
        canMoveCards: _controller.canMoveCards,
        isBusy: _controller.isMutating,
        onManageColumns: _openManageBacklogColumns,
        onCreateColumn: _openCreateKanbanColumn,
        onCreateCard: _openCreateKanbanCard,
        onMoveCard: _moveCardWithFeedback,
        onEditCard: _openEditKanbanCard,
        onDeleteCard: _confirmDeleteKanbanCard,
        onManageAssignees: _openManageKanbanAssignees,
        onOpenDetails: _openEditKanbanCard,
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (_controller.boardError != null) ...<Widget>[
            _KanbanNotice(
                message: _controller.boardError!, onRetry: _controller.reload),
            const SizedBox(height: 8),
          ],
          Expanded(child: backlog),
        ],
      );
    }

    final isMutating = _controller.isMutating;
    final query =
        TaskSearchQuery.parse(_taskSearchText, columns: board.columns);
    final matchedCardIds = <String>{
      if (query.isActive)
        for (final column in board.columns)
          for (final card in column.cards)
            if (query.matches(card, column)) card.id,
    };
    return Stack(
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_controller.boardError != null) ...<Widget>[
              _KanbanNotice(
                message: _controller.boardError!,
                onRetry: _controller.reload,
              ),
              const SizedBox(height: 8),
            ],
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 60),
                child: RepaintBoundary(
                  child: ProjectKanbanBoard(
                    key: _boardKey,
                    board: board,
                    visibleCardIds: _kanbanStatus.isEmpty &&
                            _kanbanAssignee.isEmpty
                        ? null
                        : {
                            for (final column in board.columns)
                              for (final card in column.cards)
                                if ((_kanbanStatus.isEmpty ||
                                        column.id == _kanbanStatus) &&
                                    (_kanbanAssignee.isEmpty ||
                                        card.assignees.any((a) =>
                                            a.employeeId == _kanbanAssignee)))
                                  card.id
                          },
                    matchedCardIds: matchedCardIds,
                    isSearchActive: query.isActive,
                    isBusy: isMutating,
                    canMoveCards: _controller.canMoveCards,
                    canManageStructure: _controller.canManageStructure,
                    canManageCards: _controller.canManageCards,
                    canManageAssignees: _controller.canManageAssignees,
                    onMoveCard: _moveCardWithFeedback,
                    onMoveColumn: (columnId, index) => _controller.moveColumn(
                      columnId: columnId,
                      toIndex: index,
                    ),
                    onCreateColumn: _openCreateKanbanColumn,
                    onRenameColumn: _openRenameKanbanColumn,
                    onDeleteColumn: _confirmDeleteKanbanColumn,
                    onCreateCard: _openCreateKanbanCard,
                    onEditCard: _openEditKanbanCard,
                    onDeleteCard: _confirmDeleteKanbanCard,
                    onManageAssignees: _openManageKanbanAssignees,
                  ),
                ),
              ),
            ),
          ],
        ),
        if (isMutating)
          const Positioned(
            left: 0,
            top: 0,
            right: 0,
            child: _KanbanMutationStatus(),
          ),
      ],
    );
  }

  Future<String?> _promptKanbanColumnName({
    required String title,
    String initialValue = '',
  }) async {
    final formKey = GlobalKey<FormState>();
    var name = initialValue;
    final editing = initialValue.trim().isNotEmpty;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => WorkspaceEditorDialog(
        title: title,
        subtitle: editing
            ? 'Atualize o nome desta etapa do fluxo.'
            : 'Crie uma nova etapa para organizar o fluxo.',
        icon: editing ? Icons.edit_note_rounded : Icons.view_column_outlined,
        primaryLabel: editing ? 'Salvar' : 'Criar coluna',
        primaryIcon: editing ? Icons.save_outlined : Icons.add_rounded,
        maxWidth: 520,
        onPrimary: () {
          if (!formKey.currentState!.validate()) {
            return;
          }
          Navigator.of(dialogContext).pop(name.trim());
        },
        child: Form(
          key: formKey,
          child: TextFormField(
            initialValue: initialValue,
            onChanged: (value) => name = value,
            autofocus: true,
            maxLength: 160,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: 'Nome da coluna'),
            validator: (value) {
              final trimmed = value?.trim() ?? '';
              if (trimmed.isEmpty) {
                return 'Campo obrigatório.';
              }
              return null;
            },
            onFieldSubmitted: (_) {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(name.trim());
              }
            },
          ),
        ),
      ),
    );
    return result;
  }

  Future<void> _openCreateKanbanColumn() async {
    final name = await _promptKanbanColumnName(title: 'Nova coluna');
    if (name == null) {
      return;
    }
    await _runAction(
      () => _controller.createColumn(name),
      successMessage: 'Coluna criada.',
    );
  }

  Future<void> _openRenameKanbanColumn(KanbanColumn column) async {
    final name = await _promptKanbanColumnName(
      title: 'Renomear coluna',
      initialValue: column.name,
    );
    if (name == null || name == column.name) {
      return;
    }
    await _runAction(
      () => _controller.renameColumn(column.id, name),
      successMessage: 'Coluna atualizada.',
    );
  }

  Future<void> _confirmDeleteKanbanColumn(KanbanColumn column) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => WorkspaceEditorDialog(
        title: 'Excluir coluna?',
        subtitle:
            'A coluna deve estar vazia e não pode ser a última do quadro.',
        icon: Icons.delete_outline_rounded,
        primaryLabel: 'Excluir',
        onPrimary: () => Navigator.of(dialogContext).pop(true),
        onSecondary: () => Navigator.of(dialogContext).pop(false),
        child: Text(
          'A coluna "${column.name}" só pode ser excluída quando estiver vazia '
          'e não for a última coluna do quadro.',
        ),
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _runAction(
      () => _controller.deleteColumn(column.id),
      successMessage: 'Coluna excluída.',
    );
  }

  Future<void> _openCreateKanbanCard(KanbanColumn column) async {
    if (_controller.selectedProject == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => ProjectTaskEditorDialog(
        tasks: _controller.tasks,
        onSave: (draft) async {
          await _controller.createCard(
            TaskDraft(
              name: draft.name,
              description: draft.description,
              type: draft.type,
              parentTaskId: draft.parentTaskId,
              columnId: column.id,
              creationKey: draft.creationKey,
            ),
          );
          if (mounted && _controller.boardError == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Card criado em ${column.name}.')),
            );
          }
        },
      ),
    );
  }

  Future<void> _openEditKanbanCard(KanbanCard card) async {
    if (_controller.selectedProject == null) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => ProjectTaskEditorDialog(
        tasks: _controller.tasks,
        task: card.toTaskRecord(),
        startInViewMode: true,
        canEdit: _controller.canManageCards,
        supplementaryDetails: _buildCardOperationalDetails(card),
        onSave: (draft) async {
          await _controller.updateCard(card.toTaskRecord(), draft);
          if (mounted && _controller.boardError == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Card atualizado.')),
            );
          }
        },
      ),
    );
  }

  Future<void> _openManageBacklogColumns() async {
    if (!_controller.canManageStructure || _controller.isMutating) return;
    final columns = _controller.board?.columns ?? const <KanbanColumn>[];
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => WorkspaceEditorDialog(
        title: 'Gerenciar colunas',
        subtitle: 'Etapas compartilhadas entre Kanban e Backlog.',
        icon: Icons.view_column_outlined,
        primaryLabel: 'Novo status',
        primaryIcon: Icons.add_rounded,
        secondaryLabel: 'Fechar',
        onPrimary: () {
          Navigator.of(dialogContext).pop();
          _openCreateKanbanColumn();
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (columns.isEmpty)
              const Text('Crie o primeiro status do projeto.'),
            for (var index = 0; index < columns.length; index++)
              ListTile(
                dense: true,
                title: Text(columns[index].name),
                subtitle: Text('${columns[index].cards.length} cards'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    IconButton(
                      tooltip: 'Mover coluna para cima',
                      onPressed: index == 0
                          ? null
                          : () {
                              Navigator.of(dialogContext).pop();
                              _runAction(
                                  () => _controller.moveColumn(
                                        columnId: columns[index].id,
                                        toIndex: index - 1,
                                      ),
                                  successMessage: 'Colunas reordenadas.');
                            },
                      icon: const Icon(Icons.arrow_upward_rounded, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Mover coluna para baixo',
                      onPressed: index == columns.length - 1
                          ? null
                          : () {
                              Navigator.of(dialogContext).pop();
                              _runAction(
                                  () => _controller.moveColumn(
                                        columnId: columns[index].id,
                                        toIndex: index + 1,
                                      ),
                                  successMessage: 'Colunas reordenadas.');
                            },
                      icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Renomear status',
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _openRenameKanbanColumn(columns[index]);
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                    ),
                    IconButton(
                      tooltip: 'Excluir status',
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        _confirmDeleteKanbanColumn(columns[index]);
                      },
                      icon: const Icon(Icons.delete_outline_rounded, size: 18),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _moveCardWithFeedback(
          String taskId, String columnId, int index) =>
      _runAction(
        () => _controller.moveCard(
            taskId: taskId, toColumnId: columnId, toIndex: index),
        successMessage: 'Status do card atualizado.',
      );

  Widget _buildCardOperationalDetails(KanbanCard initialCard) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final columns = _controller.board?.columns ?? const <KanbanColumn>[];
        var card = initialCard;
        for (final column in columns) {
          for (final candidate in column.cards) {
            if (candidate.id == initialCard.id) card = candidate;
          }
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            const Divider(height: 24),
            WorkspaceInstantSelectField<String>(
              key: const ValueKey<String>('card-dialog-status'),
              value: card.kanbanColumnId,
              decoration: const InputDecoration(labelText: 'Status'),
              options: columns
                  .map((column) => WorkspaceSelectOption(
                        value: column.id,
                        label: column.name,
                      ))
                  .toList(),
              onChanged: !_controller.canMoveCards || _controller.isMutating
                  ? null
                  : (value) {
                      if (value == null || value == card.kanbanColumnId) return;
                      final column =
                          columns.firstWhere((column) => column.id == value);
                      _moveCardWithFeedback(
                          card.id, value, column.cards.length);
                    },
            ),
            const SizedBox(height: 12),
            Text('Projeto: ${_controller.selectedProject?.name ?? ''}'),
            Text(
                'Responsáveis: ${card.assignees.isEmpty ? 'Sem responsáveis' : card.assignees.map((item) => item.employeeName).join(', ')}'),
            Text('Criado: ${card.createdAt.toLocal()}'),
            Text('Atualizado: ${card.updatedAt.toLocal()}'),
          ],
        );
      },
    );
  }

  Future<void> _confirmDeleteKanbanCard(KanbanCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => WorkspaceEditorDialog(
        title: 'Excluir #${card.cardNumber}?',
        subtitle: 'Esta operação remove o card do projeto.',
        icon: Icons.delete_outline_rounded,
        primaryLabel: 'Excluir',
        onPrimary: () => Navigator.of(dialogContext).pop(true),
        onSecondary: () => Navigator.of(dialogContext).pop(false),
        child: Text(
          'O card "${card.name}" será removido. O número '
          '#${card.cardNumber} não será reutilizado.',
        ),
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _runAction(
      () => _controller.deleteCard(card.id),
      successMessage: 'Card excluído.',
    );
  }

  Future<void> _openManageKanbanAssignees(KanbanCard card) async {
    final project = _controller.selectedProject;
    if (project == null ||
        !_controller.canManageAssignees ||
        _controller.isMutating) return;
    final assignedIds = card.assignees.map((item) => item.employeeId).toSet();
    final atCapacity = assignedIds.length >= project.taskEmployeeLimit;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => WorkspaceEditorDialog(
        title: 'Responsáveis de #${card.cardNumber}',
        subtitle:
            '${assignedIds.length}/${project.taskEmployeeLimit} responsável(is)',
        icon: Icons.people_outline_rounded,
        primaryLabel: 'Fechar',
        onPrimary: () => Navigator.of(dialogContext).pop(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _controller.projectMembers.map((member) {
            final assigned = assignedIds.contains(member.employeeId);
            return CheckboxListTile(
              dense: true,
              value: assigned,
              title: Text(member.employeeName),
              controlAffinity: ListTileControlAffinity.leading,
              onChanged: !assigned && atCapacity
                  ? null
                  : (selected) async {
                      Navigator.of(dialogContext).pop();
                      await _runAction(
                        () => selected == true
                            ? _controller.addAssignee(
                                card.id, member.employeeId)
                            : _controller.removeAssignee(
                                card.id, member.employeeId),
                        successMessage: selected == true
                            ? 'Responsável adicionado.'
                            : 'Responsável removido.',
                      );
                    },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _runAction(
    Future<dynamic> Function() action, {
    required String successMessage,
  }) async {
    try {
      await action();
      if (!mounted || _controller.boardError != null) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(successMessage)),
      );
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível concluir a operação.')),
      );
    }
  }
}

class _KanbanBoardSkeleton extends StatelessWidget {
  const _KanbanBoardSkeleton();

  @override
  Widget build(BuildContext context) {
    return const WorkspaceSkeletonRegion(
      key: ValueKey<String>('kanban-board-skeleton'),
      label: 'Carregando quadro Kanban',
      child: _KanbanBoardSkeletonBody(),
    );
  }
}

class _KanbanPageSkeleton extends StatelessWidget {
  const _KanbanPageSkeleton();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 600;
        final wide = constraints.maxWidth >= 980;
        final horizontalPadding = compact ? 10.0 : (wide ? 28.0 : 16.0);
        final verticalPadding = compact ? 8.0 : 14.0;
        final gap = compact ? 8.0 : 12.0;
        return WorkspaceSkeletonRegion(
          key: const ValueKey<String>('kanban-page-skeleton'),
          label: 'Carregando Kanban',
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              compact ? 4 : verticalPadding,
              horizontalPadding,
              compact ? 0 : verticalPadding,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _KanbanProjectOverviewSkeleton(compact: compact),
                SizedBox(height: gap),
                WorkspaceFilterSection(
                  key: const ValueKey<String>(
                    'workspace-task-filter-section',
                  ),
                  surfaceKey: const ValueKey<String>('kanban-filter-toolbar'),
                  padding: const EdgeInsets.all(12),
                  headingIcon: Icons.task_alt_rounded,
                  title: 'Tarefas do projeto',
                  description: 'Encontre e organize as tarefas do projeto',
                  searchField: const WorkspaceSkeleton(height: 48),
                ),
                SizedBox(height: gap),
                const Expanded(child: _KanbanBoardSkeletonBody()),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KanbanProjectOverviewSkeleton extends StatelessWidget {
  const _KanbanProjectOverviewSkeleton({required this.compact});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Row(
          children: <Widget>[
            for (var index = 0; index < 3; index++) ...<Widget>[
              if (index > 0) const SizedBox(width: 8),
              const Expanded(
                child: WorkspaceSkeleton(
                  height: 42,
                  radius: BorderRadius.all(Radius.circular(10)),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Material(
          key: const ValueKey<String>('kanban-project-overview'),
          color: colors.surfaceContainerHighest.withValues(alpha: 0.28),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: colors.outlineVariant),
          ),
          child: Padding(
            padding: EdgeInsets.all(compact ? 8 : 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    const Expanded(child: WorkspaceSkeleton(height: 52)),
                    const SizedBox(width: 8),
                    WorkspaceSkeleton(
                      width: 52,
                      height: 52,
                      radius: BorderRadius.circular(12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: WorkspaceSkeleton(
                    width: compact ? 104 : 196,
                    height: 50,
                    radius: BorderRadius.circular(8),
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

class _KanbanBoardSkeletonBody extends StatelessWidget {
  const _KanbanBoardSkeletonBody();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final laneWidth = ProjectKanbanBoard.laneWidthFor(constraints.maxWidth);
        final laneExtent = laneWidth + ProjectKanbanBoard.laneGap;
        final laneCount = constraints.maxWidth <= 0
            ? 1
            : (constraints.maxWidth / laneExtent).ceil();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: const <Widget>[
                WorkspaceSkeleton(width: 118, height: 20),
                Spacer(),
                WorkspaceSkeleton(width: 92, height: 30),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const NeverScrollableScrollPhysics(),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: List<Widget>.generate(laneCount, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        right: ProjectKanbanBoard.laneGap,
                      ),
                      child: SizedBox(
                        width: laneWidth,
                        child: _KanbanLaneSkeleton(index: index),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _KanbanLaneSkeleton extends StatelessWidget {
  const _KanbanLaneSkeleton({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.32),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                WorkspaceSkeleton(width: 92 + (index * 12), height: 16),
                const Spacer(),
                const WorkspaceSkeleton(width: 28, height: 28),
              ],
            ),
            const SizedBox(height: 12),
            _KanbanCardSkeleton(colorScheme: colorScheme),
            const SizedBox(height: 10),
            _KanbanCardSkeleton(colorScheme: colorScheme, compact: true),
            const Spacer(),
            const WorkspaceSkeleton(height: 38),
          ],
        ),
      ),
    );
  }
}

class _KanbanCardSkeleton extends StatelessWidget {
  const _KanbanCardSkeleton({required this.colorScheme, this.compact = false});

  final ColorScheme colorScheme;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.72),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const WorkspaceSkeleton(width: 72, height: 14),
            const SizedBox(height: 10),
            WorkspaceSkeleton(width: compact ? 120 : 172, height: 16),
            const SizedBox(height: 8),
            WorkspaceSkeleton(width: compact ? 154 : 210, height: 12),
          ],
        ),
      ),
    );
  }
}

class _KanbanMutationStatus extends StatelessWidget {
  const _KanbanMutationStatus();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Atualizando o quadro',
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'Atualizando o quadro…',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ),
    );
  }
}

class _KanbanTopBar extends StatelessWidget {
  const _KanbanTopBar({required this.controller});

  final ProjectKanbanController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final isIdle = !controller.isMutating &&
            !controller.isLoading &&
            !controller.isLoadingBoard &&
            controller.loadError == null &&
            controller.boardError == null;
        if (isIdle) return const SizedBox.shrink();
        return Material(
          key: const ValueKey<String>('kanban-topbar'),
          color: colorScheme.surface,
          child: Container(
            height: 54,
            padding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: colorScheme.outlineVariant),
              ),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: _KanbanSyncStatus(controller: controller),
                  ),
                ),
                const SizedBox(width: 4),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _KanbanSyncStatus extends StatelessWidget {
  const _KanbanSyncStatus({required this.controller});

  final ProjectKanbanController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        if (controller.isLoading || controller.isLoadingBoard) {
          return const SizedBox.shrink();
        }
        final (label, icon) = controller.isMutating
            ? ('Salvando', Icons.sync_rounded)
            : ('Atenção', Icons.cloud_off_outlined);
        return Container(
          key: const ValueKey<String>('kanban-navbar-sync-status'),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Colors.black.withValues(alpha: 0.08),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                icon,
                size: 14,
                color: colorScheme.onPrimary,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _KanbanMetricsStrip extends StatelessWidget {
  const _KanbanMetricsStrip({
    required this.columns,
    required this.cards,
    required this.team,
  });

  final int? columns;
  final int? cards;
  final int team;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey<String>('kanban-project-metrics'),
      constraints: const BoxConstraints(minHeight: 36),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Row(
            children: <Widget>[
              Expanded(
                child: _KanbanMetricCell(
                  icon: Icons.view_column_outlined,
                  label: 'Colunas',
                  value: columns?.toString() ?? '—',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KanbanMetricCell(
                  icon: Icons.task_alt_outlined,
                  label: 'Cards',
                  value: cards?.toString() ?? '—',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _KanbanMetricCell(
                  icon: Icons.groups_2_outlined,
                  label: 'Equipe',
                  value: team.toString(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KanbanMetricCell extends StatelessWidget {
  const _KanbanMetricCell({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(icon, size: 14, color: colorScheme.primary),
          const SizedBox(width: 6),
          Text(value,
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(width: 4),
          Flexible(
              child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          )),
        ],
      ),
    );
  }
}

class _KanbanPageMessage extends StatelessWidget {
  const _KanbanPageMessage({
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.view_kanban_outlined,
                size: 44,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 16),
                FilledButton.tonal(
                  onPressed: onAction,
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _KanbanNotice extends StatelessWidget {
  const _KanbanNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          const Icon(Icons.info_outline_rounded),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(message),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Recarregar')),
        ],
      ),
    );
  }
}
