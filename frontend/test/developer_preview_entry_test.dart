import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/dev_preview/preview_launcher.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
import 'package:touchin_flutter/main.dart' as app;

void main() {
  const optedIn = String.fromEnvironment('TOUCHIN_FRONTEND_DEV_MODE') == 'true';

  testWidgets('startup only shows the preview launcher with explicit opt-in',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues(
      optedIn ? {'access_token': 'existing-real-session-must-not-be-used'} : {},
    );
    await app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));

    if (optedIn) {
      expect(find.byType(PreviewLauncher), findsOneWidget);
      expect(find.text('Abrir login normal'), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    } else {
      expect(find.byType(app.MyApp), findsOneWidget);
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(PreviewLauncher), findsNothing);
    }
    expect(find.text('Aguardando o servidor'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
