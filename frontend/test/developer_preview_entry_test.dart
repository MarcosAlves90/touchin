import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/main.dart' as app;

void main() {
  testWidgets('explicit offline preview entry before real session bootstrap',
      (tester) async {
    FlutterSecureStorage.setMockInitialValues({
      'access_token': 'existing-real-session-must-not-be-used',
    });
    await app.main();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Entrar na prévia de desenvolvimento'), findsOneWidget);
    expect(find.text('Abrir login normal'), findsOneWidget);
    expect(find.text('Aguardando o servidor'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
