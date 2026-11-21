import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/startup_ascii_orb.dart';

void main() {
  Widget scene({bool reducedMotion = false, bool visible = true}) {
    return MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: TickerMode(
          enabled: visible,
          child: Scaffold(
            body: StartupAsciiOrb(
              child: Center(
                child: TextButton(
                  onPressed: () {},
                  child: const Text('Continuar'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  StartupAsciiOrbState orb(WidgetTester tester) =>
      tester.state<StartupAsciiOrbState>(find.byType(StartupAsciiOrb));

  testWidgets('backdrop sits behind content without gestures or semantics',
      (tester) async {
    final semantics = tester.ensureSemantics();
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StartupAsciiOrb(
            child: Center(
              child: TextButton(
                onPressed: () => taps++,
                child: const Text('Continuar'),
              ),
            ),
          ),
        ),
      ),
    );

    final paint = find.byKey(const ValueKey<String>('startup-ascii-orb'));
    expect(paint, findsOneWidget);
    expect(
        tester
            .widget<IgnorePointer>(find
                .ancestor(of: paint, matching: find.byType(IgnorePointer))
                .first)
            .ignoring,
        isTrue);
    expect(find.ancestor(of: paint, matching: find.byType(ExcludeSemantics)),
        findsWidgets);
    final stack = tester.widget<Stack>(find.descendant(
      of: find.byType(StartupAsciiOrb),
      matching: find.byType(Stack),
    ));
    expect(stack.children.first, isA<Positioned>());
    expect(stack.children.last, isA<Center>());
    expect(tester.getCenter(paint), tester.getCenter(find.byType(Scaffold)));
    expect(find.text('Continuar'), findsOneWidget);
    await tester.tap(find.text('Continuar'));
    expect(taps, 1);
    expect(tester.getSemantics(find.text('Continuar')).label, 'Continuar');
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('orb remains bounded and centered for phone and desktop',
      (tester) async {
    for (final dimensions in <Size>[
      const Size(320, 568),
      const Size(375, 812),
      const Size(1440, 900),
    ]) {
      await tester.binding.setSurfaceSize(dimensions);
      await tester.pumpWidget(scene());
      await tester.pump(const Duration(milliseconds: 120));
      final paint = find.byKey(const ValueKey<String>('startup-ascii-orb'));
      expect(tester.getSize(paint), dimensions);
      expect(tester.getCenter(find.text('Continuar')),
          Offset(dimensions.width / 2, dimensions.height / 2));
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('painted pixels use technical ASCII glyph shapes, not letters',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 240));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(scene(reducedMotion: true));

    // Rasterize the same CustomPainter used in the splash. This checks actual
    // ink pixels, rather than just the widget tree or a declared character set.
    final painter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey<String>('startup-ascii-orb')),
        )
        .painter!;
    final recorder = ui.PictureRecorder();
    painter.paint(Canvas(recorder), const Size(320, 240));
    final picture = recorder.endRecording();
    // Engine-backed rasterization must run outside testWidgets' fake clock.
    final pixels = await tester.runAsync(() async {
      final image = await picture.toImage(320, 240);
      try {
        return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      } finally {
        image.dispose();
      }
    });
    expect(pixels, isNotNull);

    var inkPixels = 0;
    for (var offset = 0; offset < pixels!.lengthInBytes; offset += 4) {
      final alpha = pixels.getUint8(offset + 3);
      if (alpha > 0) {
        inkPixels++;
        // Flutter's raster image contains premultiplied RGB values.
        expect(pixels.getUint8(offset), closeTo(243 * alpha / 255, 3));
        expect(pixels.getUint8(offset + 1), closeTo(186 * alpha / 255, 3));
        expect(pixels.getUint8(offset + 2), closeTo(50 * alpha / 255, 3));
      }
    }
    expect(inkPixels, greaterThan(100),
        reason: 'The backdrop must actually rasterize visible ASCII marks');

    final glyphs = orb(tester).paintedGlyphs;
    const technicalMarks = r'._:;+/>=][{}*$#@';
    expect(glyphs.length, greaterThan(4),
        reason: 'Several technical shapes must be visible in the raster');
    expect(
      glyphs.every(
          (glyph) => glyph.length == 1 && technicalMarks.contains(glyph)),
      isTrue,
      reason: 'Every TextPainter used for the image must draw a technical mark',
    );
    expect(
        glyphs.any((glyph) => RegExp(r'[A-Za-z0-9]').hasMatch(glyph)), isFalse);
    picture.dispose();
  });

  testWidgets('mouse hover changes local ink at a fixed animation phase',
      (tester) async {
    const size = Size(600, 480);
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(scene());
    final state = orb(tester);
    final painter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey<String>('startup-ascii-orb')),
        )
        .painter!;

    Future<ByteData> rasterize() async {
      final recorder = ui.PictureRecorder();
      painter.paint(Canvas(recorder), size);
      final picture = recorder.endRecording();
      try {
        final pixels = await tester.runAsync(() async {
          final image = await picture.toImage(600, 480);
          try {
            return await image.toByteData(format: ui.ImageByteFormat.rawRgba);
          } finally {
            image.dispose();
          }
        });
        expect(pixels, isNotNull);
        return pixels!;
      } finally {
        picture.dispose();
      }
    }

    final phaseBefore = state.animationPhase;
    final seedBefore = state.fieldSeed;
    final baseline = await rasterize();
    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(410, 230));
    await mouse.moveTo(const Offset(460, 250));
    expect(state.pointerTrailSampleCount, greaterThan(0));
    expect(state.animationPhase, phaseBefore,
        reason: 'Only pointer position may change between rasterized frames');
    expect(state.fieldSeed, seedBefore);
    final hovered = await rasterize();

    var nearChanges = 0;
    var distantChanges = 0;
    for (var y = 0; y < 480; y++) {
      for (var x = 0; x < 600; x++) {
        final offset = (y * 600 + x) * 4;
        var changed = false;
        for (var channel = 0; channel < 4; channel++) {
          changed |= baseline.getUint8(offset + channel) !=
              hovered.getUint8(offset + channel);
        }
        if (!changed) continue;
        final fromPrevious = (x - 410) * (x - 410) + (y - 230) * (y - 230);
        final fromLatest = (x - 460) * (x - 460) + (y - 250) * (y - 250);
        // Both retained hover samples affect the paint. Glyph ink can also
        // extend beyond the 200px radius measured at its grid origin.
        if (fromPrevious < 225 * 225 || fromLatest < 225 * 225) {
          nearChanges++;
        } else {
          distantChanges++;
        }
      }
    }
    expect(nearChanges, greaterThan(0),
        reason:
            'Hover must alter pixels near the mouse in an otherwise frozen field');
    expect(distantChanges, 0,
        reason: 'Hover must not alter ink far from either retained sample');
    await mouse.removePointer();
  });

  testWidgets('animation pauses when inactive or hidden and resumes once',
      (tester) async {
    await tester.pumpWidget(scene());
    final state = orb(tester);
    expect(state.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 300));
    final activePhase = state.animationPhase;
    expect(activePhase, greaterThan(0));

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    expect(state.isAnimating, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(state.animationPhase, activePhase);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(state.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    final resumedPhase = state.animationPhase;
    expect(resumedPhase, greaterThan(activePhase));

    await tester.pumpWidget(scene(visible: false));
    expect(orb(tester), same(state));
    expect(state.isAnimating, isFalse);
    await tester.pump(const Duration(seconds: 1));
    expect(state.animationPhase, resumedPhase);

    await tester.pumpWidget(scene());
    expect(state.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 100));
    expect(state.animationPhase, greaterThan(resumedPhase));
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'a long wait flows continuously and a new wait starts differently',
      (tester) async {
    await tester.pumpWidget(scene());
    final initial = orb(tester);
    final initialSeed = initial.fieldSeed;

    // The old phase wrapped at 2π after 14 seconds, visibly resetting the
    // currents (which have different phase multipliers).
    await tester.pump(const Duration(seconds: 15));
    expect(initial.animationPhase, greaterThan(2 * math.pi));
    final previousPhase = initial.animationPhase;
    await tester.pump(const Duration(milliseconds: 100));
    expect(initial.animationPhase, closeTo(previousPhase + math.pi / 70, 1e-8));

    await tester.pump(const Duration(seconds: 60));
    expect(initial.animationPhase, greaterThan(previousPhase));
    expect(initial.fieldSeed, initialSeed,
        reason: 'A mounted splash must not get another field layout');

    // A temporary pause or rebuild must preserve the same field.
    await tester.pumpWidget(scene(visible: false));
    expect(orb(tester), same(initial));
    expect(orb(tester).fieldSeed, initialSeed);
    await tester.pumpWidget(scene());
    expect(orb(tester).fieldSeed, initialSeed);

    // A subsequent, separately mounted splash begins with a different phase
    // offset and glyph seed, instead of replaying the identical arrangement.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(scene());
    expect(orb(tester), isNot(same(initial)));
    expect(orb(tester).animationPhase, 0);
    expect(orb(tester).fieldSeed, isNot(initialSeed));
    expect(tester.takeException(), isNull);
  });

  testWidgets('reduced motion is static and mouse hover alone creates a trail',
      (tester) async {
    await tester.pumpWidget(scene(reducedMotion: true));
    expect(orb(tester).isAnimating, isFalse);
    await tester.pump(const Duration(seconds: 2));
    expect(orb(tester).animationPhase, 0);

    await tester.pumpWidget(scene());
    expect(orb(tester).isAnimating, isTrue);
    final painter = tester
        .widget<CustomPaint>(
          find.byKey(const ValueKey<String>('startup-ascii-orb')),
        )
        .painter!;
    var repaintSignals = 0;
    void onRepaint() => repaintSignals++;
    painter.addListener(onRepaint);
    final touch = await tester.createGesture(kind: ui.PointerDeviceKind.touch);
    await touch.down(const Offset(120, 120));
    await touch.moveTo(const Offset(140, 140));
    await touch.up();
    expect(orb(tester).pointerTrailStrength, 0);

    final mouse = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
    await mouse.addPointer(location: const Offset(100, 100));
    await mouse.moveTo(const Offset(125, 125));
    await mouse.moveTo(const Offset(180, 180));
    for (var index = 0; index < 12; index++) {
      await mouse.moveTo(Offset(200 + index * 20, 190 + index * 10));
    }
    expect(orb(tester).pointerTrailStrength, 1);
    expect(orb(tester).pointerTrailSampleCount, greaterThanOrEqualTo(2),
        reason: 'Hover retains a short path, not only the last pointer point');
    expect(orb(tester).pointerTrailSampleCount, lessThanOrEqualTo(6),
        reason: 'Pointer history must remain bounded during continuous hover');
    expect(repaintSignals, 0,
        reason: 'Individual hover events must not request a repaint');
    await tester.pump(const Duration(milliseconds: 500));
    expect(repaintSignals, greaterThan(0),
        reason: 'The animation timer drives the repaint instead');
    expect(orb(tester).pointerTrailStrength, lessThan(1));
    await mouse.removePointer();

    await tester.pump(const Duration(seconds: 3));
    expect(orb(tester).pointerTrailSampleCount, 0);
    painter.removeListener(onRepaint);

    await tester.pumpWidget(scene(reducedMotion: true));
    expect(orb(tester).isAnimating, isFalse);
    expect(orb(tester).pointerTrailStrength, 0);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
}
