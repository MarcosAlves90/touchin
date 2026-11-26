import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/punch.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/time_tracking/application/punch_location_service.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_controller.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_page.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTimeClockController extends TimeClockController {
  _FakeTimeClockController(this.pageStates)
      : super(
          api: _FakeTimeClockApi(),
          punchLocationService: _FakePunchLocationService(),
        );

  final Map<int, TimeClockState> pageStates;
  PunchType? lastPunchType;

  @override
  Future<void> start() async {}

  @override
  Future<void> loadTimeClockState({
    int page = 1,
    int limit = 4,
    bool showLoading = true,
  }) async {
    final state = pageStates[page] ?? pageStates[pageStates.keys.last]!;
    isLoadingState = false;
    loadError = null;
    employeeName = state.employee.name;
    employeeUnit = state.employee.unit;
    status = state.currentStatus;
    todayWorkedMinutes = state.todayWorkedMinutes;
    todayBreakMinutes = state.todayBreakMinutes;
    firstCheckInAt = state.firstCheckInAt;
    lastPunchAt = state.lastPunchAt;
    records = state.records;
    recordsPage = state.recordsPage;
    recordsPageSize = state.recordsPageSize;
    recordsTotal = state.recordsTotal;
    recordsTotalPages = state.recordsTotalPages;
    recordsHasPrevious = state.recordsHasPrevious;
    recordsHasNext = state.recordsHasNext;
    notifyListeners();
  }

  @override
  Future<String?> handlePunch(
    PunchType type, {
    String? projectId,
    WorkLogPayload? workLog,
  }) async {
    lastPunchType = type;
    return 'Entrada registrado com sucesso.';
  }
}

class _LoadingTimeClockController extends TimeClockController {
  _LoadingTimeClockController()
      : super(
          api: _FakeTimeClockApi(),
          punchLocationService: _FakePunchLocationService(),
        );

  @override
  Future<void> start() async {}

  @override
  Future<void> loadTimeClockState({
    int page = 1,
    int limit = 4,
    bool showLoading = true,
  }) async {}
}

class _FakeTimeClockApi extends TouchInApi {}

class _FakePunchLocationService extends PunchLocationService {
  const _FakePunchLocationService();
}

List<PunchRecord> _buildTimelineRecords() {
  return List<PunchRecord>.generate(
    5,
    (index) => PunchRecord(
      type: PunchType.checkIn,
      timestamp: DateTime(2026, 5, 24, 8, index * 10),
      detail: 'Registro ${index + 1}',
    ),
  );
}

TimeClockState _timelineState({
  required int page,
  required List<PunchRecord> records,
  required int totalPages,
}) {
  return TimeClockState(
    employee: const TimeClockEmployeeSummary(
      id: 'emp-01',
      name: 'Marina Silva',
      unit: 'Operações',
      status: EmployeeStatus.active,
      workMode: EmployeeWorkMode.onsite,
      requiresLocationOnPunch: true,
      trustedDeviceRequired: false,
    ),
    currentStatus: ShiftStatus.working,
    todayWorkedMinutes: 240,
    todayBreakMinutes: 30,
    firstCheckInAt: DateTime.parse('2026-05-24T08:00:00Z'),
    lastPunchAt: DateTime.parse('2026-05-24T12:00:00Z'),
    records: records,
    recordsPage: page,
    recordsPageSize: 4,
    recordsTotal: 5,
    recordsTotalPages: totalPages,
    recordsHasPrevious: page > 1,
    recordsHasNext: page < totalPages,
  );
}

