import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/navigation/workspace_destinations.dart';
import 'package:touchin_flutter/core/navigation/workspace_router.dart';
import 'package:touchin_flutter/features/auth/presentation/logout_navigation.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

export 'package:touchin_flutter/core/navigation/workspace_destinations.dart';

typedef WorkspaceLogoutHandler = Future<void> Function(BuildContext context);

abstract final class WorkspaceBreakpoints {
  static const double wide = 1080;
}

// Session-scoped so a reload restores expanded labels if the viewport changes.
final ValueNotifier<bool> workspaceSidebarCollapsed =
    ValueNotifier<bool>(false);

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
  const WorkspaceNavigationBrand({
    super.key,
    this.compact = false,
    this.collapsed = false,
    this.onOpenDrawer,
    this.onToggleCollapse,
  });

  final bool compact;
  final bool collapsed;
  final VoidCallback? onOpenDrawer;
  final VoidCallback? onToggleCollapse;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final mark = Container(
      width: compact || collapsed ? 28 : 42,
      height: compact || collapsed ? 28 : 42,
      decoration: BoxDecoration(
        color: colors.onPrimary,
      ),
      child: Icon(
        Icons.fingerprint_rounded,
        size: compact || collapsed ? 20 : 30,
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

    if (collapsed) {
      return Container(
        alignment: Alignment.center,
        decoration: const BoxDecoration(color: AppTheme.accent),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            mark,
            const SizedBox(height: 4),
            IconButton(
              onPressed: onToggleCollapse,
              tooltip: 'Expandir navegação',
              icon: Icon(Icons.chevron_right_rounded, color: colors.onPrimary),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              visualDensity: VisualDensity.standard,
            ),
          ],
        ),
      );
    }

    return Container(
      key: compact && onOpenDrawer != null
          ? const ValueKey<String>('workspace-mobile-brand-block')
          : null,
      decoration: BoxDecoration(
        color: AppTheme.accent,
      ),
      padding: compact
          ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
          : const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Row(
        mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
        children: <Widget>[
          if (compact && onOpenDrawer != null) ...<Widget>[
            IconButton(
              onPressed: onOpenDrawer,
              tooltip: 'Abrir menu',
              icon: Icon(Icons.menu_rounded, color: colors.onPrimary),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 4),
          ],
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
          if (onToggleCollapse != null)
            IconButton(
              onPressed: onToggleCollapse,
              tooltip: 'Recolher navegação',
              icon: Icon(Icons.chevron_left_rounded, color: colors.onPrimary),
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              visualDensity: VisualDensity.standard,
            ),
        ],
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
    this.iconOnly = false,
    this.foreground,
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onPressed;
  final bool iconOnly;

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
    final child = widget.iconOnly
        ? Center(child: Icon(widget.icon, size: 24, color: foreground))
        : Row(
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
          );
    final item = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onPressed,
        onHover: (hovered) => setState(() => _hovered = hovered),
        onFocusChange: (focused) => setState(() => _focused = focused),
        hoverColor: Colors.transparent,
        focusColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 48),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(
              color: _focused ? navigation.focusRing : Colors.transparent,
              width: 2,
            ),
          ),
          padding: widget.iconOnly
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: child,
        ),
      ),
    );
    final interactive = widget.tooltip == null
        ? item
        : Tooltip(
            message: widget.tooltip!,
            excludeFromSemantics: true,
            child: item,
          );
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.label,
      child: interactive,
    );
  }
}

class _AvailableWorkspaceDestinations extends StatelessWidget {
  const _AvailableWorkspaceDestinations({required this.builder});

  final Widget Function(
    BuildContext context,
    List<WorkspaceDestination> destinations,
  ) builder;

  @override
  Widget build(BuildContext context) {
    final router = WorkspaceRouterScope.maybeOf(context);
    if (router == null) return builder(context, workspaceDestinations);
    return ValueListenableBuilder<AuthUserSummary?>(
      valueListenable: router.navigationUser,
      builder: (context, user, _) =>
          builder(context, availableWorkspaceDestinations(user)),
    );
  }
}

class WorkspaceNavigationPanel extends StatelessWidget {
  const WorkspaceNavigationPanel({
    super.key,
    this.collapsed = false,
    this.contextualContent,
    this.onLogoutRequested = logoutFromWorkspace,
    this.currentRoute,
    this.onToggleCollapse,
  });

  final bool collapsed;
  final Widget? contextualContent;
  final WorkspaceLogoutHandler onLogoutRequested;
  final String? currentRoute;
  final VoidCallback? onToggleCollapse;

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
          WorkspaceNavigationBrand(
            collapsed: collapsed,
            onToggleCollapse: onToggleCollapse,
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey<String>('workspace-desktop-destinations'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  _AvailableWorkspaceDestinations(
                    builder: (context, destinations) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (final destination in destinations)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: WorkspaceNavigationItem(
                              icon: destination.icon,
                              label: destination.label,
                              selected: activeRoute == destination.route,
                              iconOnly: collapsed,
                              tooltip: collapsed ? destination.label : null,
                              onPressed: () =>
                                  _navigateTo(context, destination.route),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Divider(color: colors.outlineVariant),
                  const SizedBox(height: 10),
                  WorkspaceNavigationItem(
                    icon: Icons.logout_rounded,
                    label: 'Sair do Sistema',
                    selected: false,
                    iconOnly: collapsed,
                    tooltip: collapsed ? 'Sair do Sistema' : null,
                    foreground: colors.error,
                    onPressed: () => onLogoutRequested(context),
                  ),
                  if (contextualContent != null && !collapsed) ...<Widget>[
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
                _AvailableWorkspaceDestinations(
                  builder: (context, destinations) => Column(
                    children: <Widget>[
                      for (final destination in destinations)
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
                    ],
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
          padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: colors.outlineVariant)),
          ),
          child: Row(
            children: <Widget>[
              WorkspaceNavigationBrand(
                compact: true,
                onOpenDrawer: onOpenDrawer,
              ),
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
