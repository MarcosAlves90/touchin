import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/location.dart';
import 'package:touchin_flutter/contracts/punch.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_controller.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_page.dart';

class _StaticTimeClockController extends TimeClockController {
  _StaticTimeClockController() {
    isLoadingState = false;
  }

  @override
  Future<void> start() async {}
}

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

void main() {
  for (final brightness in Brightness.values) {
    testWidgets('shift and location status meet text contrast in $brightness',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final dark = brightness == Brightness.dark;
      final surface = Color(dark ? 0xFF1F1F1F : 0xFFFFFFFF);
      final panel = Color(dark ? 0xFF2A2A2A : 0xFFF1EFE8);
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB020),
          brightness: brightness,
          surface: surface,
          surfaceContainerHighest: panel,
        ),
      );
      final controller = _StaticTimeClockController();
      addTearDown(controller.dispose);
      final shiftStates = <ShiftStatus, String>{
        ShiftStatus.checkedOut: 'Fora do turno',
        ShiftStatus.working: 'Em jornada',
        ShiftStatus.onBreak: 'Em pausa',
      };

      for (final state in shiftStates.entries) {
        controller.status = state.key;
        controller.locationState =
            const PunchLocationResult.permissionDeniedForever();
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: TimeClockPage(controller: controller),
        ));
        await tester.pump();

        final badge = tester.widget<WorkspaceStatusBadge>(
          find.widgetWithText(WorkspaceStatusBadge, state.value),
        );
        final badgeBackground = Color.alphaBlend(
          badge.tone.withValues(alpha: 0.14),
          panel,
        );
        expect(
            _contrast(badge.tone, badgeBackground), greaterThanOrEqualTo(4.5),
            reason: '$brightness: ${state.value} badge');

        final locationHeading = tester.widget<Text>(
          find.byKey(
            const ValueKey<String>('time-clock-location-status-heading'),
          ),
        );
        final locationForeground = locationHeading.style!.color!;
        final locationBackground = Color.alphaBlend(
          locationForeground.withValues(alpha: 0.08),
          panel,
        );
        expect(_contrast(locationForeground, locationBackground),
            greaterThanOrEqualTo(4.5),
            reason: '$brightness: location error heading');
      }
    });

    testWidgets('sidebar summary label meets text contrast in $brightness',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 1800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final onPrimary = brightness == Brightness.dark
          ? const Color(0xFF412B00)
          : const Color(0xFF2C1800);
      final theme = ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFFFB020),
          brightness: brightness,
          onPrimary: onPrimary,
        ),
      );
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(size: Size(1400, 1800)),
            child: WorkspaceSidebar(
              title: 'Bater ponto',
              description: 'Descrição',
              summaryChildren: const [Text('Informação do resumo')],
              highlightChips: const [],
            ),
          ),
        ),
      ));
      final summary = tester.widget<Text>(find.text('RESUMO'));
      final foreground = Color.alphaBlend(
        summary.style!.color!,
        const Color(0xFFFFB020),
      );
      expect(_contrast(foreground, const Color(0xFFFFB020)),
          greaterThanOrEqualTo(4.5));
    });
  }
}
