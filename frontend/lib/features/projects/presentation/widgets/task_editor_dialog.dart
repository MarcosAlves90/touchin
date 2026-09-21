import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';

class ProjectTaskEditorDialog extends StatefulWidget {
  const ProjectTaskEditorDialog({
    super.key,
    required this.project,
    required this.tasks,
    this.task,
  });

  final ProjectSummary project;
  final List<TaskRecord> tasks;
  final TaskRecord? task;

  @override
  State<ProjectTaskEditorDialog> createState() =>
      _ProjectTaskEditorDialogState();
}

class _ProjectTaskEditorDialogState extends State<ProjectTaskEditorDialog> {
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
                    () => _parentTaskId =
                        value == null || value.isEmpty ? null : value,
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

String? _requiredTextWithinLimit(
  String? value, {
  required int maxLength,
}) {
  if (value == null || value.trim().isEmpty) {
    return 'Campo obrigatório.';
  }
  if (value.trim().length > maxLength) {
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
