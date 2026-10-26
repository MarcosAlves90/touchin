import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/core/navigation/workspace_router.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_page.dart';
import 'package:touchin_flutter/features/projects/presentation/project_tasks_page.dart';
import 'package:touchin_flutter/features/settings/presentation/settings_page.dart';
import 'package:touchin_flutter/main.dart';

void main() {
  testWidgets(
    'workspace page entrance remains animated while later routes are instant',
    (tester) async {
      final router = WorkspaceRouter(
        initialPath: '/time-clock',
        buildRoute: (_, path, __) => Scaffold(body: Text(path)),
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        MaterialApp.router(
          routerDelegate: router,
          routeInformationParser: WorkspaceRouteParser(),
          routeInformationProvider: PlatformRouteInformationProvider(
            initialRouteInformation: RouteInformation(
              uri: Uri(path: '/time-clock'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      var navigator = tester.widget<Navigator>(find.byKey(router.navigatorKey));
      final firstPageRoute = navigator.pages.single.createRoute(
        tester.element(find.byKey(router.navigatorKey)),
      );
      expect(firstPageRoute, isA<PageRouteBuilder<void>>());
      expect(
        (firstPageRoute as PageRouteBuilder<void>).transitionDuration,
        const Duration(milliseconds: 450),
      );

      router.navigate('/projects');
      await tester.pump();

      navigator = tester.widget<Navigator>(find.byKey(router.navigatorKey));
      final destinationPageRoute = navigator.pages.last.createRoute(
        tester.element(find.byKey(router.navigatorKey)),
      );
      expect(destinationPageRoute, isA<PageRouteBuilder<void>>());
      expect(
        (destinationPageRoute as PageRouteBuilder<void>).transitionDuration,
        Duration.zero,
        reason: 'workspace_route_transition_missing',
      );
      final destination = ModalRoute.of(tester.element(find.text('/projects')))!;
      expect(destination.animation!.value, 1);
      expect(find.text('/time-clock'), findsNothing);
    },
  );

  testWidgets('obsolete auth check cannot revoke a newer login',
      (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/admin/employees';
    addTearDown(() {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    });
    final storage = _MemoryStorage()..session = _session;
    final api = _DelayedSessionApi(tokenStorage: storage);
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    router.navigate('/projects');
    await tester.pump();
    expect(api.authContextRequests, 2);

    router.signedOut();
    await storage.clearAccessToken();
    final newerSession = _session.copyWith(accessToken: 'new-session-token');
    await storage.saveAuthSession(newerSession);
    router.authenticate(newerSession);
    await tester.pump();

    api.pendingCheck.completeError(
      ApiException('Old session revoked', statusCode: 401),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(router.sessionRevoked, isFalse);
    expect(storage.session?.accessToken, 'new-session-token');
    expect(find.byType(AdminEmployeesPage), findsOneWidget);
  });

  testWidgets('delayed revocation cleanup cannot clear a newer login',
      (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/projects';
    addTearDown(() {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    });
    final storage = _MemoryStorage()..session = _session;
    final api = _DelayedSessionApi(tokenStorage: storage, rejectFirst: true);
    final cleanupBarrier = Completer<void>();
    storage.clearBarrier = cleanupBarrier;
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    expect(api.authContextRequests, 1);
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(CircularProgressIndicator)),
    )!;

    api.pendingCheck.completeError(
      ApiException('Session revoked', statusCode: 403),
    );
    await tester.pump();
    expect(router.sessionRevoked, isTrue);

    final newerSession = _session.copyWith(accessToken: 'new-session-token');
    await storage.saveAuthSession(newerSession);
    router.authenticate(newerSession);
    cleanupBarrier.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(router.sessionRevoked, isFalse);
    expect(storage.session?.accessToken, 'new-session-token');
    expect(find.byType(AdminEmployeesPage), findsOneWidget);
  });

  testWidgets(
      'revoked session cannot restore a cached page via Back or Forward',
      (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/admin/employees';
    addTearDown(() {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    });
    final storage = _MemoryStorage()..session = _session;
    final api = _RevokingSessionApi(tokenStorage: storage);
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AdminEmployeesPage), findsOneWidget);

    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    final first = router.currentConfiguration;
    router.navigate('/projects');
    final second = router.currentConfiguration;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(api.authContextRequests, 2);
    expect(storage.session, isNull);
    expect(find.byType(ProjectTasksPage), findsNothing);
    expect(find.text('Entrar'), findsWidgets);

    await router.setNewRoutePath(first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AdminEmployeesPage), findsNothing,
        reason: 'Back must not expose the cached authenticated screen');
    expect(find.text('Entrar'), findsWidgets);

    await router.setNewRoutePath(second);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ProjectTasksPage), findsNothing);
    expect(find.text('Entrar'), findsWidgets);
  });

  testWidgets('reload restores one page and avoids reused history IDs',
      (tester) async {
    final router = WorkspaceRouter(
      initialPath: '/admin/employees',
      buildRoute: (_, path, __) => Text(path),
    );
    addTearDown(router.dispose);
    final restored = await WorkspaceRouteParser().parseRouteInformation(
      RouteInformation(
        uri: Uri(path: '/admin/employees'),
        state: 'entry-1',
      ),
    );
    await router.setNewRoutePath(restored);
    await tester.pumpWidget(MaterialApp(
        home: Builder(
      builder: (context) => router.build(context),
    )));

    expect(router.currentConfiguration, restored);
    expect(tester.widget<Navigator>(find.byKey(router.navigatorKey)).pages,
        hasLength(1));

    router.navigate('/projects');
    final next = router.currentConfiguration;
    expect(next.entryId, isNot(restored.entryId));
    await router.setNewRoutePath(restored);
    expect(router.currentConfiguration, restored);
    await router.setNewRoutePath(next);
    expect(router.currentConfiguration, next);
  });

  test('repeated URLs retain their distinct browser history entry IDs',
      () async {
    final router = WorkspaceRouter(
      initialPath: '/projects',
      buildRoute: (_, __, ___) => const SizedBox.shrink(),
    );
    addTearDown(router.dispose);
    final first = router.currentConfiguration;
    router.navigate('/settings');
    final middle = router.currentConfiguration;
    router.navigate('/projects');
    final last = router.currentConfiguration;

    expect(first.entryId, isNot(last.entryId));
    await router.setNewRoutePath(middle);
    expect(router.currentConfiguration.entryId, middle.entryId);
    await router.setNewRoutePath(last);
    expect(router.currentConfiguration.entryId, last.entryId);
    await router.setNewRoutePath(middle);
    await router.setNewRoutePath(first);
    expect(router.currentConfiguration.entryId, first.entryId);

    final parser = WorkspaceRouteParser();
    final recovered = await parser.parseRouteInformation(
      parser.restoreRouteInformation(last),
    );
    expect(recovered.path, last.path);
    expect(recovered.entryId, last.entryId);
  });

  testWidgets('production Router handles native Back after closing a modal',
      (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/admin/employees';
    addTearDown(() {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    });
    final storage = _MemoryStorage()..session = _session;
    await tester.pumpWidget(MyApp(
      api: _SessionApi(tokenStorage: storage),
      tokenStorage: storage,
    ));
    await tester.pump();
    await tester.pump();
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;

    router.navigate('/projects');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(ProjectTasksPage), findsOneWidget);

    showDialog<void>(
      context: tester.element(find.byType(ProjectTasksPage)),
      builder: (_) => const AlertDialog(title: Text('Diálogo de teste')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Diálogo de teste'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Diálogo de teste'), findsNothing);
    expect(router.currentConfiguration.path, '/projects');

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.currentConfiguration.path, '/admin/employees');
    expect(find.byType(AdminEmployeesPage), findsOneWidget);
    expect(find.byType(ProjectTasksPage), findsNothing);
  });

  testWidgets('browser router supports bidirectional history', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/admin/employees';
    addTearDown(() {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    });
    final storage = _MemoryStorage()..session = _session;
    final api = _SessionApi(tokenStorage: storage);
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump();

    // A declarative Router handles browser history entries independently of
    // Navigator 1.0's named-route stack.
    expect(
      find.byWidgetPredicate(
        (widget) => widget.runtimeType.toString().startsWith('Router<'),
      ),
      findsOneWidget,
    );
    expect(find.text('Administrar equipe'), findsOneWidget);

    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.text('Administrar equipe')),
    )!;
    router.navigate('/projects');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.currentConfiguration.path, '/projects');
    expect(find.byType(ProjectTasksPage), findsOneWidget);

    router.navigate('/settings');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.currentConfiguration.path, '/settings');
    expect(find.byType(ThemeSettingsPage), findsOneWidget);

    // Popstate-style updates must move through A-B-C-Back-Back-Forward-Forward
    // without adding entries or leaving a different screen mounted.
    for (final (path, screen) in <(String, Type)>[
      ('/projects', ProjectTasksPage),
      ('/admin/employees', AdminEmployeesPage),
      ('/projects', ProjectTasksPage),
      ('/settings', ThemeSettingsPage),
    ]) {
      await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/navigation',
        JSONMethodCodec().encodeMethodCall(
          MethodCall('pushRouteInformation', {'location': path}),
        ),
        (_) {},
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      expect(router.currentConfiguration.path, path);
      expect(find.byType(screen), findsOneWidget);
    }
  });
}

