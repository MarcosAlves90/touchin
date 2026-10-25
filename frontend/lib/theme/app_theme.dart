import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color accent = Color(0xFFFFB020);
  static const BorderRadius _radius = BorderRadius.zero;

  static const Color _lightBackground = Color(0xFFFAFAF7);
  static const Color _lightSurface = Color(0xFFFFFFFF);
  static const Color _lightSurfaceVariant = Color(0xFFF1EFE8);
  static const Color _lightText = Color(0xFF1D1B16);

  static const Color _darkBackground = Color(0xFF161616);
  static const Color _darkSurface = Color(0xFF1F1F1F);
  static const Color _darkSurfaceVariant = Color(0xFF2A2A2A);
  static const Color _darkText = Color(0xFFF5F1E8);

  static const AdminSemanticColors _lightAdminColors = AdminSemanticColors(
    selectedForeground: Color(0xFF704600),
    selectedContainer: Color(0xFFFFF1D6),
    selectedIndicator: Color(0xFF704600),
    success: AdminToneColors(
        foreground: Color(0xFF1B5E20), container: Color(0xFFE8F5E9)),
    warning: AdminToneColors(
        foreground: Color(0xFF704600), container: Color(0xFFFFF1D6)),
    info: AdminToneColors(
        foreground: Color(0xFF075985), container: Color(0xFFE0F2FE)),
    danger: AdminToneColors(
        foreground: Color(0xFF8B1E1E), container: Color(0xFFFCE8E6)),
    neutral: AdminToneColors(
        foreground: Color(0xFF4E4739), container: Color(0xFFF1EFE8)),
  );

  static const AdminSemanticColors _darkAdminColors = AdminSemanticColors(
    selectedForeground: Color(0xFFFFE6A6),
    selectedContainer: Color(0xFF4A3200),
    selectedIndicator: Color(0xFFFFD180),
    success: AdminToneColors(
        foreground: Color(0xFFA5D6A7), container: Color(0xFF1B3A20)),
    warning: AdminToneColors(
        foreground: Color(0xFFFFCC80), container: Color(0xFF4B3300)),
    info: AdminToneColors(
        foreground: Color(0xFF81D4FA), container: Color(0xFF123746)),
    danger: AdminToneColors(
        foreground: Color(0xFFFFB4AB), container: Color(0xFF4B1E1B)),
    neutral: AdminToneColors(
        foreground: Color(0xFFD1C6B4), container: Color(0xFF303030)),
  );

  static ThemeData get lightTheme => _buildTheme(
        colorScheme: _lightColorScheme,
        backgroundColor: _lightBackground,
      );

  static ThemeData get darkTheme => _buildTheme(
        colorScheme: _darkColorScheme,
        backgroundColor: _darkBackground,
      );

  static AdminSemanticColors adminColors(ThemeData theme) =>
      theme.extension<AdminSemanticColors>() ??
      (theme.brightness == Brightness.dark
          ? _darkAdminColors
          : _lightAdminColors);

  static ThemeData adminContrastTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final colors = adminColors(theme);
    final extensions = Map<Object, ThemeExtension<dynamic>>.from(
      theme.extensions,
    )..[AdminSemanticColors] = colors;
    return theme.copyWith(
      extensions: extensions.values,
      inputDecorationTheme: theme.inputDecorationTheme.copyWith(
        filled: true,
        fillColor: scheme.surfaceContainerHighest,
        border: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: scheme.outline, width: 2),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style:
            (theme.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
          side: WidgetStatePropertyAll(BorderSide(color: scheme.outline)),
        ),
      ),
      chipTheme: theme.chipTheme.copyWith(
        selectedColor: colors.selectedContainer,
        side: BorderSide(color: scheme.outline),
      ),
    );
  }

  static const ColorScheme _lightColorScheme = ColorScheme(
    brightness: Brightness.light,
    primary: accent,
    onPrimary: Color(0xFF2C1800),
    secondary: Color(0xFFF3A61B),
    onSecondary: Color(0xFF2A1700),
    error: Color(0xFFBA1A1A),
    onError: Colors.white,
    surface: _lightSurface,
    onSurface: _lightText,
    surfaceContainerHighest: _lightSurfaceVariant,
    onSurfaceVariant: Color(0xFF4E4739),
    outline: Color(0xFF82786A),
    outlineVariant: Color(0xFFD5CFC2),
    shadow: Color(0x1A000000),
    scrim: Color(0x33000000),
    inverseSurface: Color(0xFF2F2B24),
    onInverseSurface: Color(0xFFF6F0E7),
    inversePrimary: Color(0xFFFFCD71),
  );

  static const ColorScheme _darkColorScheme = ColorScheme(
    brightness: Brightness.dark,
    primary: accent,
    onPrimary: Color(0xFF412B00),
    secondary: Color(0xFFFFC95B),
    onSecondary: Color(0xFF412C00),
    error: Color(0xFFFFB4AB),
    onError: Color(0xFF690005),
    surface: _darkSurface,
    onSurface: _darkText,
    surfaceContainerHighest: _darkSurfaceVariant,
    onSurfaceVariant: Color(0xFFD1C6B4),
    outline: Color(0xFF9A907F),
    outlineVariant: Color(0xFF4E4739),
    shadow: Color(0x66000000),
    scrim: Color(0x66000000),
    inverseSurface: Color(0xFFE8E1D7),
    onInverseSurface: Color(0xFF1D1B16),
    inversePrimary: Color(0xFF8C5D00),
  );

  static ThemeData _buildTheme({
    required ColorScheme colorScheme,
    required Color backgroundColor,
  }) {
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: backgroundColor,
      canvasColor: backgroundColor,
      brightness: colorScheme.brightness,
    );

    final textTheme = GoogleFonts.poppinsTextTheme(baseTheme.textTheme).apply(
      bodyColor: colorScheme.onSurface,
      displayColor: colorScheme.onSurface,
    );

    return baseTheme.copyWith(
      textTheme: textTheme,
      datePickerTheme: DatePickerThemeData(
        shape: RoundedRectangleBorder(borderRadius: _radius),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      cardTheme: CardThemeData(
        color: colorScheme.surfaceContainerHighest,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ),
      dividerTheme: DividerThemeData(
        color: colorScheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: BorderSide(color: colorScheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: _radius,
          borderSide: const BorderSide(color: accent, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          minimumSize: const Size.fromHeight(52),
          backgroundColor: accent,
          foregroundColor: colorScheme.onPrimary,
          shape: const RoundedRectangleBorder(borderRadius: _radius),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outlineVariant),
          shape: const RoundedRectangleBorder(borderRadius: _radius),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: const RoundedRectangleBorder(borderRadius: _radius),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          shape: const RoundedRectangleBorder(borderRadius: _radius),
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: colorScheme.onPrimary,
        elevation: 0,
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ),
      chipTheme: baseTheme.chipTheme.copyWith(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: accent.withValues(alpha: 0.16),
        side: BorderSide(color: colorScheme.outlineVariant),
        labelStyle: textTheme.labelLarge,
        secondaryLabelStyle: textTheme.labelLarge?.copyWith(
          color: colorScheme.onSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: textTheme.bodyMedium?.copyWith(
          color: colorScheme.onInverseSurface,
        ),
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: colorScheme.surface,
        modalBackgroundColor: colorScheme.surface,
        shape: const RoundedRectangleBorder(borderRadius: _radius),
      ),
    );
  }
}

@immutable
class AdminToneColors {
  const AdminToneColors({required this.foreground, required this.container});

  final Color foreground;
  final Color container;

  AdminToneColors lerp(AdminToneColors other, double t) => AdminToneColors(
        foreground: Color.lerp(foreground, other.foreground, t)!,
        container: Color.lerp(container, other.container, t)!,
      );
}

@immutable
class AdminSemanticColors extends ThemeExtension<AdminSemanticColors> {
  const AdminSemanticColors({
    required this.selectedForeground,
    required this.selectedContainer,
    required this.selectedIndicator,
    required this.success,
    required this.warning,
    required this.info,
    required this.danger,
    required this.neutral,
  });

  final Color selectedForeground;
  final Color selectedContainer;
  final Color selectedIndicator;
  final AdminToneColors success;
  final AdminToneColors warning;
  final AdminToneColors info;
  final AdminToneColors danger;
  final AdminToneColors neutral;

  @override
  AdminSemanticColors copyWith({
    Color? selectedForeground,
    Color? selectedContainer,
    Color? selectedIndicator,
    AdminToneColors? success,
    AdminToneColors? warning,
    AdminToneColors? info,
    AdminToneColors? danger,
    AdminToneColors? neutral,
  }) =>
      AdminSemanticColors(
        selectedForeground: selectedForeground ?? this.selectedForeground,
        selectedContainer: selectedContainer ?? this.selectedContainer,
        selectedIndicator: selectedIndicator ?? this.selectedIndicator,
        success: success ?? this.success,
        warning: warning ?? this.warning,
        info: info ?? this.info,
        danger: danger ?? this.danger,
        neutral: neutral ?? this.neutral,
      );

  @override
  AdminSemanticColors lerp(
    covariant ThemeExtension<AdminSemanticColors>? other,
    double t,
  ) {
    if (other is! AdminSemanticColors) {
      return this;
    }
    return AdminSemanticColors(
      selectedForeground:
          Color.lerp(selectedForeground, other.selectedForeground, t)!,
      selectedContainer:
          Color.lerp(selectedContainer, other.selectedContainer, t)!,
      selectedIndicator:
          Color.lerp(selectedIndicator, other.selectedIndicator, t)!,
      success: success.lerp(other.success, t),
      warning: warning.lerp(other.warning, t),
      info: info.lerp(other.info, t),
      danger: danger.lerp(other.danger, t),
      neutral: neutral.lerp(other.neutral, t),
    );
  }
}
