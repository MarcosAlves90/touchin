import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
import 'package:touchin_flutter/features/auth/presentation/register_page.dart';
import 'package:touchin_flutter/features/auth/presentation/forgot_password_page.dart';
import 'package:touchin_flutter/features/auth/presentation/reset_password_page.dart';
import 'package:touchin_flutter/features/auth/presentation/must_change_password_page.dart';

void main() {
  testWidgets('auth redesign hierarchy', (tester) async {
    final pages = <Widget>[
      const LoginPage(),
      const RegisterPage(),
      const ForgotPasswordPage(),
      const ResetPasswordPage(token: 'fixture-token-of-sufficient-length-for-test'),
      const MustChangePasswordPage(),
    ];
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final size in [const Size(1440, 900), const Size(390, 844)]) {
      tester.view.physicalSize = size;
      for (final brightness in Brightness.values) {
        for (final page in pages) {
          await tester.pumpWidget(MaterialApp(
            theme: ThemeData(brightness: brightness), home: page));
          final field = find.byType(TextFormField).first;
          final surface = find.ancestor(of: field, matching: find.byType(Card));
          expect(surface, findsOneWidget, reason: 'auth_redesign_hierarchy');
          final rect = tester.getRect(surface);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.header == true), findsWidgets);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    }
  });
}
