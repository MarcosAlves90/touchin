import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

void main() {
  testWidgets('application themes share the action menu surface and border',
      (tester) async {
    final base = AppTheme.lightTheme;
    final themes = <ThemeData>[
      base,
      AppTheme.darkTheme,
      AppTheme.highContrastTheme(base),
      AppTheme.adminContrastTheme(base),
    ];

    for (final theme in themes) {
      final colors = theme.colorScheme;
      final popup = theme.popupMenuTheme;
      expect(popup.color, colors.surfaceContainerHighest,
          reason: 'popup_menu_surface');
      expect(popup.surfaceTintColor, Colors.transparent,
          reason: 'popup_menu_surface_tint');
      expect(popup.shape, isA<RoundedRectangleBorder>(),
          reason: 'popup_menu_shape');
      final shape = popup.shape! as RoundedRectangleBorder;
      expect(shape.borderRadius, BorderRadius.circular(10),
          reason: 'popup_menu_radius_10');
      expect(shape.side.color, colors.outlineVariant,
          reason: 'popup_menu_border');
    }
  });
}
