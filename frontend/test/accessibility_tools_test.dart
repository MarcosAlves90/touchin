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
      tester
          .getSize(find.byKey(const ValueKey<String>('accessibility-panel')))
          .width,
      lessThanOrEqualTo(320),
    );
  });

  testWidgets('accessibility panel stays bounded at maximum text size',
      (tester) async {
    tester.view.physicalSize = const Size(320, 480);
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
    for (var i = 0; i < 4; i++) {
      await tester.tap(find.byTooltip('Aumentar texto'));
      await tester.pumpAndSettle();
    }

    expect(tester.takeException(), isNull);
    final panel = tester.getSize(
      find.byKey(const ValueKey<String>('accessibility-panel')),
    );
    expect(panel.width, lessThanOrEqualTo(320));
    expect(panel.height, lessThan(480));
  });

  testWidgets('accessibility panel tooltips work in the app builder',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => AccessibilityTools(child: child!),
        home: const Scaffold(body: Text('Conteúdo')),
      ),
    );
    await tester.tap(find.bySemanticsLabel('Acessibilidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumentar texto'));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('110%'), findsOneWidget);
  });

  testWidgets(
      'accessibility overlay follows ancestor media query changes while retaining state',
      (tester) async {
    final mediaData = ValueNotifier<MediaQueryData>(
      const MediaQueryData(
        size: Size(390, 844),
        viewInsets: EdgeInsets.zero,
        textScaler: TextScaler.linear(1),
      ),
    );
    addTearDown(mediaData.dispose);

    await tester.pumpWidget(
      MaterialApp(
        builder: (context, child) => ValueListenableBuilder<MediaQueryData>(
          valueListenable: mediaData,
          builder: (context, data, _) => MediaQuery(
            data: data,
            child: AccessibilityTools(child: child!),
          ),
        ),
        home: Builder(
          builder: (context) {
            final media = MediaQuery.of(context);
            return Text(
              '${media.size.width.toInt()}|'
              '${media.size.height.toInt()}|'
              '${media.viewInsets.bottom.toInt()}|'
              '${media.textScaler.scale(10).toStringAsFixed(1)}|'
              '${media.disableAnimations}',
            );
          },
        ),
      ),
    );

    expect(find.text('390|844|0|10.0|false'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('Acessibilidade'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Aumentar texto'));
    await tester.pumpAndSettle();
    expect(find.text('110%'), findsOneWidget);

    mediaData.value = const MediaQueryData(
      size: Size(600, 900),
      viewInsets: EdgeInsets.only(bottom: 250),
      textScaler: TextScaler.linear(1.5),
      disableAnimations: true,
    );
    await tester.pumpAndSettle();

    expect(
      find.text('600|900|250|16.5|true'),
      findsOneWidget,
      reason: 'accessibility_overlay_keeps_live_media_query',
    );
    expect(find.text('110%'), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('accessibility-panel')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
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
