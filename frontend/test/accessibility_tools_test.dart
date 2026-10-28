import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/accessibility_tools.dart';

void main() {
  testWidgets('site-wide accessibility controls adjust and reset preferences',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: AccessibilityTools(
          child: Scaffold(
            body: Builder(
              builder: (context) => Text(
                '${MediaQuery.textScalerOf(context).scale(10)}|'
                '${MediaQuery.disableAnimationsOf(context)}',
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.bySemanticsLabel('Acessibilidade'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Acessibilidade'));
    await tester.pumpAndSettle();

    expect(find.text('Acessibilidade'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
    await tester.tap(find.byTooltip('Aumentar texto'));
    await tester.pumpAndSettle();
    expect(find.text('110%'), findsOneWidget);
    expect(find.text('11.0|false'), findsOneWidget);

    await tester.tap(find.text('Reduzir animações'));
    await tester.pumpAndSettle();
    expect(find.text('11.0|true'), findsOneWidget);

    await tester.tap(find.text('Restaurar padrão'));
    await tester.pumpAndSettle();
    expect(find.text('100%'), findsOneWidget);
    expect(find.text('10.0|false'), findsOneWidget);
  });

  testWidgets('accessibility panel fits a narrow viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: AccessibilityTools(child: Scaffold(body: Text('Conteúdo'))),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Acessibilidade'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Restaurar padrão'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey<String>('accessibility-panel'))).width,
      lessThanOrEqualTo(320),
    );
  });

  testWidgets('accessibility settings preserve nonlinear platform text scaling',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: _NonlinearTextScaler()),
          child: AccessibilityTools(
            child: Scaffold(
              body: Builder(
                builder: (context) => Text(
                  '${MediaQuery.textScalerOf(context).scale(10).toStringAsFixed(1)}|'
                  '${MediaQuery.textScalerOf(context).scale(20).toStringAsFixed(1)}',
                ),
              ),
            ),
          ),
        ),
      ),
    );

    expect(find.text('12.0|30.0'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Acessibilidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumentar texto'));
    await tester.pumpAndSettle();
    expect(find.text('13.2|33.0'), findsOneWidget);

    await tester.tap(find.text('Restaurar padrão'));
    await tester.pumpAndSettle();
    expect(find.text('12.0|30.0'), findsOneWidget);
  });
}

class _NonlinearTextScaler extends TextScaler {
  const _NonlinearTextScaler();

  @override
  double scale(double fontSize) => fontSize * (fontSize < 16 ? 1.2 : 1.5);

  @override
  double get textScaleFactor => 1.2;
}
