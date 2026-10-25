import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/punch.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_controller.dart';

void main() {
  test('filter reconciles selection to a visible employee', () async {
    final controller = AdminEmployeesController(
      api: _AdminApi(<EmployeeProfile>[
        _employee('active', status: EmployeeStatus.active),
        _employee('inactive', status: EmployeeStatus.inactive),
      ]),
    );
    addTearDown(controller.dispose);

    await controller.start();
    controller.setFilter(EmployeeFilter.inactive);
    await Future<void>.delayed(Duration.zero);

    expect(controller.visibleEmployees.map((employee) => employee.id), [
      'inactive',
    ]);
    expect(controller.selectedEmployeeId, 'inactive');
    expect(controller.selectedEmployee?.id, 'inactive');
  });

  test('employee page change reconciles selection to the new page', () async {
    final controller = AdminEmployeesController(
      api: _AdminApi(
        List<EmployeeProfile>.generate(
            9, (index) => _employee('employee-$index')),
      ),
    );
    addTearDown(controller.dispose);

    await controller.start();
    final firstPageSelection = controller.selectedEmployeeId;
    controller.loadNextEmployeesPage();
    await Future<void>.delayed(Duration.zero);

    expect(controller.employeesPage, 2);
    expect(controller.pagedEmployees.map((employee) => employee.id),
        ['employee-8']);
    expect(controller.selectedEmployeeId, 'employee-8');
    expect(controller.selectedEmployeeId, isNot(firstPageSelection));
    expect(controller.selectedEmployee?.id, controller.selectedEmployeeId);
  });

  test('empty search clears selection, punch state, and loading', () async {
    final pending = Completer<ManagedPunchPage>();
    final api = _AdminApi(<EmployeeProfile>[
      _employee('employee'),
    ], punchLoader: (_, __) => pending.future);
    final controller = AdminEmployeesController(api: api);
    addTearDown(controller.dispose);

    final starting = controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(controller.isLoadingEmployeePunches, isTrue);
    controller.setSearchQuery('nobody matches');
    expect(controller.selectedEmployeeId, isNull);
    expect(controller.isLoadingEmployeePunches, isFalse);
    expect(controller.employeePunches, isEmpty);

    pending.complete(_page('stale-record'));
    await starting;
    expect(controller.employeePunches, isEmpty);
    expect(controller.isLoadingEmployeePunches, isFalse);
  });

  test(
    'latest request wins for overlapping pages of the same employee',
    () async {
      final older = Completer<ManagedPunchPage>();
      final newer = Completer<ManagedPunchPage>();
      var requestCount = 0;
      final controller = AdminEmployeesController(
        api: _AdminApi(
          <EmployeeProfile>[_employee('employee')],
          punchLoader: (_, page) {
            requestCount++;
            if (requestCount == 1) return Future.value(_page('initial'));
            return page == 1 ? older.future : newer.future;
          },
        ),
      );
      addTearDown(controller.dispose);
      await controller.start();

      final olderRequest = controller.loadEmployeePunches('employee', page: 1);
      final newerRequest = controller.loadEmployeePunches('employee', page: 2);
      newer.complete(_page('newer-page', page: 2));
      await newerRequest;
      older.complete(_page('older-page'));
      await olderRequest;

      expect(controller.employeePunches.single.id, 'newer-page');
      expect(controller.employeePunchesPage, 2);
      expect(controller.isLoadingEmployeePunches, isFalse);
    },
  );

  test('punch request errors clear loading and expose the message', () async {
    final controller = AdminEmployeesController(
      api: _AdminApi(<EmployeeProfile>[
        _employee('employee'),
      ], punchLoader: (_, __) => throw ApiException('Falha no ponto.')),
    );
    addTearDown(controller.dispose);

    await controller.start();
    await Future<void>.delayed(Duration.zero);
    expect(controller.isLoadingEmployeePunches, isFalse);
    expect(controller.employeePunchesError, 'Falha no ponto.');
  });
}

class _AdminApi extends TouchInApi {
  _AdminApi(this.employees, {this.punchLoader});

  final List<EmployeeProfile> employees;
  final Future<ManagedPunchPage> Function(String employeeId, int page)?
      punchLoader;

  @override
  Future<AuthContext> getAuthContext() async => const AuthContext(
        company: AuthCompanySummary(
          id: 'company',
          legalName: 'TouchIn',
          tradeName: 'TouchIn',
          cnpjMasked: '',
          emailMasked: '',
          phoneMasked: '',
        ),
        user: AuthUserSummary(
          id: 'admin',
          email: 'admin@example.com',
          role: 'admin',
        ),
      );

  @override
  Future<List<EmployeeProfile>> listEmployees() async => employees;

  @override
  Future<ManagedPunchPage> listManagedPunches(
    String employeeId, {
    int page = 1,
    int limit = 4,
  }) {
    return punchLoader?.call(employeeId, page) ?? Future.value(_page('record'));
  }
}

EmployeeProfile _employee(
  String id, {
  EmployeeStatus status = EmployeeStatus.active,
}) =>
    EmployeeProfile(
      id: id,
      name: id,
      role: 'Analista',
      department: 'Financeiro',
      email: '$id@example.com',
      phone: '',
      unit: 'Matriz',
      expectedShiftStart: const TimeOfDay(hour: 8, minute: 0),
      expectedShiftEnd: const TimeOfDay(hour: 17, minute: 0),
      status: status,
      workMode: EmployeeWorkMode.hybrid,
      roleLevel: RoleLevel.staff,
      requiresLocationOnPunch: false,
      trustedDeviceRequired: false,
      todayWorkedMinutes: 0,
      pendingAdjustments: 0,
      lastPunchAt: null,
      notes: '',
    );

ManagedPunchPage _page(String id, {int page = 1}) => ManagedPunchPage(
      records: <ManagedPunchRecord>[
        ManagedPunchRecord(
          id: id,
          employeeId: 'employee',
          type: PunchType.checkIn,
          timestamp: DateTime(2026, 1, 1),
          detail: id,
          projectId: null,
          location: null,
        ),
      ],
      recordsPage: page,
      recordsPageSize: 4,
      recordsTotal: 1,
      recordsTotalPages: 1,
      recordsHasPrevious: false,
      recordsHasNext: false,
    );
