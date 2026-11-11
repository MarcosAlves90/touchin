import 'package:flutter/material.dart';
import 'package:touchin_flutter/features/auth/presentation/logout_navigation.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_navigation.dart';

export 'package:touchin_flutter/features/shared/presentation/widgets/workspace_navigation.dart';

class WorkspaceScaffold extends StatelessWidget {
  const WorkspaceScaffold({
    super.key,
    required this.contentBuilder,
    this.contextualContent,
    this.contentScrollable = true,
    this.onLogoutRequested = logoutFromWorkspace,
  });

  final Widget Function(BuildContext context, bool isWide) contentBuilder;
  final Widget? contextualContent;
  final bool contentScrollable;
  final WorkspaceLogoutHandler onLogoutRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentRoute = workspaceCurrentRoute(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= WorkspaceBreakpoints.wide;

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          drawer: isWide
              ? null
              : WorkspaceNavigationDrawer(
                  currentRoute: currentRoute,
                  onLogoutRequested: onLogoutRequested,
                ),
          body: Builder(
            builder: (bodyContext) => SafeArea(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.6),
                  ),
                ),
                child: isWide
                    ? _buildWideLayout(
                        bodyContext,
                        constraints,
                        currentRoute,
                      )
                    : _buildNarrowLayout(
                        bodyContext,
                        constraints,
                        currentRoute,
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    BoxConstraints constraints,
    String? currentRoute,
  ) {
    return ValueListenableBuilder<bool>(
      valueListenable: workspaceSidebarCollapsed,
      builder: (context, collapsed, _) => Row(
        children: <Widget>[
          SizedBox(
            key: const ValueKey<String>('workspace-navigation-sidebar'),
            width: collapsed ? 88 : 360,
            child: WorkspaceNavigationPanel(
              collapsed: collapsed,
              onToggleCollapse: () {
                workspaceSidebarCollapsed.value =
                    !workspaceSidebarCollapsed.value;
              },
              contextualContent: contextualContent,
              onLogoutRequested: onLogoutRequested,
              currentRoute: currentRoute,
            ),
          ),
          Expanded(child: _buildContentPane(context, constraints, true)),
        ],
      ),
    );
  }

  Widget _buildNarrowLayout(
    BuildContext context,
    BoxConstraints constraints,
    String? currentRoute,
  ) {
    return Column(
      children: <Widget>[
        WorkspaceMobileHeader(
          currentRoute: currentRoute,
          onOpenDrawer: () => Scaffold.of(context).openDrawer(),
        ),
        Expanded(child: _buildContentPane(context, constraints, false)),
      ],
    );
  }

  Widget _buildContentPane(
    BuildContext context,
    BoxConstraints constraints,
    bool isWide,
  ) {
    final content = contentBuilder(context, isWide);
    if (contentScrollable) {
      return SingleChildScrollView(
        child: isWide
            ? ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: content,
              )
            : content,
      );
    }
    return content;
  }
}

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.summaryChildren,
    this.heading = 'RESUMO',
  });

  final List<Widget> summaryChildren;
  final String heading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (summaryChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (summaryChildren.isNotEmpty) ...<Widget>[
            Text(
              heading,
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 14),
            ...summaryChildren.map(
              (w) =>
                  Padding(padding: const EdgeInsets.only(bottom: 12), child: w),
            ),
          ],
        ],
      ),
    );
  }
}

class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.title,
    required this.description,
    this.kicker,
    this.kickerKey,
    this.maxContentWidth = 560,
    this.actions = const <Widget>[],
    this.compact = false,
  });

  final String title;
  final String description;
  final String? kicker;
  final Key? kickerKey;
  final double maxContentWidth;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final heading = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxContentWidth),
      child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (kicker != null) ...<Widget>[
              Text(kicker!,
                  key: kickerKey,
                  style: theme.textTheme.labelLarge?.copyWith(
                      color: colorScheme.brightness == Brightness.light
                          ? colorScheme.onSurfaceVariant
                          : colorScheme.secondary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.3)),
              const SizedBox(height: 6),
            ],
            Semantics(
                header: true,
                child: Text(title,
                    style: (compact && kicker == null
                            ? theme.textTheme.headlineSmall
                            : theme.textTheme.headlineMedium)
                        ?.copyWith(fontWeight: FontWeight.w700))),
            if (description.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(description,
                  style: (compact && kicker == null
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodyLarge)
                      ?.copyWith(
                          color: colorScheme.onSurfaceVariant, height: 1.45)),
            ],
          ]),
    );
    final actionTheme = theme.copyWith(
      filledButtonTheme: FilledButtonThemeData(
        style: (theme.filledButtonTheme.style ?? const ButtonStyle()).copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: (theme.outlinedButtonTheme.style ?? const ButtonStyle()).copyWith(
          minimumSize: const WidgetStatePropertyAll(Size(0, 48)),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 16)),
        ),
      ),
    );
    Widget actionWrap(WrapAlignment alignment) => Theme(
      data: actionTheme,
      child: Wrap(alignment: alignment, spacing: 12, runSpacing: 12, children: actions),
    );
    return LayoutBuilder(builder: (context, constraints) {
      if (actions.isNotEmpty && (!compact || kicker != null) && constraints.maxWidth >= 540) {
        return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(child: heading),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints:
                    BoxConstraints(maxWidth: constraints.maxWidth * 0.5),
                child: actionWrap(WrapAlignment.end),
              ),
            ]);
      }
      return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            heading,
            if (actions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 12),
              actionWrap(WrapAlignment.start),
            ],
          ]);
    });
  }
}

class WorkspaceSectionCard extends StatelessWidget {
  const WorkspaceSectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: SizedBox(
        width: double.infinity,
        child: Padding(padding: const EdgeInsets.all(22), child: child),
      ),
    );
  }
}

class WorkspaceMetricCard extends StatelessWidget {
  const WorkspaceMetricCard({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.helper,
  });

  final IconData icon;
  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          DecoratedBox(
            key: const ValueKey<String>('workspace-metric-icon-tile'),
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(icon, size: 20, color: colorScheme.onSurface),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  label,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  helper,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspaceSummaryStripe extends StatelessWidget {
  const WorkspaceSummaryStripe({
    super.key,
    required this.label,
    required this.value,
    required this.helper,
  });

  final String label;
  final String value;
  final String helper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.8),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspaceStatusBadge extends StatelessWidget {
  const WorkspaceStatusBadge({
    super.key,
    required this.label,
    required this.tone,
  });

  final String label;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: tone.withValues(alpha: 0.28)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: tone,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
