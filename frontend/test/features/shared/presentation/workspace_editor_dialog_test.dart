import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_editor_dialog.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final size in [const Size(390, 700), const Size(1000, 800)]) {
      testWidgets('dialog_radius_12 $brightness $size preserves editor interactions',
          (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        var submitted = '';
        final controller = TextEditingController();
        addTearDown(controller.dispose);
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Builder(builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showDialog<void>(context: context, builder: (_) =>
                WorkspaceEditorDialog(
                  title: 'Editor', subtitle: 'Details', icon: Icons.edit,
                  primaryLabel: 'Save', onPrimary: () { submitted = controller.text; },
                  child: Column(children: [
                    TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name')),
                    const SizedBox(height: 600),
                    const Text('End of form'),
                  ]),
                )),
              child: const Text('Open'),
            ),
          )),
        ));
        await tester.tap(find.text('Open'));
        await tester.pumpAndSettle();
        final dialog = tester.widget<Dialog>(find.byType(Dialog));
        expect((dialog.shape! as RoundedRectangleBorder).borderRadius,
            BorderRadius.circular(12), reason: 'dialog_radius_12');
        expect(dialog.clipBehavior, Clip.hardEdge);
        expect(find.byTooltip('Fechar'), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Example');
        await tester.drag(find.byType(SingleChildScrollView).first, const Offset(0, -500));
        await tester.pumpAndSettle();
        expect(find.text('End of form'), findsOneWidget);
        await tester.tap(find.text('Save'));
        expect(submitted, 'Example');
        await tester.tap(find.text('Cancelar'));
        await tester.pumpAndSettle();
        expect(find.byType(WorkspaceEditorDialog), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