final _session = AuthSession(
  accessToken: 'test',
  tokenType: 'bearer',
  expiresAt: DateTime.utc(2099),
  company: _company,
  user: _user,
);


const _company = AuthCompanySummary(
  id: 'cmp-01',
  legalName: 'TouchIn Teste',
  tradeName: 'TouchIn',
  cnpjMasked: '12.***.***/****-90',
  emailMasked: 'co*****@touchin.com',
  phoneMasked: '11*****0000',
);
const _user = AuthUserSummary(
  id: 'usr-01',
  email: 'admin@touchin.com',
  role: 'super_admin',
);

class _SessionApi extends TouchInApi {
  _SessionApi({required super.tokenStorage});

  @override
  Future<AuthContext> getAuthContext() async =>
      const AuthContext(company: _company, user: _user);
}

class _RevokingSessionApi extends TouchInApi {
  _RevokingSessionApi({required super.tokenStorage});

  int authContextRequests = 0;

  @override
  Future<AuthContext> getAuthContext() async {
    authContextRequests++;
    if (authContextRequests == 1) {
      return const AuthContext(company: _company, user: _user);
    }
    throw ApiException('Sessão revogada', statusCode: 401);
  }
}

class _DelayedSessionApi extends TouchInApi {
  _DelayedSessionApi({required super.tokenStorage, this.rejectFirst = false});

  final bool rejectFirst;
  final Completer<AuthContext> pendingCheck = Completer<AuthContext>();
  int authContextRequests = 0;

  @override
  Future<AuthContext> getAuthContext() {
    authContextRequests++;
    if (rejectFirst || authContextRequests > 1) {
      return pendingCheck.future;
    }
    return Future.value(const AuthContext(company: _company, user: _user));
  }
}

class _MemoryStorage extends TokenStorage {
  AuthSession? session;
  Completer<void>? clearBarrier;

  @override
  Future<void> saveAuthSession(AuthSession next) async => session = next;

  @override
  Future<AuthSession?> readAuthSession() async => session;

  @override
  Future<void> clearAccessToken() async {
    if (clearBarrier case final barrier?) {
      await barrier.future;
    }
    session = null;
  }

  @override
  Future<void> clearSessionIfTokenMatches(String expectedToken) async {
    if (clearBarrier case final barrier?) {
      await barrier.future;
    }
    if (session?.accessToken == expectedToken) {
      session = null;
    }
  }
}
