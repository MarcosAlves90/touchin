import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A decorative, local-only backdrop for the initial server wait screen.
///
/// The glyphs use logical pixels, so device pixel ratio never increases the
/// number of cells. Only a bounded disc is drawn, at ten frames per second.
class StartupAsciiOrb extends StatefulWidget {
  const StartupAsciiOrb({super.key, required this.child});

  final Widget child;

  @override
  State<StartupAsciiOrb> createState() => StartupAsciiOrbState();
}

class StartupAsciiOrbState extends State<StartupAsciiOrb>
    with WidgetsBindingObserver {
  static const _frameInterval = Duration(milliseconds: 100);

  final _frame = _OrbFrame();
  late final _painter = _OrbPainter(_frame);
  Timer? _animationTimer;
  AppLifecycleState _lifecycle =
      WidgetsBinding.instance.lifecycleState ?? AppLifecycleState.resumed;
  bool _reduceMotion = false;
  bool _tickerEnabled = true;

  @visibleForTesting
  bool get isAnimating => _animationTimer?.isActive ?? false;

  @visibleForTesting
  double get animationPhase => _frame.phase;

  @visibleForTesting
  double get pointerTrailStrength => _frame.trailStrength;

  @visibleForTesting
  int get pointerTrailSampleCount => _frame.trail.length;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _tickerEnabled = TickerMode.valuesOf(context).enabled;
    _syncAnimation();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _lifecycle = state;
    _syncAnimation();
  }

  void _syncAnimation() {
    final shouldRun = _lifecycle == AppLifecycleState.resumed &&
        !_reduceMotion &&
        _tickerEnabled;
    if (!shouldRun) {
      _animationTimer?.cancel();
      _animationTimer = null;
      _frame.clearTrail();
    } else {
      _animationTimer ??= Timer.periodic(_frameInterval, (_) {
        _frame.advance();
      });
    }
  }

  void _onHover(PointerHoverEvent event) {
    // Touch and non-hover input must never start a pointer trail.
    if (event.kind == PointerDeviceKind.mouse && isAnimating) {
      _frame.hover(event.localPosition);
    }
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _painter.disposeGlyphs();
    _frame.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      opaque: false,
      onHover: _onHover,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          Positioned.fill(
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey<String>('startup-ascii-orb'),
                    painter: _painter,
                  ),
                ),
              ),
            ),
          ),
          widget.child,
        ],
      ),
    );
  }
}

class _OrbFrame extends ChangeNotifier {
  double phase = 0;
  final List<_TrailPoint> trail = <_TrailPoint>[];

  double get trailStrength => trail.isEmpty ? 0 : trail.last.strength;

  void advance() {
    // Speed 1: one slow revolution of the flow in roughly 14 seconds.
    phase = (phase + math.pi / 70) % (2 * math.pi);
    for (final point in trail) {
      point.strength *= 0.83;
    }
    trail.removeWhere((point) => point.strength < 0.015);
    notifyListeners();
  }

  void hover(Offset localPosition) {
    final last = trail.isEmpty ? null : trail.last;
    if (last != null && (last.position - localPosition).distanceSquared < 64) {
      last.position = localPosition;
      last.strength = 1;
    } else {
      trail.add(_TrailPoint(localPosition));
      if (trail.length > 6) trail.removeAt(0);
    }
    // Hover can arrive much faster than the animation rate. The single timer
    // repaints at 10 Hz, including the most recent pointer samples.
  }

  void clearTrail() {
    if (trail.isEmpty) return;
    trail.clear();
    notifyListeners();
  }
}

class _TrailPoint {
  _TrailPoint(this.position);

