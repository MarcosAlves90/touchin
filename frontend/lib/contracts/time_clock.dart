import 'package:touchin_flutter/contracts/contract_parsing.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/location.dart';
import 'package:touchin_flutter/contracts/punch.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'time_clock.freezed.dart';

class ManagedPunchRecord {
  const ManagedPunchRecord({
    required this.id,
    required this.employeeId,
    required this.type,
    required this.timestamp,
    required this.detail,
    required this.projectId,
    required this.location,
  });

  final String id;
  final String employeeId;
  final PunchType type;
  final DateTime timestamp;
  final String detail;
  final String? projectId;
  final PunchLocationSnapshot? location;

  factory ManagedPunchRecord.fromJson(JsonMap json) {
    final rawLocation = json['location'];

    return ManagedPunchRecord(
      id: requireString(json, 'id'),
      employeeId: requireString(json, 'employeeId'),
      type: punchTypeFromApi(requireString(json, 'type')),
      timestamp: requireDateTime(json, 'timestamp'),
      detail: requireString(json, 'detail'),
      projectId: optionalString(json, 'projectId'),
      location: rawLocation == null
          ? null
          : PunchLocationSnapshot.fromJson(
              requireJsonMap(rawLocation, 'location'),
            ),
    );
  }
}

class ManagedPunchPage {
  const ManagedPunchPage({
    required this.records,
    required this.recordsPage,
    required this.recordsPageSize,
    required this.recordsTotal,
    required this.recordsTotalPages,
    required this.recordsHasPrevious,
    required this.recordsHasNext,
  });

  final List<ManagedPunchRecord> records;
  final int recordsPage;
  final int recordsPageSize;
  final int recordsTotal;
  final int recordsTotalPages;
  final bool recordsHasPrevious;
  final bool recordsHasNext;

  factory ManagedPunchPage.fromJson(JsonMap json) {
    final rawRecords = requireJsonList(json['records'], 'records');

    return ManagedPunchPage(
      records: rawRecords
          .map(
            (item) => ManagedPunchRecord.fromJson(
              requireJsonMap(item, 'records[]'),
            ),
          )
          .toList(),
      recordsPage: requireInt(json, 'recordsPage'),
      recordsPageSize: requireInt(json, 'recordsPageSize'),
      recordsTotal: requireInt(json, 'recordsTotal'),
      recordsTotalPages: requireInt(json, 'recordsTotalPages'),
      recordsHasPrevious: requireBool(json, 'recordsHasPrevious'),
      recordsHasNext: requireBool(json, 'recordsHasNext'),
    );
  }
}

class ManagedPunchDraft {
  const ManagedPunchDraft({
    required this.type,
    required this.timestamp,
    required this.detail,
    this.projectId,
    this.location,
  });

  final PunchType type;
  final DateTime timestamp;
  final String detail;
  final String? projectId;
  final PunchLocationSnapshot? location;

  ManagedPunchDraft copyWith({
    PunchType? type,
    DateTime? timestamp,
    String? detail,
    String? projectId,
    Object? location = _managedPunchLocationSentinel,
  }) {
    return ManagedPunchDraft(
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      detail: detail ?? this.detail,
      projectId: projectId ?? this.projectId,
      location: identical(location, _managedPunchLocationSentinel)
          ? this.location
          : location as PunchLocationSnapshot?,
    );
  }

  JsonMap toCreateApiJson() {
    return {
      'type': punchTypeToApi(type),
      'timestamp': timestamp.toUtc().toIso8601String(),
      'detail': detail,
      if (projectId != null && projectId!.trim().isNotEmpty)
        'projectId': projectId!.trim(),
      if (location != null) 'location': location!.toApiJson(),
    };
  }

  JsonMap toUpdateApiJson() {
    final payload = <String, dynamic>{
      'type': punchTypeToApi(type),
      'timestamp': timestamp.toUtc().toIso8601String(),
      'detail': detail,
      if (projectId != null && projectId!.trim().isNotEmpty)
        'projectId': projectId!.trim(),
      if (location != null) 'location': location!.toApiJson(),
    };
    payload.removeWhere((key, value) => value == null);
    return payload;
  }
}

const Object _managedPunchLocationSentinel = Object();

@freezed
abstract class CreatePunchRequest with _$CreatePunchRequest {
  const CreatePunchRequest._();

  const factory CreatePunchRequest({
    required PunchType type,
    PunchLocationSnapshot? location,
  }) = _CreatePunchRequest;

  JsonMap toApiJson() {
    return {
      'type': punchTypeToApi(type),
      if (location != null) 'location': location!.toApiJson(),
    };
  }
}

@freezed
abstract class TimeClockEmployeeSummary with _$TimeClockEmployeeSummary {
  const TimeClockEmployeeSummary._();

  const factory TimeClockEmployeeSummary({
    required String id,
    required String name,
    required String unit,
    required EmployeeStatus status,
    required EmployeeWorkMode workMode,
    required bool requiresLocationOnPunch,
    required bool trustedDeviceRequired,
  }) = _TimeClockEmployeeSummary;

  factory TimeClockEmployeeSummary.fromJson(JsonMap json) {
    return TimeClockEmployeeSummary(
      id: requireString(json, 'id'),
      name: requireString(json, 'name'),
      unit: requireString(json, 'unit'),
      status: employeeStatusFromApi(requireString(json, 'status')),
      workMode: employeeWorkModeFromApi(requireString(json, 'workMode')),
      requiresLocationOnPunch: requireBool(json, 'requiresLocationOnPunch'),
      trustedDeviceRequired: requireBool(json, 'trustedDeviceRequired'),
    );
  }
}

@freezed
abstract class TimeClockState with _$TimeClockState {
  const TimeClockState._();

  const factory TimeClockState({
    required TimeClockEmployeeSummary employee,
    required ShiftStatus currentStatus,
    required int todayWorkedMinutes,
    required int todayBreakMinutes,
    required DateTime? firstCheckInAt,
    required DateTime? lastPunchAt,
    required List<PunchRecord> records,
    required int recordsPage,
    required int recordsPageSize,
    required int recordsTotal,
    required int recordsTotalPages,
    required bool recordsHasPrevious,
    required bool recordsHasNext,
  }) = _TimeClockState;

  factory TimeClockState.fromJson(JsonMap json) {
    final rawRecords = requireJsonList(json['records'], 'records');

    return TimeClockState(
      employee: TimeClockEmployeeSummary.fromJson(
        requireJsonMap(json['employee'], 'employee'),
      ),
      currentStatus: shiftStatusFromApi(requireString(json, 'currentStatus')),
      todayWorkedMinutes: requireInt(json, 'todayWorkedMinutes'),
      todayBreakMinutes: requireInt(json, 'todayBreakMinutes'),
      firstCheckInAt: optionalDateTime(json, 'firstCheckInAt'),
      lastPunchAt: optionalDateTime(json, 'lastPunchAt'),
      records: rawRecords
          .map(
            (item) => PunchRecord.fromJson(
              requireJsonMap(item, 'records[]'),
            ),
          )
          .toList(),
      recordsPage: requireInt(json, 'recordsPage'),
      recordsPageSize: requireInt(json, 'recordsPageSize'),
      recordsTotal: requireInt(json, 'recordsTotal'),
      recordsTotalPages: requireInt(json, 'recordsTotalPages'),
      recordsHasPrevious: requireBool(json, 'recordsHasPrevious'),
      recordsHasNext: requireBool(json, 'recordsHasNext'),
    );
  }
}
