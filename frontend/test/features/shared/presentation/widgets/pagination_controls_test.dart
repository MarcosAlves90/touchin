import 'package:touchin_flutter/features/shared/presentation/widgets/pagination_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('pagination_radius_8 and navigation on mobile $brightness',
        (tester) async {
      final theme = brightness == Brightness.light
          ? AppTheme.lightTheme
          : AppTheme.darkTheme;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.physicalSize = const Size(360, 800);
      addTearDown(tester.view.resetPhysicalSize);
      var page = 1;
      var previousCalls = 0;
      var nextCalls = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(body: StatefulBuilder(builder: (context, setState) {
          return PaginationControls(
            page: page,
            totalPages: 2,
            hasPrevious: page > 1,
            hasNext: page < 2,
            onPrevious: () => setState(() {
              previousCalls++;
              page--;
            }),
            onNext: () => setState(() {
              nextCalls++;
              page++;
            }),
          );
        })),
      ));

      Future<void> checkPage(int expectedPage) async {
        expect(find.text('Página $expectedPage de 2'), findsOneWidget);
        for (final label in ['Anterior', 'Próxima']) {
          final button = find.ancestor(
              of: find.text(label), matching: find.byType(FilledButton));
          expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
          expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
          expect(
              tester.getSemantics(button),
              matchesSemantics(
                label: label,
                isButton: true,
                hasEnabledState: true,
                isFocusable:
                    label == (expectedPage == 1 ? 'Próxima' : 'Anterior'),
                hasFocusAction:
                    label == (expectedPage == 1 ? 'Próxima' : 'Anterior'),
                isEnabled:
                    label == (expectedPage == 1 ? 'Próxima' : 'Anterior'),
                hasTapAction:
                    label == (expectedPage == 1 ? 'Próxima' : 'Anterior'),
              ));
          final material = tester.widget<Material>(find
              .descendant(of: button, matching: find.byType(Material))
              .first);
          expect((material.shape! as RoundedRectangleBorder).borderRadius,
              BorderRadius.circular(8),
              reason: 'pagination_radius_8');
        }
      }

      await checkPage(1);
      await tester.tap(find.text('Anterior'), warnIfMissed: false);
      expect(previousCalls, 0);
      await tester.tap(find.text('Próxima'));
      await tester.pumpAndSettle();
      expect(nextCalls, 1);
      await checkPage(2);
      await tester.tap(find.text('Próxima'), warnIfMissed: false);
      expect(nextCalls, 1);
      await tester.tap(find.text('Anterior'));
      await tester.pumpAndSettle();
      expect(previousCalls, 1);
      expect(find.text('Página 1 de 2'), findsOneWidget);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }
  testWidgets('renders pagination summary and triggers navigation',
      (tester) async {
    var previousCalls = 0;
    var nextCalls = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: PaginationControls(
              page: 2,
              totalPages: 3,
              hasPrevious: true,
              hasNext: true,
              onPrevious: () => previousCalls += 1,
              onNext: () => nextCalls += 1,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Página 2 de 3'), findsOneWidget);

    await tester.tap(find.text('Anterior'));
    await tester.tap(find.text('Próxima'));
    await tester.pump();

    expect(previousCalls, 1);
    expect(nextCalls, 1);
  });
}
