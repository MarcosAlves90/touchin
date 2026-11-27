import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../lib/theme/app_theme.dart';

void main() {
  testWidgets('shared shapes have consistent rounded corners in each theme',
      (tester) async {
    for (final base in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      for (final theme in [base, AppTheme.adminContrastTheme(base)]) {
        const expected = BorderRadius.all(Radius.circular(8));
        void check(ShapeBorder? shape) {
          expect((shape as RoundedRectangleBorder).borderRadius, expected,
              reason: 'shared_radius_expected_8');
        }

        check(theme.cardTheme.shape);
        check(theme.datePickerTheme.shape);
        check(theme.elevatedButtonTheme.style!.shape!.resolve({}));
        check(theme.outlinedButtonTheme.style!.shape!.resolve({}));
        check(theme.filledButtonTheme.style!.shape!.resolve({}));
        check(theme.textButtonTheme.style!.shape!.resolve({}));
        check(theme.floatingActionButtonTheme.shape);
        check(theme.chipTheme.shape);
        check(theme.snackBarTheme.shape);
        check(theme.bottomSheetTheme.shape);
        for (final border in [
          theme.inputDecorationTheme.border,
          theme.inputDecorationTheme.enabledBorder,
          theme.inputDecorationTheme.focusedBorder,
          if (theme.inputDecorationTheme.disabledBorder != null)
            theme.inputDecorationTheme.disabledBorder,
        ]) {
          expect((border as OutlineInputBorder).borderRadius, expected,
              reason: 'shared_radius_expected_8');
        }
      }
    }
  });

  for (final entry in <String, ThemeData Function()>{
    'light': () => AppTheme.lightTheme,
    'dark': () => AppTheme.darkTheme,
    'light contrast': () => AppTheme.adminContrastTheme(AppTheme.lightTheme),
    'dark contrast': () => AppTheme.adminContrastTheme(AppTheme.darkTheme),
  }.entries) {
    for (final state in [
      'enabled',
      'focused',
      'error',
      'focused error',
      'disabled'
    ]) {
      testWidgets('${entry.key} renders rounded $state field border',
          (tester) async {
        final previousMode = FocusManager.instance.highlightStrategy;
        FocusManager.instance.highlightStrategy =
            FocusHighlightStrategy.alwaysTraditional;
        addTearDown(
            () => FocusManager.instance.highlightStrategy = previousMode);
        final focus = FocusNode();
        addTearDown(focus.dispose);
        await tester.pumpWidget(MaterialApp(
          theme: entry.value(),
          home: Scaffold(
              body: TextField(
            focusNode: focus,
            enabled: state != 'disabled',
            decoration: InputDecoration(
                labelText: 'Nome',
                errorText: state.contains('error') ? 'Erro' : null),
          )),
        ));
        if (state.contains('focused')) {
          focus.requestFocus();
          await tester.pumpAndSettle();
        }
        final finder = find.byWidgetPredicate(
            (widget) => widget.runtimeType.toString() == '_BorderContainer');
        expect(finder, findsOneWidget);
        final dynamic container = tester.widget(finder);
        final border = container.border as OutlineInputBorder;
        if (state.contains('focused')) {
          expect(FocusManager.instance.highlightMode,
              FocusHighlightMode.traditional);
          expect(focus.hasFocus, isTrue);
          expect(border.borderSide.width, greaterThan(1));
        }
        expect(border.borderRadius, const BorderRadius.all(Radius.circular(8)),
            reason: 'shared_radius_expected_8 ${entry.key} $state');
      });
    }
    testWidgets('${entry.key} controls are accessible at 320px and 200 percent',
        (tester) async {
      tester.view.physicalSize = const Size(320, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final previousMode = FocusManager.instance.highlightStrategy;
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = previousMode);
      final semantics = tester.ensureSemantics();
      var presses = 0;
      await tester.pumpWidget(MaterialApp(
        theme: entry.value(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
              body: Column(children: [
            const TextField(decoration: InputDecoration(labelText: 'Nome')),
            ElevatedButton(
                onPressed: () => presses++, child: const Text('Salvar')),
          ])),
        ),
      ));
      expect(find.bySemanticsLabel(RegExp('Nome')), findsOneWidget);
      expect(find.bySemanticsLabel('Salvar'), findsOneWidget);
      for (final finder in [
        find.byType(TextField),
        find.byType(ElevatedButton)
      ]) {
        final size = tester.getSize(finder);
        expect(size.width, greaterThanOrEqualTo(48));
        expect(size.height, greaterThanOrEqualTo(48));
        expect(tester.getRect(finder).right, lessThanOrEqualTo(320));
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .focusNode
              .hasFocus,
          isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(presses, 1);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      final theme = entry.value();
      final scheme = theme.colorScheme;
      final button = theme.elevatedButtonTheme.style!;
      final pairs = <(Color, Color)>[
        (scheme.onSurface, theme.inputDecorationTheme.fillColor!),
        (scheme.onSurfaceVariant, theme.inputDecorationTheme.fillColor!),
        (
          button.foregroundColor!.resolve({})!,
          button.backgroundColor!.resolve({})!
        ),
      ];
      for (final (foreground, background) in pairs) {
        final a = foreground.computeLuminance();
        final b = background.computeLuminance();
        final ratio =
            (a > b ? a + 0.05 : b + 0.05) / (a > b ? b + 0.05 : a + 0.05);
        expect(ratio, greaterThanOrEqualTo(4.5),
            reason: '${entry.key} $foreground on $background');
      }
      semantics.dispose();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('controls remain usable at 320px and 200 percent text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var pressed = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.lightTheme,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Scaffold(
          body: Column(children: [
            const TextField(decoration: InputDecoration(labelText: 'Nome')),
            ElevatedButton(
              onPressed: () => pressed = true,
              child: const Text('Salvar'),
            ),
            const Chip(label: Text('Ativo')),
          ]),
        ),
      ),
    ));
    expect(tester.getSize(find.byType(ElevatedButton)).height,
        greaterThanOrEqualTo(48));
    expect(find.text('Nome'), findsOneWidget);
    await tester.tap(find.text('Salvar'));
    expect(pressed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
