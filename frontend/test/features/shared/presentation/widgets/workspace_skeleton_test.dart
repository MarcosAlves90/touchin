import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_skeleton.dart';
import 'package:touchin_flutter/theme/app_theme.dart';

Widget _wrap(
  Widget child, {
  bool reduceMotion = false,
  bool dark = false,
  double width = 900,
  TextScaler textScaler = TextScaler.noScaling,
}) {
  return MaterialApp(
    theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
    builder: (context, appChild) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          disableAnimations: reduceMotion,
          textScaler: textScaler,
        ),
        child: appChild!,
      );
    },
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(width: width, child: child),
      ),
    ),
  );
}

void main() {
  testWidgets('renders rectangle, line and avatar shapes from the theme', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const WorkspaceSkeletonRegion(
          label: 'Carregando conteúdo',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              WorkspaceSkeleton(width: 120, height: 24),
              WorkspaceSkeleton.line(width: 80),
              WorkspaceSkeleton.avatar(height: 40),
            ],
          ),
        ),
      ),
    );

    expect(find.byType(WorkspaceSkeleton), findsNWidgets(3));
    final decorations = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(WorkspaceSkeleton),
            matching: find.byType(DecoratedBox),
          ),
        )
        .map((box) => box.decoration)
        .whereType<BoxDecoration>()
        .toList();

    expect(decorations[0].shape, BoxShape.rectangle);
    expect(decorations[0].borderRadius, BorderRadius.zero);
    expect(decorations[1].shape, BoxShape.rectangle);
    expect(decorations[2].shape, BoxShape.circle);
    expect(decorations[2].borderRadius, isNull);
    expect(decorations[0].color?.a, closeTo(0.12, 0.001));

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('one region animates every block with a single fade transition', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const WorkspaceSkeletonRegion(
          label: 'Carregando conteúdo',
          child: Column(
            children: <Widget>[
              WorkspaceSkeleton(height: 16),
              WorkspaceSkeleton(height: 16),
              WorkspaceSkeleton(height: 16),
            ],
          ),
        ),
      ),
    );

    final fadeFinder = find.descendant(
      of: find.byType(WorkspaceSkeletonRegion),
      matching: find.byType(FadeTransition),
    );
    expect(fadeFinder, findsOneWidget);

    final fade = tester.widget<FadeTransition>(fadeFinder);
    final initial = fade.opacity.value;
    await tester.pump(const Duration(milliseconds: 275));
    expect(fade.opacity.value, isNot(closeTo(initial, 0.001)));
    expect(tester.binding.transientCallbackCount, greaterThan(0));

    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('reduced motion renders a static skeleton and stops the ticker', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        reduceMotion: true,
        const WorkspaceSkeletonRegion(
          label: 'Carregando conteúdo',
          child: WorkspaceSkeleton(height: 16),
        ),
      ),
    );

    final fade = tester.widget<FadeTransition>(
      find.descendant(
        of: find.byType(WorkspaceSkeletonRegion),
        matching: find.byType(FadeTransition),
      ),
    );
    expect(fade.opacity.value, 1);
    await tester.pump(const Duration(milliseconds: 500));
    expect(fade.opacity.value, 1);
    expect(tester.binding.transientCallbackCount, 0);
  });

  testWidgets('announces the region once and hides decorative blocks', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        const WorkspaceSkeletonRegion(
          label: 'Carregando eventos',
          child: Column(
            children: <Widget>[
              WorkspaceSkeleton(height: 16),
              WorkspaceSkeleton(height: 16),
            ],
          ),
        ),
      ),
    );

    final node = tester.getSemantics(find.byType(WorkspaceSkeletonRegion));
    expect(node.label, 'Carregando eventos');
    expect(node.flagsCollection.isLiveRegion, isTrue);
    expect(node.childrenCount, 0);
    expect(find.bySemanticsLabel('Carregando eventos'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('skeleton list is capped and rows expose no semantics', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(
        const WorkspaceSkeletonRegion(
          label: 'Carregando lista',
          child: WorkspaceSkeletonList(count: 40),
        ),
      ),
    );

    expect(find.byType(WorkspaceSkeletonRow), findsNWidgets(8));
    expect(find.byType(WorkspaceSkeleton), findsWidgets);
    final node = tester.getSemantics(find.byType(WorkspaceSkeletonRegion));
    expect(node.label, 'Carregando lista');
    expect(node.childrenCount, 0);

    await tester.pumpWidget(const SizedBox.shrink());
    semantics.dispose();
  });

  testWidgets('fits narrow/wide widths in both themes with large text', (
    tester,
  ) async {
    for (final width in <double>[320, 1440]) {
      for (final dark in <bool>[false, true]) {
        await tester.pumpWidget(
          _wrap(
            dark: dark,
            width: width,
            textScaler: const TextScaler.linear(2),
            const WorkspaceSkeletonRegion(
              label: 'Carregando painel',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  WorkspaceSkeletonPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        WorkspaceSkeleton(width: 220, height: 24),
                        SizedBox(height: 16),
                        WorkspaceSkeletonList(count: 4),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(tester.takeException(), isNull,
            reason: 'width=$width dark=$dark');
      }
    }
  });
}
