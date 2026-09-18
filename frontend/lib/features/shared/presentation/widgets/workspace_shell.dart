import 'dart:ui';

import 'package:bunchin_flutter/features/admin/presentation/admin_employees_page.dart';
import 'package:bunchin_flutter/features/auth/presentation/logout_navigation.dart';
import 'package:bunchin_flutter/features/projects/presentation/project_tasks_page.dart';
import 'package:bunchin_flutter/features/settings/presentation/settings_page.dart';
import 'package:bunchin_flutter/features/time_tracking/presentation/time_clock_page.dart';
import 'package:bunchin_flutter/theme/app_theme.dart';
import 'package:flutter/material.dart';

typedef WorkspaceLogoutHandler = Future<void> Function(BuildContext context);

class WorkspaceScaffold extends StatelessWidget {
  const WorkspaceScaffold({
    super.key,
    required this.sidebar,
    required this.contentBuilder,
    this.wideBreakpoint = 1080,
    this.sidebarWidth = 360,
    this.onLogoutRequested = logoutFromWorkspace,
  });

  final Widget sidebar;
  final Widget Function(BuildContext context, bool isWide) contentBuilder;
  final double wideBreakpoint;
  final double sidebarWidth;
  final WorkspaceLogoutHandler onLogoutRequested;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      drawer: _AppNavigationDrawer(onLogoutRequested: onLogoutRequested),
      body: DecoratedBox(
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
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= wideBreakpoint;

                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.74),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: isWide
                            ? _buildWideLayout(context, constraints)
                            : _buildNarrowLayout(context, constraints),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(BuildContext context, BoxConstraints constraints) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: sidebarWidth,
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: sidebar,
            ),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: contentBuilder(context, true),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout(BuildContext context, BoxConstraints constraints) {
    return Column(
      children: <Widget>[
        sidebar,
        Expanded(
          child: SingleChildScrollView(child: contentBuilder(context, false)),
        ),
      ],
    );
  }
}

class _AppNavigationDrawer extends StatelessWidget {
  const _AppNavigationDrawer({required this.onLogoutRequested});

  final WorkspaceLogoutHandler onLogoutRequested;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      width: 280,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      backgroundColor: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
            decoration: BoxDecoration(color: AppTheme.accent),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    size: 32,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'BUNCHIN',
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: colorScheme.onPrimary,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Text(
                  'CONTROLE DE PONTO',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onPrimary.withValues(alpha: 0.6),
                    letterSpacing: 1,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildDrawerItem(
            context,
            icon: Icons.timer_outlined,
            label: 'Bater Ponto',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(builder: (_) => const TimeClockPage()),
              );
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.groups_2_rounded,
            label: 'Administrar Equipe',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const AdminEmployeesPage(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.account_tree_outlined,
            label: 'Projetos e tarefas',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const ProjectTasksPage(),
                ),
              );
            },
          ),
          _buildDrawerItem(
            context,
            icon: Icons.tune_rounded,
            label: 'Configurações',
            onTap: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute<void>(
                  builder: (_) => const ThemeSettingsPage(),
                ),
              );
            },
          ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Divider(
              color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          _buildDrawerItem(
            context,
            icon: Icons.logout_rounded,
            label: 'Sair do Sistema',
            color: colorScheme.error,
            onTap: () async {
              await onLogoutRequested(context);
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final finalColor = color ?? colorScheme.onSurface.withValues(alpha: 0.8);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Icon(icon, size: 24, color: finalColor),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: finalColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WorkspaceSidebar extends StatelessWidget {
  const WorkspaceSidebar({
    super.key,
    required this.title,
    required this.description,
    required this.summaryChildren,
    required this.highlightChips,
    this.brandLabel = 'BUNCHIN',
  });

  final String title;
  final String description;
  final List<Widget> summaryChildren;
  final List<Widget> highlightChips;
  final String brandLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isWide = MediaQuery.of(context).size.width >= 1080;

    if (!isWide) {
      return _buildMobileHeader(context);
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(28, 20, 28, 40),
      decoration: BoxDecoration(
        color: AppTheme.accent,
        border: Border(
          right: BorderSide(
            color: Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: [
              IconButton(
                onPressed: () => Scaffold.of(context).openDrawer(),
                icon: Icon(Icons.menu_rounded, color: colorScheme.onPrimary),
                tooltip: 'Abrir menu',
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 8),
              Text(
                brandLabel,
                style: theme.textTheme.labelLarge?.copyWith(
                  color: colorScheme.onPrimary.withValues(alpha: 0.8),
                  letterSpacing: 2.0,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 48),
          Text(
            title,
            style: theme.textTheme.displaySmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 48,
            height: 6,
            decoration: BoxDecoration(
              color: colorScheme.onPrimary.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.8),
              height: 1.55,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (summaryChildren.isNotEmpty) ...<Widget>[
            const SizedBox(height: 48),
            Text(
              'RESUMO',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onPrimary.withValues(alpha: 0.5),
                letterSpacing: 1.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            ...summaryChildren.map(
              (w) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: DefaultTextStyle.merge(
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  child: w,
                ),
              ),
            ),
          ],
          if (highlightChips.isNotEmpty) ...<Widget>[
            const SizedBox(height: 24),
            Theme(
              data: theme.copyWith(
                chipTheme: theme.chipTheme.copyWith(
                  backgroundColor: Colors.black.withValues(alpha: 0.1),
                  labelStyle: TextStyle(color: colorScheme.onPrimary),
                ),
              ),
              child: Wrap(spacing: 8, runSpacing: 8, children: highlightChips),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileHeader(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.accent,
        border: Border(
          bottom: BorderSide(
            color: Colors.black.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            IconButton(
              onPressed: () => Scaffold.of(context).openDrawer(),
              icon: Icon(Icons.menu_rounded, color: colorScheme.onPrimary),
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
            Text(
              brandLabel,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onPrimary.withValues(alpha: 0.8),
                letterSpacing: 1.5,
                fontWeight: FontWeight.w900,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title.split(' ').first,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    Icons.account_circle,
                    color: colorScheme.onPrimary,
                    size: 18,
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

class WorkspaceHeader extends StatelessWidget {
  const WorkspaceHeader({
    super.key,
    required this.title,
    required this.description,
    this.maxContentWidth = 560,
    this.actions = const <Widget>[],
  });

  final String title;
  final String description;
  final double maxContentWidth;
  final List<Widget> actions;

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
              Text(
                title,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                description,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
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
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: child,
        ),
      ),
    );
  }
}

class WorkspaceMetricCard extends StatelessWidget {
  const WorkspaceMetricCard({
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
              Text(
                value,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
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
        color: Colors.black.withValues(alpha: 0.1),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: theme.textTheme.labelLarge?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            helper,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.88),
              height: 1.45,
            ),
          ),
        ],
      ),
    );
  }
}

class WorkspaceHighlightChip extends StatelessWidget {
  const WorkspaceHighlightChip({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: theme.colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
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
