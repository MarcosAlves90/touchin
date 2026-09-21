import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/kanban.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/projects/presentation/project_tasks_controller.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/task_editor_dialog.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';

class ProjectKanbanPage extends StatefulWidget {
  const ProjectKanbanPage({super.key, this.api, this.controller});

  final TouchInApi? api;
  final ProjectTasksController? controller;

  @override
  State<ProjectKanbanPage> createState() => _ProjectKanbanPageState();
}

class _ProjectKanbanPageState extends State<ProjectKanbanPage> {
  late final ProjectTasksController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _controller =
        widget.controller ?? ProjectTasksController(api: widget.api);
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
        return WorkspaceScaffold(
          contentScrollable: false,
          sidebar: _buildSidebar(),
          contentBuilder: (context, isWide) => _buildContent(isWide),
        );
      },
    );
  }

  Widget _buildSidebar() {
    final project = _controller.selectedProject;
    final board = _controller.kanbanBoard;
    final cardCount = board?.columns.fold<int>(
          0,
          (total, column) => total + column.cards.length,
        ) ??
        0;

    return WorkspaceSidebar(
      title: 'Kanban por projeto.',
      description:
          'Organize o fluxo de trabalho do projeto selecionado em colunas e cards.',
      summaryChildren: <Widget>[
        WorkspaceSummaryStripe(
          label: 'Projeto',
          value: project?.name ?? 'Nenhum',
          helper: project == null
              ? 'Selecione um projeto para carregar o quadro.'
              : 'Quadro exclusivo deste projeto.',
        ),
        WorkspaceSummaryStripe(
          label: 'Colunas',
          value: board == null ? '—' : '${board.columns.length}',
          helper: 'Etapas configuradas no quadro atual.',
        ),
        WorkspaceSummaryStripe(
          label: 'Cards',
          value: board == null ? '—' : '$cardCount',
          helper: 'Tarefas representadas no quadro atual.',
        ),
      ],
      highlightChips: <Widget>[
        if (_controller.canManageKanbanStructure)
          const WorkspaceHighlightChip(label: 'Estrutura gerencial'),
        if (_controller.canMoveKanbanCards)
          const WorkspaceHighlightChip(label: 'Movimentação de cards'),
      ],
    );
  }

  Widget _buildContent(bool isWide) {
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

    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 32 : 20, 24, isWide ? 32 : 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const WorkspaceHeader(
            title: 'Kanban',
            description:
                'Acompanhe e mova os cards sem misturar o quadro com a tela administrativa de projetos e tarefas.',
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: isWide ? 420 : double.infinity,
            child: DropdownButtonFormField<String>(
              key: ValueKey<String?>(_controller.selectedProjectId),
              initialValue: _controller.selectedProjectId,
              decoration: const InputDecoration(
                labelText: 'Projeto',
                prefixIcon: Icon(Icons.account_tree_outlined),
              ),
              items: _controller.projects
                  .map(
                    (project) => DropdownMenuItem<String>(
                      value: project.id,
                      child: Text(
                        project.name,
                        overflow: TextOverflow.ellipsis,
                      ),
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
          ),
          const SizedBox(height: 16),
          Expanded(
            child: WorkspaceSectionCard(
              child: _buildBoardContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardContent() {
    if (_controller.isLoadingKanban) {
      return const Center(child: CircularProgressIndicator());
    }

    final board = _controller.kanbanBoard;
    if (board == null) {
      return _KanbanPageMessage(
        title: 'Quadro indisponível',
        message:
            _controller.kanbanError ?? 'Não foi possível carregar o Kanban.',
        actionLabel: 'Recarregar',
        onAction: _controller.reloadKanban,
      );
    }

    final columnCount = board.columns.length;
    final cardCount = board.columns.fold<int>(
      0,
      (total, column) => total + column.cards.length,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (_controller.kanbanError != null) ...<Widget>[
          _KanbanNotice(message: _controller.kanbanError!),
          const SizedBox(height: 12),
        ],
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(
                    'Diagnóstico do quadro',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Text('Colunas carregadas: $columnCount'),
                  const SizedBox(height: 4),
                  Text('Cards carregados: $cardCount'),
                  const SizedBox(height: 12),
                  Text(
                    'KanbanBoardView temporariamente isolado para verificar o deslocamento de pintura.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
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
      () => _controller.createKanbanColumn(name),
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
      () => _controller.renameKanbanColumn(column.id, name),
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
      () => _controller.deleteKanbanColumn(column.id),
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
      () => _controller.createTask(
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
      () => _controller.updateTask(card.toTaskRecord(), draft),
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
      () => _controller.deleteKanbanCard(card.id),
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
                      onChanged: _controller.isMutating ||
                              (!assigned && atCapacity)
                          ? null
                          : (selected) async {
                              Navigator.of(dialogContext).pop();
                              if (selected == true) {
                                await _runAction(
                                  () => _controller.addKanbanAssignee(
                                    card.id,
                                    member.employeeId,
                                  ),
                                  successMessage: 'Responsável adicionado.',
                                );
                              } else {
                                await _runAction(
                                  () => _controller.removeKanbanAssignee(
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
