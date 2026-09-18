import 'package:touchin_flutter/contracts/contract_parsing.dart';
import 'package:flutter/material.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'employee.freezed.dart';

enum EmployeeFilter { all, active, attention, inactive }

enum EmployeeStatus { active, onboarding, onLeave, inactive }

enum EmployeeWorkMode { onsite, hybrid, remote }

enum RoleLevel { staff, specialist, leadership }

enum EmployeeAccessRole { employee, manager }

EmployeeStatus employeeStatusFromApi(String value) {
  return switch (value) {
    'active' => EmployeeStatus.active,
    'onboarding' => EmployeeStatus.onboarding,
    'onLeave' => EmployeeStatus.onLeave,
    'inactive' => EmployeeStatus.inactive,
    _ => throw ContractParsingException(
        'Unsupported employee status value: $value',
      ),
  };
}

String employeeStatusToApi(EmployeeStatus value) {
  return switch (value) {
    EmployeeStatus.active => 'active',
    EmployeeStatus.onboarding => 'onboarding',
    EmployeeStatus.onLeave => 'onLeave',
    EmployeeStatus.inactive => 'inactive',
  };
}

EmployeeWorkMode employeeWorkModeFromApi(String value) {
  return switch (value) {
    'onsite' => EmployeeWorkMode.onsite,
    'hybrid' => EmployeeWorkMode.hybrid,
    'remote' => EmployeeWorkMode.remote,
    _ => throw ContractParsingException(
        'Unsupported employee work mode value: $value',
      ),
  };
}

String employeeWorkModeToApi(EmployeeWorkMode value) {
  return switch (value) {
    EmployeeWorkMode.onsite => 'onsite',
    EmployeeWorkMode.hybrid => 'hybrid',
    EmployeeWorkMode.remote => 'remote',
  };
}

RoleLevel roleLevelFromApi(String value) {
  return switch (value) {
    'staff' => RoleLevel.staff,
    'specialist' => RoleLevel.specialist,
    'leadership' => RoleLevel.leadership,
    _ => throw ContractParsingException(
        'Unsupported role level value: $value',
      ),
  };
}

String roleLevelToApi(RoleLevel value) {
  return switch (value) {
    RoleLevel.staff => 'staff',
    RoleLevel.specialist => 'specialist',
    RoleLevel.leadership => 'leadership',
  };
}

EmployeeAccessRole employeeAccessRoleFromApi(String value) {
  return switch (value) {
    'employee' => EmployeeAccessRole.employee,
    'manager' => EmployeeAccessRole.manager,
    _ => throw ContractParsingException(
        'Unsupported employee access role value: $value',
      ),
  };
}

String employeeAccessRoleToApi(EmployeeAccessRole value) {
  return switch (value) {
    EmployeeAccessRole.employee => 'employee',
    EmployeeAccessRole.manager => 'manager',
  };
}

TimeOfDay _parseTimeOfDayFromApi(JsonMap json, String key) {
  final raw = requireString(json, key);
  final match = RegExp(r'^(\d{2}):(\d{2})(?::\d{2})?$').firstMatch(raw);
  if (match == null) {
    throw ContractParsingException('$key must be a valid HH:mm time.');
  }
  final hour = int.parse(match.group(1)!);
  final minute = int.parse(match.group(2)!);
  if (hour > 23 || minute > 59) {
    throw ContractParsingException('$key must be a valid HH:mm time.');
  }
  return TimeOfDay(hour: hour, minute: minute);
}

