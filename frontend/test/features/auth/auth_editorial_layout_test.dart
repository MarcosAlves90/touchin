import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/auth/presentation/forgot_password_page.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
import 'package:touchin_flutter/features/auth/presentation/must_change_password_page.dart';
import 'package:touchin_flutter/features/auth/presentation/register_page.dart';

void main() {
  final pages = <String, Widget>{
    'login': const LoginPage(),
    'register': const RegisterPage(),
    'forgot_password': const ForgotPasswordPage(),
    'change_password': const MustChangePasswordPage(),
  };

  testWidgets('editorial authentication layout on desktop', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const MaterialApp(home: LoginPage()));
    expect(find.byKey(const Key('auth-editorial-hero')), findsOneWidget);
    expect(find.byKey(const Key('auth-form-stage')), findsOneWidget);
    expect(find.byType(TextFormField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  for (final entry in pages.entries) {
    testWidgets('editorial ${entry.key} desktop and compact mobile', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(MaterialApp(home: entry.value));
      expect(find.byKey(const Key('auth-editorial-hero')), findsOneWidget);
      expect(find.byKey(const Key('auth-form-stage')), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(tester.takeException(), isNull);

      tester.view.physicalSize = const Size(390, 844);
      await tester.pump();
      expect(find.byKey(const Key('auth-editorial-hero')), findsNothing);
      expect(find.byKey(const Key('auth-mobile-masthead')), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byType(TextFormField), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
