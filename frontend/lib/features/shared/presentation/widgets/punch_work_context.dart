import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/punch.dart';

/// Renders the same work context in the employee and team punch histories.
class PunchWorkContext extends StatelessWidget {
  const PunchWorkContext({
    super.key,
    required this.type,
    required this.projectId,
    required this.projectName,
    required this.workLog,
  });

  final PunchType type;
  final String? projectId;
  final String? projectName;
  final PunchWorkLog? workLog;

  String? _projectLabel(String? name, String? id) {
    if (name != null && name.trim().isNotEmpty) return name;
    if (id != null && id.trim().isNotEmpty) return id;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (!type.supportsWorkContext) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final project = _projectLabel(projectName, projectId);
    final logProject = _projectLabel(workLog?.projectName, workLog?.projectId);
    final differentLogProject =
        logProject != null && workLog?.projectId != projectId;
    final savedTasks = workLog?.tasks ?? const <PunchTask>[];
    final tasks = savedTasks.isNotEmpty
        ? savedTasks
        : (workLog?.taskNames ?? const <String>[])
            .map((name) => PunchTask(name: name))
            .toList(growable: false);
    if (project == null && !differentLogProject && tasks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (project != null)
            Text('Projeto: $project', style: theme.textTheme.bodySmall),
          if (differentLogProject)
            Text(
              'Projeto das atividades: $logProject',
              style: theme.textTheme.bodySmall,
            ),
          if (tasks.isNotEmpty) ...[
            if (project != null || differentLogProject)
              const SizedBox(height: 4),
            Text('Tarefas selecionadas', style: theme.textTheme.labelMedium),
            for (final task in tasks)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: _taskLine(task, theme.textTheme.bodySmall),
              ),
          ],
        ],
      ),
    );
  }

  Widget _taskLine(PunchTask task, TextStyle? style) {
    final number = task.cardNumber;
    final id = task.id;
    final label = number != null
        ? '#$number · ${task.name}'
        : id != null
            ? '${task.name} (ID: $id)'
            : task.name;
    final text = Text('• $label', style: style);
    return id != null && number != null
        ? Tooltip(message: 'ID: $id', child: text)
        : text;
  }
}
