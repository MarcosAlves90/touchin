import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// A decorative Estuary-like field behind the initial server wait screen.
/// All glyphs and currents are drawn here in Flutter, without external code.
/// The public widget name is retained for existing splash consumers.
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
  late final _painter = _EstuaryPainter(_frame);
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
  int get fieldSeed => _frame.fieldSeed;

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
  // The first splash varies across app launches; subsequent mounts always get
  // a different seed. A mounted splash never changes its seed.
  static int _nextFieldSeed = math.Random().nextInt(1 << 30);
  final int fieldSeed =
      _nextFieldSeed = (_nextFieldSeed + 0x9e3779b9) & 0x7fffffff;

  double phase = 0;
  final List<_TrailPoint> trail = <_TrailPoint>[];

  double get trailStrength => trail.isEmpty ? 0 : trail.last.strength;

  void advance() {
    // Do not wrap at 2π: the currents use different phase multipliers, so
    // wrapping would visibly jump after roughly 14 seconds of waiting.
    phase += math.pi / 70;
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

class _EstuaryPainter extends CustomPainter {
  _EstuaryPainter(this.frame) : super(repaint: frame);

  static const _ink = Color(0xFFF3BA32);
  // Estuary is a field of scattered letters, not a ramp of sphere contours.
  static const _characters =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  static const _fontSize = 10.0;
  static const _cellWidth = 10.0;
  static const _cellHeight = 13.0;
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
  static const _opacitySteps = 8;

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
            color: _ink.withValues(
              alpha: 0.75 * (opacityLevel + 1) / _opacitySteps,
            ),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
    });
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // Fill the viewport, not a disc. Bound the glyph grid on large displays:
    // pixel density never increases the number of cells or the work per frame.
    final nominalCells = size.width * size.height / (_cellWidth * _cellHeight);
    final scale = math.max(1.0, math.sqrt(nominalCells / 18000));
    final cellWidth = _cellWidth * scale;
    final cellHeight = _cellHeight * scale;
    final columns = (size.width / cellWidth).ceil();
    final rows = (size.height / cellHeight).ceil();
    final center = size.center(Offset.zero);
    // Each new splash starts with different currents and character placement,
    // without changing either of them while that splash stays mounted.
    final phase = frame.phase + frame.fieldSeed * (math.pi / 1073741824);
    final quietWidth = math.min(size.width * 0.43, 230.0);
    final quietHeight = math.min(size.height * 0.22, 112.0);

    for (var row = 0; row < rows; row++) {
      final y = row * cellHeight;
      for (var column = 0; column < columns; column++) {
        final x = column * cellWidth;
        final seed = _cellHash(column, row, frame.fieldSeed);

        // Slow, overlapping warped currents produce smoke-soft patches instead
        // of a recognizable silhouette or a rigid ring.
        var flowX = x + 36 * math.sin(y * 0.012 - phase * 0.32);
        var flowY = y + 25 * math.sin(x * 0.009 + phase * 0.45);
        var glow = 0.0;

        // A short mouse history stirs the same field; touch creates no trail.
        for (final point in frame.trail) {
          final dx = x - point.position.dx;
          final dy = y - point.position.dy;
          final distanceSquared = dx * dx + dy * dy;
          if (distanceSquared > 40000) continue;
          final influence = point.strength * math.exp(-distanceSquared / 9500);
          flowX -= dy * 0.4 * influence;
          flowY += dx * 0.4 * influence;
          glow = math.max(glow, influence);
        }

        final cloud = 0.5 +
            0.25 *
                math.sin(
                  flowX * 0.007 + 1.2 * math.sin(flowY * 0.01 + phase * 0.35),
                ) +
            0.18 *
                math.cos(
                  flowY * 0.012 - 1.5 * math.sin(flowX * 0.008 - phase * 0.22),
                ) +
            0.13 * math.sin((flowX + flowY) * 0.017 + phase * 0.55);
        var density = ((cloud - 0.32) * 1.35 + 0.37 * glow).clamp(0.0, 1.0);

        // Keep the waiting message and spinner quiet without making a visible
        // hole: the field fades gradually toward the center of the content.
        final centerX = (x - center.dx) / quietWidth;
        final centerY = (y - center.dy) / quietHeight;
        final quiet = (centerX * centerX + centerY * centerY).clamp(0.0, 1.0);
        density *= 0.10 + 0.90 * quiet;
        density += (_bayer4x4[(row & 3) * 4 + (column & 3)] / 15 - 0.5) *
            _ditherIntensity;
        if (density < 0.065) continue;

        // Stable per-cell characters and sparse coverage avoid flickering
        // random letters on every tick; only the ink intensity flows.
        final coverage = (0.16 + density * 0.62).clamp(0.0, 1.0);
        if (((seed >> 8) & 1023) / 1023 > coverage) continue;
        final glyphIndex = seed % _characters.length;
        final opacityLevel = (density * density * _opacitySteps)
            .floor()
            .clamp(0, _opacitySteps - 1);
        _glyph(glyphIndex, opacityLevel).paint(canvas, Offset(x, y));
      }
    }
  }

  static int _cellHash(int column, int row, int fieldSeed) {
    var value = column * 374761393 + row * 668265263 + fieldSeed * 2246822519;
    value = (value ^ (value >> 13)) * 1274126177;
    return (value ^ (value >> 16)) & 0x7fffffff;
  }

  void disposeGlyphs() {
    for (final glyph in _glyphCache.values) {
      glyph.dispose();
    }
    _glyphCache.clear();
  }

  @override
  bool shouldRepaint(covariant _EstuaryPainter oldDelegate) =>
      !identical(frame, oldDelegate.frame);
}
