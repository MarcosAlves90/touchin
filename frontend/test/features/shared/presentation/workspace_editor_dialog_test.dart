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
        final iconTile = find.ancestor(
          of: find.byIcon(Icons.edit),
          matching: find.byType(Container),
        );
        expect(iconTile, findsOneWidget);
        expect(
          (tester.widget<Container>(iconTile).decoration! as BoxDecoration)
              .borderRadius,
          BorderRadius.circular(8),
          reason: 'dialog_icon_tile_radius_8',
        );
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

    testWidgets('editor error panel rounds its surface in $brightness',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(
          body: WorkspaceEditorDialog(
            title: 'Editor',
            subtitle: 'Details',
            icon: Icons.edit,
            primaryLabel: 'Save',
            onPrimary: () {},
            errorMessage: 'Falha ao salvar',
            child: const Text('Form'),
          ),
        ),
      ));

      final errorPanel = find.ancestor(
        of: find.text('Falha ao salvar'),
        matching: find.byType(Container),
      );
      expect(errorPanel, findsOneWidget);
      expect(
        (tester.widget<Container>(errorPanel).decoration! as BoxDecoration)
            .borderRadius,
        BorderRadius.circular(8),
        reason: 'dialog_error_panel_radius_8',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