String _timeOfDayToApi(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _timeOfDayLabel(TimeOfDay value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

@freezed
abstract class EmployeeProfile with _$EmployeeProfile {
  const EmployeeProfile._();

  const factory EmployeeProfile({
    required String id,
    required String name,
    required String role,
    required String department,
    required String email,
    required String phone,
    required String unit,
    required TimeOfDay expectedShiftStart,
    required TimeOfDay expectedShiftEnd,
    required EmployeeStatus status,
    required EmployeeWorkMode workMode,
    required RoleLevel roleLevel,
    required bool requiresLocationOnPunch,
    required bool trustedDeviceRequired,
    required int todayWorkedMinutes,
    required int pendingAdjustments,
    required DateTime? lastPunchAt,
    required String notes,
  }) = _EmployeeProfile;

  factory EmployeeProfile.fromJson(JsonMap json) {
    return EmployeeProfile(
      id: requireString(json, 'id'),
      name: requireString(json, 'name'),
      role: requireString(json, 'role'),
      department: requireString(json, 'department'),
      email: requireString(json, 'email'),
      phone: requireString(json, 'phone'),
      unit: requireString(json, 'unit'),
      expectedShiftStart: _parseTimeOfDayFromApi(json, 'expectedShiftStart'),
      expectedShiftEnd: _parseTimeOfDayFromApi(json, 'expectedShiftEnd'),
      status: employeeStatusFromApi(requireString(json, 'status')),
      workMode: employeeWorkModeFromApi(requireString(json, 'workMode')),
      roleLevel: roleLevelFromApi(requireString(json, 'roleLevel')),
      requiresLocationOnPunch: requireBool(json, 'requiresLocationOnPunch'),
      trustedDeviceRequired: requireBool(json, 'trustedDeviceRequired'),
      todayWorkedMinutes: requireInt(json, 'todayWorkedMinutes'),
      pendingAdjustments: requireInt(json, 'pendingAdjustments'),
      lastPunchAt: optionalDateTime(json, 'lastPunchAt'),
      notes: requireString(json, 'notes'),
    );
  }

  factory EmployeeProfile.fromDraft({
    required String id,
    required EmployeeDraft draft,
  }) {
    return EmployeeProfile(
      id: id,
      name: draft.name,
      role: draft.role,
      department: draft.department,
      email: draft.email,
      phone: draft.phone,
      unit: draft.unit,
      expectedShiftStart: draft.expectedShiftStart,
      expectedShiftEnd: draft.expectedShiftEnd,
      status: draft.status,
      workMode: draft.workMode,
      roleLevel: draft.roleLevel,
      requiresLocationOnPunch: draft.requiresLocationOnPunch,
      trustedDeviceRequired: draft.trustedDeviceRequired,
      todayWorkedMinutes: 0,
      pendingAdjustments: draft.status == EmployeeStatus.onboarding ? 2 : 0,
      lastPunchAt: null,
      notes: draft.notes,
    );
  }

  EmployeeProfile applyDraft(EmployeeDraft draft) {
    return EmployeeProfile(
      id: id,
      name: draft.name,
      role: draft.role,
      department: draft.department,
      email: draft.email,
      phone: draft.phone,
      unit: draft.unit,
      expectedShiftStart: draft.expectedShiftStart,
      expectedShiftEnd: draft.expectedShiftEnd,
      status: draft.status,
      workMode: draft.workMode,
      roleLevel: draft.roleLevel,
      requiresLocationOnPunch: draft.requiresLocationOnPunch,
      trustedDeviceRequired: draft.trustedDeviceRequired,
      todayWorkedMinutes: todayWorkedMinutes,
      pendingAdjustments: pendingAdjustments,
      lastPunchAt: lastPunchAt,
      notes: draft.notes,
    );
  }

  String get expectedShiftLabel =>
      '${_timeOfDayLabel(expectedShiftStart)} às ${_timeOfDayLabel(expectedShiftEnd)}';
}

class EmployeeDraft {
  const EmployeeDraft({
    required this.name,
    required this.role,
    required this.department,
    required this.email,
    required this.phone,
    required this.unit,
    required this.expectedShiftStart,
    required this.expectedShiftEnd,
    required this.status,
    required this.workMode,
    required this.roleLevel,
    this.accessRole,
    required this.requiresLocationOnPunch,
    required this.trustedDeviceRequired,
    required this.notes,
  });

  final String name;
  final String role;
  final String department;
  final String email;
  final String phone;
  final String unit;
  final TimeOfDay expectedShiftStart;
  final TimeOfDay expectedShiftEnd;
  final EmployeeStatus status;
  final EmployeeWorkMode workMode;
  final RoleLevel roleLevel;
  final EmployeeAccessRole? accessRole;
  final bool requiresLocationOnPunch;
  final bool trustedDeviceRequired;
  final String notes;

  factory EmployeeDraft.fromEmployee(EmployeeProfile employee) {
    return EmployeeDraft(
      name: employee.name,
      role: employee.role,
      department: employee.department,
      email: employee.email,
      phone: employee.phone,
      unit: employee.unit,
      expectedShiftStart: employee.expectedShiftStart,
      expectedShiftEnd: employee.expectedShiftEnd,
      status: employee.status,
      workMode: employee.workMode,
      roleLevel: employee.roleLevel,
      accessRole: null,
      requiresLocationOnPunch: employee.requiresLocationOnPunch,
      trustedDeviceRequired: employee.trustedDeviceRequired,
      notes: employee.notes,
    );
  }

  EmployeeDraft copyWith({
    String? name,
    String? role,
    String? department,
    String? email,
    String? phone,
    String? unit,
    TimeOfDay? expectedShiftStart,
    TimeOfDay? expectedShiftEnd,
    EmployeeStatus? status,
    EmployeeWorkMode? workMode,
    RoleLevel? roleLevel,
    EmployeeAccessRole? accessRole,
    bool? requiresLocationOnPunch,
    bool? trustedDeviceRequired,
    String? notes,
  }) {
    return EmployeeDraft(
      name: name ?? this.name,
      role: role ?? this.role,
      department: department ?? this.department,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      unit: unit ?? this.unit,
      expectedShiftStart: expectedShiftStart ?? this.expectedShiftStart,
      expectedShiftEnd: expectedShiftEnd ?? this.expectedShiftEnd,
      status: status ?? this.status,
      workMode: workMode ?? this.workMode,
      roleLevel: roleLevel ?? this.roleLevel,
      accessRole: accessRole ?? this.accessRole,
      requiresLocationOnPunch:
          requiresLocationOnPunch ?? this.requiresLocationOnPunch,
      trustedDeviceRequired:
          trustedDeviceRequired ?? this.trustedDeviceRequired,
      notes: notes ?? this.notes,
    );
  }

  JsonMap toApiJson() {
    return {
      'name': name,
      'role': role,
      'department': department,
      'email': email,
      'phone': phone,
      'unit': unit,
      'expectedShiftStart': _timeOfDayToApi(expectedShiftStart),
      'expectedShiftEnd': _timeOfDayToApi(expectedShiftEnd),
      'status': employeeStatusToApi(status),
      'workMode': employeeWorkModeToApi(workMode),
      'roleLevel': roleLevelToApi(roleLevel),
      if (accessRole != null)
        'accessRole': employeeAccessRoleToApi(accessRole!),
      'requiresLocationOnPunch': requiresLocationOnPunch,
      'trustedDeviceRequired': trustedDeviceRequired,
      'notes': notes,
    };
  }
}
