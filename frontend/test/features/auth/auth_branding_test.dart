import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
import 'package:touchin_flutter/features/auth/presentation/register_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('auth pages show fingerprint brand mark', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));

    expect(find.byIcon(Icons.fingerprint_rounded), findsOneWidget);
  });
}
