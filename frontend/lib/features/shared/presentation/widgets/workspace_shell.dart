import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:touchin_flutter/features/auth/presentation/logout_navigation.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_navigation.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
    final currentRoute = workspaceCurrentRoute(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= WorkspaceBreakpoints.wide;

        return Scaffold(
          drawer: isWide
              ? null
              : WorkspaceNavigationDrawer(
                  currentRoute: currentRoute,
                  onLogoutRequested: onLogoutRequested,
                ),
          body: Builder(
            builder: (bodyContext) => DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: <Color>[
                    colorScheme.surface,
                    colorScheme.surfaceContainerHighest.withValues(alpha: 0.84),
                  ],
                ),
              ),
              child: Stack(
                children: <Widget>[
                  Positioned(
                    top: -120,
                    right: -40,
                    child: _AmbientGlow(
                      color: AppTheme.accent.withValues(alpha: 0.22),
                      size: 280,
                    ),
                  ),
                  Positioned(
                    bottom: -120,
                    left: -60,
                    child: _AmbientGlow(
                      color: colorScheme.secondary.withValues(alpha: 0.14),
                      size: 260,
                    ),
                  ),
                  _buildStaticBackdrop(colorScheme),
                  SafeArea(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: colorScheme.outlineVariant.withValues(
                            alpha: 0.6,
                          ),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStaticBackdrop(ColorScheme colorScheme) {
    return Positioned.fill(
      child: IgnorePointer(
        child: ClipRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: ColoredBox(
              color: colorScheme.surface.withValues(alpha: 0.74),
            ),
          ),
        ),
      ),
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
    this.maxContentWidth = 560,
    this.actions = const <Widget>[],
    this.compact = false,
  });

  final String title;
  final String description;
  final double maxContentWidth;
  final List<Widget> actions;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      spacing: 12,
      runSpacing: 12,
      children: <Widget>[
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: (compact
                          ? theme.textTheme.headlineSmall
                          : theme.textTheme.headlineMedium)
                      ?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (description.trim().isNotEmpty) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  description,
                  style: (compact
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.bodyLarge)
                      ?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (actions.isNotEmpty)
          Wrap(spacing: 12, runSpacing: 12, children: actions),
      ],
    );
  }
}

class WorkspaceSectionCard extends StatelessWidget {
  const WorkspaceSectionCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
      shape: RoundedRectangleBorder(
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.78),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(icon, size: 18, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
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
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.56),
        border: Border.all(color: colorScheme.outlineVariant),
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

class _AmbientGlow extends StatelessWidget {
  const _AmbientGlow({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: <Color>[color, color.withValues(alpha: 0)],
          ),
        ),
      ),
    );
  }
}
