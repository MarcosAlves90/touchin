import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_page.dart';
import 'package:touchin_flutter/features/auth/presentation/must_change_password_page.dart';
import 'package:touchin_flutter/features/projects/presentation/project_kanban_page.dart';
import 'package:touchin_flutter/features/projects/presentation/project_tasks_page.dart';
import 'package:touchin_flutter/features/settings/presentation/settings_page.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_page.dart';
import 'package:flutter/material.dart';

Route<void> buildAuthenticatedWorkspaceRoute(
  AuthSession session, {
  String? routeName,
}) {
  if (session.mustChangePassword) {
    return MaterialPageRoute<void>(
      builder: (_) => const MustChangePasswordPage(),
    );
  }

  final requestedPage = switch (routeName) {
    '/time-clock' => const TimeClockPage(),
    '/admin/employees' => const AdminEmployeesPage(),
    '/admin/audit' => const AdminAuditPage(),
    '/projects' => const ProjectTasksPage(),
    '/kanban' => const ProjectKanbanPage(),
    '/settings' => const ThemeSettingsPage(),
    _ => null,
  };
  if (requestedPage != null) {
    return MaterialPageRoute<void>(builder: (_) => requestedPage);
  }

  if (session.user.hasAdminWorkspaceAccess ||
      !session.user.hasEmployeeProfile) {
    return MaterialPageRoute<void>(
      builder: (_) => const AdminEmployeesPage(),
    );
  }

  return MaterialPageRoute<void>(
    builder: (_) => const TimeClockPage(),
  );
}
