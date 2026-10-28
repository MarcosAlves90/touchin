import 'dart:io';
import 'dart:typed_data';

import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
import 'package:touchin_flutter/features/auth/presentation/logout_navigation.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:touchin_flutter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final visualCase in _visualCases) {
    testWidgets(
      'navigation visual review captures ${visualCase.name}',
      (tester) async {
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _captureVisualCase(tester, visualCase);
      },
      tags: <String>{'canonical-golden'},
    );
  }

  test('workspace destinations are the unique ordered navigation source', () {
    expect(
      workspaceDestinations
          .map((destination) => (
                destination.route,
                destination.label,
                destination.icon,
              ))
          .toList(),
      <(String, String, IconData)>[
        ('/time-clock', 'Bater Ponto', Icons.timer_outlined),
        (
          '/admin/employees',
          'Administrar Equipe',
          Icons.groups_2_rounded,
        ),
        ('/admin/audit', 'Trilha de Auditoria', Icons.history_edu),
        ('/projects', 'Projetos e tarefas', Icons.account_tree_outlined),
        ('/kanban', 'Kanban', Icons.view_kanban_outlined),
        ('/settings', 'Configurações', Icons.tune_rounded),
      ],
    );
  });

  testWidgets('navigation switches layouts at the shared 1080px breakpoint', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1079, 720));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScaffold(
        contextualContent: const WorkspaceSidebar(
          summaryChildren: <Widget>[Text('Context summary')],
          highlightChips: <Widget>[],
        ),
        contentBuilder: (_, __) => const SizedBox(height: 100),
      ),
    ));
    expect(
      find.byKey(const ValueKey('workspace-desktop-destinations')),
      findsNothing,
    );
    expect(find.byTooltip('Abrir menu'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('workspace-navigation-drawer')),
      findsNothing,
    );

    await tester.binding.setSurfaceSize(const Size(1080, 720));
    await tester.pump();
    expect(
      find.byKey(const ValueKey('workspace-desktop-destinations')),
      findsOneWidget,
    );
    expect(find.byTooltip('Abrir menu'), findsNothing);
    expect(
      find.byKey(const ValueKey('workspace-navigation-drawer')),
      findsNothing,
    );
    for (final label in <String>[
      'Bater Ponto',
      'Administrar Equipe',
      'Trilha de Auditoria',
      'Projetos e tarefas',
      'Kanban',
      'Configurações',
      'Sair do Sistema',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('workspace-context-scroll')),
      findsOneWidget,
    );
  });

  testWidgets(
    'mobile header puts the contrasting menu inside the square brand block',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var menuOpened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: WorkspaceMobileHeader(
              currentRoute: '/time-clock',
              onOpenDrawer: () => menuOpened = true,
            ),
          ),
        ),
      );

      const brandKey = ValueKey<String>('workspace-mobile-brand-block');
      final brand = find.byKey(brandKey);
      final menu = find.byTooltip('Abrir menu');
      expect(
        find.descendant(of: brand, matching: menu),
        findsOneWidget,
        reason: 'mobile_brand_contains_menu',
      );

      final decoration =
          tester.widget<Container>(brand).decoration! as BoxDecoration;
      expect(decoration.color, AppTheme.accent);
      expect(
        decoration.borderRadius,
        isNull,
        reason: 'navigation_square_corners',
      );
      final header = tester.widget<Container>(
        find.byKey(const ValueKey<String>('workspace-mobile-header')),
      );
      expect(header.padding, const EdgeInsets.fromLTRB(0, 8, 16, 8));
      expect(tester.getRect(brand).left, 0);

      final menuButton = find.ancestor(
        of: menu,
        matching: find.byType(IconButton),
      );
      expect(menuButton, findsOneWidget);
      final menuIcon = tester.widget<IconButton>(menuButton).icon as Icon;
      expect(
        menuIcon.color,
        Theme.of(tester.element(menu)).colorScheme.onPrimary,
      );
      final mark = find.descendant(
        of: brand,
        matching: find.byIcon(Icons.fingerprint_rounded),
      );
      final wordmark =
          find.descendant(of: brand, matching: find.text('TOUCHIN'));
      expect(mark, findsOneWidget);
      expect(wordmark, findsOneWidget);
      expect(tester.getTopLeft(menu).dx, lessThan(tester.getTopLeft(mark).dx));

      await tester.tap(menu);
      expect(menuOpened, isTrue);
    },
  );

  testWidgets('desktop panel uses one scroll for destinations and context', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1080, 520));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScaffold(
        contextualContent: WorkspaceSidebar(
          summaryChildren: List<Widget>.generate(
            8,
            (index) => Text('Summary $index'),
          ),
          highlightChips: const <Widget>[],
        ),
        contentBuilder: (_, __) => const SizedBox.shrink(),
      ),
    ));
    final context = find.byKey(const ValueKey('workspace-context-scroll'));
    expect(
      find.ancestor(
        of: context,
        matching: find.byKey(const ValueKey('workspace-desktop-destinations')),
      ),
      findsOneWidget,
    );
    final scrollable = tester.state<ScrollableState>(
      find.descendant(
        of: find.byKey(const ValueKey('workspace-desktop-destinations')),
        matching: find.byType(Scrollable),
      ),
    );
    final initialOffset = scrollable.position.pixels;
    await tester.drag(
      find.byKey(const ValueKey('workspace-desktop-destinations')),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(initialOffset));
    expect(find.text('Sair do Sistema'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('drawer marks only the active destination as selected', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorkspaceNavigationDrawer(currentRoute: '/kanban'),
        ),
      ),
    );
    expect(
      tester.getSemantics(find.text('Kanban')),
      isSemantics(isButton: true, isSelected: true),
    );
    expect(
      tester.getSemantics(find.text('Bater Ponto')),
      isSemantics(isSelected: false),
    );
    semantics.dispose();
  });

  testWidgets('unknown active route selects no destination', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: WorkspaceNavigationPanel(currentRoute: '/unknown'),
        ),
      ),
    );
    expect(find.byIcon(Icons.chevron_right_rounded), findsNothing);
    for (final destination in workspaceDestinations) {
      expect(
        tester.getSemantics(find.text(destination.label)),
        isSemantics(isSelected: false),
      );
    }
    semantics.dispose();
  });

  testWidgets('mobile drawer keeps its open and close animation', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: WorkspaceScaffold(
          contentBuilder: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Abrir menu'));
    await tester.pump();
    final drawer = find.byKey(
      const ValueKey<String>('workspace-navigation-drawer'),
    );
    expect(drawer, findsOneWidget);
    final closedOffset = tester.getTopLeft(drawer).dx;
    expect(closedOffset, lessThan(0));

    await tester.pump(const Duration(milliseconds: 100));
    final openingOffset = tester.getTopLeft(drawer).dx;
    expect(openingOffset, greaterThan(closedOffset));
    expect(openingOffset, lessThan(0));

    await tester.pumpAndSettle();
    expect(tester.getTopLeft(drawer).dx, 0);

    await tester.tapAt(const Offset(380, 400));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.getTopLeft(drawer).dx, lessThan(0));
    await tester.pumpAndSettle();
    expect(drawer, findsNothing);
  });

  testWidgets('desktop and drawer expose the same destination source', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(MaterialApp(
      home: WorkspaceScaffold(
        contextualContent: const WorkspaceSidebar(
          summaryChildren: <Widget>[Text('Summary')],
          highlightChips: <Widget>[],
        ),
        contentBuilder: (_, __) => const Text('Content'),
      ),
    ));
    expect(find.byType(WorkspaceNavigationBrand), findsOneWidget);
    expect(
      find.byType(WorkspaceNavigationItem),
      findsNWidgets(workspaceDestinations.length + 1),
    );

    await tester.binding.setSurfaceSize(const Size(800, 800));
    await tester.pump();
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
    expect(find.byType(WorkspaceNavigationBrand), findsNWidgets(2));
    expect(
      find.byType(WorkspaceNavigationItem),
      findsNWidgets(workspaceDestinations.length + 1),
    );
    for (final destination in workspaceDestinations) {
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('workspace-navigation-drawer')),
          matching: find.text(destination.label),
        ),
        findsOneWidget,
      );
    }
  });

  testWidgets(
    'desktop sidebar collapses to an accessible icon-only rail and retains state across Kanban navigation',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1079, 720));
      addTearDown(() async {
        final expand = find.byTooltip('Expandir navegação');
        if (expand.evaluate().isNotEmpty) {
          await tester.tap(expand);
          await tester.pumpAndSettle();
        }
        await tester.binding.setSurfaceSize(null);
      });
      final semantics = tester.ensureSemantics();

      const contentKey = ValueKey<String>('workspace-content-probe');
      Route<void> workspaceRoute(RouteSettings settings) =>
          PageRouteBuilder<void>(
            settings: settings,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
            pageBuilder: (_, __, ___) => WorkspaceScaffold(
              contextualContent: const WorkspaceSidebar(
                summaryChildren: <Widget>[Text('Contextual summary')],
                highlightChips: <Widget>[],
              ),
              contentScrollable: false,
              contentBuilder: (_, __) => LayoutBuilder(
                builder: (context, constraints) => SizedBox(
                  key: contentKey,
                  width: constraints.maxWidth,
                  height: constraints.maxHeight,
                  child: Text('Active ${settings.name}'),
                ),
              ),
            ),
          );

      await tester.pumpWidget(MaterialApp(
        initialRoute: '/projects',
        onGenerateInitialRoutes: (name) => <Route<void>>[
          workspaceRoute(RouteSettings(name: name)),
        ],
        onGenerateRoute: workspaceRoute,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byTooltip('Abrir menu'), findsOneWidget);
      expect(find.byTooltip('Recolher navegação'), findsNothing);

      await tester.binding.setSurfaceSize(const Size(1280, 800));
      await tester.pumpAndSettle();
      final collapse = find.byTooltip('Recolher navegação');
      expect(
        collapse,
        findsOneWidget,
        reason: 'desktop sidebar collapses to an accessible icon-only rail',
      );
      expect(
        tester.getSemantics(collapse),
        isSemantics(isButton: true),
      );
      expect(tester.getSize(collapse).width, greaterThanOrEqualTo(48));
      final sidebar = find.byKey(
        const ValueKey<String>('workspace-navigation-sidebar'),
      );
      expect(tester.getSize(sidebar).width, 360);
      expect(find.text('Contextual summary'), findsOneWidget);
      final expandedContentWidth = tester.getSize(find.byKey(contentKey)).width;

      await tester.tap(collapse);
      await tester.pump();
      expect(tester.getSize(sidebar).width, 88);
      await tester.pumpAndSettle();
      expect(tester.getSize(sidebar).width, 88);
      expect(
        tester.getSize(find.byKey(contentKey)).width,
        greaterThan(expandedContentWidth),
      );
      expect(find.text('Contextual summary'), findsNothing);
      expect(find.text('Kanban'), findsNothing);
      expect(find.byTooltip('Kanban'), findsOneWidget);
      expect(find.byTooltip('Sair do Sistema'), findsOneWidget);
      expect(find.bySemanticsLabel('Projetos e tarefas'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(FocusManager.instance.primaryFocus, isNotNull);

      await tester.tap(find.byTooltip('Kanban'));
      await tester.pumpAndSettle();
      expect(find.text('Active /kanban'), findsOneWidget);
      expect(find.byTooltip('Expandir navegação'), findsOneWidget);
      expect(tester.getSize(sidebar).width, 88);
      expect(
        tester.getSemantics(find.byTooltip('Kanban')),
        isSemantics(isButton: true, isSelected: true),
      );

      await tester.tap(find.byTooltip('Expandir navegação'));
      await tester.pump();
      expect(tester.getSize(sidebar).width, 360);
      await tester.pumpAndSettle();
      expect(tester.getSize(sidebar).width, 360);
      expect(find.text('Kanban'), findsOneWidget);
      expect(find.text('Contextual summary'), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('desktop navigation exposes selected state and keyboard focus',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final semantics = tester.ensureSemantics();
    Route<void> route(RouteSettings settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => WorkspaceScaffold(
            contentBuilder: (_, __) => const SizedBox.shrink(),
          ),
        );
    await tester.pumpWidget(MaterialApp(
      initialRoute: '/kanban',
      onGenerateInitialRoutes: (name) => <Route<void>>[
        route(RouteSettings(name: name)),
      ],
      onGenerateRoute: route,
    ));
    expect(
      tester.getSemantics(find.text('Kanban')),
      isSemantics(isButton: true, isSelected: true),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(FocusManager.instance.primaryFocus, isNotNull);
    semantics.dispose();
  });

  testWidgets('desktop route navigation preserves Back and desktop logout',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var logoutRequested = false;
    Route<void> route(RouteSettings settings) => MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => WorkspaceScaffold(
            contentBuilder: (_, __) => Text('Active ${settings.name}'),
            onLogoutRequested: (_) async {
              logoutRequested = true;
            },
          ),
        );
    await tester.pumpWidget(MaterialApp(
      initialRoute: '/projects',
      onGenerateInitialRoutes: (name) => <Route<void>>[
        route(RouteSettings(name: name)),
      ],
      onGenerateRoute: route,
    ));
    await tester.tap(find.text('Bater Ponto'));
    await tester.pumpAndSettle();
    expect(find.text('Active /time-clock'), findsOneWidget);
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Active /projects'), findsOneWidget);
    await tester.tap(find.text('Sair do Sistema'));
    expect(logoutRequested, isTrue);
  });

  testWidgets('browser Back restores the previous workspace screen',
      (tester) async {
    Route<void> workspaceRoute(RouteSettings settings) =>
        MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => WorkspaceScaffold(
            contentBuilder: (context, _) =>
                Center(child: Text('Active ${settings.name}')),
          ),
        );

    await tester.pumpWidget(MaterialApp(
      initialRoute: '/projects',
      onGenerateInitialRoutes: (name) =>
          <Route<void>>[workspaceRoute(RouteSettings(name: name))],
      onGenerateRoute: workspaceRoute,
    ));
    await tester.pumpAndSettle();

    Future<void> navigateTo(String label) async {
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('workspace-navigation-drawer')),
        matching: find.text(label),
      ));
      await tester.pumpAndSettle();
    }

    expect(find.text('Active /projects'), findsOneWidget);
    await navigateTo('Bater Ponto');
    expect(find.text('Active /time-clock'), findsOneWidget);
    await navigateTo('Administrar Equipe');
    expect(find.text('Active /admin/employees'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Active /time-clock'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Active /projects'), findsOneWidget);
  });

  testWidgets('selecting the current named workspace route avoids duplicates',
      (tester) async {
    Route<void> workspaceRoute(RouteSettings settings) =>
        MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => WorkspaceScaffold(
            contentBuilder: (context, _) =>
                Center(child: Text('Active ${settings.name}')),
          ),
        );

    await tester.pumpWidget(MaterialApp(
      initialRoute: '/time-clock',
      onGenerateInitialRoutes: (name) =>
          <Route<void>>[workspaceRoute(RouteSettings(name: name))],
      onGenerateRoute: workspaceRoute,
    ));
    await tester.pumpAndSettle();

    Future<void> navigateTo(String label) async {
      tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
        of: find.byKey(const ValueKey('workspace-navigation-drawer')),
        matching: find.text(label),
      ));
      await tester.pumpAndSettle();
    }

    await navigateTo('Administrar Equipe');
    expect(find.text('Active /admin/employees'), findsOneWidget);
    await navigateTo('Administrar Equipe');
    expect(find.text('Active /admin/employees'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Active /time-clock'), findsOneWidget);
  });

  testWidgets(
    'non-scrollable workspace content bypasses the shell vertical scroll',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScaffold(
            contentScrollable: false,
            contentBuilder: (_, __) => const SizedBox.expand(),
          ),
        ),
      );

      expect(find.byType(SingleChildScrollView), findsOneWidget);
    },
  );

  testWidgets(
    'scrollable workspace content is painted outside the backdrop filter',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScaffold(
            contentBuilder: (_, __) => const SizedBox(height: 1600),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(SingleChildScrollView), findsNWidgets(2));
      expect(
        find.ancestor(
          of: find.byType(SingleChildScrollView),
          matching: find.byType(BackdropFilter),
        ),
        findsNothing,
      );
    },
  );

  testWidgets(
    'logout action clears the session and returns to login',
    (tester) async {
      final client = _FakeLogoutApiClient(
        postError: ApiException(
          'Falha ao encerrar sessao no servidor.',
          statusCode: 500,
        ),
      );
      final tokenStorage = _InMemoryTokenStorage()..savedToken = 'token-123';
      final api = TouchInApi(client: client, tokenStorage: tokenStorage);

      await tester.pumpWidget(
        MaterialApp(
          home: WorkspaceScaffold(
            contentBuilder: (_, __) => const SizedBox.shrink(),
            onLogoutRequested: (context) => logoutFromWorkspace(
              context,
              api: api,
            ),
          ),
        ),
      );

      final scaffoldState = tester.state<ScaffoldState>(find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sair do Sistema'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(client.lastPath, '/auth/logout');
      expect(client.lastWithAuth, isTrue);
      expect(tokenStorage.clearCalled, isTrue);
      expect(tokenStorage.savedToken, isNull);
      expect(await tester.binding.handlePopRoute(), isFalse);
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
    },
  );
}

