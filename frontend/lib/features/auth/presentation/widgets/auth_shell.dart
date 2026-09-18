import 'dart:ui';

import 'package:touchin_flutter/theme/app_theme.dart';
import 'package:flutter/material.dart';

part 'auth_form_widgets.dart';

TextStyle? authPageTitleStyle(BuildContext context) {
  final theme = Theme.of(context);
  final isMobile = MediaQuery.sizeOf(context).width < 920;

  return (isMobile
          ? theme.textTheme.headlineSmall
          : theme.textTheme.headlineMedium)
      ?.copyWith(
    fontWeight: FontWeight.w700,
    height: 1.08,
  );
}

class AuthShell extends StatelessWidget {
  const AuthShell({
    super.key,
    required this.formPanel,
    required this.brandHeadline,
    required this.brandDescription,
    required this.brandTags,
  });

  final Widget formPanel;
  final String brandHeadline;
  final String brandDescription;
  final List<String> brandTags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;
    final secondary = colorScheme.secondary;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.surface,
              colorScheme.surfaceContainerHighest.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -120,
              right: -40,
              child: _AmbientGlow(
                color: primary.withValues(alpha: 0.22),
                size: 260,
              ),
            ),
            Positioned(
              left: -100,
              bottom: -80,
              child: _AmbientGlow(
                color: secondary.withValues(alpha: 0.14),
                size: 240,
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 920;

                  return DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface.withValues(alpha: 0.76),
                      border: Border.all(
                        color: colorScheme.outlineVariant.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                        child: SizedBox.expand(
                          child: isWide
                              ? Row(
                                  children: [
                                    Expanded(
                                      child: _AuthBrandPanel(
                                        headline: brandHeadline,
                                        description: brandDescription,
                                        tags: brandTags,
                                      ),
                                    ),
                                    Expanded(
                                      child: Material(
                                        color: Colors.transparent,
                                        child: SingleChildScrollView(
                                          child: ConstrainedBox(
                                            constraints: BoxConstraints(
                                              minHeight: constraints.maxHeight,
                                            ),
                                            child: formPanel,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                )
                              : Material(
                                  color: Colors.transparent,
                                  child: SingleChildScrollView(
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        minHeight: constraints.maxHeight,
                                      ),
                                      child: formPanel,
                                    ),
                                  ),
                                ),
                        ),
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
}

class AuthCompactBrandBadge extends StatelessWidget {
  const AuthCompactBrandBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.14),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.28),
        ),
      ),
      child: _AuthBrandMark(
        compact: true,
        foregroundColor: colorScheme.primary,
      ),
    );
  }
}

class _AuthBrandMark extends StatelessWidget {
  const _AuthBrandMark({
    required this.compact,
    required this.foregroundColor,
  });

  final bool compact;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.fingerprint_rounded,
          size: compact ? 18 : 20,
          color: foregroundColor,
        ),
        SizedBox(width: compact ? 8 : 10),
        Text(
          'TOUCHIN',
          style: theme.textTheme.labelLarge?.copyWith(
            color: foregroundColor,
            letterSpacing: compact ? 2.0 : 2.4,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _AuthBrandPanel extends StatelessWidget {
  const _AuthBrandPanel({
    required this.headline,
    required this.description,
    required this.tags,
  });

  final String headline;
  final String description;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final primary = colorScheme.primary;
    final secondary = colorScheme.secondary;

    return Container(
      padding: const EdgeInsets.fromLTRB(40, 48, 40, 40),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            primary.withValues(alpha: 0.96),
            secondary.withValues(alpha: 0.92),
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: colorScheme.surface.withValues(alpha: 0.12),
              border: Border.all(
                color: colorScheme.onPrimary.withValues(alpha: 0.22),
              ),
            ),
            child: _AuthBrandMark(
              compact: false,
              foregroundColor: colorScheme.onPrimary,
            ),
          ),
          const Spacer(),
          Text(
            headline,
            style: theme.textTheme.displaySmall?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w700,
              height: 1.05,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.onPrimary.withValues(alpha: 0.92),
              height: 1.55,
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final tag in tags) _AuthHighlightTag(label: tag)],
          ),
        ],
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
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}

class _AuthHighlightTag extends StatelessWidget {
  const _AuthHighlightTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.12),
        border:
            Border.all(color: colorScheme.onPrimary.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelLarge?.copyWith(
          color: colorScheme.onPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
