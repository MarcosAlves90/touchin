import 'dart:async';

import 'package:touchin_flutter/contracts/punch.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/time_tracking/application/punch_location_service.dart';
import 'package:flutter/foundation.dart';

class TimeClockController extends ChangeNotifier {
  TimeClockController({
    TouchInApi? api,
    PunchLocationService? punchLocationService,
    Duration punchLocationTimeout = const Duration(seconds: 6),
  })  : _api = api ?? TouchInApi(),
        _punchLocationService =
            punchLocationService ?? const PunchLocationService(),
        _punchLocationTimeout = punchLocationTimeout;

  final TouchInApi _api;
  final PunchLocationService _punchLocationService;
  final Duration _punchLocationTimeout;

  DateTime now = DateTime.now();
  List<PunchRecord> records = <PunchRecord>[];
  ShiftStatus status = ShiftStatus.checkedOut;
  PunchLocationResult locationState = const PunchLocationResult.checking();
  bool isSubmittingPunch = false;
  bool isLoadingState = true;
  String? loadError;
  String employeeName = 'Funcionario';
  String employeeUnit = '-';
  int todayWorkedMinutes = 0;
  int todayBreakMinutes = 0;
  DateTime? firstCheckInAt;
  DateTime? lastPunchAt;
  int recordsPage = 1;
  int recordsPageSize = 4;
  int recordsTotal = 0;
  int recordsTotalPages = 1;
  bool recordsHasPrevious = false;
  bool recordsHasNext = false;

  bool get hasTimelinePagination => recordsTotalPages > 1;

  Timer? _clockTimer;
  bool _isDisposed = false;

  Future<void> start() async {
    now = DateTime.now();
    _clockTimer?.cancel();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isDisposed) {
        return;
      }
      now = DateTime.now();
      notifyListeners();
    });

    unawaited(prepareLocationAccess());
    await loadTimeClockState(page: recordsPage, limit: recordsPageSize);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _clockTimer?.cancel();
    super.dispose();
  }

  Future<void> loadTimeClockState({
    int page = 1,
    int limit = 4,
    bool showLoading = true,
  }) async {
    if (_isDisposed) {
      return;
    }

    if (showLoading) {
      isLoadingState = true;
    }
    loadError = null;
    notifyListeners();

    try {
      final state = await _api.getMyTimeClockState(page: page, limit: limit);
      if (_isDisposed) {
        return;
      }

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
      isLoadingState = false;
      notifyListeners();
    } on ApiException catch (error) {
      if (_isDisposed) {
        return;
      }
      isLoadingState = false;
      loadError = error.message;
      notifyListeners();
    } catch (_) {
      if (_isDisposed) {
        return;
      }
      isLoadingState = false;
      loadError = 'Não foi possível carregar o estado de ponto.';
      notifyListeners();
    }
  }

  Future<void> loadPreviousTimelinePage() async {
    if (!recordsHasPrevious) {
      return;
    }

    await loadTimeClockState(
      page: recordsPage - 1,
      limit: recordsPageSize,
      showLoading: false,
    );
  }

  Future<void> loadNextTimelinePage() async {
    if (!recordsHasNext) {
      return;
    }

    await loadTimeClockState(
      page: recordsPage + 1,
      limit: recordsPageSize,
      showLoading: false,
    );
  }

  Future<void> prepareLocationAccess() async {
    if (_isDisposed) {
      return;
    }

    final result = await _punchLocationService.requestPermission();
    if (_isDisposed) {
      return;
    }

    locationState = result;
    notifyListeners();
  }

  Future<String?> handlePunch(PunchType type) async {
    if (_isDisposed) {
      return null;
    }

    if (isSubmittingPunch) {
      return null;
    }

    isSubmittingPunch = true;
    notifyListeners();

    try {
      final locationResult =
          await _punchLocationService.captureForPunch().timeout(
                _punchLocationTimeout,
                onTimeout: () => const PunchLocationResult.error(
                  message:
                      'Não foi possível validar a localização a tempo. Tente novamente.',
                ),
              );

      if (_isDisposed) {
        return null;
      }

      locationState = locationResult;
      notifyListeners();

      final punchLocation = locationResult.snapshot;
      if (punchLocation == null) {
        return locationResult.message;
      }

      final punch = await _api.createPunch(
        request: CreatePunchRequest(
          type: type,
          location: punchLocation,
        ),
      );
      unawaited(
        loadTimeClockState(
          page: recordsPage,
          limit: recordsPageSize,
          showLoading: false,
        ),
      );
      return '${punch.title} registrado com sucesso.';
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Não foi possível registrar o ponto.';
    } finally {
      if (!_isDisposed) {
        isSubmittingPunch = false;
        notifyListeners();
      }
    }
  }
}
