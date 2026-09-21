import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/projects/presentation/kanban_controller.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/project_kanban_board.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/task_editor_dialog.dart';
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
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Scaffold(
          drawer: const WorkspaceNavigationDrawer(),
          body: Builder(
            builder: (scaffoldContext) => SafeArea(
              child: Column(
                children: <Widget>[
                  _KanbanTopBar(
                    projectName: _controller.selectedProject?.name,
                    isBusy: _controller.isMutating,
                    onMenuPressed: () =>
                        Scaffold.of(scaffoldContext).openDrawer(),
                  ),
                  Expanded(child: _buildPageBody()),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPageBody() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
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
        final isWide = constraints.maxWidth >= 980;
        final horizontalPadding = isWide ? 32.0 : 16.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            horizontalPadding,
            isWide ? 24 : 18,
            horizontalPadding,
            isWide ? 24 : 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              WorkspaceHeader(
                title: 'Kanban do projeto',
                description:
                    'Acompanhe e mova os cards do projeto selecionado.',
                maxContentWidth: 680,
                actions: <Widget>[
                  SizedBox(
                    width: 160,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: _controller.isMutating ||
                              _controller.isLoadingBoard
                          ? null
                          : () => _controller.reload(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Atualizar'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildProjectOverview(),
              const SizedBox(height: 16),
              Expanded(child: _buildBoardContent()),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProjectOverview() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final project = _controller.selectedProject;
    final board = _controller.board;
    final cardCount = board?.columns.fold<int>(
          0,
          (total, column) => total + column.cards.length,
        ) ??
        0;

    final selector = DropdownButtonFormField<String>(
      key: ValueKey<String?>(_controller.selectedProjectId),
      initialValue: _controller.selectedProjectId,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Projeto',
        prefixIcon: Icon(Icons.account_tree_outlined),
      ),
      items: _controller.projects
          .map(
            (project) => DropdownMenuItem<String>(
              value: project.id,
              child: Text(project.name, overflow: TextOverflow.ellipsis),
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

    final metrics = <Widget>[
      _KanbanMetricItem(
        icon: Icons.view_column_outlined,
        label: 'Colunas',
        value: board == null ? '—' : '${board.columns.length}',
      ),
      _KanbanMetricItem(
        icon: Icons.task_alt_outlined,
        label: 'Cards',
        value: board == null ? '—' : '$cardCount',
      ),
      _KanbanMetricItem(
        icon: Icons.groups_2_outlined,
        label: 'Equipe',
        value: '${_controller.projectMembers.length}',
      ),
    ];

    return WorkspaceSectionCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 860;
          final identity = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'PROJETO ATUAL',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                project?.name ?? 'Kanban por projeto',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              if ((project?.description ?? '').trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 4),
                Text(
                  project?.description ?? '',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ],
          );

          final contextRow = wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: <Widget>[
                    Expanded(child: identity),
                    const SizedBox(width: 24),
                    SizedBox(width: 340, child: selector),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    identity,
                    const SizedBox(height: 14),
                    selector,
                  ],
                );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              contextRow,
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, metricConstraints) {
                  final singleRow = metricConstraints.maxWidth >= 680;
                  if (singleRow) {
                    return Row(
                      children: metrics.asMap().entries.map((entry) {
                        return Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: entry.key == metrics.length - 1 ? 0 : 8,
                            ),
                            child: entry.value,
                          ),
                        );
                      }).toList(),
                    );
                  }
                  final twoColumns = metricConstraints.maxWidth >= 300;
                  final itemWidth = twoColumns
                      ? (metricConstraints.maxWidth - 8) / 2
                      : metricConstraints.maxWidth;
                  return Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: metrics
                        .map(
                          (metric) => SizedBox(
                            width: itemWidth,
                            child: metric,
                          ),
                        )
                        .toList(),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBoardContent() {
    if (_controller.isLoadingBoard) {
      return const Center(
        key: ValueKey<String>('kanban-board-loading'),
        child: CircularProgressIndicator(),
      );
    }

    final board = _controller.board;
    if (board == null) {
      return _KanbanPageMessage(
        title: 'Quadro indisponível',
        message: _controller.boardError ?? 'Não foi possível carregar o Kanban.',
        actionLabel: 'Recarregar',
        onAction: _controller.reload,
      );
    }

    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      key: ValueKey<String>('kanban-board-${board.kanbanVersion}'),
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Stack(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (_controller.boardError != null) ...<Widget>[
                  _KanbanNotice(message: _controller.boardError!),
                  const SizedBox(height: 12),
                ],
                Expanded(
                  child: ProjectKanbanBoard(
                    board: board,
                    isBusy: _controller.isMutating,
                    canMoveCards: _controller.canMoveCards,
                    canManageStructure: _controller.canManageStructure,
                    canManageCards: _controller.canManageCards,
                    canManageAssignees: _controller.canManageAssignees,
                    onMoveCard: (taskId, columnId, index) =>
                        _controller.moveCard(
                      taskId: taskId,
                      toColumnId: columnId,
                      toIndex: index,
                    ),
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
              ],
            ),
          ),
          if (_controller.isMutating)
            const Positioned(
              left: 0,
              top: 0,
              right: 0,
              child: LinearProgressIndicator(minHeight: 2),
            ),
        ],
      ),
    );
  }

  Future<String?> _promptKanbanColumnName({
    required String title,
    String initialValue = '',
  }) async {
    final controller = TextEditingController(text: initialValue);
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 160,
          decoration: const InputDecoration(labelText: 'Nome da coluna'),
          onSubmitted: (value) {
            final trimmed = value.trim();
            if (trimmed.isNotEmpty) {
              Navigator.of(dialogContext).pop(trimmed);
            }
          },
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                Navigator.of(dialogContext).pop(trimmed);
              }
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    controller.dispose();
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
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir coluna?'),
        content: Text(
          'A coluna "${column.name}" só pode ser excluída quando estiver vazia '
          'e não for a última coluna do quadro.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
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
    final project = _controller.selectedProject;
    if (project == null) {
      return;
    }
    final draft = await showDialog<TaskDraft>(
      context: context,
      builder: (_) => ProjectTaskEditorDialog(
        project: project,
        tasks: _controller.tasks,
      ),
    );
    if (draft == null) {
      return;
    }
    await _runAction(
      () => _controller.createCard(
        TaskDraft(
          name: draft.name,
          description: draft.description,
          type: draft.type,
          parentTaskId: draft.parentTaskId,
          columnId: column.id,
        ),
      ),
      successMessage: 'Card criado em ${column.name}.',
    );
  }

  Future<void> _openEditKanbanCard(KanbanCard card) async {
    final project = _controller.selectedProject;
    if (project == null) {
      return;
    }
    final draft = await showDialog<TaskDraft>(
      context: context,
      builder: (_) => ProjectTaskEditorDialog(
        project: project,
        tasks: _controller.tasks,
        task: card.toTaskRecord(),
      ),
    );
    if (draft == null) {
      return;
    }
    await _runAction(
      () => _controller.updateCard(card.toTaskRecord(), draft),
      successMessage: 'Card atualizado.',
    );
  }

  Future<void> _confirmDeleteKanbanCard(KanbanCard card) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Excluir #${card.cardNumber}?'),
        content: Text(
          'O card "${card.name}" será removido. O número '
          '#${card.cardNumber} não será reutilizado.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Excluir'),
          ),
        ],
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
    if (project == null) {
      return;
    }
    final assignedIds = card.assignees.map((item) => item.employeeId).toSet();
    final atCapacity = assignedIds.length >= project.taskEmployeeLimit;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Responsáveis de #${card.cardNumber}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                '${assignedIds.length}/${project.taskEmployeeLimit} responsável(is)',
              ),
              const SizedBox(height: 12),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: _controller.projectMembers.map((member) {
                    final assigned = assignedIds.contains(member.employeeId);
                    return CheckboxListTile(
                      value: assigned,
                      title: Text(member.employeeName),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: _controller.isMutating || (!assigned && atCapacity)
                          ? null
                          : (selected) async {
                              Navigator.of(dialogContext).pop();
                              if (selected == true) {
                                await _runAction(
                                  () => _controller.addAssignee(
                                    card.id,
                                    member.employeeId,
                                  ),
                                  successMessage: 'Responsável adicionado.',
                                );
                              } else {
                                await _runAction(
                                  () => _controller.removeAssignee(
                                    card.id,
                                    member.employeeId,
                                  ),
                                  successMessage: 'Responsável removido.',
                                );
                              }
                            },
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fechar'),
          ),
        ],
      ),
    );
  }

  Future<void> _runAction(
    Future<dynamic> Function() action, {
    required String successMessage,
  }) async {
    try {
      await action();
      if (!mounted) {
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

class _KanbanTopBar extends StatelessWidget {
  const _KanbanTopBar({
    required this.projectName,
    required this.isBusy,
    required this.onMenuPressed,
  });

  final String? projectName;
  final bool isBusy;
  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Material(
      color: AppTheme.accent,
      child: SizedBox(
        height: 58,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final showContext = constraints.maxWidth >= 680;
              return Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Abrir menu',
                    onPressed: onMenuPressed,
                    icon: Icon(
                      Icons.menu_rounded,
                      color: colorScheme.onPrimary,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'TOUCHIN',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.onPrimary.withValues(alpha: 0.82),
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 24,
                    color: colorScheme.onPrimary.withValues(alpha: 0.2),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.view_kanban_outlined,
                    size: 20,
                    color: colorScheme.onPrimary,
                  ),
                  const SizedBox(width: 7),
                  Text(
                    'Kanban',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (showContext && projectName != null) ...<Widget>[
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        '· $projectName',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colorScheme.onPrimary.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  if (showContext)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
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
                            isBusy
                                ? Icons.sync_rounded
                                : Icons.cloud_done_outlined,
                            size: 15,
                            color: colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            isBusy ? 'Salvando alterações' : 'Atualizado',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: colorScheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _KanbanMetricItem extends StatelessWidget {
  const _KanbanMetricItem({
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.68),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.1),
              border: Border.all(
                color: colorScheme.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Icon(icon, size: 16, color: colorScheme.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
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
  const _KanbanNotice({required this.message});

  final String message;

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
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}
