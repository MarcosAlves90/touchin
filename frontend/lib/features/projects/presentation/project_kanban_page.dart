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
                    onMenuPressed: () => Scaffold.of(scaffoldContext).openDrawer(),
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
        final horizontalPadding = constraints.maxWidth >= 900 ? 28.0 : 16.0;
        return CustomScrollView(
          key: const ValueKey<String>('project-kanban-page-scroll'),
          physics: const ClampingScrollPhysics(),
          slivers: <Widget>[
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                20,
                horizontalPadding,
                0,
              ),
              sliver: SliverToBoxAdapter(
                child: _buildProjectToolbar(constraints.maxWidth),
              ),
            ),
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                16,
                horizontalPadding,
                20,
              ),
              sliver: SliverFillRemaining(
                hasScrollBody: false,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 360),
                  child: _buildBoardContent(),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildProjectToolbar(double availableWidth) {
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
              if (projectId != null && projectId != _controller.selectedProjectId) {
                _controller.selectProject(projectId);
              }
            },
    );

    final summary = Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        _KanbanMetricChip(
          icon: Icons.view_column_outlined,
          label: board == null ? '— colunas' : '${board.columns.length} colunas',
        ),
        _KanbanMetricChip(
          icon: Icons.task_alt_outlined,
          label: board == null ? '— cards' : '$cardCount cards',
        ),
      ],
    );

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          project?.name ?? 'Kanban por projeto',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Acompanhe e mova os cards do projeto selecionado.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 10),
        summary,
      ],
    );

    final wide = availableWidth >= 760;
    return Material(
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  Expanded(child: intro),
                  const SizedBox(width: 24),
                  SizedBox(width: 360, child: selector),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  intro,
                  const SizedBox(height: 16),
                  selector,
                ],
              ),
      ),
    );
  }

  Widget _buildBoardContent() {
    if (_controller.isLoadingBoard) {
      return const Center(child: CircularProgressIndicator());
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
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
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
                onMoveCard: (taskId, columnId, index) => _controller.moveCard(
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
  const _KanbanTopBar({required this.onMenuPressed});

  final VoidCallback onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: AppTheme.accent,
      child: SizedBox(
        height: 56,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Abrir menu',
                onPressed: onMenuPressed,
                icon: Icon(Icons.menu_rounded, color: colorScheme.onPrimary),
              ),
              const SizedBox(width: 8),
              Text(
                'Kanban',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KanbanMetricChip extends StatelessWidget {
  const _KanbanMetricChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: theme.textTheme.labelMedium),
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
