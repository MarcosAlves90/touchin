import 'package:touchin_flutter/core/theme/theme_mode_controller.dart';
import 'package:touchin_flutter/features/settings/presentation/settings_page.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('keeps page copy in the content and out of the summary panel', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final store = _InMemoryThemeStore();
    final controller = ThemeModeController(store: store);
    await controller.load();

    await tester.pumpWidget(
      MaterialApp(home: ThemeSettingsPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byType(WorkspaceHeader),
        matching: find.text('Configurações'),
      ),
      findsOneWidget,
    );
    expect(find.text('Aparência e tema.'), findsNothing);
    expect(find.text('Tema atual'), findsOneWidget);
    expect(
      find.text(
        'Ajuste preferências globais da interface e mantenha a experiência do jeito que preferir.',
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('switches between light, dark and system themes', (tester) async {
    final store = _InMemoryThemeStore();
    final controller = ThemeModeController(store: store);

    await controller.load();

    await tester.pumpWidget(
      MaterialApp(home: ThemeSettingsPage(controller: controller)),
    );
    await tester.pumpAndSettle();

    expect(controller.mode, ThemeMode.dark);
    expect(store.savedMode, isNull);

    await tester.tap(find.text('Tema claro'));
    await tester.pumpAndSettle();

    expect(controller.mode, ThemeMode.light);
    expect(store.savedMode, 'light');
    expect(find.text('O tema claro está ativo em todo o app.'), findsOneWidget);

    await tester.tap(find.text('Seguir sistema'));
    await tester.pumpAndSettle();

    expect(controller.mode, ThemeMode.system);
    expect(store.savedMode, 'system');
    expect(
      find.text('O app continuará acompanhando o tema configurado no sistema.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Tema escuro'));
    await tester.pumpAndSettle();

    expect(controller.mode, ThemeMode.dark);
    expect(store.savedMode, 'dark');
    expect(
        find.text('O tema escuro está ativo em todo o app.'), findsOneWidget);
  });
}

class _InMemoryThemeStore implements ThemePreferenceStore {
  String? savedMode;

  @override
  Future<String?> readThemeMode() async {
    return savedMode;
  }

  @override
  Future<void> writeThemeMode(ThemeMode mode) async {
    savedMode = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
  }
}