final _visualCases = <({String name, Size size, ThemeData theme, bool mobile})>[
  (
    name: 'desktop-light',
    size: const Size(1440, 900),
    theme: _visualLightTheme,
    mobile: false,
  ),
  (
    name: 'desktop-dark',
    size: const Size(1440, 900),
    theme: _visualDarkTheme,
    mobile: false,
  ),
  (
    name: 'mobile-light',
    size: const Size(390, 844),
    theme: _visualLightTheme,
    mobile: true,
  ),
  (
    name: 'mobile-dark',
    size: const Size(390, 844),
    theme: _visualDarkTheme,
    mobile: true,
  ),
];

Future<void> _captureVisualCase(
  WidgetTester tester,
  ({String name, Size size, ThemeData theme, bool mobile}) visualCase,
) async {
  final fontBytes = await tester.runAsync(() async {
    var directory = Directory(Platform.resolvedExecutable).parent;
    while (directory.path != directory.parent.path) {
      final candidate = File(
        '${directory.path}/bin/cache/artifacts/material_fonts/Roboto-Regular.ttf',
      );
      if (await candidate.exists()) {
        return candidate.readAsBytes();
      }
      directory = directory.parent;
    }
    throw StateError('Roboto was not found in the active Flutter SDK.');
  });
  expect(fontBytes, isNotNull);
  await (FontLoader('Roboto')
        ..addFont(Future<ByteData>.value(
          ByteData.sublistView(fontBytes!),
        )))
      .load();

  await tester.binding.setSurfaceSize(visualCase.size);
  await tester.pumpWidget(MaterialApp(
    theme: visualCase.theme,
    initialRoute: '/admin/audit',
    onGenerateRoute: (settings) => MaterialPageRoute<void>(
      settings: settings,
      builder: (_) => WorkspaceScaffold(
        contextualContent: const WorkspaceSidebar(
          summaryChildren: <Widget>[
            Text('Resumo do projeto'),
            Text('12 tarefas abertas'),
            Text('Atualizado hoje'),
          ],
          highlightChips: <Widget>[
            Chip(label: Text('3 atrasadas')),
            Chip(label: Text('9 em andamento')),
          ],
        ),
        contentBuilder: (context, _) => const Padding(
          padding: EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text('Trilha de Auditoria'),
              SizedBox(height: 8),
              Text('Acompanhe as alterações recentes da equipe.'),
              SizedBox(height: 24),
              Card(child: ListTile(title: Text('Registro de atividade'))),
              Card(child: ListTile(title: Text('Alteração de projeto'))),
            ],
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  if (visualCase.mobile) {
    tester.state<ScaffoldState>(find.byType(Scaffold)).openDrawer();
    await tester.pumpAndSettle();
  }

  expect(tester.takeException(), isNull, reason: visualCase.name);
  await expectLater(
    find.byType(WorkspaceScaffold),
    matchesGoldenFile(
      '../../../../../../docs/validation/issue-119/${visualCase.name}.png',
    ),
  );
}

final ThemeData _visualLightTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Roboto',
  colorScheme: const ColorScheme.light(
    primary: AppTheme.accent,
    onPrimary: Color(0xFF2C1800),
    surface: Color(0xFFFFFFFF),
    onSurface: Color(0xFF1D1B16),
    surfaceContainerHighest: Color(0xFFF1EFE8),
    onSurfaceVariant: Color(0xFF4E4739),
    outline: Color(0xFF82786A),
    outlineVariant: Color(0xFFD5CFC2),
  ),
  extensions: <ThemeExtension<dynamic>>[WorkspaceNavigationColors.light],
);

final ThemeData _visualDarkTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Roboto',
  colorScheme: const ColorScheme.dark(
    primary: AppTheme.accent,
    onPrimary: Color(0xFF412B00),
    surface: Color(0xFF1F1F1F),
    onSurface: Color(0xFFF5F1E8),
    surfaceContainerHighest: Color(0xFF2A2A2A),
    onSurfaceVariant: Color(0xFFD1C6B4),
    outline: Color(0xFF9A907F),
    outlineVariant: Color(0xFF4E4739),
  ),
  extensions: <ThemeExtension<dynamic>>[WorkspaceNavigationColors.dark],
);

class _FakeLogoutApiClient extends ApiClient {
  _FakeLogoutApiClient({this.postError});

  final Object? postError;
  String? lastPath;
  bool? lastWithAuth;

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool withAuth = false,
  }) async {
    lastPath = path;
    lastWithAuth = withAuth;
    if (postError != null) {
      throw postError!;
    }
    return null;
  }
}

class _InMemoryTokenStorage extends TokenStorage {
  String? savedToken;
  AuthSession? savedSession;
  bool clearCalled = false;

  @override
  Future<void> saveAccessToken(String token) async {
    savedToken = token;
  }

  @override
  Future<void> saveAuthSession(AuthSession session) async {
    savedToken = session.accessToken;
    savedSession = session;
  }

  @override
  Future<String?> readAccessToken() async {
    return savedToken ?? savedSession?.accessToken;
  }

  @override
  Future<AuthSession?> readAuthSession() async {
    return savedSession;
  }

  @override
  Future<void> clearAccessToken() async {
    clearCalled = true;
    savedToken = null;
    savedSession = null;
  }
}
