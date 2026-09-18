import 'dart:async';

import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/location.dart';
import 'package:touchin_flutter/contracts/punch.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/time_tracking/application/punch_location_service.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_controller.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeTouchInApi extends TouchInApi {
  _FakeTouchInApi(this.state, {this.refreshStateCompleter});

  final TimeClockState state;
  final Completer<TimeClockState>? refreshStateCompleter;
  int getStateCalls = 0;
  CreatePunchRequest? lastPunchRequest;

  @override
  Future<TimeClockState> getMyTimeClockState({
    int page = 1,
    int limit = 4,
  }) async {
    getStateCalls += 1;
    if (getStateCalls > 1 && refreshStateCompleter != null) {
      return refreshStateCompleter!.future;
    }
    return state;
  }

  @override
  Future<PunchRecord> createPunch({
    required CreatePunchRequest request,
  }) async {
    lastPunchRequest = request;
    return PunchRecord(
      type: request.type,
      timestamp: DateTime.parse('2026-05-24T13:30:00Z'),
      detail: 'registrado',
      location: request.location,
    );
  }
}

class _BlockingPunchLocationService extends PunchLocationService {
  _BlockingPunchLocationService(this.permission);

  final Completer<PunchLocationResult> permission;

  @override
  Future<PunchLocationResult> requestPermission() => permission.future;
}

class _ReadyPunchLocationService extends PunchLocationService {
  _ReadyPunchLocationService(this.result);

  final PunchLocationResult result;

  @override
  Future<PunchLocationResult> requestPermission() async => result;

  @override
  Future<PunchLocationResult> captureForPunch() async => result;
}

class _FailingPunchLocationService extends PunchLocationService {
  const _FailingPunchLocationService();

  @override
  Future<PunchLocationResult> captureForPunch() async {
    return const PunchLocationResult.error(
      message:
          'Não foi possível validar a localização a tempo. Tente novamente.',
    );
  }
}

TimeClockState _timeClockState() {
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
    todayWorkedMinutes: 360,
    todayBreakMinutes: 30,
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

void main() {
  test('start loads time clock state without waiting for location permission',
      () async {
    final permission = Completer<PunchLocationResult>();
    final api = _FakeTouchInApi(_timeClockState());
    final controller = TimeClockController(
      api: api,
      punchLocationService: _BlockingPunchLocationService(permission),
    );

    await controller.start();

    expect(api.getStateCalls, 1);
    expect(controller.isLoadingState, isFalse);
    expect(controller.employeeName, 'Marina Silva');
    expect(controller.status, ShiftStatus.working);
    expect(controller.locationState.status, PunchLocationStatus.checking);

    permission.complete(const PunchLocationResult.ready());
    await Future<void>.delayed(Duration.zero);

    expect(controller.locationState.status, PunchLocationStatus.ready);

    controller.dispose();
  });

  test(
    'handlePunch sends location when capture is available',
    () async {
      final api = _FakeTouchInApi(_timeClockState());
      final controller = TimeClockController(
        api: api,
        punchLocationService: _ReadyPunchLocationService(
          PunchLocationResult.ready(
            snapshot: PunchLocationSnapshot(
              latitude: -23.55052,
              longitude: -46.63331,
              accuracyMeters: 8,
              capturedAt: DateTime.parse('2026-05-24T13:29:00Z'),
            ),
          ),
        ),
      );

      final message = await controller.handlePunch(PunchType.checkIn);

      expect(message, 'Entrada registrado com sucesso.');
      expect(api.lastPunchRequest, isNotNull);
      expect(api.lastPunchRequest?.location, isNotNull);
      expect(controller.isSubmittingPunch, isFalse);

      controller.dispose();
    },
  );

  test(
    'handlePunch returns without waiting for the refresh load',
    () async {
      final refreshCompleter = Completer<TimeClockState>();
      final api = _FakeTouchInApi(
        _timeClockState(),
        refreshStateCompleter: refreshCompleter,
      );
      final controller = TimeClockController(
        api: api,
        punchLocationService: _ReadyPunchLocationService(
          PunchLocationResult.ready(
            snapshot: PunchLocationSnapshot(
              latitude: -23.55052,
              longitude: -46.63331,
              accuracyMeters: 8,
              capturedAt: DateTime.parse('2026-05-24T13:29:00Z'),
            ),
          ),
        ),
      );
      controller.isLoadingState = false;
      controller.locationState = PunchLocationResult.ready(
        snapshot: PunchLocationSnapshot(
          latitude: -23.55052,
          longitude: -46.63331,
          accuracyMeters: 8,
          capturedAt: DateTime.parse('2026-05-24T13:29:00Z'),
        ),
      );

      final message = await controller.handlePunch(PunchType.checkIn);

      expect(message, 'Entrada registrado com sucesso.');
      expect(api.lastPunchRequest?.location, isNotNull);
      expect(controller.isSubmittingPunch, isFalse);
      expect(controller.isLoadingState, isFalse);

      refreshCompleter.complete(_timeClockState());
      await Future<void>.delayed(Duration.zero);

      controller.dispose();
    },
  );

  test(
    'handlePunch stops when location capture fails',
    () async {
      final api = _FakeTouchInApi(_timeClockState());
      final controller = TimeClockController(
        api: api,
        punchLocationService: const _FailingPunchLocationService(),
        punchLocationTimeout: const Duration(milliseconds: 1),
      );

      final message = await controller.handlePunch(PunchType.checkIn);

      expect(
        message,
        'Não foi possível validar a localização a tempo. Tente novamente.',
      );
      expect(api.lastPunchRequest, isNull);

      controller.dispose();
    },
  );
}
