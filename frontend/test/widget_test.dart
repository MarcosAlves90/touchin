import 'dart:async';
import 'dart:io';

import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/core/navigation/workspace_router.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
import 'package:touchin_flutter/features/auth/presentation/reset_password_page.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_page.dart';
import 'package:touchin_flutter/features/projects/presentation/project_kanban_page.dart';
import 'package:touchin_flutter/features/projects/presentation/project_tasks_page.dart';
import 'package:touchin_flutter/features/settings/presentation/settings_page.dart';
import 'package:touchin_flutter/features/time_tracking/presentation/time_clock_page.dart';
import 'package:touchin_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const company = AuthCompanySummary(
    id: 'cmp-01',
    legalName: 'TouchIn Tecnologia LTDA',
    tradeName: 'TouchIn',
    cnpjMasked: '12.***.***/****-90',
    emailMasked: 'co*****@touchin.com',
    phoneMasked: '11*****0000',
  );
  const user = AuthUserSummary(
    id: 'usr-01',
    email: 'super.admin@touchin.com',
    role: 'super_admin',
  );
  const primaryRoutes = <String, Type>{
    '/time-clock': TimeClockPage,
    '/admin/employees': AdminEmployeesPage,
    '/admin/audit': AdminAuditPage,
    '/projects': ProjectTasksPage,
    '/kanban': ProjectKanbanPage,
    '/settings': ThemeSettingsPage,
  };

  testWidgets('authenticated login replacement publishes canonical browser URL',
      (tester) async {
    final routeUpdates = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method == 'routeInformationUpdated') {
          final args = call.arguments! as Map<dynamic, dynamic>;
          routeUpdates.add(args['uri']! as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      );
    });
    await tester.pumpWidget(MyApp(tokenStorage: _InMemoryTokenStorage()));
    await tester.pumpAndSettle();

    final session = AuthSession(
      accessToken: 'token-123',
      tokenType: 'bearer',
      expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
      company: company,
      user: user,
    );
    WorkspaceRouterScope.replaceWithAuthenticated(
        tester.element(find.byType(LoginPage)), session);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.byType(AdminEmployeesPage), findsOneWidget);
    expect(routeUpdates, contains('/admin/employees'));
  });

  for (final route in primaryRoutes.entries) {
    testWidgets('deep link to ${route.key} opens the expected workspace',
        (tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = route.key;
      addTearDown(() {
        tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
      });
      final tokenStorage = _InMemoryTokenStorage()
        ..savedSession = AuthSession(
          accessToken: 'token-123',
          tokenType: 'bearer',
          expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
          company: company,
          user: user,
        );
      final api = _FakeTouchInApi(
        tokenStorage: tokenStorage,
        authContext: const AuthContext(company: company, user: user),
      );

      await tester.pumpWidget(MyApp(api: api, tokenStorage: tokenStorage));
      await tester.pump();
      await tester.pump();

      expect(find.byType(route.value), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);
      expect(api.authContextRequests, 1);
    });
  }

  testWidgets('revoked session blocks a protected deep link', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/kanban';
    addTearDown(() {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    });
    final tokenStorage = _InMemoryTokenStorage()
      ..savedSession = AuthSession(
        accessToken: 'revoked-token',
        tokenType: 'bearer',
        expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
        company: company,
        user: user,
      );
    final api = _FakeTouchInApi(
      tokenStorage: tokenStorage,
      authContextError: ApiException('Sessão revogada', statusCode: 401),
    );

    await tester.pumpWidget(MyApp(api: api, tokenStorage: tokenStorage));
    await tester.pump();
    await tester.pump();

    expect(find.byType(ProjectKanbanPage), findsNothing);
    expect(find.text('Entrar'), findsWidgets);
    expect(tokenStorage.savedSession, isNull);
  });

  testWidgets('renders login experience on startup', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MyApp(tokenStorage: _InMemoryTokenStorage()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Entrar'), findsNWidgets(2));
    expect(find.text('TOUCHIN'), findsWidgets);
    expect(find.text('Cadastrar empresa'), findsOneWidget);
  });

  testWidgets('startup splash explains pending session verification', (
    WidgetTester tester,
  ) async {
    final tokenStorage = _InMemoryTokenStorage()
      ..savedSession = AuthSession(
        accessToken: 'token-123',
        tokenType: 'bearer',
        expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
        company: const AuthCompanySummary(
          id: 'cmp-01',
          legalName: 'TouchIn Tecnologia LTDA',
          tradeName: 'TouchIn',
          cnpjMasked: '12.***.***/****-90',
          emailMasked: 'co*****@touchin.com',
          phoneMasked: '11*****0000',
        ),
        user: const AuthUserSummary(
          id: 'usr-01',
          email: 'super.admin@touchin.com',
          role: 'super_admin',
        ),
      );
    final authContextCompleter = Completer<AuthContext>();
    final api = _FakeTouchInApi(
      tokenStorage: tokenStorage,
      authContextCompleter: authContextCompleter,
    );

    await tester.pumpWidget(
      MyApp(api: api, tokenStorage: tokenStorage),
    );
    await tester.pump();
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Aguardando o servidor'), findsOneWidget);
    expect(find.text('Escrevendo documentos'), findsOneWidget);
    final initialDots = tester
        .widget<Text>(
          find.byKey(const ValueKey<String>('startup-status-dots')),
        )
        .data;

    await tester.pump(const Duration(milliseconds: 500));
    final animatedDots = tester
        .widget<Text>(
          find.byKey(const ValueKey<String>('startup-status-dots')),
        )
        .data;
    expect(animatedDots, isNot(initialDots));

    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Organizando rotinas'), findsOneWidget);

    authContextCompleter.complete(
      const AuthContext(
        company: AuthCompanySummary(
          id: 'cmp-01',
          legalName: 'TouchIn Tecnologia LTDA',
          tradeName: 'TouchIn',
          cnpjMasked: '12.***.***/****-90',
          emailMasked: 'co*****@touchin.com',
          phoneMasked: '11*****0000',
        ),
        user: AuthUserSummary(
          id: 'usr-01',
          email: 'super.admin@touchin.com',
          role: 'super_admin',
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Aguardando o servidor'), findsNothing);
    expect(find.text('Administrar equipe'), findsOneWidget);
  });

  testWidgets('background resume keeps mounted workspace until auth check ends',
      (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/admin/employees';
    addTearDown(() {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    });
    final storage = _InMemoryTokenStorage()
      ..savedSession = AuthSession(
        accessToken: 'token-123',
        tokenType: 'bearer',
        expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
        company: company,
        user: user,
      );
    final check = Completer<AuthContext>();
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContext: const AuthContext(company: company, user: user),
      authContextRequestCompleters: {2: check},
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final workspace = tester.element(find.byType(AdminEmployeesPage).last);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(api.authContextRequests, 2);
    expect(
        tester.element(find.byType(AdminEmployeesPage).last), same(workspace));
    expect(find.text('Aguardando o servidor'), findsNothing);

    check.completeError(const SocketException('offline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Não foi possível validar sua sessão'), findsOneWidget);
    expect(find.byType(AdminEmployeesPage, skipOffstage: false), findsWidgets);
    expect(storage.savedSession, isNotNull);
    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AdminEmployeesPage), findsWidgets);
    expect(
        tester.element(find.byType(AdminEmployeesPage).last), same(workspace));
    expect(find.text('Aguardando o servidor'), findsNothing);
  });

  testWidgets('resource 403 does not revoke or replace an active workspace',
      (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/admin/employees';
    addTearDown(() {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    });
    final storage = _InMemoryTokenStorage()
      ..savedSession = AuthSession(
        accessToken: 'token-123',
        tokenType: 'bearer',
        expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
        company: company,
        user: user,
      );
    final check = Completer<AuthContext>();
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContext: const AuthContext(company: company, user: user),
      authContextRequestCompleters: {2: check},
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final workspace = tester.element(find.byType(AdminEmployeesPage).last);
    AuthRejectionEvents.onRejected?.call('token-123');
    await tester.pump();
    expect(
        tester.element(find.byType(AdminEmployeesPage).last), same(workspace));
    expect(find.text('Aguardando o servidor'), findsNothing);
    check.complete(const AuthContext(company: company, user: user));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    expect(storage.savedSession, isNotNull);
    expect(find.byType(AdminEmployeesPage), findsWidgets);
  });

  testWidgets('reset success removes prior local session before login',
      (tester) async {
    final storage = _InMemoryTokenStorage()
      ..savedSession = AuthSession(
        accessToken: 'token-123',
        tokenType: 'bearer',
        expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
        company: company,
        user: user,
      );
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContext: const AuthContext(company: company, user: user),
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    final protectedEntry = router.currentConfiguration;
    router.navigate(
      '/reset-password?token=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(storage.savedSession, isNotNull);
    await tester.enterText(find.byType(TextFormField).at(0), 'NovaSenha123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NovaSenha123!');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Senha atualizada'), findsOneWidget);
    expect(api.resetConfirmRequests, 1);
    expect(storage.savedSession, isNull,
        reason:
            'reset success must invalidate credentials before the next tap');
    expect(router.verifiedSession, isNull);
    await tester.tap(find.text('Ir para login'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(storage.savedSession, isNull);
    expect(find.byType(LoginPage), findsOneWidget);
    expect(find.byType(AdminEmployeesPage), findsNothing);
    await router.setNewRoutePath(protectedEntry);
    await tester.pumpAndSettle();
    expect(find.byType(AdminEmployeesPage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('reset success blocks protected Back and Forward before login',
      (tester) async {
    final storage = _InMemoryTokenStorage()
      ..savedSession = AuthSession(
        accessToken: 'old-token',
        tokenType: 'bearer',
        expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
        company: company,
        user: user,
      );
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContext: const AuthContext(company: company, user: user),
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    final workspaceEntry = router.currentConfiguration;
    router.navigate(
        '/reset-password?token=rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final resetEntry = router.currentConfiguration;
    await tester.enterText(find.byType(TextFormField).at(0), 'NovaSenha123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NovaSenha123!');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Senha atualizada'), findsOneWidget);
    expect(storage.savedSession, isNull);
    expect(router.sessionRevoked, isTrue);
    expect(find.byType(AdminEmployeesPage), findsNothing);

    await router.setNewRoutePath(workspaceEntry);
    await tester.pumpAndSettle();
    expect(find.byType(AdminEmployeesPage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
    await router.setNewRoutePath(resetEntry);
    await tester.pumpAndSettle();
    expect(find.byType(AdminEmployeesPage), findsNothing);
    router.navigate('/time-clock');
    await tester.pumpAndSettle();
    expect(find.byType(TimeClockPage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('opening invalid reset form never revokes a valid session',
      (tester) async {
    final storage = _InMemoryTokenStorage()
      ..savedSession = AuthSession(
        accessToken: 'original-token',
        tokenType: 'bearer',
        expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
        company: company,
        user: user,
      );
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContext: const AuthContext(company: company, user: user),
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    router.navigate('/reset-password?token=invalid');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Link inválido ou incompleto. Solicite um novo link.'),
        findsOneWidget);
    expect(router.sessionRevoked, isFalse);
    expect(storage.savedSession?.accessToken, 'original-token');
    expect(api.resetConfirmRequests, 0);
  });

  testWidgets('rejected reset confirmation keeps the current session',
      (tester) async {
    final storage = _InMemoryTokenStorage()
      ..savedSession = AuthSession(
        accessToken: 'original-token',
        tokenType: 'bearer',
        expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
        company: company,
        user: user,
      );
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContext: const AuthContext(company: company, user: user),
      resetConfirmError: ApiException('Token expirado', statusCode: 400),
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    router.navigate(
        '/reset-password?token=rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextFormField).at(0), 'NovaSenha123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NovaSenha123!');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Senha atualizada'), findsNothing);
    expect(find.text('Token expirado'), findsOneWidget);
    expect(router.sessionRevoked, isFalse);
    expect(storage.savedSession?.accessToken, 'original-token');
  });

  testWidgets('late reset confirmation never clears a newer session',
      (tester) async {
    final oldSession = AuthSession(
      accessToken: 'old-token',
      tokenType: 'bearer',
      expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
      company: company,
      user: user,
    );
    final storage = _InMemoryTokenStorage()..savedSession = oldSession;
    final pendingReset = Completer<void>();
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContext: const AuthContext(company: company, user: user),
      resetConfirmCompleter: pendingReset,
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    router.navigate(
        '/reset-password?token=rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextFormField).at(0), 'NovaSenha123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NovaSenha123!');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    expect(api.resetConfirmRequests, 1);
    final newerSession = oldSession.copyWith(accessToken: 'newer-token');
    await storage.saveAuthSession(newerSession);
    router.restoreVerifiedSession(newerSession);
    pendingReset.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(storage.savedSession?.accessToken, 'newer-token');
    expect(router.verifiedSession?.accessToken, 'newer-token');
    expect(router.sessionRevoked, isFalse);
  });

  testWidgets('reset succeeds after leaving page and revokes old workspace',
      (tester) async {
    final storage = _InMemoryTokenStorage()
      ..savedSession = AuthSession(
        accessToken: 'revoked-token',
        tokenType: 'bearer',
        expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
        company: company,
        user: user,
      );
    final pendingReset = Completer<void>();
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContext: const AuthContext(company: company, user: user),
      resetConfirmCompleter: pendingReset,
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    final workspaceEntry = router.currentConfiguration;
    router.navigate(
        '/reset-password?token=rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final resetEntry = router.currentConfiguration;
    await tester.enterText(find.byType(TextFormField).at(0), 'NovaSenha123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NovaSenha123!');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    expect(api.resetConfirmRequests, 1);

    await router.setNewRoutePath(workspaceEntry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ResetPasswordPage, skipOffstage: false), findsNothing);
    expect(find.byType(AdminEmployeesPage), findsOneWidget);
    pendingReset.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(router.sessionRevoked, isTrue);
    expect(router.verifiedSession, isNull);
    expect(storage.savedSession, isNull);
    expect(find.byType(AdminEmployeesPage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);

    await router.setNewRoutePath(resetEntry);
    await tester.pumpAndSettle();
    expect(find.byType(AdminEmployeesPage), findsNothing);
    await router.setNewRoutePath(workspaceEntry);
    await tester.pumpAndSettle();
    expect(find.byType(AdminEmployeesPage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);
  });

  testWidgets('late reset after page disposal preserves a newly logged-in user',
      (tester) async {
    final originalSession = AuthSession(
      accessToken: 'old-token',
      tokenType: 'bearer',
      expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
      company: company,
      user: user,
    );
    final storage = _InMemoryTokenStorage()..savedSession = originalSession;
    final pendingReset = Completer<void>();
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContext: const AuthContext(company: company, user: user),
      resetConfirmCompleter: pendingReset,
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    final workspaceEntry = router.currentConfiguration;
    router.navigate(
        '/reset-password?token=rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextFormField).at(0), 'NovaSenha123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NovaSenha123!');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    expect(api.resetConfirmRequests, 1);

    await router.setNewRoutePath(workspaceEntry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ResetPasswordPage, skipOffstage: false), findsNothing);
    final newSession = originalSession.copyWith(accessToken: 'fresh-token');
    await storage.saveAuthSession(newSession);
    router.authenticate(newSession);
    await tester.pump();
    pendingReset.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(router.sessionRevoked, isFalse);
    expect(router.verifiedSession?.accessToken, 'fresh-token');
    expect(storage.savedSession?.accessToken, 'fresh-token');
    expect(find.byType(AdminEmployeesPage), findsOneWidget);
  });

  testWidgets('login before reset commit must recheck and revoke new token',
      (tester) async {
    final oldSession = AuthSession(
      accessToken: 'old-token',
      tokenType: 'bearer',
      expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
      company: company,
      user: user,
    );
    final storage = _InMemoryTokenStorage()..savedSession = oldSession;
    final reset = Completer<void>();
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContextResults: <Object>[
        const AuthContext(company: company, user: user),
        ApiException('Sessão revogada pelo reset', statusCode: 401),
      ],
      resetConfirmCompleter: reset,
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    final earlierWorkspace = router.currentConfiguration;
    router.navigate(
        '/reset-password?token=rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextFormField).at(0), 'NovaSenha123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NovaSenha123!');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    expect(api.resetConfirmRequests, 1);

    final loginSession =
        oldSession.copyWith(accessToken: 'issued-before-reset-commit');
    await storage.saveAuthSession(loginSession);
    router.authenticate(loginSession);
    await tester.pump();
    reset.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(api.authContextRequests, 2,
        reason: 'Changed login must be rechecked against auth/me');
    expect(router.sessionRevoked, isTrue);
    expect(router.verifiedSession, isNull);
    expect(storage.savedSession, isNull);
    expect(find.byType(AdminEmployeesPage), findsNothing);
    await router.setNewRoutePath(earlierWorkspace);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AdminEmployeesPage), findsNothing);
  });

  testWidgets('login after reset stays concealed until auth/me confirms it',
      (tester) async {
    final original = AuthSession(
      accessToken: 'original-token',
      tokenType: 'bearer',
      expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
      company: company,
      user: user,
    );
    final storage = _InMemoryTokenStorage()..savedSession = original;
    final reset = Completer<void>();
    final serverCheck = Completer<AuthContext>();
    const validContext = AuthContext(company: company, user: user);
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContext: validContext,
      authContextRequestCompleters: {2: serverCheck},
      resetConfirmCompleter: reset,
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    router.navigate(
        '/reset-password?token=rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextFormField).at(0), 'NovaSenha123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NovaSenha123!');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();

    // Models a login made with the new password after reset committed,
    // before the reset response reaches the previous form.
    final newer = original.copyWith(accessToken: 'issued-after-reset');
    await storage.saveAuthSession(newer);
    router.authenticate(newer);
    reset.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(api.authContextRequests, 2);
    expect(router.passwordResetVerificationPending, isTrue);
    expect(find.byType(AdminEmployeesPage), findsNothing);
    expect(
        find.byType(AdminEmployeesPage, skipOffstage: false), findsOneWidget);
    expect(find.byKey(const ValueKey<String>('route-session-skeleton')),
        findsOneWidget);
    expect(storage.savedSession?.accessToken, 'issued-after-reset');

    router.navigate('/');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(router.passwordResetVerificationPending, isTrue,
        reason: 'The root route must not reauthenticate an unverified token');
    expect(find.byType(AdminEmployeesPage), findsNothing);

    serverCheck.complete(validContext);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(router.passwordResetVerificationPending, isFalse);
    expect(router.sessionRevoked, isFalse);
    expect(router.verifiedSession?.accessToken, 'issued-after-reset');
    expect(storage.savedSession?.accessToken, 'issued-after-reset');
    expect(find.byType(AdminEmployeesPage), findsWidgets);
  });

  testWidgets(
      'ambiguous reset login survives network outage without showing workspace',
      (tester) async {
    final original = AuthSession(
      accessToken: 'old-token',
      tokenType: 'bearer',
      expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
      company: company,
      user: user,
    );
    final storage = _InMemoryTokenStorage()..savedSession = original;
    final reset = Completer<void>();
    final serverCheck = Completer<AuthContext>();
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContext: const AuthContext(company: company, user: user),
      authContextRequestCompleters: {2: serverCheck},
      resetConfirmCompleter: reset,
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    router.navigate(
        '/reset-password?token=rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextFormField).at(0), 'NovaSenha123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NovaSenha123!');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();

    final newer = original.copyWith(accessToken: 'unknown-token');
    await storage.saveAuthSession(newer);
    router.authenticate(newer);
    reset.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(router.passwordResetVerificationPending, isTrue);
    expect(find.byType(AdminEmployeesPage), findsNothing);
    serverCheck.completeError(const SocketException('offline'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(router.verificationUnavailable, isTrue);
    expect(find.byType(AdminEmployeesPage), findsNothing);
    expect(find.text('Não foi possível validar sua sessão'), findsOneWidget);
    expect(storage.savedSession?.accessToken, 'unknown-token');

    await tester.tap(find.text('Tentar novamente'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(api.authContextRequests, 3);
    expect(router.verificationUnavailable, isFalse);
    expect(find.byType(AdminEmployeesPage), findsOneWidget);
    expect(storage.savedSession?.accessToken, 'unknown-token');
  });

  testWidgets('stale auth/me rejection cannot revoke a later replacement login',
      (tester) async {
    final original = AuthSession(
      accessToken: 'old-token',
      tokenType: 'bearer',
      expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
      company: company,
      user: user,
    );
    final storage = _InMemoryTokenStorage()..savedSession = original;
    final reset = Completer<void>();
    final serverCheck = Completer<AuthContext>();
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContext: const AuthContext(company: company, user: user),
      authContextRequestCompleters: {2: serverCheck},
      resetConfirmCompleter: reset,
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    router.navigate(
        '/reset-password?token=rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextFormField).at(0), 'NovaSenha123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NovaSenha123!');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();

    final intermediate = original.copyWith(accessToken: 'intermediate-token');
    await storage.saveAuthSession(intermediate);
    router.authenticate(intermediate);
    reset.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(router.passwordResetVerificationPending, isTrue);

    final finalSession =
        original.copyWith(accessToken: 'confirmed-later-token');
    await storage.saveAuthSession(finalSession);
    router.authenticate(finalSession);
    await tester.pump();
    serverCheck.completeError(
        ApiException('Intermediate session revoked', statusCode: 401));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
    expect(router.sessionRevoked, isFalse);
    expect(router.verifiedSession?.accessToken, 'confirmed-later-token');
    expect(storage.savedSession?.accessToken, 'confirmed-later-token');
    expect(find.byType(AdminEmployeesPage), findsOneWidget);
  });

  testWidgets('failed reset after page disposal never revokes the workspace',
      (tester) async {
    final storage = _InMemoryTokenStorage()
      ..savedSession = AuthSession(
        accessToken: 'valid-token',
        tokenType: 'bearer',
        expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
        company: company,
        user: user,
      );
    final pendingReset = Completer<void>();
    final api = _FakeTouchInApi(
      tokenStorage: storage,
      authContext: const AuthContext(company: company, user: user),
      resetConfirmCompleter: pendingReset,
      resetConfirmError: ApiException('Token expirado', statusCode: 400),
    );
    await tester.pumpWidget(MyApp(api: api, tokenStorage: storage));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    final router = WorkspaceRouterScope.maybeOf(
      tester.element(find.byType(AdminEmployeesPage)),
    )!;
    final workspaceEntry = router.currentConfiguration;
    router.navigate(
        '/reset-password?token=rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrrr');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.enterText(find.byType(TextFormField).at(0), 'NovaSenha123!');
    await tester.enterText(find.byType(TextFormField).at(1), 'NovaSenha123!');
    await tester.tap(find.text('Salvar nova senha'));
    await tester.pump();
    expect(api.resetConfirmRequests, 1);

    await router.setNewRoutePath(workspaceEntry);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(ResetPasswordPage, skipOffstage: false), findsNothing);
    pendingReset.complete();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(router.sessionRevoked, isFalse);
    expect(router.verifiedSession?.accessToken, 'valid-token');
    expect(storage.savedSession?.accessToken, 'valid-token');
    expect(find.byType(AdminEmployeesPage), findsOneWidget);
  });

  testWidgets(
    'reuses verified session on internal navigation without redundant bootstrap',
    (WidgetTester tester) async {
      final tokenStorage = _InMemoryTokenStorage()
        ..savedSession = AuthSession(
          accessToken: 'token-123',
          tokenType: 'bearer',
          expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
          company: company,
          user: user,
        );
      final api = _FakeTouchInApi(
        tokenStorage: tokenStorage,
        authContext: const AuthContext(company: company, user: user),
      );

      await tester.pumpWidget(MyApp(api: api, tokenStorage: tokenStorage));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(AdminEmployeesPage), findsOneWidget);
      expect(api.authContextRequests, 1);

      WorkspaceRouterScope.maybeOf(
        tester.element(find.byType(AdminEmployeesPage)),
      )!
          .navigate('/time-clock');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(api.authContextRequests, 1);
      expect(find.byKey(const ValueKey<String>('route-session-skeleton')),
          findsNothing);
      expect(find.text('Aguardando o servidor'), findsNothing);
      expect(find.byType(AdminEmployeesPage), findsNothing);
      expect(find.byType(TimeClockPage), findsOneWidget);
      expect(find.byTooltip('Abrir menu'), findsOneWidget);

      // An actual auth rejection, unlike navigation, triggers revalidation.
      AuthRejectionEvents.onRejected?.call('token-123');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(api.authContextRequests, 2);
      expect(find.byType(TimeClockPage), findsOneWidget);
    },
  );

  testWidgets(
    'shows a scoped retry after route verification fails transiently',
    (WidgetTester tester) async {
      final tokenStorage = _InMemoryTokenStorage()
        ..savedSession = AuthSession(
          accessToken: 'token-123',
          tokenType: 'bearer',
          expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
          company: company,
          user: user,
        );
      final api = _FakeTouchInApi(
        tokenStorage: tokenStorage,
        authContextResults: <Object>[
          const AuthContext(company: company, user: user),
          ApiException('Serviço temporariamente indisponível.',
              statusCode: 503),
          const AuthContext(company: company, user: user),
        ],
      );

      await tester.pumpWidget(MyApp(api: api, tokenStorage: tokenStorage));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      WorkspaceRouterScope.maybeOf(
        tester.element(find.byType(AdminEmployeesPage)),
      )!
          .navigate('/time-clock');
      await tester.pump();
      AuthRejectionEvents.onRejected?.call('token-123');
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Não foi possível validar sua sessão'), findsOneWidget);
      expect(find.text('Aguardando o servidor'), findsNothing);
      expect(find.byTooltip('Abrir menu'), findsOneWidget);
      expect(tokenStorage.savedSession, isNotNull);
      expect(api.authContextRequests, 2);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TimeClockPage), findsOneWidget);
      expect(find.text('Não foi possível validar sua sessão'), findsNothing);
      expect(api.authContextRequests, 3);
    },
  );

  for (final statusCode in <int>[401, 403]) {
    testWidgets(
      'route verification $statusCode still revokes the session',
      (WidgetTester tester) async {
        final tokenStorage = _InMemoryTokenStorage()
          ..savedSession = AuthSession(
            accessToken: 'token-123',
            tokenType: 'bearer',
            expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
            company: company,
            user: user,
          );
        final api = _FakeTouchInApi(
          tokenStorage: tokenStorage,
          authContextResults: <Object>[
            const AuthContext(company: company, user: user),
            ApiException('Sessão revogada', statusCode: statusCode),
          ],
        );

        await tester.pumpWidget(MyApp(api: api, tokenStorage: tokenStorage));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
        WorkspaceRouterScope.maybeOf(
          tester.element(find.byType(AdminEmployeesPage)),
        )!
            .navigate('/time-clock');
        await tester.pump();
        AuthRejectionEvents.onRejected?.call('token-123');
        await tester.pump(const Duration(milliseconds: 500));
        // The Navigator removes the old workspace page after the session
        // revocation animation has completed, not during its first frame.
        await tester.pumpAndSettle();

        expect(find.byType(TimeClockPage), findsNothing);
        expect(find.text('Entrar'), findsWidgets);
        expect(find.text('Aguardando o servidor'), findsNothing);
        expect(tokenStorage.savedSession, isNull);
        expect(api.authContextRequests, 2);
      },
    );
  }

  testWidgets('keeps opaque themed backgrounds during auth navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(MyApp(tokenStorage: _InMemoryTokenStorage()));
    await tester.pumpAndSettle();

    void expectThemedBackgrounds() {
      for (final element in find.byType(Scaffold).evaluate()) {
        final scaffold = element.widget as Scaffold;
        final background = scaffold.backgroundColor ??
            Theme.of(element).scaffoldBackgroundColor;
        expect(background, const Color(0xFF161616));
      }
    }

    expectThemedBackgrounds();
    await tester.tap(find.text('Cadastrar empresa'));
    await tester.pump();
    expectThemedBackgrounds();
    await tester.pump(const Duration(milliseconds: 150));
    expectThemedBackgrounds();
    await tester.pumpAndSettle();
    expect(find.text('Cadastrar empresa'), findsWidgets);
    expectThemedBackgrounds();

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Entrar'), findsWidgets);
    expectThemedBackgrounds();
  });

  testWidgets('restores persisted session before showing login', (
    WidgetTester tester,
  ) async {
    final tokenStorage = _InMemoryTokenStorage()
      ..savedSession = AuthSession(
        accessToken: 'token-123',
        tokenType: 'bearer',
        expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
        company: const AuthCompanySummary(
          id: 'cmp-01',
          legalName: 'TouchIn Tecnologia LTDA',
          tradeName: 'TouchIn',
          cnpjMasked: '12.***.***/****-90',
          emailMasked: 'co*****@touchin.com',
          phoneMasked: '11*****0000',
        ),
        user: const AuthUserSummary(
          id: 'usr-01',
          email: 'super.admin@touchin.com',
          role: 'super_admin',
        ),
      );
    final api = _FakeTouchInApi(
      tokenStorage: tokenStorage,
      authContext: const AuthContext(
        company: AuthCompanySummary(
          id: 'cmp-01',
          legalName: 'TouchIn Tecnologia LTDA',
          tradeName: 'TouchIn',
          cnpjMasked: '12.***.***/****-90',
          emailMasked: 'co*****@touchin.com',
          phoneMasked: '11*****0000',
        ),
        user: AuthUserSummary(
          id: 'usr-01',
          email: 'super.admin@touchin.com',
          role: 'super_admin',
        ),
      ),
    );

    await tester.pumpWidget(
      MyApp(
        api: api,
        tokenStorage: tokenStorage,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Entrar'), findsNothing);
    expect(find.byType(Scaffold), findsWidgets);
    expect(api.authContextRequests, 1,
        reason: 'restoring a persisted session validates it on the server');
  });

  testWidgets('falls back to login when persisted session is revoked', (
    WidgetTester tester,
  ) async {
    final tokenStorage = _InMemoryTokenStorage()
      ..savedSession = AuthSession(
        accessToken: 'token-123',
        tokenType: 'bearer',
        expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
        company: const AuthCompanySummary(
          id: 'cmp-01',
          legalName: 'TouchIn Tecnologia LTDA',
          tradeName: 'TouchIn',
          cnpjMasked: '12.***.***/****-90',
          emailMasked: 'co*****@touchin.com',
          phoneMasked: '11*****0000',
        ),
        user: const AuthUserSummary(
          id: 'usr-01',
          email: 'super.admin@touchin.com',
          role: 'super_admin',
        ),
      );
    final api = _FakeTouchInApi(
      tokenStorage: tokenStorage,
      authContextError: ApiException('Sessao expirada.', statusCode: 401),
    );

    await tester.pumpWidget(
      MyApp(
        api: api,
        tokenStorage: tokenStorage,
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Entrar'), findsWidgets);
    expect(tokenStorage.savedSession, isNull);
    expect(api.authContextRequests, 1);
  });

  testWidgets('restores requested workspace route after startup', (
    WidgetTester tester,
  ) async {
    final routeUpdates = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.navigation,
      (call) async {
        if (call.method == 'routeInformationUpdated') {
          final arguments = call.arguments! as Map<dynamic, dynamic>;
          routeUpdates.add(arguments['uri']! as String);
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.navigation,
        null,
      );
    });
    tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    final tokenStorage = _InMemoryTokenStorage()
      ..savedSession = AuthSession(
        accessToken: 'token-123',
        tokenType: 'bearer',
        expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
        company: const AuthCompanySummary(
          id: 'cmp-01',
          legalName: 'TouchIn Tecnologia LTDA',
          tradeName: 'TouchIn',
          cnpjMasked: '12.***.***/****-90',
          emailMasked: 'co*****@touchin.com',
          phoneMasked: '11*****0000',
        ),
        user: const AuthUserSummary(
          id: 'usr-01',
          email: 'super.admin@touchin.com',
          role: 'super_admin',
        ),
      );
    final api = _FakeTouchInApi(
      tokenStorage: tokenStorage,
      authContext: const AuthContext(
        company: AuthCompanySummary(
          id: 'cmp-01',
          legalName: 'TouchIn Tecnologia LTDA',
          tradeName: 'TouchIn',
          cnpjMasked: '12.***.***/****-90',
          emailMasked: 'co*****@touchin.com',
          phoneMasked: '11*****0000',
        ),
        user: AuthUserSummary(
          id: 'usr-01',
          email: 'super.admin@touchin.com',
          role: 'super_admin',
        ),
      ),
    );

    await tester.pumpWidget(
      MyApp(api: api, tokenStorage: tokenStorage),
    );
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Administrar equipe'), findsOneWidget);
    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pump(const Duration(seconds: 1));
    final timeClockMenuItem = tester.widget<InkWell>(
      find
          .ancestor(
            of: find.text('Bater Ponto'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    timeClockMenuItem.onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final routeAfterNavigation =
        routeUpdates.contains('/time-clock') ? '/time-clock' : '/';
    await tester.pumpWidget(const SizedBox.shrink());
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        routeAfterNavigation;
    await tester.pumpWidget(
      MyApp(api: api, tokenStorage: tokenStorage),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Bater ponto'), findsOneWidget);
    expect(find.text('Administrar equipe'), findsNothing);
    expect(routeUpdates, contains('/time-clock'));
  });

  testWidgets('navigates after login when startup had no persisted session', (
    WidgetTester tester,
  ) async {
    final tokenStorage = _InMemoryTokenStorage();
    const company = AuthCompanySummary(
      id: 'cmp-01',
      legalName: 'TouchIn Tecnologia LTDA',
      tradeName: 'TouchIn',
      cnpjMasked: '12.***.***/****-90',
      emailMasked: 'co*****@touchin.com',
      phoneMasked: '11*****0000',
    );
    const user = AuthUserSummary(
      id: 'usr-01',
      email: 'super.admin@touchin.com',
      role: 'super_admin',
    );
    final session = AuthSession(
      accessToken: 'token-123',
      tokenType: 'bearer',
      expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
      company: company,
      user: user,
    );
    final api = _FakeTouchInApi(
      tokenStorage: tokenStorage,
      authContext: const AuthContext(company: company, user: user),
    );

    await tester.pumpWidget(
      MyApp(api: api, tokenStorage: tokenStorage),
    );
    await tester.pump();
    await tester.pump();
    expect(find.text('Entrar'), findsWidgets);

    await tokenStorage.saveAuthSession(session);
    WorkspaceRouterScope.replaceWithAuthenticated(
        tester.element(find.byType(LoginPage)), session);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Administrar equipe'), findsOneWidget);

    tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
    await tester.pump(const Duration(seconds: 1));
    final timeClockMenuItem = tester.widget<InkWell>(
      find
          .ancestor(
            of: find.text('Bater Ponto'),
            matching: find.byType(InkWell),
          )
          .first,
    );
    timeClockMenuItem.onTap!();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Bater ponto'), findsOneWidget);
    expect(find.text('Entrar'), findsNothing);
    expect(api.authContextRequests, 0,
        reason: 'login supplied a verified session for internal navigation');
  });

  testWidgets(
    'keeps requested route retryable after transient session verification failures',
    (WidgetTester tester) async {
      tester.binding.platformDispatcher.defaultRouteNameTestValue =
          '/time-clock';
      addTearDown(() {
        tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
      });
      final tokenStorage = _InMemoryTokenStorage()
        ..savedSession = AuthSession(
          accessToken: 'token-123',
          tokenType: 'bearer',
          expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
          company: const AuthCompanySummary(
            id: 'cmp-01',
            legalName: 'TouchIn Tecnologia LTDA',
            tradeName: 'TouchIn',
            cnpjMasked: '12.***.***/****-90',
            emailMasked: 'co*****@touchin.com',
            phoneMasked: '11*****0000',
          ),
          user: const AuthUserSummary(
            id: 'usr-01',
            email: 'super.admin@touchin.com',
            role: 'super_admin',
          ),
        );
      const authContext = AuthContext(
        company: AuthCompanySummary(
          id: 'cmp-01',
          legalName: 'TouchIn Tecnologia LTDA',
          tradeName: 'TouchIn',
          cnpjMasked: '12.***.***/****-90',
          emailMasked: 'co*****@touchin.com',
          phoneMasked: '11*****0000',
        ),
        user: AuthUserSummary(
          id: 'usr-01',
          email: 'super.admin@touchin.com',
          role: 'super_admin',
        ),
      );
      final api = _FakeTouchInApi(
        tokenStorage: tokenStorage,
        authContextResults: <Object>[
          ApiException('Serviço temporariamente indisponível.',
              statusCode: 503),
          SocketException('Network is unreachable'),
          authContext,
        ],
      );

      await tester.pumpWidget(
        MyApp(api: api, tokenStorage: tokenStorage),
      );
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível validar sua sessão'), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);
      expect(tokenStorage.savedSession, isNotNull);
      expect(api.authContextRequests, 1);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pumpAndSettle();

      expect(find.text('Não foi possível validar sua sessão'), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);
      expect(tokenStorage.savedSession, isNotNull);
      expect(api.authContextRequests, 2);

      await tester.tap(find.text('Tentar novamente'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Bater ponto'), findsOneWidget);
      expect(find.text('Entrar'), findsNothing);
      expect(api.authContextRequests, 3);
    },
  );
}

class _FakeTouchInApi extends TouchInApi {
  _FakeTouchInApi({
    required this.tokenStorage,
    this.authContext,
    this.authContextError,
    this.authContextResults,
    this.authContextCompleter,
    this.authContextRequestCompleters,
    this.resetConfirmCompleter,
    this.resetConfirmError,
  }) : super(tokenStorage: tokenStorage);

  final TokenStorage tokenStorage;
  final AuthContext? authContext;
  final ApiException? authContextError;
  final List<Object>? authContextResults;
  final Completer<AuthContext>? authContextCompleter;
  final Map<int, Completer<AuthContext>>? authContextRequestCompleters;
  final Completer<void>? resetConfirmCompleter;
  final ApiException? resetConfirmError;
  int authContextRequests = 0;
  int resetConfirmRequests = 0;
  final List<String> resetVerifiedTokens = <String>[];

  @override
  Future<void> confirmPasswordReset({
    required String token,
    required String newPassword,
  }) async {
    resetConfirmRequests++;
    if (resetConfirmCompleter != null) {
      await resetConfirmCompleter!.future;
    }
    if (resetConfirmError != null) throw resetConfirmError!;
  }

  @override
  Future<AuthContext> getAuthContext() async {
    authContextRequests += 1;
    final requestCompleter = authContextRequestCompleters?[authContextRequests];
    if (requestCompleter != null) {
      return await requestCompleter.future;
    }
    if (authContextCompleter != null) {
      return await authContextCompleter!.future;
    }
    final results = authContextResults;
    if (results != null && results.isNotEmpty) {
      final result = results.removeAt(0);
      if (result is AuthContext) {
        return result;
      }
      throw result;
    }
    if (authContextError != null) {
      throw authContextError!;
    }
    final context = authContext;
    if (context == null) {
      throw StateError('No auth context registered.');
    }
    return context;
  }

  @override
  Future<AuthContext> getAuthContextForToken(String token) async {
    resetVerifiedTokens.add(token);
    return getAuthContext();
  }
}

class _InMemoryTokenStorage extends TokenStorage {
  AuthSession? savedSession;

  @override
  Future<void> saveAuthSession(AuthSession session) async {
    savedSession = session;
  }

  @override
  Future<String?> readAccessToken() async {
    return savedSession?.accessToken;
  }

  @override
  Future<AuthSession?> readAuthSession() async {
    return savedSession;
  }

  @override
  Future<void> clearAccessToken() async {
    savedSession = null;
  }

  @override
  Future<void> clearSessionIfTokenMatches(String expectedToken) async {
    if (savedSession?.accessToken == expectedToken) {
      savedSession = null;
    }
  }
}
