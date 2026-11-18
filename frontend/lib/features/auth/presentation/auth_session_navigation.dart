import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/navigation/workspace_destinations.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_page.dart';
import 'package:touchin_flutter/features/auth/presentation/must_change_password_page.dart';
import 'package:touchin_flutter/features/projects/presentation/project_kanban_page.dart';
import 'package:touchin_flutter/features/projects/presentation/project_tasks_page.dart';
import 'package:touchin_flutter/features/settings/presentation/ai_settings_page.dart';
import 'package:touchin_flutter/features/settings/presentation/settings_page.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_page.dart';
import 'package:flutter/material.dart';

Route<void> buildAuthenticatedWorkspaceRoute(
  AuthSession session, {
  String? routeName,
}) {
  if (session.mustChangePassword) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/must-change-password'),
      builder: (_) => const MustChangePasswordPage(),
    );
  }

  final requestedPage = _workspacePage(routeName);
  final requestedPageIsAllowed = routeName != '/admin/ai-settings' ||
      session.user.role == 'admin' ||
      session.user.role == 'super_admin';
  if (requestedPage != null && requestedPageIsAllowed) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: routeName),
      builder: (_) => requestedPage,
    );
  }

  final defaultRoute = defaultWorkspaceRouteFor(session.user);
  final defaultPage = _workspacePage(defaultRoute)!;
  return MaterialPageRoute<void>(
    settings: RouteSettings(name: defaultRoute),
    builder: (_) => defaultPage,
  );
}

Widget? _workspacePage(String? routeName) => switch (routeName) {
      '/time-clock' => const TimeClockPage(),
      '/admin/employees' => const AdminEmployeesPage(),
      '/admin/audit' => const AdminAuditPage(),
      '/admin/ai-settings' => const AdminAISettingsPage(),
      '/projects' => const ProjectTasksPage(),
      '/kanban' => const ProjectKanbanPage(),
      '/settings' => const ThemeSettingsPage(),
      _ => null,
    };
