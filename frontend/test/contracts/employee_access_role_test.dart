import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/employee.dart';

void main() {
  test('parses account role separately from the employee job title', () {
    final profile = EmployeeProfile.fromJson(
      _employeeJson(hasAccount: true, accessRole: 'manager'),
    );

    expect(profile.hasAccount, isTrue);
    expect(profile.accessRole, 'manager');
    expect(profile.role, 'Analista Financeira');
  });

  test('accepts legacy responses and preserves role when it is not edited', () {
    final legacyProfile = EmployeeProfile.fromJson(_employeeJson());
    final draft = EmployeeDraft.fromEmployee(legacyProfile);

    expect(legacyProfile.hasAccount, isNull);
    expect(legacyProfile.accessRole, isNull);
    expect(draft.toApiJson().containsKey('accessRole'), isFalse);
  });

  test('account metadata survives employee field edits', () {
    final manager = EmployeeProfile.fromJson(
      _employeeJson(hasAccount: true, accessRole: 'manager'),
    );
    final updated = manager.applyDraft(EmployeeDraft.fromEmployee(manager));

    expect(updated.hasAccount, isTrue);
    expect(updated.accessRole, 'manager');
    expect(updated.role, 'Analista Financeira');
  });

  test(
    'only an explicit supported role choice adds accessRole to the payload',
    () {
      final profile = EmployeeProfile.fromJson(
        _employeeJson(hasAccount: true, accessRole: 'employee'),
      );
      final draft = EmployeeDraft.fromEmployee(profile)
          .copyWith(accessRole: EmployeeAccessRole.manager);

      expect(draft.toApiJson()['accessRole'], 'manager');
    },
  );
}

Map<String, dynamic> _employeeJson({
  bool? includeAccountMetadata,
  bool? hasAccount,
  String? accessRole,
}) =>
    <String, dynamic>{
      'id': 'employee-1',
      'name': 'Renata Souza',
      'role': 'Analista Financeira',
      'department': 'Financeiro',
      'email': 'renata.souza@touchin.com',
      'phone': '(11) 94444-6060',
      'unit': 'Matriz',
      'expectedShiftStart': '08:00:00',
      'expectedShiftEnd': '17:00:00',
      'status': 'active',
      'workMode': 'hybrid',
      'roleLevel': 'specialist',
      'requiresLocationOnPunch': false,
      'trustedDeviceRequired': true,
      'todayWorkedMinutes': 0,
      'pendingAdjustments': 0,
      'lastPunchAt': null,
      'notes': '',
      if (includeAccountMetadata ?? (hasAccount != null || accessRole != null))
        'hasAccount': hasAccount,
      if (includeAccountMetadata ?? (hasAccount != null || accessRole != null))
        'accessRole': accessRole,
    };
