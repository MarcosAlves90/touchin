import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/punch.dart';

/// Renders the same work context in the employee and team punch histories.
class PunchWorkContext extends StatelessWidget {
  const PunchWorkContext({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.workLog,
  });

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
    final theme = Theme.of(context);
    final project = _projectLabel(projectName, projectId);
    final logProject = _projectLabel(workLog?.projectName, workLog?.projectId);
    final differentLogProject =
        logProject != null && workLog?.projectId != projectId;
    final tasks = workLog?.taskNames ?? const <String>[];
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
                child: Text('• $task', style: theme.textTheme.bodySmall),
              ),
          ],
        ],
      ),
    );
  }
}
