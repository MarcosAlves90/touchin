import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/navigation/workspace_destinations.dart';
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
      settings: const RouteSettings(name: '/must-change-password'),
      builder: (_) => const MustChangePasswordPage(),
    );
  }

  final requestedRouteName =
      routeName == '/admin/ai-settings' ? '/settings' : routeName;
  final requestedPage = _workspacePage(requestedRouteName, session.user);
  final requestedPageIsAllowed =
      routeName != '/admin/ai-settings' || session.user.hasAdminWorkspaceAccess;
  if (requestedPage != null && requestedPageIsAllowed) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: requestedRouteName),
      builder: (_) => requestedPage,
    );
  }

  final defaultRoute = defaultWorkspaceRouteFor(session.user);
  final defaultPage = _workspacePage(defaultRoute, session.user)!;
  return MaterialPageRoute<void>(
    settings: RouteSettings(name: defaultRoute),
    builder: (_) => defaultPage,
  );
}

Widget? _workspacePage(String? routeName, AuthUserSummary user) =>
    switch (routeName) {
      '/time-clock' => const TimeClockPage(),
      '/admin/employees' => const AdminEmployeesPage(),
      '/admin/audit' => const AdminAuditPage(),
      '/projects' => const ProjectTasksPage(),
      '/kanban' => const ProjectKanbanPage(),
      '/settings' => ThemeSettingsPage(
          canManageAISettings: user.hasAdminWorkspaceAccess,
        ),
      _ => null,
    };
