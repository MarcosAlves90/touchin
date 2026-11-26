import 'dart:async';

import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_editor_dialog.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_skeleton.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_controller.dart';
import 'package:touchin_flutter/theme/app_theme.dart';
import 'package:touchin_flutter/theme/workspace_menu_style.dart';

class WorkLogSubmission {
  const WorkLogSubmission({
    required this.projectId,
    required this.workLog,
  });

  final String? projectId;
  final WorkLogPayload workLog;
}

class WorkLogDialog extends StatefulWidget {
  const WorkLogDialog({
    super.key,
    required this.controller,
  });

  final TimeClockController controller;

  @override
  State<WorkLogDialog> createState() => _WorkLogDialogState();
}

class _WorkLogDialogState extends State<WorkLogDialog> {
  // Only a dropdown value; never sent to the API or persisted.
  static const String _noProjectOption = '__no_project__';
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _taskSearchController = TextEditingController();
  final FocusNode _taskSearchFocusNode = FocusNode();
  final Set<String> _selectedTaskIds = <String>{};
  String? _selectedProjectId;
  String? _loadError;
  Timer? _recommendationDebounce;
  String _recommendationSnapshot = '';

  bool get _canSubmit =>
      _selectedProjectId != null &&
      _descriptionController.text.trim().isNotEmpty &&
      (_selectedProjectId == _noProjectOption || _selectedTaskIds.isNotEmpty);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_controllerChanged);
    _recommendationSnapshot = _currentRecommendationSnapshot;
    if (widget.controller.workLogProjects.isEmpty) {
      _selectedProjectId = _noProjectOption;
    }
    _descriptionController.addListener(_descriptionChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_controllerChanged);
    _descriptionController
      ..removeListener(_descriptionChanged)
      ..dispose();
    _taskSearchController.dispose();
    _taskSearchFocusNode.dispose();
    _recommendationDebounce?.cancel();
    widget.controller.cancelWorkLogRecommendations();
    super.dispose();
  }

  String get _currentRecommendationSnapshot =>
      '${widget.controller.workLogRecommendationStatus}:'
      '${widget.controller.workLogRecommendations.map((item) => '${item.taskId}=${item.taskName}').join('|')}';

  void _controllerChanged() {
    if (!mounted) return;
    final snapshot = _currentRecommendationSnapshot;
    if (snapshot == _recommendationSnapshot) return;
    setState(() => _recommendationSnapshot = snapshot);
  }

  void _descriptionChanged() {
    if (!mounted) return;
    setState(() {});
    _recommendationDebounce?.cancel();
    final projectId = _selectedProjectId;
    final description = _descriptionController.text.trim();
    widget.controller.clearWorkLogRecommendations();
    if (projectId == null ||
        projectId == _noProjectOption ||
        description.isEmpty) {
      return;
    }
    _recommendationDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted ||
          _selectedProjectId != projectId ||
          _descriptionController.text.trim() != description) {
        return;
      }
      unawaited(widget.controller.loadWorkLogRecommendations(
        projectId: projectId,
        description: description,
      ));
    });
  }

  Future<void> _selectProject(String? projectId) async {
    if (projectId == null || projectId == _selectedProjectId) {
      return;
    }

    setState(() {
      _selectedProjectId = projectId;
      _selectedTaskIds.clear();
      _taskSearchController.clear();
      _loadError = null;
    });

    if (projectId == _noProjectOption) {
      widget.controller.clearWorkLogProjectSelection();
      return;
    }

    final error = await widget.controller.loadWorkLogTasks(projectId);
    if (!mounted || _selectedProjectId != projectId) {
      return;
    }
    setState(() {
      _loadError = error;
    });
    final description = _descriptionController.text.trim();
    if (error == null && description.isNotEmpty) {
      unawaited(widget.controller.loadWorkLogRecommendations(
        projectId: projectId,
        description: description,
      ));
    }
  }

  void _submit() {
    if (!_canSubmit) {
      return;
    }

    Navigator.of(context).pop(
      WorkLogSubmission(
        projectId:
            _selectedProjectId == _noProjectOption ? null : _selectedProjectId,
        workLog: WorkLogPayload(
          description: _descriptionController.text.trim(),
          taskIds: _selectedTaskIds.toList(growable: false),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final projects = controller.workLogProjects;
    final tasks = controller.workLogTasks;

    return WorkspaceEditorDialog(
      title: 'Registrar atividades',
      subtitle: 'Registre sua atividade e, se aplicável, as tarefas.',
      icon: Icons.edit_note_rounded,
      primaryLabel: 'Continuar',
      primaryIcon: Icons.arrow_forward_rounded,
      onPrimary: _canSubmit ? _submit : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Descreva o trabalho realizado. Se selecionar um projeto, escolha ao menos uma tarefa.',
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            key: const Key('work-log-project'),
            initialValue: _selectedProjectId,
            dropdownColor:
                WorkspaceMenuStyle.surface(Theme.of(context).colorScheme),
            borderRadius: WorkspaceMenuStyle.borderRadius,
            decoration: const InputDecoration(labelText: 'Projeto'),
            items: [
              const DropdownMenuItem<String>(
                value: _noProjectOption,
                child: Text('Nenhum'),
              ),
              ...projects.map(
                (project) => DropdownMenuItem<String>(
                  value: project.id,
                  child: Text(project.name),
                ),
              ),
            ],
            onChanged: _selectProject,
          ),
          const SizedBox(height: 16),
          Semantics(
            liveRegion: true,
            child: Text(
              'Se a empresa habilitou recomendações, a descrição e as tarefas deste projeto podem ser enviadas ao provedor de embeddings configurado. Revise e selecione as tarefas manualmente.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('work-log-description'),
            controller: _descriptionController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: 'Descrição da atividade',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          if (_selectedProjectId != null &&
              _selectedProjectId != _noProjectOption &&
              controller.workLogRecommendationStatus != 'idle' &&
              controller.workLogRecommendationStatus != 'disabled') ...[
            const SizedBox(height: 8),
            Container(
              key: const Key('work-log-ai-suggestions'),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Sugestões da IA',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Revise as sugestões e selecione as tarefas que deseja adicionar. Nada é selecionado automaticamente.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 12),
                  if (controller.workLogRecommendationStatus == 'loading')
                    const WorkspaceSkeletonRegion(
                      label: 'Buscando sugestões de tarefas',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          WorkspaceSkeleton(width: 164, height: 36),
                          WorkspaceSkeleton(width: 132, height: 36),
                        ],
                      ),
                    )
                  else if (controller.workLogRecommendationStatus ==
                      'unavailable')
                    Text(
                      'Sugestões indisponíveis no momento. Você ainda pode selecionar as tarefas manualmente.',
                      style: Theme.of(context).textTheme.bodySmall,
                    )
                  else if (controller.workLogRecommendations.isNotEmpty)
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: controller.workLogRecommendations.map((item) {
                        final selected = _selectedTaskIds.contains(item.taskId);
                        return FilterChip(
                          key: Key('work-log-task-suggestion-${item.taskId}'),
                          selected: selected,
                          checkmarkColor: AppTheme.adminColors(
                            Theme.of(context),
                          ).selectedForeground,
                          label: Text(item.taskName),
                          onSelected: (value) => setState(() {
                            if (value) {
                              _selectedTaskIds.add(item.taskId);
                            } else {
                              _selectedTaskIds.remove(item.taskId);
                            }
                          }),
                        );
                      }).toList(growable: false),
                    )
                  else if (controller.workLogRecommendationStatus == 'no_match')
                    Text(
                      'Nenhuma sugestão encontrada. Você ainda pode escolher manualmente.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (_selectedProjectId == null)
            const Text('Selecione um projeto ou Nenhum.')
          else if (_selectedProjectId == _noProjectOption)
            const SizedBox.shrink()
          else if (controller.isLoadingWorkLogTasks)
            const WorkspaceSkeletonRegion(
              key: ValueKey<String>('work-log-tasks-skeleton'),
              label: 'Carregando tarefas do projeto',
              child: WorkspaceSkeletonList(count: 3, leadingSize: 24),
            )
          else if (_loadError != null)
            Text(_loadError!)
          else if (tasks.isEmpty)
            const Text('Nenhuma tarefa disponível para este projeto.')
          else ...[
            Text(
              'Tarefas relacionadas',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Autocomplete<TaskRecord>(
              key: const Key('work-log-task-search'),
              textEditingController: _taskSearchController,
              focusNode: _taskSearchFocusNode,
              displayStringForOption: (task) => task.name,
              optionsMaxHeight: 240,
              optionsBuilder: (value) {
                final query = value.text.trim().toLowerCase();
                if (query.isEmpty) {
                  return const Iterable<TaskRecord>.empty();
                }
                return tasks.where(
                  (task) =>
                      !_selectedTaskIds.contains(task.id) &&
                      task.name.toLowerCase().contains(query),
                );
              },
              onSelected: (task) => setState(() {
                _selectedTaskIds.add(task.id);
                _taskSearchController.clear();
              }),
              fieldViewBuilder: (context, controller, focusNode, _) =>
                  TextField(
                key: const Key('work-log-task-search-field'),
                controller: controller,
                focusNode: focusNode,
                decoration: const InputDecoration(
                  labelText: 'Buscar tarefa',
                  hintText: 'Digite para encontrar uma tarefa',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
              ),
            ),
            if (_selectedTaskIds.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                'Selecionadas',
                style: Theme.of(context).textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: tasks
                    .where((task) => _selectedTaskIds.contains(task.id))
                    .map(
                      (task) => InputChip(
                        key: Key('work-log-selected-task-${task.id}'),
                        selected: true,
                        label: Text(task.name),
                        deleteIconColor:
                            Theme.of(context).colorScheme.onSurface,
                        onDeleted: () => setState(
                          () => _selectedTaskIds.remove(task.id),
                        ),
                      ),
                    )
                    .toList(growable: false),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
