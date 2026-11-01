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
  testWidgets('time clock history composition', (tester) async {
    final controller = _FakeTimeClockController(<int, TimeClockState>{
      1: _timelineState(page: 1, records: const <PunchRecord>[], totalPages: 1),
    })..isLoadingState = false;
    tester.view.physicalSize = const Size(1600, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: TimeClockPage(controller: controller)));
    await tester.pump();
    final history = find.ancestor(
      of: find.text('Jornada do dia'), matching: find.byType(WorkspaceSectionCard),
    ).first;
    expect(find.descendant(of: history, matching: find.text('Permissão')),
        findsOneWidget, reason: 'time_clock_history_composition');
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
    final banner = find.ancestor(
      of: location,
      matching: find.byWidgetPredicate((widget) =>
          widget is Container && widget.padding == const EdgeInsets.all(18)),
    ).first;
    expect((tester.widget<Container>(banner).decoration! as BoxDecoration).borderRadius,
        BorderRadius.circular(12), reason: 'location_rounded_corners');
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
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

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

    expect(find.text('Registro 5'), findsOneWidget);
    expect(find.text('Registro 2'), findsOneWidget);
    expect(find.text('Registro 1'), findsNothing);
    expect(find.text('Página 1 de 2'), findsOneWidget);

    await tester.tap(find.text('Próxima'));
    await tester.pumpAndSettle();

    expect(find.text('Registro 5'), findsNothing);
    expect(find.text('Registro 1'), findsOneWidget);
    expect(find.text('Página 2 de 2'), findsOneWidget);
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
    expect(find.byType(WorkspaceMetricCard), findsNWidgets(4));
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
    var previousTop = double.negativeInfinity;
    for (final label in metricLabels) {
      final top = tester.getTopLeft(label).dy;
      expect(top, greaterThan(previousTop));
      previousTop = top;
    }
    controller.dispose();
  });
}
