import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/theme/app_theme.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/accessibility_tools.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page.dart';
import 'admin_audit_page_test.dart' show FakeTouchInApi, openAuditFilters;

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('high contrast disabled button differs from enabled ${brightness.name}', (tester) async {
      final base = brightness == Brightness.light ? AppTheme.lightTheme : AppTheme.darkTheme;
      await tester.pumpWidget(MaterialApp(theme: AppTheme.highContrastTheme(base), home: Scaffold(body: Column(children: [
        ElevatedButton(onPressed: () {}, child: const Text('Enabled')),
        const ElevatedButton(onPressed: null, child: Text('Disabled')),
      ]))));
      final style = Theme.of(tester.element(find.text('Enabled'))).elevatedButtonTheme.style!;
      expect(style.backgroundColor!.resolve({WidgetState.disabled}), isNot(style.backgroundColor!.resolve({})), reason: 'high_contrast_disabled_state');
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('audit picker updates while open ${brightness.name}', (tester) async {
      tester.view.physicalSize = const Size(1200, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final base = brightness == Brightness.light ? AppTheme.lightTheme : AppTheme.darkTheme;
      await tester.pumpWidget(MaterialApp(theme: base, builder: (context, child) => AccessibilityTools(child: child!), home: AdminAuditPage(api: FakeTouchInApi())));
      await tester.pumpAndSettle();
      await openAuditFilters(tester);
      await tester.ensureVisible(find.text('Data inicial'));
      await tester.tap(find.text('Data inicial'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Acessibilidade'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Alto contraste'));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.byType(DatePickerDialog))).colorScheme.surface, AppTheme.highContrastTheme(base).colorScheme.surface, reason: 'audit_picker_live_theme');
      await tester.tap(find.text('Alto contraste'));
      await tester.pumpAndSettle();
      expect(Theme.of(tester.element(find.byType(DatePickerDialog))).colorScheme.surface, base.colorScheme.surface);
    });
  }
  for (final brightness in Brightness.values) {
    testWidgets('global contrast toggle survives navigation ${brightness.name}',
        (tester) async {
      final theme = brightness == Brightness.light
          ? AppTheme.lightTheme
          : AppTheme.darkTheme;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        builder: (context, child) => AccessibilityTools(child: child!),
        home: Builder(
            builder: (context) => Scaffold(
                  body: TextButton(
                    onPressed: () =>
                        Navigator.of(context).push(MaterialPageRoute<void>(
                      builder: (_) =>
                          const Scaffold(body: Text('Outra página')),
                    )),
                    child: const Text('Navegar'),
                  ),
                )),
      ));
      final before = Theme.of(tester.element(find.text('Navegar')))
          .inputDecorationTheme
          .enabledBorder;
      await tester.tap(find.bySemanticsLabel('Acessibilidade'));
      await tester.pumpAndSettle();
      expect(find.text('Alto contraste'), findsOneWidget,
          reason: 'global_contrast_toggle');
      await tester.tap(find.text('Alto contraste'));
      await tester.pumpAndSettle();
      final active = Theme.of(tester.element(find.text('Navegar')));
      double contrast(Color a, Color b) {
        final x = a.computeLuminance();
        final y = b.computeLuminance();
        return (x > y ? x + .05 : y + .05) / (x > y ? y + .05 : x + .05);
      }

      expect(
          active.scaffoldBackgroundColor, isNot(theme.scaffoldBackgroundColor));
      expect(
          contrast(
              active.colorScheme.onSurface, active.scaffoldBackgroundColor),
          greaterThanOrEqualTo(4.5));
      expect(contrast(active.colorScheme.onSurface, active.cardTheme.color!),
          greaterThanOrEqualTo(4.5));
      expect(
          contrast(active.colorScheme.outline,
              active.colorScheme.surfaceContainerHighest),
          greaterThanOrEqualTo(3));
      final enabled = Theme.of(tester.element(find.text('Navegar')))
          .inputDecorationTheme
          .enabledBorder;
      expect(enabled, isNot(equals(before)));
      await tester.tap(find.text('Navegar'));
      await tester.pumpAndSettle();
      expect(
          Theme.of(tester.element(find.text('Outra página')))
              .inputDecorationTheme
              .enabledBorder,
          equals(enabled));
      await tester.tap(find.text('Alto contraste'));
      await tester.pumpAndSettle();
      expect(
          Theme.of(tester.element(find.text('Outra página')))
              .inputDecorationTheme
              .enabledBorder,
          equals(before));
    });
  }
  testWidgets(
      'keyboard contrast and dialog inherit palette without losing focus',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      builder: (context, child) => AccessibilityTools(child: child!),
      home: Builder(
          builder: (context) => Scaffold(
                  body: TextButton(
                onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) =>
                        const AlertDialog(content: Text('Diálogo'))),
                child: const Text('Abrir diálogo'),
              ))),
    ));
    await tester.tap(find.bySemanticsLabel('Acessibilidade'));
    await tester.pumpAndSettle();
    final switchTile = find.widgetWithText(SwitchListTile, 'Alto contraste');
    tester.widget<SwitchListTile>(switchTile).focusNode!.requestFocus();
    await tester.pump();
    final beforeFocus = FocusManager.instance.primaryFocus;
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pumpAndSettle();
    expect(FocusManager.instance.primaryFocus, same(beforeFocus));
    expect(tester.widget<SwitchListTile>(switchTile).value, isTrue);
    await tester.tap(find.text('Abrir diálogo'));
    await tester.pumpAndSettle();
    final dialogTheme = Theme.of(tester.element(find.text('Diálogo')));
    expect(dialogTheme.scaffoldBackgroundColor, Colors.white);
    expect(dialogTheme.colorScheme.onSurface, Colors.black);
    await tester.tap(find.text('Restaurar padrão'));
    await tester.pumpAndSettle();
    expect(Theme.of(tester.element(find.text('Diálogo'))).colorScheme,
        AppTheme.lightTheme.colorScheme);
  });
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
