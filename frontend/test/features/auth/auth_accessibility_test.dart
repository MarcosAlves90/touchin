import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
import 'package:touchin_flutter/features/auth/presentation/must_change_password_page.dart';
import 'package:touchin_flutter/features/auth/presentation/register_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('compact brand follows the $brightness foreground color',
        (tester) async {
      final theme = ThemeData(brightness: brightness);
      await tester
          .pumpWidget(MaterialApp(theme: theme, home: const LoginPage()));
      final brandText = tester.widget<Text>(find.text('TOUCHIN'));
      expect(brandText.style?.color, theme.colorScheme.onSurface);
    });
  }

  testWidgets('login exposes a named password toggle and validation status',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.byTooltip('Mostrar senha'), findsOneWidget);
    expect(
        tester.getSemantics(find.text('Entrar').first).flagsCollection.isHeader,
        isTrue);

    await tester.tap(find.byTooltip('Mostrar senha'));
    await tester.pump();
    expect(find.byTooltip('Ocultar senha'), findsOneWidget);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Entrar'));
    await tester.pump();
    const message = 'Confira os campos destacados e tente novamente.';
    expect(find.text(message), findsOneWidget);
    expect(tester.getSemantics(find.text(message)).flagsCollection.isLiveRegion,
        isTrue);
    semantics.dispose();
  });

  testWidgets(
      'registration has distinct password controls and labelled back action',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));

    expect(find.byTooltip('Voltar'), findsOneWidget);
    expect(find.byTooltip('Mostrar senha'), findsOneWidget);
    expect(find.byTooltip('Mostrar confirmação de senha'), findsOneWidget);

    await tester.ensureVisible(find.byTooltip('Mostrar confirmação de senha'));
    await tester.tap(find.byTooltip('Mostrar confirmação de senha'));
    await tester.pump();
    expect(find.byTooltip('Ocultar confirmação de senha'), findsOneWidget);
  });

  testWidgets('required password change identifies each visibility button',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: MustChangePasswordPage()));

    for (final tooltip in [
      'Mostrar senha atual (temporária)',
      'Mostrar nova senha',
      'Mostrar confirmar nova senha',
    ]) {
      expect(find.byTooltip(tooltip), findsOneWidget);
    }
  });

  for (final width in [360.0, 1100.0]) {
    testWidgets(
        'login remains usable at 200% text scale and ${width.toInt()}px',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 600);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, 600),
            textScaler: const TextScaler.linear(2),
          ),
          child: const LoginPage(),
        ),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
      expect(find.byType(TextFormField), findsNWidgets(2));
    });
  }
}
