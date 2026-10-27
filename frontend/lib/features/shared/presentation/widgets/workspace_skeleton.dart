import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Shared animated skeleton primitives for ordinary content-loading states.
///
/// The cold-start "Aguardando o servidor" screen keeps its circular progress
/// indicator; every other content load should build a placeholder from these
/// widgets so the surrounding workspace stays visible.
///
/// Usage:
///
/// ```dart
/// WorkspaceSkeletonRegion(
///   label: 'Carregando tarefas',
///   child: Column(
///     crossAxisAlignment: CrossAxisAlignment.stretch,
///     children: <Widget>[
///       WorkspaceSkeleton.line(width: 220, height: 18),
///       const SizedBox(height: 16),
///       WorkspaceSkeletonList(count: 3),
///     ],
///   ),
/// )
/// ```
///
/// A region owns a single animation controller and fades its whole subtree, so
/// adding more blocks does not add tickers or rebuilds. The animation is
/// replaced by a static skeleton when the operating system asks for reduced
/// motion, and each decorative block is hidden from assistive technologies:
/// the region announces its [WorkspaceSkeletonRegion.label] once.
class WorkspaceSkeletonRegion extends StatefulWidget {
  const WorkspaceSkeletonRegion({
    super.key,
    required this.label,
    required this.child,
    this.duration = const Duration(milliseconds: 1100),
    this.minimumOpacity = 0.6,
  });

  /// Single accessible announcement for the pending region, in Portuguese.
  final String label;

  /// Placeholder composition; build it from [WorkspaceSkeleton] blocks and
  /// page-specific layouts.
  final Widget child;

  final Duration duration;
  final double minimumOpacity;

  @override
  State<WorkspaceSkeletonRegion> createState() =>
      _WorkspaceSkeletonRegionState();
}

class _WorkspaceSkeletonRegionState extends State<WorkspaceSkeletonRegion>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late Animation<double> _opacity = Tween<double>(
    begin: widget.minimumOpacity,
    end: 1,
  ).animate(_controller);

  bool _animating = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion) {
      if (_animating) {
        _animating = false;
        _controller.stop();
      }
      _controller.value = 1;
      return;
    }
    if (!_animating) {
      _animating = true;
      _controller.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(WorkspaceSkeletonRegion oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.duration != widget.duration) {
      _controller.duration = widget.duration;
    }
    if (oldWidget.minimumOpacity != widget.minimumOpacity) {
      _opacity = Tween<double>(
        begin: widget.minimumOpacity,
        end: 1,
      ).animate(_controller);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      liveRegion: true,
      label: widget.label,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: FadeTransition(
            opacity: _opacity,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Skeleton color tones, derived from the active theme so light and dark mode
/// keep the same relative contrast.
enum WorkspaceSkeletonTone { subtle, base, strong }

enum WorkspaceSkeletonShape { rectangle, circle }

/// A single decorative placeholder block.
class WorkspaceSkeleton extends StatelessWidget {
  const WorkspaceSkeleton({
    super.key,
    this.width,
    this.height = 12,
    this.shape = WorkspaceSkeletonShape.rectangle,
    this.tone = WorkspaceSkeletonTone.base,
    this.radius,
  });

  /// Text-line placeholder.
  const WorkspaceSkeleton.line({
    super.key,
    this.width,
    this.height = 12,
    this.tone = WorkspaceSkeletonTone.base,
  })  : shape = WorkspaceSkeletonShape.rectangle,
        radius = null;

  /// Round placeholder for avatars, icons or status dots.
  const WorkspaceSkeleton.avatar({
    super.key,
    this.height = 40,
    this.tone = WorkspaceSkeletonTone.base,
  })  : width = height,
        shape = WorkspaceSkeletonShape.circle,
        radius = null;

  /// Leave null to let the parent constraints decide (recommended inside
  /// stretched columns and expanded rows).
  final double? width;
  final double height;
  final WorkspaceSkeletonShape shape;
  final WorkspaceSkeletonTone tone;

  /// TouchIn uses square corners; pass a radius only for intentional circles.
  final BorderRadius? radius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (tone) {
      WorkspaceSkeletonTone.subtle => colorScheme.onSurface.withValues(
          alpha: 0.08,
        ),
      WorkspaceSkeletonTone.base => colorScheme.onSurface.withValues(
          alpha: 0.12,
        ),
      WorkspaceSkeletonTone.strong => colorScheme.onSurface.withValues(
          alpha: 0.20,
        ),
    };
    return SizedBox(
      width: width,
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color,
          shape: shape == WorkspaceSkeletonShape.circle
              ? BoxShape.circle
              : BoxShape.rectangle,
          borderRadius: shape == WorkspaceSkeletonShape.circle
              ? null
              : (radius ?? BorderRadius.zero),
        ),
      ),
    );
  }
}

/// Card-shaped placeholder that mirrors the shared TouchIn surface/border.
class WorkspaceSkeletonPanel extends StatelessWidget {
  const WorkspaceSkeletonPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.zero,
      ),
      child: child,
    );
  }
}

/// Placeholder for a list/tile row: optional leading block, two text lines and
/// an optional trailing block. Widths are fractional so the skeleton follows
/// the available width on mobile and desktop.
class WorkspaceSkeletonRow extends StatelessWidget {
  const WorkspaceSkeletonRow({
    super.key,
    this.leadingSize,
    this.trailingWidth,
    this.titleWidthFactor = 0.55,
    this.subtitleWidthFactor = 0.85,
  });

  final double? leadingSize;
  final double? trailingWidth;
  final double titleWidthFactor;
  final double subtitleWidthFactor;

  @override
  Widget build(BuildContext context) {
    final leading = leadingSize;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (leading != null) ...<Widget>[
          WorkspaceSkeleton.avatar(height: leading),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              FractionallySizedBox(
                widthFactor: titleWidthFactor,
                alignment: Alignment.centerLeft,
                child: const WorkspaceSkeleton.line(height: 16),
              ),
              const SizedBox(height: 10),
              FractionallySizedBox(
                widthFactor: subtitleWidthFactor,
                alignment: Alignment.centerLeft,
                child: const WorkspaceSkeleton.line(height: 12),
              ),
            ],
          ),
        ),
        if (trailingWidth != null) ...<Widget>[
          const SizedBox(width: 14),
          WorkspaceSkeleton.line(width: trailingWidth, height: 14),
        ],
      ],
    );
  }
}

/// Bounded list of [WorkspaceSkeletonRow]s. The cap keeps a single animation
/// region cheap even for long tables.
class WorkspaceSkeletonList extends StatelessWidget {
  const WorkspaceSkeletonList({
    super.key,
    this.count = 4,
    this.leadingSize = 40,
    this.spacing = 12,
    this.maxCount = 8,
  });

  final int count;
  final double? leadingSize;
  final double spacing;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final total = math.min(math.max(count, 0), math.max(maxCount, 0));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var index = 0; index < total; index++) ...<Widget>[
          WorkspaceSkeletonRow(leadingSize: leadingSize),
          if (index != total - 1) SizedBox(height: spacing),
        ],
      ],
    );
  }
}
