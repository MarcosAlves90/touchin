import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/auth/presentation/widgets/auth_shell.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
import 'package:touchin_flutter/features/auth/presentation/register_page.dart';
import 'package:touchin_flutter/features/auth/presentation/forgot_password_page.dart';
import 'package:touchin_flutter/features/auth/presentation/reset_password_page.dart';
import 'package:touchin_flutter/features/auth/presentation/must_change_password_page.dart';

void main() {
  testWidgets('registration notice retains its main content with a rounded border',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: RegisterPage()));

    final notice = find.text(
        'Cadastro exclusivo para empresas com CNPJ. Perfis pessoais devem ser tratados no painel do gestor.');
    expect(notice, findsOneWidget);
    final borderedContainers = tester.widgetList<Container>(
      find.ancestor(of: notice, matching: find.byType(Container)),
    ).where((container) =>
        container.decoration is BoxDecoration &&
        (container.decoration as BoxDecoration).border != null);
    expect(borderedContainers, hasLength(1));
    expect((borderedContainers.single.decoration as BoxDecoration).borderRadius,
        BorderRadius.circular(8));
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth shell keeps main hierarchy and rounds only components', (tester) async {
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
          final frame = find.ancestor(of: field, matching: find.byType(AuthFormFrame));
          expect(frame, findsOneWidget, reason: 'auth_main_form_frame');
          expect(find.ancestor(of: field, matching: find.byType(Card)), findsNothing,
              reason: 'auth_main_form_has_no_added_card');
          final rect = tester.getRect(frame);
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(size.width));
          expect(find.byWidgetPredicate((widget) => widget is Semantics && widget.properties.header == true), findsWidgets);

          final fingerprint = tester.widget<Container>(
            find.ancestor(of: find.byIcon(Icons.fingerprint_rounded),
                matching: find.byWidgetPredicate((widget) =>
                    widget is Container && widget.child is Icon)).first,
          );
          expect((fingerprint.decoration as BoxDecoration).borderRadius,
              BorderRadius.circular(8), reason: 'auth_rounded_brand_mark');

          if (size.width >= 920) {
            expect(find.byKey(const Key('auth-editorial-hero')), findsOneWidget);
            expect(find.byType(ImageFiltered), findsOneWidget,
                reason: 'auth_main_full_bleed_blurred_photo');
            final rows = tester.widgetList<Row>(
                find.descendant(of: find.byType(AuthShell), matching: find.byType(Row)));
            final split = rows.singleWhere((row) =>
                row.children.length == 2 && row.children.every((child) => child is Expanded));
            expect(split.children.cast<Expanded>().map((child) => child.flex),
                [53, 47], reason: 'auth_main_split_proportions');
            final borderedTags = tester.widgetList<Container>(
                find.descendant(of: find.byKey(const Key('auth-editorial-hero')),
                    matching: find.byType(Container))).where((container) =>
                container.decoration is BoxDecoration &&
                (container.decoration as BoxDecoration).border != null);
            expect(borderedTags, isNotEmpty);
            for (final tag in borderedTags) {
              expect((tag.decoration as BoxDecoration).borderRadius,
                  BorderRadius.circular(8), reason: 'auth_rounded_tags');
            }
          } else {
            expect(find.byKey(const Key('auth-editorial-hero')), findsNothing);
            expect(find.byKey(const Key('auth-mobile-masthead')), findsOneWidget);
          }

          final checkbox = find.byType(CheckboxListTile);
          if (checkbox.evaluate().isNotEmpty) {
            expect((tester.widget<CheckboxListTile>(checkbox).checkboxShape!
                        as RoundedRectangleBorder).borderRadius,
                BorderRadius.circular(4), reason: 'auth_rounded_checkbox');
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        }
      }
    }
  });
}
