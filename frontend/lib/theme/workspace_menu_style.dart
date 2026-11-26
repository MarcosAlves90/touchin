import 'package:flutter/material.dart';

/// Shared surface treatment for popup selection menus across the app.
///
/// Keeps menu backgrounds, borders and corner radius aligned with the existing
/// card action menus while deriving every color from the active [ColorScheme].
class WorkspaceMenuStyle {
  const WorkspaceMenuStyle._();

  static const double radius = 10;

  static Color surface(ColorScheme colors) => colors.surfaceContainerHighest;

  static BorderRadius get borderRadius => BorderRadius.circular(radius);

  static RoundedRectangleBorder shape(ColorScheme colors) =>
      RoundedRectangleBorder(
        borderRadius: borderRadius,
        side: BorderSide(color: colors.outlineVariant),
      );
}
