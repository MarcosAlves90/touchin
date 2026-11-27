import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/auth.dart';

/// Which users may use a workspace destination. Mirrors the backend
/// `ROLE_PERMISSIONS`; the backend stays the authority and rejects anything
/// this list hides or shows by mistake.
enum WorkspaceDestinationAccess {
  /// Needs `time_clock.*` (every known role) and a linked employee profile.
  employeeProfile,

  /// Needs `employees.read`/`audit.read`, granted to managerial roles only.
  managerial,

  /// Needs `projects.read`/`kanban.read`, granted to every known role.
  knownRole,

  /// Needs Kanban permission and, for employees, a linked employee profile.
  kanban,

  /// Local-only screen that never calls the backend.
  everyone,
}

class WorkspaceDestination {
  const WorkspaceDestination({
    required this.icon,
    required this.label,
    required this.route,
    required this.access,
  });

  final IconData icon;
  final String label;
  final String route;
  final WorkspaceDestinationAccess access;

  bool isAvailableTo(AuthUserSummary? user) {
    if (access == WorkspaceDestinationAccess.everyone) return true;
    if (user == null || !_knownRoles.contains(user.role)) return false;
    return switch (access) {
      WorkspaceDestinationAccess.employeeProfile => user.hasEmployeeProfile,
      WorkspaceDestinationAccess.managerial =>
        _managerialRoles.contains(user.role),
      WorkspaceDestinationAccess.kanban =>
        _managerialRoles.contains(user.role) || user.hasEmployeeProfile,
      WorkspaceDestinationAccess.knownRole ||
      WorkspaceDestinationAccess.everyone =>
        true,
    };
  }
}

const _knownRoles = <String>{'employee', 'manager', 'admin', 'super_admin'};
const _managerialRoles = <String>{'manager', 'admin', 'super_admin'};

/// Every workspace destination in the canonical navigation order.
const workspaceDestinations = <WorkspaceDestination>[
  WorkspaceDestination(
    icon: Icons.timer_outlined,
    label: 'Bater Ponto',
    route: '/time-clock',
    access: WorkspaceDestinationAccess.employeeProfile,
  ),
  WorkspaceDestination(
    icon: Icons.groups_2_rounded,
    label: 'Administrar Equipe',
    route: '/admin/employees',
    access: WorkspaceDestinationAccess.managerial,
  ),
  WorkspaceDestination(
    icon: Icons.history_edu,
    label: 'Trilha de Auditoria',
    route: '/admin/audit',
    access: WorkspaceDestinationAccess.managerial,
  ),
  WorkspaceDestination(
    icon: Icons.account_tree_outlined,
    label: 'Projetos e tarefas',
    route: '/projects',
    access: WorkspaceDestinationAccess.knownRole,
  ),
  WorkspaceDestination(
    icon: Icons.view_kanban_outlined,
    label: 'Kanban',
    route: '/kanban',
    access: WorkspaceDestinationAccess.kanban,
  ),
  WorkspaceDestination(
    icon: Icons.tune_rounded,
    label: 'Configurações',
    route: '/settings',
    access: WorkspaceDestinationAccess.everyone,
  ),
];

/// Destinations [user] can use, in canonical order. Without a verified user
/// only destinations that never call the backend are listed.
List<WorkspaceDestination> availableWorkspaceDestinations(
  AuthUserSummary? user,
) {
  return <WorkspaceDestination>[
    for (final destination in workspaceDestinations)
      if (destination.isAvailableTo(user)) destination,
  ];
}

/// The landing route after authentication; always an available destination.
String defaultWorkspaceRouteFor(AuthUserSummary user) {
  final routes = availableWorkspaceDestinations(user)
      .map((destination) => destination.route)
      .toList();
  if (user.hasAdminWorkspaceAccess && routes.contains('/admin/employees')) {
    return '/admin/employees';
  }
  // The canonical order puts the time clock first, then team administration.
  return routes.first;
}
