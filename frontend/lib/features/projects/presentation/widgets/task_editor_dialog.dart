import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_editor_dialog.dart';

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
            _ProjectContext(projectName: widget.project.name),
            SizedBox(height: compact ? 14 : 18),
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
                  DropdownButtonFormField<TaskType>(
                    initialValue: _type,
                    isExpanded: true,
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
                  DropdownButtonFormField<String>(
                    initialValue: _parentTaskId ?? '',
                    isExpanded: true,
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
                          child: Text(
                            task.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
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

class _ProjectContext extends StatelessWidget {
  const _ProjectContext({required this.projectName});

  final String projectName;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.folder_open_outlined,
            size: 18,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Projeto atual',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  projectName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
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