  Offset position;
  double strength = 1;
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.frame) : super(repaint: frame);

  static const _ink = Color(0xFFF3BA32);
  static const _characters = r' ._:;+/>=][{}*$#@';
  static const _fontSize = 10.0;
  static const _cellWidth = 10.0;
  static const _cellHeight = 12.5;
  static const _bayer4x4 = <int>[
    0,
    8,
    2,
    10,
    12,
    4,
    14,
    6,
    3,
    11,
    1,
    9,
    15,
    7,
    13,
    5,
  ];
  static const _ditherIntensity = 0.0;

  final _OrbFrame frame;
  final Map<int, TextPainter> _glyphCache = {};

  TextPainter _glyph(int index, int opacityLevel) {
    final key = opacityLevel * _characters.length + index;
    return _glyphCache.putIfAbsent(key, () {
      return TextPainter(
        text: TextSpan(
          text: _characters[index],
          style: TextStyle(
            fontFamily: 'monospace',
            fontSize: _fontSize,
            height: 1,
            color: _ink.withValues(alpha: 0.75 * (opacityLevel + 1) / 4),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final radius = math.min(size.shortestSide * 0.45, 220.0);
    if (radius < _cellWidth) return;
    final center = size.center(Offset.zero);
    final columns = (radius / _cellWidth).floor();
    final rows = (radius / _cellHeight).floor();
    final phase = frame.phase;
    final safeWidth = math.min(radius * 0.72, 148.0);
    final safeHeight = math.min(radius * 0.43, 72.0);

    for (var row = -rows; row <= rows; row++) {
      final y = row * _cellHeight;
      for (var column = -columns; column <= columns; column++) {
        final x = column * _cellWidth;
        final angle = math.atan2(y, x);
        final distance = math.sqrt(x * x + y * y) / radius;
        final edge = 0.94 +
            0.045 * math.sin(5 * angle + phase) +
            0.03 * math.cos(9 * angle - phase * 0.7);
        if (distance > edge) continue;

        // A slow, layered current gives the sphere a soft shifting contour.
        final current = math.sin(
                y * 0.049 + phase + 1.4 * math.sin(x * 0.025 - phase * 0.6)) *
            0.5;
        final crossCurrent = math.cos(x * 0.044 - phase * 0.8) * 0.5;
        final depth = math.sqrt(math.max(0, 1 - distance * distance));
        var density =
            0.51 + 0.21 * current + 0.20 * crossCurrent + 0.16 * depth;
        density += (_bayer4x4[(row & 3) * 4 + (column & 3)] / 15 - 0.5) *
            _ditherIntensity;

        // Fade an elliptical safe area for the spinner and both text lines.
        // Its width stays useful even when the viewport is phone-sized.
        final contentDistance = math.sqrt(
          (x / safeWidth) * (x / safeWidth) +
              (y / safeHeight) * (y / safeHeight),
        );
        final clearance = ((contentDistance - 0.65) / 0.7).clamp(0.0, 1.0);
        var pointerGlow = 0.0;
        for (final point in frame.trail) {
          final dx = center.dx + x - point.position.dx;
          final dy = center.dy + y - point.position.dy;
          final distanceSquared = dx * dx + dy * dy;
          if (distanceSquared < 14400) {
            pointerGlow = math.max(
              pointerGlow,
              0.23 * point.strength * math.exp(-distanceSquared / 3600),
            );
          }
        }
        density += pointerGlow;
        density = (density * clearance).clamp(0.0, 1.0);
        if (density < 0.18) continue;
        final glyphIndex = (density * (_characters.length - 1))
            .floor()
            .clamp(1, _characters.length - 1);
        final opacityLevel = (density * 4).floor().clamp(0, 3);
        _glyph(glyphIndex, opacityLevel).paint(
          canvas,
          Offset(center.dx + x, center.dy + y),
        );
      }
    }
  }

  void disposeGlyphs() {
    for (final glyph in _glyphCache.values) {
      glyph.dispose();
    }
    _glyphCache.clear();
  }

  @override
  bool shouldRepaint(covariant _OrbPainter oldDelegate) =>
      !identical(frame, oldDelegate.frame);
}
