import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_navigation.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

double _luminance(Color color) {
  double channel(double component) {
    final value = component / 255;
    return value <= 0.04045
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel((color.r * 255).roundToDouble()) +
      0.7152 * channel((color.g * 255).roundToDouble()) +
      0.0722 * channel((color.b * 255).roundToDouble());
}

double _contrast(Color foreground, Color background) {
  final a = _luminance(foreground);
  final b = _luminance(background);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

ThemeData _testTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppTheme.accent,
      brightness: brightness,
      surface: Color(dark ? 0xFF1F1F1F : 0xFFFFFFFF),
      onPrimary: Color(dark ? 0xFF412B00 : 0xFF2C1800),
      surfaceContainerHighest: Color(dark ? 0xFF2A2A2A : 0xFFF1EFE8),
    ),
    extensions: <ThemeExtension<dynamic>>[
      dark ? WorkspaceNavigationColors.dark : WorkspaceNavigationColors.light,
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final brightness in Brightness.values) {
    final label = brightness.name;
    ThemeData theme() => _testTheme(brightness);

    test('$label navigation tokens meet WCAG AA against composed surfaces', () {
      final data = theme();
      final navigation = WorkspaceNavigationColors.of(data);
      final surface = data.colorScheme.surface;
      final hover = Color.alphaBlend(navigation.hoverOverlay, surface);

      expect(
        _contrast(navigation.itemForeground, surface),
        greaterThanOrEqualTo(4.5),
        reason: '$label unselected item text',
      );
      expect(
        _contrast(navigation.itemForeground, hover),
        greaterThanOrEqualTo(4.5),
        reason: '$label hovered item text',
      );
      expect(
        _contrast(
          navigation.selectedForeground,
          navigation.selectedContainer,
        ),
        greaterThanOrEqualTo(4.5),
        reason: '$label selected item text',
      );
      expect(
        _contrast(navigation.focusRing, surface),
        greaterThanOrEqualTo(3),
        reason: '$label focus indicator against panel',
      );
      expect(
        _contrast(navigation.focusRing, navigation.selectedContainer),
        greaterThanOrEqualTo(3),
        reason: '$label focus indicator against selected item',
      );

      final brandBackground = AppTheme.accent;
      expect(
        _contrast(data.colorScheme.onPrimary, brandBackground),
        greaterThanOrEqualTo(4.5),
        reason: '$label brand wordmark',
      );
      final brandMuted = Color.alphaBlend(
        data.colorScheme.onPrimary.withValues(alpha: 0.82),
        brandBackground,
      );
      expect(
        _contrast(brandMuted, brandBackground),
        greaterThanOrEqualTo(4.5),
        reason: '$label brand subtitle',
      );
    });

    testWidgets('$label panel renders the selected and unselected tokens',
        (tester) async {
      final data = theme();
      await tester.binding.setSurfaceSize(const Size(420, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          theme: data,
          home: const Scaffold(
            body: SizedBox(
              width: 360,
              height: 900,
              child: WorkspaceNavigationPanel(currentRoute: '/kanban'),
            ),
          ),
        ),
      );

      final navigation = WorkspaceNavigationColors.of(data);
      final selectedText = tester.widget<Text>(find.text('Kanban'));
      final unselectedText = tester.widget<Text>(find.text('Bater Ponto'));
      expect(selectedText.style!.color, navigation.selectedForeground);
      expect(unselectedText.style!.color, navigation.itemForeground);

      final selectedDecoration = tester
          .widget<AnimatedContainer>(
            find.ancestor(
              of: find.text('Kanban'),
              matching: find.byType(AnimatedContainer),
            ),
          )
          .decoration! as BoxDecoration;
      expect(selectedDecoration.color, navigation.selectedContainer);
    });
  }
}
