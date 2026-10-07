import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/project.dart';
import 'package:touchin_flutter/contracts/punch.dart';
import 'package:touchin_flutter/contracts/task.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/time_tracking/application/punch_location_service.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_controller.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_page.dart';

class _WorkLogApi extends TouchInApi {
  _WorkLogApi({
    this.status = ShiftStatus.working,
    this.projectsCompleter,
  });

  final ShiftStatus status;
  final Completer<List<ProjectSummary>>? projectsCompleter;
  Map<String, dynamic>? lastPunchJson;
  int listProjectsCalls = 0;

  final List<ProjectSummary> projects = <ProjectSummary>[
    _project('project-a', 'Projeto A'),
    _project('project-b', 'Projeto B'),
  ];

  final Map<String, List<TaskRecord>> tasks = <String, List<TaskRecord>>{
    'project-a': <TaskRecord>[_task('task-a', 'project-a', 'Tarefa A')],
    'project-b': <TaskRecord>[_task('task-b', 'project-b', 'Tarefa B')],
  };

  @override
  Future<TimeClockState> getMyTimeClockState({
    int page = 1,
    int limit = 4,
  }) async {
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
      currentStatus: status,
      todayWorkedMinutes: 240,
      todayBreakMinutes: status == ShiftStatus.onBreak ? 20 : 0,
      firstCheckInAt: DateTime.parse('2026-05-24T08:00:00Z'),
      lastPunchAt: DateTime.parse('2026-05-24T12:00:00Z'),
      records: const <PunchRecord>[],
      recordsPage: 1,
      recordsPageSize: 4,
      recordsTotal: 0,
      recordsTotalPages: 1,
      recordsHasPrevious: false,
      recordsHasNext: false,
    );
  }

  @override
  Future<List<ProjectSummary>> listProjects({ProjectStatus? status}) async {
    listProjectsCalls += 1;
    if (projectsCompleter != null) {
      return projectsCompleter!.future;
    }
    return projects;
  }

  @override
  Future<List<TaskRecord>> listTasks(String projectId) async {
    return tasks[projectId] ?? const <TaskRecord>[];
  }

  @override
  Future<PunchRecord> createPunch({required CreatePunchRequest request}) async {
    lastPunchJson = request.toApiJson();
    return PunchRecord(
      type: request.type,
      timestamp: DateTime.parse('2026-05-24T13:30:00Z'),
      detail: 'registrado',
      location: request.location,
    );
  }
}

class _ReadyLocationService extends PunchLocationService {
  const _ReadyLocationService();

  PunchLocationResult get _result => PunchLocationResult.ready(
        snapshot: PunchLocationSnapshot(
          latitude: -23.55052,
          longitude: -46.63331,
          accuracyMeters: 8,
          capturedAt: DateTime.parse('2026-05-24T13:29:00Z'),
        ),
      );

  @override
  Future<PunchLocationResult> requestPermission() async => _result;

  @override
  Future<PunchLocationResult> captureForPunch() async => _result;
}

class _TestTimeClockController extends TimeClockController {
  _TestTimeClockController({
    required super.api,
    required super.punchLocationService,
  });

  @override
  Future<void> start() async {
    await loadTimeClockState(page: recordsPage, limit: recordsPageSize);
  }
}

