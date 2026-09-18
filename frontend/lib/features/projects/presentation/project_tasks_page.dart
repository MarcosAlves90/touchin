import 'package:bunchin_flutter/contracts/employee.dart';
import 'package:bunchin_flutter/contracts/project.dart';
import 'package:bunchin_flutter/contracts/task.dart';
import 'package:bunchin_flutter/core/network/api_client.dart';
import 'package:bunchin_flutter/core/network/bunchin_api.dart';
import 'package:bunchin_flutter/features/projects/presentation/project_tasks_controller.dart';
import 'package:bunchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:bunchin_flutter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ProjectTasksPage extends StatefulWidget {
  const ProjectTasksPage({super.key, this.api, this.controller});

  final BunchinApi? api;
  final ProjectTasksController? controller;

  @override
  State<ProjectTasksPage> createState() => _ProjectTasksPageState();
}

class _ProjectTasksPageState extends State<ProjectTasksPage> {
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
          sidebar: _buildSidebar(),
          contentBuilder: (context, isWide) => _buildContent(isWide),
        );
      },
    );
  }

  Widget _buildSidebar() {
    final project = _controller.selectedProject;
    final task = _controller.selectedTask;
    return WorkspaceSidebar(
      title: 'Painel de projetos da empresa.',
      description:
          'Acompanhe projetos, tarefas, acessos e capacidade em um só lugar.',
      summaryChildren: <Widget>[
        WorkspaceSummaryStripe(
          label: 'Projetos',
          value: _controller.isLoading ? '...' : '${_controller.projects.length}',
          helper: 'Projetos ativos disponíveis para a empresa atual.',
        ),
        WorkspaceSummaryStripe(
          label: 'Projeto selecionado',
          value: project?.name ?? 'Nenhum',
          helper: project == null
              ? 'Selecione ou crie um projeto para começar.'
              : '${_controller.tasks.length} tarefa(s) • limite ${project.taskEmployeeLimit} por tarefa',
        ),
        WorkspaceSummaryStripe(
          label: 'Tarefa selecionada',
          value: task?.name ?? 'Nenhuma',
          helper: task == null
              ? 'Selecione uma tarefa para consultar participantes.'
              : '${_controller.taskMembers.length} participante(s) na tarefa atual.',
        ),
      ],
      highlightChips: <Widget>[
        if (_controller.canManageProjects)
          const WorkspaceHighlightChip(label: 'Acesso gerencial'),
        if (_controller.canManageOwnTaskMembership)
          const WorkspaceHighlightChip(label: 'Participação em tarefas'),
      ],
    );
  }

  Widget _buildContent(bool isWide) {
    if (_controller.isLoading) {
      return const SizedBox(
        height: 520,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_controller.loadError != null) {
      return _PageMessage(
        title: 'Não foi possível carregar os projetos',
        message: _controller.loadError!,
        actionLabel: 'Tentar novamente',
        onAction: _controller.retry,
      );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(isWide ? 32 : 24, 28, isWide ? 32 : 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _buildWorkspaceHeader(isWide),
          const SizedBox(height: 16),
          _buildMetricGrid(isWide),
          const SizedBox(height: 20),
          _buildProjectsSection(isWide),
          if (_controller.selectedProject != null) ...<Widget>[
            const SizedBox(height: 20),
            _buildProjectAccessCard(),
            const SizedBox(height: 20),
            _buildTaskWorkspace(isWide),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkspaceHeader(bool isWide) {
    if (!isWide) {
      return WorkspaceHeader(
        title: 'Administrar projetos',
        description: '',
        maxContentWidth: 620,
        actions: _buildHeaderActions(false),
      );
    }

    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 620),
            child: Text(
              'Administrar projetos',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        ..._buildHeaderActions(true),
      ],
    );
  }

  List<Widget> _buildHeaderActions(bool isWide) {
    if (!_controller.canManageProjects) {
      return <Widget>[];
    }

    return <Widget>[
      SizedBox(
        width: isWide ? 210 : double.infinity,
        child: ElevatedButton.icon(
          onPressed: _controller.isMutating ? null : _openCreateProject,
          icon: const Icon(Icons.create_new_folder_outlined),
          label: const Text('Novo projeto'),
        ),
      ),
    ];
  }

  Widget _buildMetricGrid(bool isWide) {
    final project = _controller.selectedProject;
    final task = _controller.selectedTask;
    final occupancy = project == null || task == null
        ? '—'
        : '${_controller.taskMembers.length}/${project.taskEmployeeLimit}';

    return LayoutBuilder(
      builder: (context, constraints) {
        final useSingleRow = isWide && constraints.maxWidth >= 980;
        final useTwoColumns = !useSingleRow && constraints.maxWidth >= 500;
        final itemWidth = useTwoColumns
            ? (constraints.maxWidth - 8) / 2
            : constraints.maxWidth;
        final metricItems = <Widget>[
          _ProjectMetricItem(
            icon: Icons.folder_copy_outlined,
            label: 'Projetos',
            value: _controller.projects.length.toString(),
          ),
          _ProjectMetricItem(
            icon: Icons.account_tree_outlined,
            label: 'Tarefas',
            value: project == null ? '—' : _controller.tasks.length.toString(),
          ),
          _ProjectMetricItem(
            icon: Icons.groups_2_outlined,
            label: 'Acessos',
            value: project == null
                ? '—'
                : _controller.projectMembers.length.toString(),
          ),
          _ProjectMetricItem(
            icon: Icons.group_work_outlined,
            label: 'Ocupação',
            value: occupancy,
          ),
        ];

        if (useSingleRow) {
          return Row(
            children: metricItems.asMap().entries.map((entry) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: entry.key == metricItems.length - 1 ? 0 : 8,
                  ),
                  child: entry.value,
                ),
              );
            }).toList(),
          );
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: metricItems
              .map(
                (item) => SizedBox(
                  width: itemWidth,
                  child: item,
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildProjectsSection(bool isWide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSplitLayout = isWide && constraints.maxWidth >= 980;
        if (useSplitLayout) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 11, child: _buildProjectsListCard()),
              const SizedBox(width: 20),
              Expanded(flex: 9, child: _buildSelectedProjectCard()),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildProjectsListCard(),
            const SizedBox(height: 20),
            _buildSelectedProjectCard(),
          ],
        );
      },
    );
  }

  Widget _buildProjectsListCard() {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return WorkspaceSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            'Projetos',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Selecione um projeto para consultar dados, acessos e tarefas.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          if (_controller.projects.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: colorScheme.surface.withValues(alpha: 0.8),
                border: Border.all(color: colorScheme.outlineVariant),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Nenhum projeto disponível.',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Crie um projeto para começar a organizar tarefas e participantes.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  if (_controller.canManageProjects) ...<Widget>[
                    const SizedBox(height: 14),
                    OutlinedButton.icon(
                      onPressed: _controller.isMutating ? null : _openCreateProject,
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: const Text('Novo projeto'),
                    ),
                  ],
                ],
              ),
            )
          else
            Column(
              children: _controller.projects.map((project) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ProjectListTile(
                    project: project,
                    selected: project.id == _controller.selectedProjectId,
                    canManage: _controller.canManageProjects,
                    onTap: () => _controller.selectProject(project.id),
                    onEdit: () => _openEditProject(project),
                    onDelete: () => _confirmDeleteProject(project),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildSelectedProjectCard() {
    final project = _controller.selectedProject;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (project == null) {
      return WorkspaceSectionCard(
        child: Row(
          children: <Widget>[
            Icon(
              Icons.touch_app_rounded,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Selecione um projeto para ver os detalhes.',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return WorkspaceSectionCard(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final useTwoColumns = constraints.maxWidth >= 520;
          final overviewItemWidth = useTwoColumns
              ? (constraints.maxWidth - 12) / 2
              : constraints.maxWidth;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _ProjectDetailHero(
                project: project,
                canEdit: _controller.canManageProjects,
                isMutating: _controller.isMutating,
                onEdit: () => _openEditProject(project),
              ),
              const SizedBox(height: 12),
              Text(
                'Resumo rápido',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: <Widget>[
                  SizedBox(
                    width: overviewItemWidth,
                    child: _ProjectOverviewCard(
                      icon: Icons.account_tree_outlined,
                      label: 'Tarefas',
                      value: _controller.tasks.length.toString(),
                    ),
                  ),
                  SizedBox(
                    width: overviewItemWidth,
                    child: _ProjectOverviewCard(
                      icon: Icons.groups_2_outlined,
                      label: 'Acessos',
                      value: _controller.projectMembers.length.toString(),
                    ),
                  ),
                  SizedBox(
                    width: overviewItemWidth,
                    child: _ProjectOverviewCard(
                      icon: Icons.group_work_outlined,
                      label: 'Limite por tarefa',
                      value: project.taskEmployeeLimit.toString(),
                    ),
                  ),
                  SizedBox(
                    width: overviewItemWidth,
                    child: _ProjectOverviewCard(
                      icon: Icons.task_alt_outlined,
                      label: 'Tarefa atual',
                      value: _controller.selectedTask?.name ?? 'Nenhuma',
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTaskWorkspace(bool isWide) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useSplitLayout = isWide && constraints.maxWidth >= 980;
        if (useSplitLayout) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(flex: 11, child: _buildTasksCard()),
              const SizedBox(width: 20),
              Expanded(flex: 9, child: _buildMembershipCard()),
            ],
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _buildTasksCard(),
            const SizedBox(height: 20),
            _buildMembershipCard(),
          ],
        );
      },
    );
  }

  Widget _buildProjectAccessCard() {
    return WorkspaceSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          WorkspaceHeader(
            title: 'Acesso ao projeto',
            description:
                'Somente os funcionários adicionados aqui podem visualizar o projeto e assumir responsabilidades nas tarefas.',
            maxContentWidth: 620,
            actions: <Widget>[
              if (_controller.canManageProjects)
                FilledButton.tonalIcon(
                  onPressed: _controller.isMutating
                      ? null
                      : _openAddProjectMemberDialog,
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Adicionar ao projeto'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_controller.isLoadingProjectMembers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_controller.projectMembersError != null)
            _InlineError(
              message: _controller.projectMembersError!,
              onRetry: _controller.reloadProjectMembers,
            )
          else if (_controller.projectMembers.isEmpty)
            const _EmptyState(
              icon: Icons.group_off_outlined,
              title: 'Nenhum funcionário com acesso',
              description:
                  'Adicione funcionários ao projeto antes de atribuí-los às tarefas.',
            )
          else
            Column(
              children: _controller.projectMembers.map((member) {
                final isCurrent =
                    member.employeeId == _controller.currentEmployeeId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(_initials(member.employeeName)),
                  ),
                  title: Text(member.employeeName),
                  subtitle: Text(
                    isCurrent
                        ? 'Você • ${member.employeeId}'
                        : member.employeeId,
                  ),
                  trailing: _controller.canManageProjects
                      ? IconButton(
                          tooltip: 'Remover acesso ao projeto',
                          onPressed: _controller.isMutating
                              ? null
                              : () => _confirmRemoveProjectMember(member),
                          icon: const Icon(Icons.person_remove_outlined),
                        )
                      : null,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildTasksCard() {
    return WorkspaceSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          WorkspaceHeader(
            title: 'Tarefas',
            description:
                'As tarefas podem ter tipo e tarefa-pai, formando uma hierarquia dentro do projeto.',
            maxContentWidth: 520,
            actions: <Widget>[
              if (_controller.canManageTasks)
                FilledButton.tonalIcon(
                  onPressed: _controller.isMutating
                      ? null
                      : () => _openCreateTask(_controller.selectedProject!),
                  icon: const Icon(Icons.add_task_rounded),
                  label: const Text('Nova tarefa'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (_controller.isLoadingTasks)
            const Center(child: CircularProgressIndicator())
          else if (_controller.tasksError != null)
            _InlineError(
              message: _controller.tasksError!,
              onRetry: _controller.reloadTasks,
            )
          else if (_controller.tasks.isEmpty)
            const _EmptyState(
              icon: Icons.task_alt_rounded,
              title: 'Nenhuma tarefa criada',
              description: 'Crie a primeira tarefa para estruturar o projeto.',
            )
          else
            Column(
              children: _controller.tasks
                  .map(
                    (task) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _TaskTile(
                        task: task,
                        parentName: _parentTaskName(task),
                        selected: task.id == _controller.selectedTaskId,
                        canEdit: _controller.canManageTasks,
                        onSelected: () => _controller.selectTask(task.id),
                        onEdit: () => _openEditTask(task),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildMembershipCard() {
    final task = _controller.selectedTask;
    if (task == null) {
      return const _EmptyCard(
        icon: Icons.group_outlined,
        title: 'Selecione uma tarefa',
        description:
            'Escolha uma tarefa acima para consultar e gerenciar seus participantes.',
      );
    }

    final project = _controller.selectedProject!;
    return WorkspaceSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          WorkspaceHeader(
            title: 'Participantes de ${task.name}',
            description:
                '${_controller.taskMembers.length} de ${project.taskEmployeeLimit} vaga(s) ocupada(s).',
            maxContentWidth: 520,
            actions: <Widget>[
              if (_controller.canManageOwnTaskMembership &&
                  _controller.currentEmployeeIsMember)
                OutlinedButton.icon(
                  onPressed: _controller.isMutating
                      ? null
                      : () => _runAction(
                            _controller.leaveSelectedTask,
                            successMessage: 'Você saiu da tarefa.',
                          ),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sair da tarefa'),
                )
              else if (_controller.canJoinSelectedTask)
                FilledButton.tonalIcon(
                  onPressed: _controller.isMutating
                      ? null
                      : () => _runAction(
                            _controller.joinSelectedTask,
                            successMessage: 'Você entrou na tarefa.',
                          ),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Entrar na tarefa'),
                ),
              if (_controller.canManageMembership)
                OutlinedButton.icon(
                  onPressed:
                      _controller.isMutating ? null : _openAddMemberDialog,
                  icon: const Icon(Icons.group_add_outlined),
                  label: const Text('Adicionar membro'),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (!_controller.canManageMembership)
            const _InfoBanner(
              message:
                  'Você pode entrar ou sair da tarefa, mas somente gestores podem adicionar ou remover outras pessoas.',
            ),
          if (_controller.isLoadingMembers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_controller.membersError != null)
            _InlineError(
              message: _controller.membersError!,
              onRetry: _controller.reloadMembers,
            )
          else if (_controller.taskMembers.isEmpty)
            const _EmptyState(
              icon: Icons.person_off_outlined,
              title: 'Nenhum participante',
              description: 'Ainda há vagas disponíveis nesta tarefa.',
            )
          else
            Column(
              children: _controller.taskMembers.map((member) {
                final isCurrent =
                    member.employeeId == _controller.currentEmployeeId;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    child: Text(_initials(member.employeeName)),
                  ),
                  title: Text(member.employeeName),
                  subtitle: Text(
                    isCurrent ? 'Você • ${member.employeeId}' : member.employeeId,
                  ),
                  trailing: _controller.canManageMembership
                      ? IconButton(
                          tooltip: isCurrent
                              ? 'Sair da tarefa'
                              : 'Remover da tarefa',
                          onPressed: _controller.isMutating
                              ? null
                              : () => _runAction(
                                    () => _controller
                                        .removeMemberFromSelectedTask(
                                      member.employeeId,
                                    ),
                                    successMessage: isCurrent
                                        ? 'Você saiu da tarefa.'
                                        : 'Membro removido da tarefa.',
                                  ),
                          icon: const Icon(Icons.person_remove_outlined),
                        )
                      : null,
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  String? _parentTaskName(TaskRecord task) {
    final parentId = task.parentTaskId;
    if (parentId == null) {
      return null;
    }
    for (final candidate in _controller.tasks) {
      if (candidate.id == parentId) {
        return candidate.name;
      }
    }
    return parentId;
  }

  Future<void> _openCreateProject() async {
    final draft = await showDialog<ProjectDraft>(
      context: context,
      builder: (_) => const _ProjectEditorDialog(),
    );
    if (draft == null) {
      return;
    }
    await _runAction(
      () => _controller.createProject(draft),
      successMessage: 'Projeto criado.',
    );
  }

  Future<void> _openEditProject(ProjectSummary project) async {
    final draft = await showDialog<ProjectDraft>(
      context: context,
      builder: (_) => _ProjectEditorDialog(project: project),
    );
    if (draft == null) {
      return;
    }
    await _runAction(
      () => _controller.updateProject(project, draft),
      successMessage: 'Projeto atualizado.',
    );
  }

  Future<void> _confirmDeleteProject(ProjectSummary project) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Excluir projeto'),
        content: Text(
          'Deseja excluir “${project.name}”? O projeto deixará de aparecer na gestão.',
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
      () => _controller.deleteProject(project),
      successMessage: 'Projeto excluído.',
    );
  }

  Future<void> _openCreateTask(ProjectSummary project) async {
    final draft = await showDialog<TaskDraft>(
      context: context,
      builder: (_) => _TaskEditorDialog(
        project: project,
        tasks: _controller.tasks,
      ),
    );
    if (draft == null) {
      return;
    }
    await _runAction(
      () => _controller.createTask(draft),
      successMessage: 'Tarefa criada.',
    );
  }

  Future<void> _openEditTask(TaskRecord task) async {
    final draft = await showDialog<TaskDraft>(
      context: context,
      builder: (_) => _TaskEditorDialog(
        project: _controller.selectedProject!,
        tasks: _controller.tasks,
        task: task,
      ),
    );
    if (draft == null) {
      return;
    }
    await _runAction(
      () => _controller.updateTask(task, draft),
      successMessage: 'Tarefa atualizada.',
    );
  }

  Future<void> _openAddProjectMemberDialog() async {
    final employeeId = await showDialog<String>(
      context: context,
      builder: (_) => _AddProjectMemberDialog(
        employees: _controller.employees,
        existingEmployeeIds: _controller.projectMembers
            .map((member) => member.employeeId)
            .toSet(),
      ),
    );
    if (employeeId == null) {
      return;
    }
    await _runAction(
      () => _controller.addMemberToSelectedProject(employeeId),
      successMessage: 'Funcionário adicionado ao projeto.',
    );
  }

  Future<void> _confirmRemoveProjectMember(ProjectMemberSummary member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remover acesso ao projeto'),
        content: Text(
          'Remover “${member.employeeName}” deste projeto? As responsabilidades dessa pessoa nas tarefas do projeto também serão removidas.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    await _runAction(
      () => _controller.removeMemberFromSelectedProject(member.employeeId),
      successMessage: 'Acesso ao projeto removido.',
    );
  }

  Future<void> _openAddMemberDialog() async {
    final employeeId = await showDialog<String>(
      context: context,
      builder: (_) => _AddTaskMemberDialog(
        projectMembers: _controller.projectMembers,
        existingEmployeeIds: _controller.taskMembers
            .map((member) => member.employeeId)
            .toSet(),
      ),
    );
    if (employeeId == null) {
      return;
    }
    await _runAction(
      () => _controller.addMemberToSelectedTask(employeeId),
      successMessage: 'Membro adicionado à tarefa.',
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

class _ProjectMetricItem extends StatelessWidget {
  const _ProjectMetricItem({
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.58),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(icon, size: 16, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
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
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectListTile extends StatelessWidget {
  const _ProjectListTile({
    required this.project,
    required this.selected,
    required this.canManage,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ProjectSummary project;
  final bool selected;
  final bool canManage;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AppTheme.accent.withValues(alpha: 0.08)
                : colorScheme.surface.withValues(alpha: 0.8),
            border: Border.all(
              color: selected ? AppTheme.accent : colorScheme.outlineVariant,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxWidth < 560;
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  if (!isCompact) ...<Widget>[
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppTheme.accent.withValues(alpha: 0.16)
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.72),
                        border: Border.all(
                          color: selected
                              ? AppTheme.accent.withValues(alpha: 0.36)
                              : colorScheme.outlineVariant,
                        ),
                      ),
                      child: Icon(
                        Icons.folder_open_rounded,
                        size: 20,
                        color: selected
                            ? AppTheme.accent
                            : colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Expanded(
                              child: Text(
                                project.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            if (canManage) ...<Widget>[
                              const SizedBox(width: 6),
                              IconButton(
                                onPressed: onEdit,
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Editar projeto',
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                onPressed: onDelete,
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints.tightFor(
                                  width: 32,
                                  height: 32,
                                ),
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Excluir projeto',
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Limite ${project.taskEmployeeLimit} por tarefa • ${project.status == ProjectStatus.active ? 'Ativo' : 'Inativo'}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            height: 1.2,
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

class _ProjectDetailHero extends StatelessWidget {
  const _ProjectDetailHero({
    required this.project,
    required this.canEdit,
    required this.isMutating,
    required this.onEdit,
  });

  final ProjectSummary project;
  final bool canEdit;
  final bool isMutating;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusColor = project.status == ProjectStatus.active
        ? const Color(0xFF2F8F46)
        : colorScheme.onSurfaceVariant;
    final showIdentityIcon = MediaQuery.sizeOf(context).width >= 560;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 620;
          final identityBlock = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (showIdentityIcon) ...<Widget>[
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.28),
                    ),
                  ),
                  child: Icon(
                    Icons.account_tree_rounded,
                    size: 28,
                    color: statusColor,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Projeto selecionado',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
                        _ProjectPill(
                          label: project.status == ProjectStatus.active
                              ? 'Ativo'
                              : 'Inativo',
                          tone: statusColor,
                          icon: project.status == ProjectStatus.active
                              ? Icons.check_circle_outline_rounded
                              : Icons.pause_circle_outline_rounded,
                        ),
                        _ProjectPill(
                          label: 'Limite ${project.taskEmployeeLimit}/tarefa',
                          tone: colorScheme.onSurfaceVariant,
                          icon: Icons.groups_2_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      project.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      project.description?.trim().isNotEmpty == true
                          ? project.description!
                          : 'Sem descrição.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );

          if (!canEdit) {
            return identityBlock;
          }

          final editButton = OutlinedButton.icon(
            onPressed: isMutating ? null : onEdit,
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Editar'),
          );

          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                identityBlock,
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: editButton),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: identityBlock),
              const SizedBox(width: 12),
              SizedBox(width: 128, child: editButton),
            ],
          );
        },
      ),
    );
  }
}

class _ProjectPill extends StatelessWidget {
  const _ProjectPill({
    required this.label,
    required this.tone,
    required this.icon,
  });

  final String label;
  final Color tone;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        border: Border.all(color: tone.withValues(alpha: 0.22)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 14, color: tone),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: tone,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectOverviewCard extends StatelessWidget {
  const _ProjectOverviewCard({
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.82),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.88),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w700,
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

class _TaskTile extends StatelessWidget {
  const _TaskTile({
    required this.task,
    required this.parentName,
    required this.selected,
    required this.canEdit,
    required this.onSelected,
    required this.onEdit,
  });

  final TaskRecord task;
  final String? parentName;
  final bool selected;
  final bool canEdit;
  final VoidCallback onSelected;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.5)
          : colorScheme.surface.withValues(alpha: 0.72),
      child: InkWell(
        onTap: onSelected,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? colorScheme.primary : colorScheme.outlineVariant,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(_taskTypeIcon(task.type), size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          task.name,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        Chip(
                          visualDensity: VisualDensity.compact,
                          label: Text(_taskTypeLabel(task.type)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      task.description,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (parentName != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        'Subtarefa de: $parentName',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                      ),
                    ],
                  ],
                ),
              ),
              if (canEdit)
                IconButton(
                  tooltip: 'Editar tarefa',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectEditorDialog extends StatefulWidget {
  const _ProjectEditorDialog({this.project});

  final ProjectSummary? project;

  @override
  State<_ProjectEditorDialog> createState() => _ProjectEditorDialogState();
}

class _ProjectEditorDialogState extends State<_ProjectEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _limitController;
  late ProjectStatus _status;

  @override
  void initState() {
    super.initState();
    final project = widget.project;
    _nameController = TextEditingController(text: project?.name ?? '');
    _descriptionController =
        TextEditingController(text: project?.description ?? '');
    _limitController = TextEditingController(
      text: '${project?.taskEmployeeLimit ?? 1}',
    );
    _status = project?.status ?? ProjectStatus.active;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _limitController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.project == null ? 'Novo projeto' : 'Editar projeto'),
      content: SizedBox(
        width: 520,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: projectNameMaxLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (value) => _requiredTextWithinLimit(
                    value,
                    maxLength: projectNameMaxLength,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: projectDescriptionMaxLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  validator: (value) => _requiredTextWithinLimit(
                    value,
                    maxLength: projectDescriptionMaxLength,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _limitController,
                  keyboardType: TextInputType.number,
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  decoration: InputDecoration(
                    labelText: 'Máximo de funcionários por tarefa',
                    helperText: widget.project == null
                        ? 'Define a capacidade máxima de participantes em cada tarefa.'
                        : 'Ao reduzir, o limite não pode ficar abaixo da quantidade de funcionários já associada a nenhuma tarefa existente.',
                    helperMaxLines: 3,
                  ),
                  validator: (value) {
                    final parsed = int.tryParse(value?.trim() ?? '');
                    if (parsed == null || parsed < 1) {
                      return 'Informe um número maior ou igual a 1.';
                    }
                    if (parsed > 2147483647) {
                      return 'Informe um número menor ou igual a 2147483647.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<ProjectStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const <DropdownMenuItem<ProjectStatus>>[
                    DropdownMenuItem(
                      value: ProjectStatus.active,
                      child: Text('Ativo'),
                    ),
                    DropdownMenuItem(
                      value: ProjectStatus.inactive,
                      child: Text('Inativo'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _status = value);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              ProjectDraft(
                name: _nameController.text,
                description: _descriptionController.text,
                taskEmployeeLimit: int.parse(_limitController.text.trim()),
                status: _status,
              ),
            );
          },
          child: Text(widget.project == null ? 'Criar projeto' : 'Salvar'),
        ),
      ],
    );
  }
}

class _TaskEditorDialog extends StatefulWidget {
  const _TaskEditorDialog({
    required this.project,
    required this.tasks,
    this.task,
  });

  final ProjectSummary project;
  final List<TaskRecord> tasks;
  final TaskRecord? task;

  @override
  State<_TaskEditorDialog> createState() => _TaskEditorDialogState();
}

class _TaskEditorDialogState extends State<_TaskEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late TaskType _type;
  String? _parentTaskId;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.task?.name ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
    _type = widget.task?.type ?? TaskType.feature;
    _parentTaskId = widget.task?.parentTaskId;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final possibleParents = widget.tasks
        .where((candidate) => candidate.id != widget.task?.id)
        .toList();

    return AlertDialog(
      title: Text(widget.task == null ? 'Nova tarefa' : 'Editar tarefa'),
      content: SizedBox(
        width: 540,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: _nameController,
                  autofocus: true,
                  maxLength: taskNameMaxLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  decoration: const InputDecoration(labelText: 'Nome'),
                  validator: (value) => _requiredTextWithinLimit(
                    value,
                    maxLength: taskNameMaxLength,
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: taskDescriptionMaxLength,
                  maxLengthEnforcement: MaxLengthEnforcement.enforced,
                  decoration: const InputDecoration(labelText: 'Descrição'),
                  validator: (value) => _requiredTextWithinLimit(
                    value,
                    maxLength: taskDescriptionMaxLength,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<TaskType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: TaskType.values
                      .map(
                        (type) => DropdownMenuItem<TaskType>(
                          value: type,
                          child: Text(_taskTypeLabel(type)),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _type = value);
                    }
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _parentTaskId ?? '',
                  decoration: const InputDecoration(
                    labelText: 'Tarefa-pai',
                    helperText: 'Opcional',
                  ),
                  items: <DropdownMenuItem<String>>[
                    const DropdownMenuItem<String>(
                      value: '',
                      child: Text('Sem tarefa-pai'),
                    ),
                    ...possibleParents.map(
                      (task) => DropdownMenuItem<String>(
                        value: task.id,
                        child: Text(task.name),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(
                    () => _parentTaskId = value == null || value.isEmpty ? null : value,
                  ),
                ),
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Projeto: ${widget.project.name}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (!_formKey.currentState!.validate()) {
              return;
            }
            Navigator.of(context).pop(
              TaskDraft(
                name: _nameController.text,
                description: _descriptionController.text,
                type: _type,
                parentTaskId: _parentTaskId,
              ),
            );
          },
          child: Text(widget.task == null ? 'Criar tarefa' : 'Salvar'),
        ),
      ],
    );
  }
}

class _AddProjectMemberDialog extends StatefulWidget {
  const _AddProjectMemberDialog({
    required this.employees,
    required this.existingEmployeeIds,
  });

  final List<EmployeeProfile> employees;
  final Set<String> existingEmployeeIds;

  @override
  State<_AddProjectMemberDialog> createState() =>
      _AddProjectMemberDialogState();
}

class _AddProjectMemberDialogState extends State<_AddProjectMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedEmployeeId;

  @override
  Widget build(BuildContext context) {
    final availableEmployees = widget.employees
        .where(
          (employee) => !widget.existingEmployeeIds.contains(employee.id),
        )
        .toList();

    return AlertDialog(
      title: const Text('Adicionar ao projeto'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: availableEmployees.isEmpty
              ? const Text(
                  'Todos os funcionários disponíveis já possuem acesso a este projeto.',
                )
              : DropdownButtonFormField<String>(
                  initialValue: _selectedEmployeeId,
                  decoration: const InputDecoration(labelText: 'Funcionário'),
                  items: availableEmployees
                      .map(
                        (employee) => DropdownMenuItem<String>(
                          value: employee.id,
                          child: Text(employee.name),
                        ),
                      )
                      .toList(),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Selecione um funcionário.'
                      : null,
                  onChanged: (value) => setState(
                    () => _selectedEmployeeId = value,
                  ),
                ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: availableEmployees.isEmpty
              ? null
              : () {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  Navigator.of(context).pop(_selectedEmployeeId);
                },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _AddTaskMemberDialog extends StatefulWidget {
  const _AddTaskMemberDialog({
    required this.projectMembers,
    required this.existingEmployeeIds,
  });

  final List<ProjectMemberSummary> projectMembers;
  final Set<String> existingEmployeeIds;

  @override
  State<_AddTaskMemberDialog> createState() => _AddTaskMemberDialogState();
}

class _AddTaskMemberDialogState extends State<_AddTaskMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedEmployeeId;

  @override
  Widget build(BuildContext context) {
    final availableMembers = widget.projectMembers
        .where(
          (member) => !widget.existingEmployeeIds.contains(member.employeeId),
        )
        .toList();

    return AlertDialog(
      title: const Text('Adicionar responsável'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: availableMembers.isEmpty
              ? const Text(
                  'Não há membros do projeto disponíveis para esta tarefa.',
                )
              : DropdownButtonFormField<String>(
                  initialValue: _selectedEmployeeId,
                  decoration: const InputDecoration(
                    labelText: 'Membro do projeto',
                    helperText:
                        'Somente pessoas com acesso ao projeto podem assumir tarefas.',
                  ),
                  items: availableMembers
                      .map(
                        (member) => DropdownMenuItem<String>(
                          value: member.employeeId,
                          child: Text(member.employeeName),
                        ),
                      )
                      .toList(),
                  validator: (value) => value == null || value.isEmpty
                      ? 'Selecione um membro do projeto.'
                      : null,
                  onChanged: (value) => setState(
                    () => _selectedEmployeeId = value,
                  ),
                ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: availableMembers.isEmpty
              ? null
              : () {
                  if (!_formKey.currentState!.validate()) {
                    return;
                  }
                  Navigator.of(context).pop(_selectedEmployeeId);
                },
          child: const Text('Adicionar'),
        ),
      ],
    );
  }
}

class _PageMessage extends StatelessWidget {
  const _PageMessage({
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String message;
  final String actionLabel;
  final Future<void> Function() onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: WorkspaceSectionCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.error_outline_rounded, size: 42),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => onAction(),
              child: Text(actionLabel),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return WorkspaceSectionCard(
      child: _EmptyState(icon: icon, title: title, description: description),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(icon, size: 38, color: colorScheme.onSurfaceVariant),
            const SizedBox(height: 12),
            Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.error_outline_rounded),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
        TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
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

String? _requiredText(String? value) {
  if (value == null || value.trim().isEmpty) {
    return 'Campo obrigatório.';
  }
  return null;
}

String? _requiredTextWithinLimit(
  String? value, {
  required int maxLength,
}) {
  final requiredError = _requiredText(value);
  if (requiredError != null) {
    return requiredError;
  }
  if (value!.trim().length > maxLength) {
    return 'Máximo de $maxLength caracteres.';
  }
  return null;
}

String _taskTypeLabel(TaskType type) {
  return switch (type) {
    TaskType.bug => 'Bug',
    TaskType.improvement => 'Melhoria',
    TaskType.feature => 'Feature',
  };
}

IconData _taskTypeIcon(TaskType type) {
  return switch (type) {
    TaskType.bug => Icons.bug_report_outlined,
    TaskType.improvement => Icons.auto_fix_high_outlined,
    TaskType.feature => Icons.new_releases_outlined,
  };
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
    return parts.first.substring(0, 1).toUpperCase();
  }
  return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
}
