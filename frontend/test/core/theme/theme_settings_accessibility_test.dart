import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/core/theme/theme_mode_controller.dart';
import 'package:touchin_flutter/features/settings/presentation/settings_page.dart';

void main() {
  testWidgets('theme persistence failure is visible and announced',
      (tester) async {
    final semantics = tester.ensureSemantics();
    final controller = ThemeModeController(store: _FailingThemeStore());
    await controller.load();
    await tester.pumpWidget(
        MaterialApp(home: ThemeSettingsPage(controller: controller)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Tema claro'));
    await tester.pumpAndSettle();
    expect(controller.mode, ThemeMode.dark);
    const message =
        'Não foi possível carregar ou salvar a preferência de tema. '
        'Selecione o tema novamente para tentar salvar.';
    expect(find.text(message), findsOneWidget);
    expect(tester.getSemantics(find.text(message)).flagsCollection.isLiveRegion,
        isTrue);
    semantics.dispose();
  });
}

class _FailingThemeStore implements ThemePreferenceStore {
  @override
  Future<String?> readThemeMode() async => 'dark';

  @override
  Future<void> writeThemeMode(ThemeMode mode) async {
    throw StateError('simulated write failure');
  }
}
