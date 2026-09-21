import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_editor_dialog.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_instant_select_field.dart';

class ProjectTaskEditorDialog extends StatefulWidget {
  const ProjectTaskEditorDialog({
    super.key,
    required this.tasks,
    this.task,
  });

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

  bool get _isEditing => widget.task != null;

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
    final viewport = MediaQuery.sizeOf(context);
    final compact = viewport.width < 600;
    final possibleParents = widget.tasks
        .where((candidate) => candidate.id != widget.task?.id)
        .toList();

    return WorkspaceEditorDialog(
      title: _isEditing ? 'Editar tarefa' : 'Nova tarefa',
      subtitle: 'Detalhes da tarefa',
      icon: _isEditing ? Icons.edit_note_rounded : Icons.add_task,
      primaryLabel: _isEditing ? 'Salvar' : 'Criar tarefa',
      primaryIcon: _isEditing ? Icons.save_outlined : Icons.add_rounded,
      onPrimary: _submit,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            TextFormField(
              controller: _nameController,
              autofocus: !compact,
              maxLength: taskNameMaxLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Nome'),
              validator: (value) => _requiredTextWithinLimit(
                value,
                maxLength: taskNameMaxLength,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _descriptionController,
              minLines: compact ? 2 : 3,
              maxLines: compact ? 4 : 5,
              maxLength: taskDescriptionMaxLength,
              maxLengthEnforcement: MaxLengthEnforcement.enforced,
              decoration: const InputDecoration(
                labelText: 'Descrição',
                alignLabelWithHint: true,
              ),
              validator: (value) => _requiredTextWithinLimit(
                value,
                maxLength: taskDescriptionMaxLength,
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final fields = <Widget>[
                  WorkspaceInstantSelectField<TaskType>(
                    value: _type,
                    decoration: const InputDecoration(labelText: 'Tipo'),
                    options: TaskType.values
                        .map(
                          (type) => WorkspaceSelectOption<TaskType>(
                            value: type,
                            label: _taskTypeLabel(type),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _type = value);
                      }
                    },
                  ),
                  WorkspaceInstantSelectField<String>(
                    value: _parentTaskId ?? '',
                    decoration: const InputDecoration(
                      labelText: 'Tarefa-pai',
                      helperText: 'Opcional',
                    ),
                    options: <WorkspaceSelectOption<String>>[
                      const WorkspaceSelectOption<String>(
                        value: '',
                        label: 'Sem tarefa-pai',
                      ),
                      ...possibleParents.map(
                        (task) => WorkspaceSelectOption<String>(
                          value: task.id,
                          label: task.name,
                        ),
                      ),
                    ],
                    onChanged: (value) => setState(
                      () => _parentTaskId =
                          value == null || value.isEmpty ? null : value,
                    ),
                  ),
                ];

                if (constraints.maxWidth >= 520) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(child: fields[0]),
                      const SizedBox(width: 12),
                      Expanded(child: fields[1]),
                    ],
                  );
                }

                return Column(
                  children: <Widget>[
                    fields[0],
                    const SizedBox(height: 12),
                    fields[1],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
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
