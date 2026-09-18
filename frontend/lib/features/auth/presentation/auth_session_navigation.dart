import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_page.dart';
import 'package:touchin_flutter/features/auth/presentation/must_change_password_page.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_page.dart';
import 'package:flutter/material.dart';

Route<void> buildAuthenticatedWorkspaceRoute(AuthSession session) {
  if (session.mustChangePassword) {
    return MaterialPageRoute<void>(
      builder: (_) => const MustChangePasswordPage(),
    );
  }

  if (session.user.hasAdminWorkspaceAccess || !session.user.hasEmployeeProfile) {
    return MaterialPageRoute<void>(
      builder: (_) => const AdminEmployeesPage(),
    );
  }

  return MaterialPageRoute<void>(
    builder: (_) => const TimeClockPage(),
  );
}
