import 'package:flutter/material.dart';
import 'package:touchin_flutter/core/navigation/workspace_router.dart';
import 'package:touchin_flutter/features/auth/presentation/logout_navigation.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

typedef WorkspaceLogoutHandler = Future<void> Function(BuildContext context);

/// The only list of workspace destinations used by both navigation layouts.
class WorkspaceDestination {
  const WorkspaceDestination(this.icon, this.label, this.route);

  final IconData icon;
  final String label;
  final String route;
}

const workspaceDestinations = <WorkspaceDestination>[
  WorkspaceDestination(Icons.timer_outlined, 'Bater Ponto', '/time-clock'),
  WorkspaceDestination(
    Icons.groups_2_rounded,
    'Administrar Equipe',
    '/admin/employees',
  ),
  WorkspaceDestination(
    Icons.history_edu,
    'Trilha de Auditoria',
    '/admin/audit',
  ),
  WorkspaceDestination(
    Icons.account_tree_outlined,
    'Projetos e tarefas',
    '/projects',
  ),
  WorkspaceDestination(Icons.view_kanban_outlined, 'Kanban', '/kanban'),
  WorkspaceDestination(Icons.tune_rounded, 'Configurações', '/settings'),
];

abstract final class WorkspaceBreakpoints {
  static const double wide = 1080;
}

String? workspaceCurrentRoute(BuildContext context) {
  return WorkspaceRouterScope.maybeOf(context)?.currentConfiguration.path ??
      ModalRoute.of(context)?.settings.name;
}

WorkspaceDestination? workspaceDestinationFor(String? route) {
  for (final destination in workspaceDestinations) {
    if (destination.route == route) return destination;
  }
  return null;
}

