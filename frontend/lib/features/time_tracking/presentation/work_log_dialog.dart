import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_controller.dart';

class WorkLogSubmission {
  const WorkLogSubmission({
    required this.projectId,
    required this.workLog,
  });

  final String projectId;
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
  final TextEditingController _descriptionController = TextEditingController();
  final Set<String> _selectedTaskIds = <String>{};
  String? _selectedProjectId;
  String? _loadError;

  bool get _canSubmit =>
      _selectedProjectId != null &&
      _descriptionController.text.trim().isNotEmpty &&
      _selectedTaskIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _descriptionController.addListener(_descriptionChanged);
  }

  @override
  void dispose() {
    _descriptionController
      ..removeListener(_descriptionChanged)
      ..dispose();
    super.dispose();
  }

  void _descriptionChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _selectProject(String? projectId) async {
    if (projectId == null || projectId == _selectedProjectId) {
      return;
    }

    setState(() {
      _selectedProjectId = projectId;
      _selectedTaskIds.clear();
      _loadError = null;
    });

    final error = await widget.controller.loadWorkLogTasks(projectId);
    if (!mounted) {
      return;
    }
    setState(() {
      _loadError = error;
    });
  }

  void _submit() {
    if (!_canSubmit) {
      return;
    }

    Navigator.of(context).pop(
      WorkLogSubmission(
        projectId: _selectedProjectId!,
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

    return AlertDialog(
      title: const Text('Registrar atividades'),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Informe o projeto, descreva o trabalho realizado e selecione ao menos uma tarefa.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                key: const Key('work-log-project'),
                initialValue: _selectedProjectId,
                decoration: const InputDecoration(labelText: 'Projeto'),
                items: projects
                    .map(
                      (project) => DropdownMenuItem<String>(
                        value: project.id,
                        child: Text(project.name),
                      ),
                    )
                    .toList(growable: false),
                onChanged:
                    controller.isLoadingWorkLogTasks ? null : _selectProject,
              ),
              const SizedBox(height: 16),
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
              const SizedBox(height: 16),
              if (_selectedProjectId == null)
                const Text('Selecione um projeto para carregar as tarefas.')
              else if (controller.isLoadingWorkLogTasks)
                const Center(child: CircularProgressIndicator())
              else if (_loadError != null)
                Text(_loadError!)
              else if (tasks.isEmpty)
                const Text('Nenhuma tarefa disponível para este projeto.')
              else ...[
                const Text('Tarefas relacionadas'),
                const SizedBox(height: 8),
                ...tasks.map(
                  (task) => CheckboxListTile(
                    key: Key('work-log-task-${task.id}'),
                    contentPadding: EdgeInsets.zero,
                    value: _selectedTaskIds.contains(task.id),
                    title: Text(task.name),
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (selected) {
                      setState(() {
                        if (selected ?? false) {
                          _selectedTaskIds.add(task.id);
                        } else {
                          _selectedTaskIds.remove(task.id);
                        }
                      });
                    },
                  ),
                ),
              ],
              if (projects.isEmpty) ...[
                const SizedBox(height: 12),
                const Text(
                    'Nenhum projeto ativo disponível para este usuário.'),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('work-log-submit'),
          onPressed: _canSubmit ? _submit : null,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}
