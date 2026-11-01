import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_toolbar.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('rounded toolbar preserves content and interaction in $brightness',
        (tester) async {
      var presses = 0;
      final theme = ThemeData(brightness: brightness);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: WorkspaceToolbar(
              surfaceKey: const ValueKey('surface'),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  const Text('Quadro'),
                  const SizedBox(width: 300),
                  FilledButton(
                    style: workspaceToolbarActionStyle(theme),
                    onPressed: () => presses++,
                    child: const Text('Coluna'),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ));
      final surface = tester.widget<Material>(find.byKey(const ValueKey('surface')));
      expect(surface.shape, isA<RoundedRectangleBorder>(), reason: 'toolbar_radius_12');
      final shape = surface.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(12), reason: 'toolbar_radius_12');
      expect(shape.side, BorderSide(color: theme.colorScheme.outlineVariant));
      expect(surface.color, theme.colorScheme.surface);
      expect(surface.clipBehavior, Clip.none);
      expect(find.text('Quadro'), findsOneWidget);
      await tester.drag(find.byType(SingleChildScrollView), const Offset(-350, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coluna'));
      await tester.pump();
      expect(presses, 1);
      expect(tester.getSize(find.byType(FilledButton)).height, greaterThanOrEqualTo(48));
      expect(tester.takeException(), isNull);
    });
  }
}