class WorkspaceNavigationBrand extends StatelessWidget {
  const WorkspaceNavigationBrand({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mark = Container(
      width: compact ? 28 : 42,
      height: compact ? 28 : 42,
      decoration: BoxDecoration(
        color: colors.onPrimary,
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
      ),
      child: Icon(
        Icons.fingerprint_rounded,
        size: compact ? 20 : 30,
        color: AppTheme.accent,
      ),
    );
    final wordmark = Semantics(
      header: true,
      child: Text(
        'TOUCHIN',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style:
            (compact ? theme.textTheme.labelLarge : theme.textTheme.titleMedium)
                ?.copyWith(
          color: colors.onPrimary,
          letterSpacing: compact ? 1.4 : 1.7,
          fontWeight: FontWeight.w900,
        ),
      ),
    );

    return ColoredBox(
      color: AppTheme.accent,
      child: Padding(
        padding: compact
            ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
            : const EdgeInsets.fromLTRB(20, 18, 20, 18),
        child: Row(
          mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
          children: <Widget>[
            mark,
            SizedBox(width: compact ? 7 : 12),
            if (compact)
              wordmark
            else
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    wordmark,
                    const SizedBox(height: 2),
                    Text(
                      'CONTROLE DE PONTO',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colors.onPrimary.withValues(alpha: 0.82),
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class WorkspaceNavigationItem extends StatefulWidget {
  const WorkspaceNavigationItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.foreground,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;

  /// Used by logout while retaining the shared item shape and focus treatment.
  final Color? foreground;
  final String? tooltip;

  @override
  State<WorkspaceNavigationItem> createState() =>
      _WorkspaceNavigationItemState();
}

class _WorkspaceNavigationItemState extends State<WorkspaceNavigationItem> {
  bool _hovered = false;
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final navigation = WorkspaceNavigationColors.of(theme);
    final foreground = widget.foreground ??
        (widget.selected
            ? navigation.selectedForeground
            : navigation.itemForeground);
    final background = widget.selected
        ? navigation.selectedContainer
        : _hovered
            ? Color.alphaBlend(navigation.hoverOverlay, colors.surface)
            : Colors.transparent;
    final item = Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onPressed,
          onHover: (hovered) => setState(() => _hovered = hovered),
          onFocusChange: (focused) => setState(() => _focused = focused),
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _focused ? navigation.focusRing : Colors.transparent,
                width: 2,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: <Widget>[
                Icon(widget.icon, size: 24, color: foreground),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    widget.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: foreground,
                      fontWeight:
                          widget.selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                ),
                if (widget.selected)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: foreground,
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    if (widget.tooltip case final tooltip?) {
      return Tooltip(message: tooltip, excludeFromSemantics: true, child: item);
    }
    return item;
  }
}

class WorkspaceNavigationPanel extends StatelessWidget {
  const WorkspaceNavigationPanel({
    super.key,
    this.contextualContent,
    this.onLogoutRequested = logoutFromWorkspace,
    this.currentRoute,
  });

  final Widget? contextualContent;
  final WorkspaceLogoutHandler onLogoutRequested;
  final String? currentRoute;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeRoute = currentRoute ?? workspaceCurrentRoute(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(right: BorderSide(color: colors.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const WorkspaceNavigationBrand(),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey<String>('workspace-desktop-destinations'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final destination in workspaceDestinations)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: WorkspaceNavigationItem(
                        icon: destination.icon,
                        label: destination.label,
                        selected: activeRoute == destination.route,
                        onPressed: () =>
                            _navigateTo(context, destination.route),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Divider(color: colors.outlineVariant),
                  const SizedBox(height: 10),
                  WorkspaceNavigationItem(
                    icon: Icons.logout_rounded,
                    label: 'Sair do Sistema',
                    selected: false,
                    foreground: colors.error,
                    onPressed: () => onLogoutRequested(context),
                  ),
                  if (contextualContent != null) ...<Widget>[
                    const SizedBox(height: 8),
                    KeyedSubtree(
                      key: const ValueKey<String>('workspace-context-scroll'),
                      child: contextualContent!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, String routeName) {
    final router = WorkspaceRouterScope.maybeOf(context);
    final route = workspaceCurrentRoute(context);
    if (route == routeName) return;
    if (router != null) {
      router.navigate(routeName);
    } else {
      Navigator.of(context).pushNamed(routeName);
    }
  }
}

/// Backwards-compatible public name used by existing callers and tests.
class WorkspaceDesktopNavigation extends StatelessWidget {
  const WorkspaceDesktopNavigation({
    super.key,
    this.contextualContent,
    this.onLogoutRequested = logoutFromWorkspace,
    this.currentRoute,
  });

  final Widget? contextualContent;
  final WorkspaceLogoutHandler onLogoutRequested;
  final String? currentRoute;

  @override
  Widget build(BuildContext context) {
    return WorkspaceNavigationPanel(
      contextualContent: contextualContent,
      onLogoutRequested: onLogoutRequested,
      currentRoute: currentRoute,
    );
  }
}

class WorkspaceNavigationDrawer extends StatelessWidget {
  const WorkspaceNavigationDrawer({
    super.key,
    this.currentRoute,
    this.onLogoutRequested = logoutFromWorkspace,
  });

  final String? currentRoute;
  final WorkspaceLogoutHandler onLogoutRequested;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final activeRoute = currentRoute ?? workspaceCurrentRoute(context);

    return Drawer(
      key: const ValueKey<String>('workspace-navigation-drawer'),
      width: 280,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: colors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const WorkspaceNavigationBrand(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              children: <Widget>[
                for (final destination in workspaceDestinations)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: WorkspaceNavigationItem(
                      icon: destination.icon,
                      label: destination.label,
                      selected: activeRoute == destination.route,
                      onPressed: () => _navigateTo(context, destination.route),
                    ),
                  ),
                const SizedBox(height: 12),
                Divider(color: colors.outlineVariant),
                const SizedBox(height: 10),
                WorkspaceNavigationItem(
                  icon: Icons.logout_rounded,
                  label: 'Sair do Sistema',
                  selected: false,
                  foreground: colors.error,
                  onPressed: () async {
                    await onLogoutRequested(context);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _navigateTo(BuildContext context, String routeName) {
    final navigator = Navigator.of(context);
    final router = WorkspaceRouterScope.maybeOf(context);
    final current = workspaceCurrentRoute(context);
    navigator.pop();
    if (current == routeName) return;
    if (router != null) {
      router.navigate(routeName);
    } else {
      navigator.pushNamed(routeName);
    }
  }
}

class WorkspaceMobileHeader extends StatelessWidget {
  const WorkspaceMobileHeader({
    super.key,
    required this.onOpenDrawer,
    this.currentRoute,
  });

  final VoidCallback onOpenDrawer;
  final String? currentRoute;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final navigation = WorkspaceNavigationColors.of(theme);
    final active = workspaceDestinationFor(
      currentRoute ?? workspaceCurrentRoute(context),
    );

    return Material(
      color: colors.surface,
      child: SafeArea(
        bottom: false,
        child: Container(
          key: const ValueKey<String>('workspace-mobile-header'),
          padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: Row(
            children: <Widget>[
              IconButton(
                onPressed: onOpenDrawer,
                tooltip: 'Abrir menu',
                icon: Icon(Icons.menu_rounded, color: colors.onSurface),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 4),
              const WorkspaceNavigationBrand(compact: true),
              const SizedBox(width: 8),
              const Spacer(),
              if (active != null)
                Flexible(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 170),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: navigation.selectedContainer,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      active.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      semanticsLabel: 'Destino atual: ${active.label}',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: navigation.selectedForeground,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
