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
}
