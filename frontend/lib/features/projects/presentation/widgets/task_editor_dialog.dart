import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_editor_dialog.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_instant_select_field.dart';

class ProjectTaskEditorDialog extends StatefulWidget {
  const ProjectTaskEditorDialog({
    super.key,
    required this.tasks,
    this.task,
    this.startInViewMode = false,
    this.canEdit = true,
    this.supplementaryDetails,
    this.onSave,
  });

  final List<TaskRecord> tasks;
  final TaskRecord? task;
  final bool startInViewMode;
  final bool canEdit;
  final Widget? supplementaryDetails;

  /// When supplied, edit drafts remain in this dialog until persistence succeeds.
  final Future<void> Function(TaskDraft draft)? onSave;

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
  late bool _viewMode;
  bool get _readOnly => _viewMode || !widget.canEdit || _saving;
  bool _saving = false;
  String? _saveError;
  bool _editConflict = false;

  bool get _isEditing => widget.task != null;

  @override
  void initState() {
    super.initState();
    _viewMode = widget.task != null && widget.startInViewMode;
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

    final dialog = WorkspaceEditorDialog(
      title: _viewMode
          ? '#${widget.task!.cardNumber} · ${widget.task!.name}'
          : _isEditing
              ? 'Editar tarefa'
              : 'Nova tarefa',
      subtitle: 'Detalhes da tarefa',
      icon: _isEditing ? Icons.edit_note_rounded : Icons.add_task,
      primaryLabel: _viewMode
          ? (widget.canEdit ? 'Editar' : 'Fechar')
          : _isEditing
              ? 'Salvar'
              : 'Criar tarefa',
      primaryIcon: _viewMode
          ? Icons.edit_outlined
          : _isEditing
              ? Icons.save_outlined
              : Icons.add_rounded,
      secondaryLabel: _viewMode ? 'Fechar' : 'Cancelar',
      onSecondary: () {
        if (!_saving) Navigator.of(context).pop();
      },
      onPrimary: _viewMode
          ? () {
              if (widget.canEdit) {
                setState(() => _viewMode = false);
              } else {
                Navigator.of(context).pop();
              }
            }
          : _submit,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_saveError != null) ...[
              Text(
                _saveError!,
                key: const ValueKey('task-editor-save-error'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              if (_editConflict)
                TextButton.icon(
                  key: const ValueKey('task-editor-copy-draft'),
                  onPressed: () => Clipboard.setData(ClipboardData(
                    text: 'Nome: ${_nameController.text}\n'
                        'Descrição: ${_descriptionController.text}\n'
                        'Tipo: ${_type.name}\n'
                        'Tarefa-pai: ${_parentTaskId ?? 'Nenhuma'}',
                  )),
                  icon: const Icon(Icons.copy_outlined),
                  label: const Text('Copiar rascunho antes de revisar'),
                ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              controller: _nameController,
              readOnly: _readOnly,
              autofocus: !compact && !_readOnly,
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
              readOnly: _readOnly,
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
                    onChanged: _readOnly
                        ? null
                        : (value) {
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
                    onChanged: _readOnly
                        ? null
                        : (value) => setState(
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
            if (widget.supplementaryDetails != null)
              widget.supplementaryDetails!,
          ],
        ),
      ),
    );
    return PopScope(canPop: !_saving, child: dialog);
  }

  Future<void> _submit() async {
    if (_readOnly || _saving) return;
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final draft = TaskDraft(
      name: _nameController.text,
      description: _descriptionController.text,
      type: _type,
      parentTaskId: _parentTaskId,
    );
    if (widget.onSave == null) {
      Navigator.of(context).pop(draft);
      return;
    }
    setState(() {
      _saving = true;
      _saveError = null;
      _editConflict = false;
    });
    try {
      await widget.onSave!(draft);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _editConflict = error.code == 'task_version_conflict';
        _saveError = _editConflict
            ? '${error.message} Os campos permanecem aqui; copie o rascunho '
                'e compare-o com a versão mais recente antes de editar novamente.'
            : error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saveError = 'Não foi possível salvar. O rascunho foi mantido.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