void main() {
  testWidgets('history details remain available across screen sizes',
      (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final timestamp = DateTime(2026, 5, 24, 9);
    final record = PunchRecord(
      type: PunchType.checkIn,
      timestamp: timestamp,
      detail: 'Registro de teste',
      projectId: 'atlas',
      projectName: 'Projeto Atlas',
      workLog: const PunchWorkLog(
        projectId: 'atlas',
        projectName: 'Projeto Atlas',
        taskNames: ['Revisar checklist', 'Validar relatório'],
      ),
      location: PunchLocationSnapshot(
          latitude: -23.5,
          longitude: -46.6,
          accuracyMeters: 12,
          capturedAt: timestamp),
    );
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(page: 1, records: [record], totalPages: 1),
    })
      ..isLoadingState = false;
    await controller.loadTimeClockState();
    for (final width in [1440.0, 768.0, 390.0, 320.0]) {
      tester.view.physicalSize = Size(width, 1400);
      await tester
          .pumpWidget(MaterialApp(home: TimeClockPage(controller: controller)));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('09:00').last);
      await tester.tap(find.text('09:00').last);
      await tester.pumpAndSettle();
      expect(find.text('Registro de teste'), findsOneWidget);
      expect(find.text('Projeto: Projeto Atlas'), findsOneWidget);
      expect(find.text('Tarefas selecionadas'), findsOneWidget);
      expect(find.text('• Revisar checklist'), findsOneWidget);
      expect(find.text('• Validar relatório'), findsOneWidget);
      expect(find.text('Lat -23.50000 | Long -46.60000'), findsOneWidget);
      expect(find.text('Precisão estimada 12 m'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'width $width');
      await tester.pumpWidget(const SizedBox.shrink());
    }
    controller.dispose();
  });
  testWidgets('history is compact with expandable record and location details',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(
          page: 1,
          records: _buildTimelineRecords().take(4).toList(),
          totalPages: 1),
    })
      ..isLoadingState = false;
    await controller.loadTimeClockState();
    await tester
        .pumpWidget(MaterialApp(home: TimeClockPage(controller: controller)));
    await tester.pumpAndSettle();
    final history = find
        .ancestor(
          of: find.text('Jornada do dia'),
          matching: find.byType(WorkspaceSectionCard),
        )
        .first;
    final collapsedHeight = tester.getRect(history).height;
    expect(find.text('Registro 1'), findsNothing);
    expect(find.text('Última coordenada'), findsNothing);
    expect(find.text('Detalhes de localização'), findsOneWidget);
    await tester.ensureVisible(find.text('Detalhes de localização'));
    await tester.tap(find.text('Detalhes de localização'));
    await tester.pumpAndSettle();
    expect(find.text('Última coordenada'), findsOneWidget);
    await tester.ensureVisible(find.text('08:00').last);
    await tester.tap(find.text('08:00').last);
    await tester.pumpAndSettle();
    expect(find.text('Registro 1'), findsOneWidget);
    expect(tester.getRect(history).height, greaterThan(collapsedHeight),
        reason: 'expanded details occupy more space than the collapsed view');
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('timeline error state keeps reload and location context',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(page: 1, records: const <PunchRecord>[], totalPages: 1),
    })
      ..isLoadingState = false
      ..loadError = 'Falha ao carregar o histórico.';
    await tester
        .pumpWidget(MaterialApp(home: TimeClockPage(controller: controller)));
    await tester.pump();

    expect(find.text('Falha ao carregar o histórico.'), findsOneWidget);
    expect(find.text('Recarregar'), findsOneWidget);
    expect(find.text('Detalhes de localização'), findsOneWidget);

    await tester.ensureVisible(find.text('Recarregar'));
    await tester.tap(find.text('Recarregar'));
    await tester.pumpAndSettle();

    expect(find.text('Falha ao carregar o histórico.'), findsNothing);
    expect(
      find.byKey(const ValueKey<String>('time-clock-empty-state')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('shift status sits with actions rather than above the clock',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(page: 1, records: const <PunchRecord>[], totalPages: 1),
    })
      ..isLoadingState = false
      ..status = ShiftStatus.working
      ..now = DateTime(2026, 5, 24, 9, 10, 25);
    await tester
        .pumpWidget(MaterialApp(home: TimeClockPage(controller: controller)));
    await tester.pump();
    final hero = find
        .ancestor(
          of: find.byKey(const ValueKey<String>('time-clock-hero-layout')),
          matching: find.byType(WorkspaceSectionCard),
        )
        .first;
    final status = find.descendant(of: hero, matching: find.text('Em jornada'));
    final clock = find.descendant(of: hero, matching: find.text('09:10:25'));
    final actions =
        find.byKey(const ValueKey<String>('time-clock-hero-actions'));
    expect(status, findsOneWidget);
    expect(tester.getTopLeft(status).dy,
        greaterThan(tester.getBottomLeft(clock).dy));
    expect(tester.getBottomLeft(status).dy,
        lessThanOrEqualTo(tester.getTopLeft(actions).dy));
    expect(
        find.descendant(of: hero, matching: find.byType(WorkspaceStatusBadge)),
        findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('shift status remains visible without a badge', (tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final brightness in Brightness.values) {
      for (final width in [400.0, 1600.0]) {
        tester.view.physicalSize = Size(width, 1600);
        final controller = _FakeTimeClockController(<int, TimeClockState>{
          1: _timelineState(
              page: 1, records: const <PunchRecord>[], totalPages: 1),
        })
          ..isLoadingState = false
          ..status = ShiftStatus.working;
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: TimeClockPage(controller: controller),
        ));
        await tester.pump();
        final status = tester.widget<Text>(
          find.byKey(const ValueKey<String>('time-clock-shift-status')),
        );
        expect(status.data, 'Em jornada');
        expect(find.byType(WorkspaceStatusBadge), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        controller.dispose();
      }
    }
  });
  testWidgets('location details remain readable without nested cards',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    for (final brightness in Brightness.values) {
      final controller = _FakeTimeClockController(<int, TimeClockState>{
        1: _timelineState(
            page: 1, records: const <PunchRecord>[], totalPages: 1),
      })
        ..isLoadingState = false;
      final theme = ThemeData(brightness: brightness);
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: TimeClockPage(controller: controller),
      ));
      await tester.pump();
      await tester.ensureVisible(find.text('Detalhes de localização'));
      await tester.tap(find.text('Detalhes de localização'));
      await tester.pumpAndSettle();
      final details =
          find.byKey(const ValueKey<String>('time-clock-location-details'));
      expect(
          find.descendant(
              of: details, matching: find.byType(WorkspaceSectionCard)),
          findsNothing);
      expect(tester.getTopLeft(find.text('Permissão')).dx,
          closeTo(tester.getTopLeft(details).dx, 2));
      for (final label in [
        'Permissão',
        'Última coordenada',
        'Precisão',
        'Modo'
      ]) {
        expect(find.descendant(of: details, matching: find.text(label)),
            findsOneWidget);
      }
      expect(find.text('Aguardando batida'), findsOneWidget);
      expect(find.text('Presencial rastreado'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    }
  });

  testWidgets('time clock history composition', (tester) async {
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(page: 1, records: const <PunchRecord>[], totalPages: 1),
    })
      ..isLoadingState = false;
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(MaterialApp(home: TimeClockPage(controller: controller)));
    await tester.pump();
    await tester.ensureVisible(find.text('Detalhes de localização'));
    await tester.tap(find.text('Detalhes de localização'));
    await tester.pumpAndSettle();
    final history = find
        .ancestor(
          of: find.text('Jornada do dia'),
          matching: find.byType(WorkspaceSectionCard),
        )
        .first;
    expect(find.descendant(of: history, matching: find.text('Permissão')),
        findsOneWidget,
        reason: 'time_clock_history_composition');
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('hero actions follow clock and location', (tester) async {
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(page: 1, records: const <PunchRecord>[], totalPages: 1),
    })
      ..isLoadingState = false
      ..status = ShiftStatus.working;
    tester.view.physicalSize = const Size(1600, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester
        .pumpWidget(MaterialApp(home: TimeClockPage(controller: controller)));
    await tester.pump();
    final actions =
        find.byKey(const ValueKey<String>('time-clock-hero-actions'));
    expect(actions, findsOneWidget, reason: 'time_clock_action_placement');
    final location = find
        .byKey(const ValueKey<String>('time-clock-location-status-heading'));
    final banner = find
        .ancestor(
          of: location,
          matching: find.byWidgetPredicate((widget) =>
              widget is Container &&
              widget.padding == const EdgeInsets.all(12)),
        )
        .first;
    expect(
        (tester.widget<Container>(banner).decoration! as BoxDecoration)
            .borderRadius,
        BorderRadius.circular(12),
        reason: 'location_rounded_corners');
    expect(tester.getTopLeft(actions).dy,
        lessThan(tester.getBottomLeft(banner).dy),
        reason: 'actions share the location row to reduce vertical space');
    expect(tester.getTopLeft(actions).dy,
        greaterThan(tester.getBottomLeft(location).dy));
    expect(find.descendant(of: actions, matching: find.text('Iniciar pausa')),
        findsOneWidget);
    expect(find.descendant(of: actions, matching: find.text('Registrar saída')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets('time clock does not claim a trusted device without validation',
      (WidgetTester tester) async {
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(page: 1, records: const <PunchRecord>[], totalPages: 1),
    })
      ..isLoadingState = false;
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester
        .pumpWidget(MaterialApp(home: TimeClockPage(controller: controller)));
    await tester.pump();

    expect(
      find.text('Jornada auditável'),
      findsNothing,
      reason: 'workspace_sidebar_chips_removed',
    );
    expect(find.text('Dispositivo confiável'), findsNothing);
    controller.dispose();
  });

  testWidgets('last punch summary label is spelled correctly',
      (WidgetTester tester) async {
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(page: 1, records: const <PunchRecord>[], totalPages: 1),
    })
      ..isLoadingState = false;
    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester
        .pumpWidget(MaterialApp(home: TimeClockPage(controller: controller)));
    await tester.pump();

    expect(find.text('Último evento'), findsOneWidget);
    expect(find.text('Útimo evento'), findsNothing);
    controller.dispose();
  });

  testWidgets('keeps workspace visible while initial state loads',
      (WidgetTester tester) async {
    final controller = _LoadingTimeClockController();

    tester.view.physicalSize = const Size(1400, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: TimeClockPage(controller: controller),
      ),
    );

    await tester.pump();

    expect(find.text('RESUMO'), findsOneWidget);
    expect(find.text('Bater ponto'), findsOneWidget);
    expect(find.text('Carregando estado do ponto...'), findsOneWidget);
    expect(find.text('Carregando...'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('time-clock-state-skeleton')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('time-clock-history-skeleton')),
      findsOneWidget,
    );
    final iconContainers = tester
        .widgetList<Container>(find.descendant(
          of: find.byKey(const ValueKey<String>('time-clock-state-skeleton')),
          matching: find.byType(Container),
        ))
        .where((c) =>
            c.constraints?.maxWidth == 58 && c.constraints?.maxHeight == 58);
    expect(iconContainers, isNotEmpty);
    expect((iconContainers.first.decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(12),
        reason: 'skeleton_radius_rounded');
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  for (final brightness in Brightness.values) {
    testWidgets('loading message panel is rounded in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(1400, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final controller = _LoadingTimeClockController();
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: TimeClockPage(controller: controller),
      ));
      await tester.pump();

      final text = find.text('Carregando estado do ponto...');
      final panel = tester
          .widgetList<Container>(find.ancestor(
            of: text,
            matching: find.byType(Container),
          ))
          .singleWhere((container) =>
              container.child is Text &&
              (container.child! as Text).data ==
                  'Carregando estado do ponto...');
      final decoration = panel.decoration! as BoxDecoration;
      final colors = Theme.of(tester.element(text)).colorScheme;
      expect(decoration.color, colors.surface.withValues(alpha: 0.8));
      expect(decoration.border, Border.all(color: colors.outlineVariant));
      expect(decoration.borderRadius, BorderRadius.circular(12),
          reason: 'skeleton_message_panel_rounded $brightness');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
    });
  }

  testWidgets('tap on register entry calls punch handler',
      (WidgetTester tester) async {
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(page: 1, records: const <PunchRecord>[], totalPages: 1),
    })
      ..isLoadingState = false
      ..employeeName = 'Marina Silva'
      ..employeeUnit = 'Operações'
      ..status = ShiftStatus.checkedOut
      ..todayWorkedMinutes = 0
      ..todayBreakMinutes = 0
      ..records = const <PunchRecord>[];

    await tester.binding.setSurfaceSize(const Size(1400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: TimeClockPage(controller: controller),
      ),
    );

    await tester.pump();

    await tester.ensureVisible(find.text('Registrar entrada'));
    await tester.tap(find.text('Registrar entrada'));
    await tester.pump();

    expect(controller.lastPunchType, PunchType.checkIn);
  });

  testWidgets('paginates the daily timeline card', (WidgetTester tester) async {
    final timelineRecords = _buildTimelineRecords();
    final descendingRecords = timelineRecords.reversed.toList(growable: false);
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(
        page: 1,
        records: descendingRecords.sublist(0, 4),
        totalPages: 2,
      ),
      2: _timelineState(
        page: 2,
        records: descendingRecords.sublist(4),
        totalPages: 2,
      ),
    })
      ..isLoadingState = false
      ..employeeName = 'Marina Silva'
      ..employeeUnit = 'Operações'
      ..status = ShiftStatus.working
      ..todayWorkedMinutes = 240
      ..todayBreakMinutes = 30
      ..records = descendingRecords.sublist(0, 4)
      ..recordsPage = 1
      ..recordsPageSize = 4
      ..recordsTotal = 5
      ..recordsTotalPages = 2
      ..recordsHasPrevious = false
      ..recordsHasNext = true;

    await tester.binding.setSurfaceSize(const Size(1400, 1800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: TimeClockPage(controller: controller),
      ),
    );

    await tester.pump();

    expect(find.text('08:40'), findsOneWidget);
    expect(find.text('08:10'), findsOneWidget);
    expect(find.text('Página 1 de 2'), findsOneWidget);
    await tester.tap(find.byTooltip('Próxima'));
    await tester.pumpAndSettle();

    expect(find.text('08:40'), findsNothing);
    await tester.tap(find.text('08:00').last);
    await tester.pumpAndSettle();
    expect(find.text('Registro 1'), findsOneWidget);
    expect(find.text('Página 2 de 2'), findsOneWidget);
  });

  testWidgets(
      'compact four-metric strip preserves values and accessibility across viewports',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(page: 1, records: const <PunchRecord>[], totalPages: 1),
    })
      ..isLoadingState = false
      ..now = DateTime(2026, 5, 24, 9)
      ..todayWorkedMinutes = 240
      ..todayBreakMinutes = 30
      ..firstCheckInAt = DateTime.parse('2026-05-24T08:00:00Z')
      ..lastPunchAt = DateTime.parse('2026-05-24T12:00:00Z');

    const labels = <String>[
      'Horas hoje',
      'Pausa acumulada',
      'Primeira entrada',
      'Último evento',
    ];
    const values = <String>['04h 00m', '00h 30m', '08:00', '12:00'];
    const redundantHelpers = <String>[
      'Tempo acumulado em jornada ativa',
      'Tempo total em intervalo no dia',
      'Primeiro registro válido de hoje',
      'Último ponto enviado hoje',
      'Carregando jornada do dia',
      'Carregando intervalo do dia',
      'Aguardando resposta da API',
    ];
    final metricFinder =
        find.byWidgetPredicate((widget) => widget is Semantics);

    for (final width in <double>[1668, 390]) {
      tester.view.physicalSize = Size(width, 1100);
      await tester.pumpWidget(
        MaterialApp(home: TimeClockPage(controller: controller)),
      );
      await tester.pump();

      final strip =
          find.byKey(const ValueKey<String>('time-clock-metrics-strip'));
      expect(strip, findsOneWidget,
          reason: 'compact_metrics_strip_missing $width');
      expect(find.byType(WorkspaceMetricCard), findsNothing,
          reason: 'legacy_metric_cards_removed $width');
      expect(
        tester
            .widgetList<Semantics>(metricFinder)
            .where((semantics) => semantics.container == true)
            .length,
        greaterThanOrEqualTo(4),
        reason: 'compact_metrics_semantics $width',
      );

      for (var index = 0; index < labels.length; index++) {
        expect(find.text(labels[index]), findsOneWidget,
            reason: 'metric_label_preserved ${labels[index]} $width');
        expect(
          find.descendant(
            of: strip,
            matching: find.text(values[index]),
          ),
          findsOneWidget,
          reason: 'metric_value_preserved ${values[index]} $width',
        );
        expect(
          find.byWidgetPredicate((widget) =>
              widget is Semantics &&
              widget.properties.label == '${labels[index]}: ${values[index]}'),
          findsOneWidget,
          reason: 'metric_accessibility_label ${labels[index]} $width',
        );
      }
      for (final helper in redundantHelpers) {
        expect(find.text(helper), findsNothing,
            reason: 'redundant_metric_text_removed $helper $width');
      }

      final stripHeight = tester.getRect(strip).height;
      if (width >= 1024) {
        expect(stripHeight, lessThanOrEqualTo(88),
            reason: 'compact_metrics_desktop_height $stripHeight');
        final top = tester.getTopLeft(find.text(labels.first)).dy;
        for (final label in labels.skip(1)) {
          expect(tester.getTopLeft(find.text(label)).dy, closeTo(top, 1),
              reason: 'compact_metrics_desktop_single_row $label');
        }
      } else {
        expect(stripHeight, lessThanOrEqualTo(140),
            reason: 'compact_metrics_mobile_height $stripHeight');
        final firstTop = tester.getTopLeft(find.text(labels[0])).dy;
        expect(tester.getTopLeft(find.text(labels[1])).dy, closeTo(firstTop, 1),
            reason: 'compact_metrics_mobile_first_row');
        final secondRowTop = tester.getTopLeft(find.text(labels[2])).dy;
        expect(tester.getTopLeft(find.text(labels[3])).dy,
            closeTo(secondRowTop, 1),
            reason: 'compact_metrics_mobile_second_row');
        expect(secondRowTop, greaterThan(firstTop),
            reason: 'compact_metrics_mobile_two_rows');
      }
      expect(tester.takeException(), isNull,
          reason: 'compact_metrics_no_layout_exception $width');
    }
    controller.dispose();

    final loadingController = _LoadingTimeClockController();
    tester.view.physicalSize = const Size(390, 1100);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(
      MaterialApp(home: TimeClockPage(controller: loadingController)),
    );
    await tester.pump();

    final loadingStrip =
        find.byKey(const ValueKey<String>('time-clock-metrics-strip'));
    expect(loadingStrip, findsOneWidget,
        reason: 'compact_metrics_loading_strip');
    expect(find.byType(WorkspaceMetricCard), findsNothing,
        reason: 'compact_metrics_loading_cards_removed');
    expect(
      find.descendant(of: loadingStrip, matching: find.text('--h --m')),
      findsNWidgets(2),
      reason: 'compact_metrics_loading_duration_placeholders',
    );
    expect(
      find.descendant(of: loadingStrip, matching: find.text('--:--')),
      findsNWidgets(2),
      reason: 'compact_metrics_loading_time_placeholders',
    );
    for (final label in labels) {
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Semantics &&
            widget.properties.label == '$label: carregando'),
        findsOneWidget,
        reason: 'compact_metrics_loading_accessibility $label',
      );
    }
    for (final helper in redundantHelpers) {
      expect(find.text(helper), findsNothing,
          reason: 'compact_metrics_loading_text_removed $helper');
    }
    expect(tester.takeException(), isNull,
        reason: 'compact_metrics_loading_no_layout_exception');
    loadingController.dispose();
  });

  testWidgets('time-clock reference layout adapts across viewport sizes',
      (WidgetTester tester) async {
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(page: 1, records: const <PunchRecord>[], totalPages: 1),
    })
      ..isLoadingState = false
      ..now = DateTime(2026, 5, 24, 9);

    tester.view.physicalSize = const Size(1668, 1100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(home: TimeClockPage(controller: controller)),
    );
    await tester.pump();

    expect(
      find.byKey(const ValueKey<String>('time-clock-page-kicker')),
      findsOneWidget,
      reason: 'time_clock_reference_header_missing',
    );
    expect(find.text('CONTROLE DE PONTO'), findsWidgets);
    expect(
      find.byKey(const ValueKey<String>('time-clock-metrics-strip')),
      findsOneWidget,
      reason: 'compact_metrics_strip_replaces_cards',
    );
    expect(find.byType(WorkspaceMetricCard), findsNothing);
    expect(
      (tester.widget<Flex>(find.byKey(
        const ValueKey<String>('time-clock-hero-layout'),
      ))).direction,
      Axis.horizontal,
    );
    final metricLabels = <Finder>[
      find.text('Horas hoje'),
      find.text('Pausa acumulada'),
      find.text('Primeira entrada'),
      find.text('Último evento'),
    ];
    final firstMetricTop = tester.getTopLeft(metricLabels.first).dy;
    for (final label in metricLabels.skip(1)) {
      expect(tester.getTopLeft(label).dy, closeTo(firstMetricTop, 1));
    }
    expect(
      find.byKey(const ValueKey<String>('time-clock-timeline-date')),
      findsOneWidget,
    );
    final dateBadge = tester.widget<Container>(
      find.byKey(const ValueKey<String>('time-clock-timeline-date')),
    );
    expect((dateBadge.decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(8),
        reason: 'timeline_date_radius_8');
    final heroIcon = tester
        .widgetList<Container>(find.byType(Container))
        .singleWhere((container) =>
            container.constraints?.maxWidth == 58 &&
            container.constraints?.maxHeight == 58 &&
            container.decoration is BoxDecoration);
    expect((heroIcon.decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(12),
        reason: 'time_clock_hero_icon_radius_12');
    expect(
      find.byKey(const ValueKey<String>('time-clock-empty-state')),
      findsOneWidget,
    );

    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpWidget(
      MaterialApp(home: TimeClockPage(controller: controller)),
    );
    await tester.pump();

    expect(
      (tester.widget<Flex>(find.byKey(
        const ValueKey<String>('time-clock-hero-layout'),
      ))).direction,
      Axis.vertical,
    );
    final firstRowTop = tester.getTopLeft(metricLabels[0]).dy;
    expect(tester.getTopLeft(metricLabels[1]).dy, closeTo(firstRowTop, 1));
    final secondRowTop = tester.getTopLeft(metricLabels[2]).dy;
    expect(tester.getTopLeft(metricLabels[3]).dy, closeTo(secondRowTop, 1));
    expect(secondRowTop, greaterThan(firstRowTop));
    expect(tester.takeException(), isNull);
    controller.dispose();
  });

  testWidgets(
      'compact hero keeps clock, status and actions without duplicated ready text',
      (WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(page: 1, records: const <PunchRecord>[], totalPages: 1),
    })
      ..isLoadingState = false
      ..now = DateTime(2026, 5, 24, 9, 10, 25)
      ..status = ShiftStatus.working
      ..locationState = const PunchLocationResult.ready()
      ..records = <PunchRecord>[
        PunchRecord(
          type: PunchType.checkIn,
          timestamp: DateTime(2026, 5, 24, 8),
          detail: 'Entrada registrada',
          location: PunchLocationSnapshot(
            latitude: -23.55052,
            longitude: -46.63331,
            accuracyMeters: 8,
            capturedAt: DateTime(2026, 5, 24, 8),
          ),
        ),
      ];

    const clockText = '09:10:25';
    const dateText = 'domingo, 24 de maio';
    const statusDescription = 'Jornada em andamento.';
    const readyMessage =
        'Permissão concedida. A localização será anexada nas próximas batidas.';

    for (final viewport in <Size>[
      const Size(1668, 1000),
      const Size(390, 900),
    ]) {
      tester.view.physicalSize = viewport;
      await tester.pumpWidget(
        MaterialApp(home: TimeClockPage(controller: controller)),
      );
      await tester.pump();

      final hero = find
          .ancestor(
            of: find.byKey(const ValueKey<String>('time-clock-hero-layout')),
            matching: find.byType(WorkspaceSectionCard),
          )
          .first;
      final heroHeight = tester.getRect(hero).height;
      final heightLimit = viewport.width >= 900 ? 280.0 : 360.0;
      expect(heroHeight, lessThanOrEqualTo(heightLimit),
          reason: 'hero_compact_height ${viewport.width} $heroHeight');

      expect(
        find.descendant(of: hero, matching: find.text('Em jornada')),
        findsOneWidget,
        reason: 'hero_status_preserved ${viewport.width}',
      );
      expect(
        find.descendant(of: hero, matching: find.text(clockText)),
        findsOneWidget,
        reason: 'hero_clock_preserved ${viewport.width}',
      );
      expect(
        find.descendant(of: hero, matching: find.text(dateText)),
        findsOneWidget,
        reason: 'hero_date_preserved ${viewport.width}',
      );
      expect(
        find.descendant(of: hero, matching: find.text('Iniciar pausa')),
        findsOneWidget,
        reason: 'hero_primary_action_preserved ${viewport.width}',
      );
      expect(
        find.descendant(of: hero, matching: find.text('Registrar saída')),
        findsOneWidget,
        reason: 'hero_secondary_action_preserved ${viewport.width}',
      );
      expect(
        find.descendant(
          of: hero,
          matching: find.byKey(
            const ValueKey<String>('time-clock-location-status-heading'),
          ),
        ),
        findsOneWidget,
        reason: 'hero_location_status_preserved ${viewport.width}',
      );

      expect(find.text(readyMessage), findsNothing,
          reason: 'ready_message_not_repeated ${viewport.width}');
      expect(
        find.byWidgetPredicate((widget) =>
            widget is Text &&
            (widget.data ?? '').startsWith('Última coordenada auditada:')),
        findsNothing,
        reason: 'ready_coordinate_not_repeated ${viewport.width}',
      );
      if (viewport.width >= 900) {
        expect(find.text(statusDescription), findsOneWidget,
            reason: 'status_helper_only_in_summary ${viewport.width}');
      } else {
        expect(find.text(statusDescription), findsNothing,
            reason: 'status_helper_not_repeated ${viewport.width}');
      }
      expect(tester.takeException(), isNull,
          reason: 'hero_no_layout_exception ${viewport.width}');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    }

    tester.view.physicalSize = const Size(1668, 1000);
    await tester.pumpWidget(
      MaterialApp(home: TimeClockPage(controller: controller)),
    );
    await tester.pump();
    controller.locationState = const PunchLocationResult.permissionDenied();
    controller.notifyListeners();
    await tester.pump();
    final permissionHero = find
        .ancestor(
          of: find.byKey(const ValueKey<String>('time-clock-hero-layout')),
          matching: find.byType(WorkspaceSectionCard),
        )
        .first;
    expect(
      find.descendant(
        of: permissionHero,
        matching: find.text(
          'A permissão de localização foi negada. Sem ela, a batida nao é registrada.',
        ),
      ),
      findsOneWidget,
      reason: 'permission_message_preserved',
    );
    expect(
      find.descendant(
        of: permissionHero,
        matching: find.text('Solicitar permissão'),
      ),
      findsOneWidget,
      reason: 'permission_recovery_preserved',
    );

    controller.locationState = PunchLocationResult.error(
      message: 'Falha ao capturar coordenadas.',
    );
    controller.isSubmittingPunch = true;
    controller.notifyListeners();
    await tester.pump();
    final submittingHero = find
        .ancestor(
          of: find.byKey(const ValueKey<String>('time-clock-hero-layout')),
          matching: find.byType(WorkspaceSectionCard),
        )
        .first;
    expect(
      find.descendant(
        of: submittingHero,
        matching: find.text('Falha ao capturar coordenadas.'),
      ),
      findsOneWidget,
      reason: 'location_error_message_preserved',
    );
    expect(
      find.descendant(
        of: submittingHero,
        matching: find.text('Registrando ponto…'),
      ),
      findsOneWidget,
      reason: 'punch_submission_message_preserved',
    );
    expect(tester.takeException(), isNull, reason: 'hero_states_no_overflow');

    controller.isSubmittingPunch = false;
    controller.locationState = const PunchLocationResult.ready();
    tester.view.physicalSize = const Size(320, 900);
    tester.binding.platformDispatcher.textScaleFactorTestValue = 1.3;
    addTearDown(
        tester.binding.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(
      MaterialApp(home: TimeClockPage(controller: controller)),
    );
    await tester.pump();

    final hero = find
        .ancestor(
          of: find.byKey(const ValueKey<String>('time-clock-hero-layout')),
          matching: find.byType(WorkspaceSectionCard),
        )
        .first;
    final clock = find.descendant(of: hero, matching: find.text(clockText));
    expect(clock, findsOneWidget, reason: 'clock_320_present');
    expect(tester.widget<Text>(clock).maxLines, 1,
        reason: 'clock_320_single_line');
    final clockRect = tester.getRect(clock);
    final heroRect = tester.getRect(hero);
    expect(clockRect.left, greaterThanOrEqualTo(heroRect.left),
        reason: 'clock_320_inside_card_left');
    expect(clockRect.right, lessThanOrEqualTo(heroRect.right),
        reason:
            'clock_320_inside_card_right ${clockRect.right} ${heroRect.right}');
    expect(clockRect.height, lessThanOrEqualTo(80),
        reason: 'clock_320_no_wrap ${clockRect.height}');
    expect(tester.takeException(), isNull, reason: 'clock_320_no_overflow');

    controller.dispose();
  });
}
