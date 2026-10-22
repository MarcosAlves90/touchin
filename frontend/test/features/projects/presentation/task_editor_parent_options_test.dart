import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/task_editor_dialog.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_instant_select_field.dart';

TaskRecord task(String id, String? parentId) => TaskRecord(
      id: id,
      projectId: 'project-1',
      parentTaskId: parentId,
      name: id,
      description: 'description',
      type: TaskType.feature,
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );

void main() {
  testWidgets('parent options exclude descendants at multiple depths', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final root = task('root', null);
    final child = task('child', 'root');
    final grandchild = task('grandchild', 'child');
    final unrelated = task('unrelated', null);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ProjectTaskEditorDialog(
          tasks: [root, child, grandchild, unrelated],
          task: root,
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final parentField = tester.widget<WorkspaceInstantSelectField<String>>(
      find.byType(WorkspaceInstantSelectField<String>),
    );
    expect(parentField.options.map((option) => option.value),
        containsAll(['', 'unrelated']));
    expect(parentField.options.map((option) => option.value),
        isNot(contains(anyOf('root', 'child', 'grandchild'))));
  });
}
