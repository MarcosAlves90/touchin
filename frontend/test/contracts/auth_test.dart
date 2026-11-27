import 'package:touchin_flutter/contracts/auth.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exposes role helpers for admin, manager and super admin', () {
    const admin = AuthUserSummary(
      id: 'usr-01',
      email: 'admin@touchin.com',
      role: 'admin',
      employeeId: 'emp-01',
    );
    const manager = AuthUserSummary(
      id: 'usr-02',
      email: 'manager@touchin.com',
      role: 'manager',
      employeeId: 'emp-02',
    );
    const superAdmin = AuthUserSummary(
      id: 'usr-03',
      email: 'super.admin@touchin.com',
      role: 'super_admin',
    );

    expect(admin.isAdmin, isTrue);
    expect(admin.hasAdminWorkspaceAccess, isTrue);
    expect(admin.workspaceAccessLabel, 'Perfil administrador');

    expect(manager.isManager, isTrue);
    expect(manager.hasAdminWorkspaceAccess, isFalse);
    expect(manager.workspaceAccessLabel, 'Perfil gerencial');

    expect(superAdmin.isSuperAdmin, isTrue);
    expect(superAdmin.hasAdminWorkspaceAccess, isTrue);
    expect(superAdmin.hasEmployeeProfile, isFalse);
    expect(superAdmin.workspaceAccessLabel, 'Perfil super administrador');
  });
}
