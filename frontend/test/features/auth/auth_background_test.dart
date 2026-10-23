import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/auth/presentation/forgot_password_page.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
import 'package:touchin_flutter/features/auth/presentation/must_change_password_page.dart';
import 'package:touchin_flutter/features/auth/presentation/register_page.dart';

void main() {
  const cloudinaryAssets = <String, String>{
    'login': 'login_a7de1w.jpg',
    'register': 'cadastro_q0zfus.jpg',
    'forgot_password': 'recuperacao-de-senha_snzc6m.jpg',
    'change_password': 'troca-obrigatoria-de-senha_apzwxa.jpg',
  };

  final pages = <String, Widget>{
    'login': const LoginPage(),
    'register': const RegisterPage(),
    'forgot_password': const ForgotPasswordPage(),
    'change_password': const MustChangePasswordPage(),
  };

  for (final entry in pages.entries) {
    testWidgets('auth cloudinary background on ${entry.key} desktop',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(1200, 850);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(home: entry.value));

      final images = find.byType(Image);
      expect(images, findsOneWidget);
      final photo = tester.widget<Image>(images);
      expect(photo.image, isA<NetworkImage>());
      expect(
        (photo.image as NetworkImage).url,
        'https://res.cloudinary.com/dgsywmzb2/image/upload/'
        'f_auto,q_auto:best,w_1920,c_limit/${cloudinaryAssets[entry.key]}',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('auth brand background is omitted on ${entry.key} mobile',
        (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(375, 810);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(MaterialApp(home: entry.value));

      expect(find.byType(Image), findsNothing);
      expect(find.byType(TextFormField), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }
}
