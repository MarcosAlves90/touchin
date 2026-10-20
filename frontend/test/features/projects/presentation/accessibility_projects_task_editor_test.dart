import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/projects/presentation/widgets/task_editor_dialog.dart';

void main() {
  testWidgets('save failure is announced and the editable draft is retained',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1000, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => ProjectTaskEditorDialog(
                tasks: const [],
                onSave: (_) async => throw StateError('temporary failure'),
              ),
            ),
            child: const Text('Criar'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('Criar'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'Rascunho');
    await tester.enterText(find.byType(TextFormField).at(1), 'Descrição mantida');
    await tester.tap(find.text('Criar tarefa'));
    await tester.pumpAndSettle();

    final error = find.byKey(const ValueKey('task-editor-save-error'));
    expect(error, findsOneWidget);
    final liveRegion = find.ancestor(
      of: error,
      matching: find.byWidgetPredicate(
        (widget) => widget is Semantics && widget.properties.liveRegion == true,
      ),
    );
    expect(liveRegion, findsOneWidget);
    expect(find.text('Rascunho'), findsOneWidget);
    expect(find.text('Descrição mantida'), findsOneWidget);
    expect(find.byType(ProjectTaskEditorDialog), findsOneWidget);
  });
}
