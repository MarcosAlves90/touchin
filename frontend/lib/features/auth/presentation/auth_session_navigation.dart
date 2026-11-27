import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/navigation/workspace_destinations.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_page.dart';
import 'package:touchin_flutter/features/auth/presentation/must_change_password_page.dart';
import 'package:touchin_flutter/features/projects/presentation/project_kanban_page.dart';
import 'package:touchin_flutter/features/projects/presentation/project_tasks_page.dart';
import 'package:touchin_flutter/features/settings/presentation/settings_page.dart';
import 'package:touchin_flutter/features/time_tracking/application/punch_location_service.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_page.dart';

Route<void> buildAuthenticatedWorkspaceRoute(
  AuthSession session, {
  String? routeName,
  TouchInApi? api,
  PunchLocationService? punchLocationService,
}) {
  if (session.mustChangePassword) {
    return MaterialPageRoute<void>(
      settings: const RouteSettings(name: '/must-change-password'),
      builder: (_) => MustChangePasswordPage(api: api),
    );
  }

  final requestedRouteName =
      routeName == '/admin/ai-settings' ? '/settings' : routeName;
  final requestedPageIsAllowed =
      routeName != '/admin/ai-settings' || session.user.hasAdminWorkspaceAccess;
  final requestedPage = _workspacePage(
    requestedRouteName,
    session.user,
    api: api,
    punchLocationService: punchLocationService,
  );
  if (requestedPage != null && requestedPageIsAllowed) {
    return MaterialPageRoute<void>(
      settings: RouteSettings(name: requestedRouteName),
      builder: (_) => requestedPage,
    );
  }

  final defaultRoute = defaultWorkspaceRouteFor(session.user);
  final defaultPage = _workspacePage(
    defaultRoute,
    session.user,
    api: api,
    punchLocationService: punchLocationService,
  )!;
  return MaterialPageRoute<void>(
    settings: RouteSettings(name: defaultRoute),
    builder: (_) => defaultPage,
  );
}

Widget? _workspacePage(
  String? routeName,
  AuthUserSummary user, {
  TouchInApi? api,
  PunchLocationService? punchLocationService,
}) =>
    switch (routeName) {
      '/time-clock' =>
        TimeClockPage(api: api, punchLocationService: punchLocationService),
      '/admin/employees' => AdminEmployeesPage(api: api),
      '/admin/audit' => AdminAuditPage(api: api),
      '/projects' => ProjectTasksPage(api: api),
      '/kanban' => ProjectKanbanPage(api: api),
      '/settings' => ThemeSettingsPage(
          canManageAISettings: user.hasAdminWorkspaceAccess,
          aiSettingsApi: api,
        ),
      _ => null,
    };
