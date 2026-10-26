import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/projects/presentation/kanban_controller.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/project_backlog_view.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/project_kanban_board.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/task_editor_dialog.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_editor_dialog.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_instant_select_field.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_skeleton.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

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
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const WorkspaceNavigationDrawer(),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 1080;
          return Row(
            children: <Widget>[
              if (isWide)
                SizedBox(
                  width: 280,
                  child: WorkspaceDesktopNavigation(currentRoute: '/kanban'),
                ),
              Expanded(
                child: Builder(
                  builder: (scaffoldContext) => SafeArea(
                    child: Column(
                      children: <Widget>[
                        _KanbanTopBar(
                          controller: _controller,
                          onMenuPressed: isWide
                              ? null
                              : () => Scaffold.of(scaffoldContext).openDrawer(),
                          showBrand: !isWide,
                        ),
                        Expanded(
                          child: AnimatedBuilder(
                            animation: _controller,
                            builder: (context, _) => _buildPageBody(),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPageBody() {
    if (_controller.isLoading) {
      return const _KanbanPageSkeleton();
    }

    if (_controller.loadError != null) {
      return _KanbanPageMessage(
        title: 'Não foi possível carregar o Kanban',
        message: _controller.loadError!,
        actionLabel: 'Tentar novamente',
        onAction: _controller.retry,
      );
    }

    if (_controller.projects.isEmpty) {
      return const _KanbanPageMessage(
        title: 'Nenhum projeto disponível',
        message: 'Crie ou obtenha acesso a um projeto antes de usar o Kanban.',
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        final isWide = constraints.maxWidth >= 980;
        final horizontalPadding = isCompact ? 10.0 : (isWide ? 28.0 : 16.0);
        final verticalPadding = isCompact ? 8.0 : 14.0;
        final gap = isCompact ? 8.0 : 12.0;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            verticalPadding,
            horizontalPadding,
            isCompact ? 6 : verticalPadding,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _buildProjectOverview(compact: isCompact),
              SizedBox(height: gap),
              Expanded(child: _buildBoardContent()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectOverview({required bool compact}) {
    final colorScheme = Theme.of(context).colorScheme;
    final board = _controller.board;
    final cardCount = board?.columns.fold<int>(
          0,
          (total, column) => total + column.cards.length,
        ) ??
        0;

    final selector = WorkspaceInstantSelectField<String>(
      key: ValueKey<String?>(_controller.selectedProjectId),
      value: _controller.selectedProjectId,
      decoration: const InputDecoration(
        labelText: 'Projeto',
        isDense: true,
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
    );

    final metrics = _KanbanMetricsStrip(
      columns: board?.columns.length,
      cards: board == null ? null : cardCount,
      team: _controller.projectMembers.length,
    );

    final refresh = IconButton(
      tooltip: 'Atualizar quadro',
      visualDensity: VisualDensity.compact,
      onPressed: _controller.isMutating || _controller.isLoadingBoard
          ? null
          : () => _controller.reload(),
      icon: const Icon(Icons.refresh_rounded),
    );
    final viewSwitch = _buildProjectViewSwitch(compact: compact);

    return Material(
      key: const ValueKey<String>('kanban-project-overview'),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.28),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: EdgeInsets.all(compact ? 7 : 8),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (!compact && constraints.maxWidth >= 1080) {
              return Row(
                children: <Widget>[
                  Expanded(child: selector),
                  const SizedBox(width: 8),
                  viewSwitch,
                  const SizedBox(width: 8),
                  SizedBox(width: 292, child: metrics),
                  const SizedBox(width: 2),
                  refresh,
                ],
              );
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(child: selector),
                    const SizedBox(width: 4),
                    _buildProjectViewSwitch(compact: true),
                    const SizedBox(width: 2),
                    refresh,
                  ],
                ),
                const SizedBox(height: 6),
                metrics,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildProjectViewSwitch({required bool compact}) {
    final colors = Theme.of(context).colorScheme;
    return ToggleButtons(
      key: const ValueKey<String>('project-view-switch'),
      borderRadius: BorderRadius.zero,
      constraints: BoxConstraints(
        minWidth: compact ? 40 : 86,
        minHeight: 50,
      ),
      color: colors.onSurfaceVariant,
      selectedColor: colors.onPrimaryContainer,
      fillColor: colors.primaryContainer,
      borderColor: colors.outlineVariant,
      selectedBorderColor: colors.primary,
      isSelected: <bool>[!_showBacklog, _showBacklog],
      onPressed: (index) => setState(() => _showBacklog = index == 1),
      children: <Widget>[
        if (compact)
          const Tooltip(
            message: 'Kanban',
            child: Icon(Icons.view_kanban_outlined, size: 18),
          )
        else
          const Text('Kanban'),
        if (compact)
          const Tooltip(
            message: 'Backlog',
            child: Icon(Icons.view_list_outlined, size: 18),
          )
        else
          const Text('Backlog'),
      ],
    );
  }

  Widget _buildBoardContent() {
    if (_controller.isLoadingBoard) {
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
      final backlog = ProjectBacklogView(
        key: ValueKey<String>('project-backlog-${board.projectId}'),
        board: board,
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
              child: RepaintBoundary(
                child: ProjectKanbanBoard(
                  board: board,
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
    return const WorkspaceSkeletonRegion(
      key: ValueKey<String>('kanban-page-skeleton'),
      label: 'Carregando Kanban',
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Row(
              children: <Widget>[
                WorkspaceSkeleton(width: 148, height: 20),
                Spacer(),
                WorkspaceSkeleton(width: 112, height: 30),
              ],
            ),
            SizedBox(height: 12),
            Expanded(child: _KanbanBoardSkeletonBody()),
          ],
        ),
      ),
    );
  }
}

class _KanbanBoardSkeletonBody extends StatelessWidget {
  const _KanbanBoardSkeletonBody();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final laneCount = constraints.maxWidth >= 1050
            ? 3
            : constraints.maxWidth >= 680
                ? 2
                : 1;
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
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: List<Widget>.generate(laneCount, (index) {
                  return Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(
                          right: index == laneCount - 1 ? 0 : 12),
                      child: _KanbanLaneSkeleton(index: index),
                    ),
                  );
                }),
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
          color: colorScheme.surfaceContainerHighest,
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
  const _KanbanTopBar({
    required this.controller,
    required this.onMenuPressed,
    required this.showBrand,
  });

  final ProjectKanbanController controller;
  final VoidCallback? onMenuPressed;
  final bool showBrand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      key: const ValueKey<String>('kanban-topbar'),
      color: AppTheme.accent,
      child: SizedBox(
        height: 54,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: <Widget>[
              if (onMenuPressed != null) ...<Widget>[
                IconButton(
                  tooltip: 'Abrir menu',
                  onPressed: onMenuPressed,
                  icon: Icon(Icons.menu_rounded, color: colorScheme.onPrimary),
                ),
                const SizedBox(width: 6),
              ],
              if (showBrand)
                Text(
                  'TOUCHIN',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.82),
                    letterSpacing: 1.8,
                    fontWeight: FontWeight.w900,
                  ),
                ),
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
      ),
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
        final (label, icon) = controller.isMutating
            ? ('Salvando', Icons.sync_rounded)
            : controller.isLoading || controller.isLoadingBoard
                ? ('Sincronizando', Icons.sync_rounded)
                : controller.loadError != null || controller.boardError != null
                    ? ('Atenção', Icons.cloud_off_outlined)
                    : ('Sincronizado', Icons.cloud_done_outlined);
        return Container(
          key: const ValueKey<String>('kanban-navbar-sync-status'),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.1),
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
      height: 52,
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.58),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: _KanbanMetricCell(
              icon: Icons.view_column_outlined,
              label: 'Colunas',
              value: columns?.toString() ?? '—',
            ),
          ),
          VerticalDivider(width: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: _KanbanMetricCell(
              icon: Icons.task_alt_outlined,
              label: 'Cards',
              value: cards?.toString() ?? '—',
            ),
          ),
          VerticalDivider(width: 1, color: colorScheme.outlineVariant),
          Expanded(
            child: _KanbanMetricCell(
              icon: Icons.groups_2_outlined,
              label: 'Equipe',
              value: team.toString(),
            ),
          ),
        ],
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
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  value,
                  maxLines: 1,
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 9,
                    fontWeight: FontWeight.w600,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
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