ProjectSummary _project(String id, String name) {
  final timestamp = DateTime.parse('2026-05-24T08:00:00Z');
  return ProjectSummary(
    id: id,
    name: name,
    description: null,
    taskEmployeeLimit: 2,
    status: ProjectStatus.active,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

TaskRecord _task(String id, String projectId, String name) {
  final timestamp = DateTime.parse('2026-05-24T08:00:00Z');
  return TaskRecord(
    id: id,
    projectId: projectId,
    parentTaskId: null,
    name: name,
    description: 'desc',
    type: TaskType.feature,
    createdAt: timestamp,
    updatedAt: timestamp,
  );
}

Future<_WorkLogApi> _pumpPage(
  WidgetTester tester, {
  ShiftStatus status = ShiftStatus.working,
  Completer<List<ProjectSummary>>? projectsCompleter,
}) async {
  final api = _WorkLogApi(
    status: status,
    projectsCompleter: projectsCompleter,
  );
  final controller = _TestTimeClockController(
    api: api,
    punchLocationService: const _ReadyLocationService(),
  );

  await tester.binding.setSurfaceSize(const Size(1400, 1800));
  addTearDown(() {
    controller.dispose();
    tester.binding.setSurfaceSize(null);
  });
  await tester
      .pumpWidget(MaterialApp(home: TimeClockPage(controller: controller)));
  await tester.pumpAndSettle();
  return api;
}

Future<void> _openProject(
  WidgetTester tester,
  String projectName,
) async {
  await tester.tap(find.byKey(const Key('work-log-project')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(projectName).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('working break requires work log before punch submission',
      (tester) async {
    final api = await _pumpPage(tester);

    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();

    expect(api.lastPunchJson, isNull);
    expect(find.text('Registrar atividades'), findsOneWidget);
  });

  testWidgets('working checkout requires work log before punch submission',
      (tester) async {
    final api = await _pumpPage(tester);

    await tester.tap(find.text('Registrar saída'));
    await tester.pumpAndSettle();

    expect(api.lastPunchJson, isNull);
    expect(find.text('Registrar atividades'), findsOneWidget);
  });

  testWidgets('cancelled work log does not submit punch', (tester) async {
    final api = await _pumpPage(tester);

    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancelar'));
    await tester.pumpAndSettle();

    expect(api.lastPunchJson, isNull);
  });

  testWidgets('work-log preparation ignores repeated punch taps',
      (tester) async {
    final projectsCompleter = Completer<List<ProjectSummary>>();
    final api = await _pumpPage(
      tester,
      projectsCompleter: projectsCompleter,
    );

    await tester.tap(find.text('Iniciar pausa'));
    await tester.tap(find.text('Iniciar pausa'));

    expect(api.listProjectsCalls, 1);

    projectsCompleter.complete(api.projects);
    await tester.pumpAndSettle();

    expect(find.text('Registrar atividades'), findsOneWidget);
  });

  testWidgets('incomplete work log cannot be submitted', (tester) async {
    final api = await _pumpPage(tester);

    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();
    await _openProject(tester, 'Projeto A');
    await tester.enterText(
      find.byKey(const Key('work-log-description')),
      'Atividade sem tarefa selecionada',
    );
    await tester.pump();

    final submit =
        tester.widget<FilledButton>(find.byKey(const Key('work-log-submit')));
    expect(submit.onPressed, isNull);
    expect(api.lastPunchJson, isNull);
  });

  testWidgets('valid work log reaches punch API with project and tasks',
      (tester) async {
    final api = await _pumpPage(tester);

    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();
    await _openProject(tester, 'Projeto A');
    await tester.enterText(
      find.byKey(const Key('work-log-description')),
      'Corrigi o fluxo de ponto',
    );
    await tester.tap(find.byKey(const Key('work-log-task-task-a')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('work-log-submit')));
    await tester.pumpAndSettle();

    expect(api.lastPunchJson?['type'], 'breakStart');
    expect(api.lastPunchJson?['projectId'], 'project-a');
    expect(api.lastPunchJson?['workLog'], <String, dynamic>{
      'description': 'Corrigi o fluxo de ponto',
      'taskIds': <String>['task-a'],
    });
  });

  testWidgets('changing project clears tasks selected in previous project',
      (tester) async {
    final api = await _pumpPage(tester);

    await tester.tap(find.text('Iniciar pausa'));
    await tester.pumpAndSettle();
    await _openProject(tester, 'Projeto A');
    await tester.tap(find.byKey(const Key('work-log-task-task-a')));
    await tester.pump();
    await _openProject(tester, 'Projeto B');

    expect(find.byKey(const Key('work-log-task-task-a')), findsNothing);
    expect(find.byKey(const Key('work-log-task-task-b')), findsOneWidget);
    expect(api.lastPunchJson, isNull);
  });

  testWidgets('break end remains available without work log', (tester) async {
    final api = await _pumpPage(tester, status: ShiftStatus.onBreak);

    final checkoutButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Registrar saída'),
    );
    expect(checkoutButton.onPressed, isNull);

    await tester.tap(find.text('Retomar jornada'));
    await tester.pumpAndSettle();

    expect(api.lastPunchJson?['type'], 'breakEnd');
    expect(api.lastPunchJson?['workLog'], isNull);
  });
}
