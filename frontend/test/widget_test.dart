import 'dart:async';
import 'dart:io';

import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/core/navigation/workspace_router.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
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

  testWidgets(
    'keeps workspace shell visible while a navigated route verifies session',
    (WidgetTester tester) async {
      final tokenStorage = _InMemoryTokenStorage()
        ..savedSession = AuthSession(
          accessToken: 'token-123',
          tokenType: 'bearer',
          expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
          company: company,
          user: user,
        );
      final routeVerification = Completer<AuthContext>();
      final api = _FakeTouchInApi(
        tokenStorage: tokenStorage,
        authContext: const AuthContext(company: company, user: user),
        authContextRequestCompleters: <int, Completer<AuthContext>>{
          2: routeVerification,
        },
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

      expect(api.authContextRequests, 2);
      expect(find.byKey(const ValueKey<String>('route-session-skeleton')),
          findsOneWidget);
      expect(find.text('Aguardando o servidor'), findsNothing);
      expect(find.byType(AdminEmployeesPage), findsNothing);
      expect(find.byType(TimeClockPage), findsNothing);
      expect(find.byTooltip('Abrir menu'), findsOneWidget);

      routeVerification
          .complete(const AuthContext(company: company, user: user));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TimeClockPage), findsOneWidget);
      expect(find.byKey(const ValueKey<String>('route-session-skeleton')),
          findsNothing);
      expect(api.authContextRequests, 2);
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
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('Não foi possível validar sua sessão'), findsOneWidget);
      expect(find.text('Aguardando o servidor'), findsNothing);
      expect(find.byTooltip('Abrir menu'), findsOneWidget);
      expect(find.byType(TimeClockPage), findsNothing);
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
        await tester.pump(const Duration(milliseconds: 500));

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
    expect(api.authContextRequests, 1);
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
          employeeId: 'emp-01',
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
          employeeId: 'emp-01',
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
      employeeId: 'emp-01',
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
    expect(api.authContextRequests, 1);
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

  group('workspace navigation lists only available destinations (#60)', () {
    const canonicalDestinations = <String>[
      'Bater Ponto',
      'Administrar Equipe',
      'Trilha de Auditoria',
      'Projetos e tarefas',
      'Kanban',
      'Configurações',
    ];
    const employeeWithProfile = AuthUserSummary(
      id: 'usr-employee',
      email: 'joao.lima@touchin.com',
      role: 'employee',
      employeeId: 'emp-04',
    );
    const employeeWithoutProfile = AuthUserSummary(
      id: 'usr-employee-unlinked',
      email: 'sem.perfil@touchin.com',
      role: 'employee',
    );
    const managerWithProfile = AuthUserSummary(
      id: 'usr-manager',
      email: 'caio.martins@touchin.com',
      role: 'manager',
      employeeId: 'emp-02',
    );
    const managerWithoutProfile = AuthUserSummary(
      id: 'usr-manager-unlinked',
      email: 'gestor.sem.perfil@touchin.com',
      role: 'manager',
    );
    const adminWithoutProfile = AuthUserSummary(
      id: 'usr-admin',
      email: 'admin@touchin.com',
      role: 'admin',
    );
    const superAdminWithoutProfile = AuthUserSummary(
      id: 'usr-super-admin',
      email: 'super.admin@touchin.com',
      role: 'super_admin',
    );
    const unrecognizedRoleWithProfile = AuthUserSummary(
      id: 'usr-unrecognized',
      email: 'auditor@touchin.com',
      role: 'auditor',
      employeeId: 'emp-09',
    );
    const employeeDestinations = <String>[
      'Bater Ponto',
      'Projetos e tarefas',
      'Kanban',
      'Configurações',
    ];
    const administratorDestinations = <String>[
      'Administrar Equipe',
      'Trilha de Auditoria',
      'Projetos e tarefas',
      'Kanban',
      'Configurações',
    ];
    final roleCases = <({
      String name,
      AuthUserSummary user,
      List<String> expected,
    })>[
      (
        name: 'employee with employee profile',
        user: employeeWithProfile,
        expected: employeeDestinations,
      ),
      (
        name: 'employee without employee profile',
        user: employeeWithoutProfile,
        expected: const <String>[
          'Projetos e tarefas',
          'Kanban',
          'Configurações'
        ],
      ),
      (
        name: 'manager with employee profile',
        user: managerWithProfile,
        expected: canonicalDestinations,
      ),
      (
        name: 'admin without employee profile',
        user: adminWithoutProfile,
        expected: administratorDestinations,
      ),
      (
        name: 'super admin without employee profile',
        user: superAdminWithoutProfile,
        expected: administratorDestinations,
      ),
      (
        name: 'role the backend does not recognize',
        user: unrecognizedRoleWithProfile,
        expected: const <String>['Configurações'],
      ),
    ];

    AuthSession sessionFor(AuthUserSummary user) => AuthSession(
          accessToken: 'token-${user.id}',
          tokenType: 'bearer',
          expiresAt: DateTime.parse('2099-04-26T18:00:00Z'),
          company: company,
          user: user,
        );

    List<String> visibleDestinations(WidgetTester tester, Finder container) {
      expect(container, findsOneWidget);
      return tester
          .widgetList<Text>(
            find.descendant(of: container, matching: find.byType(Text)),
          )
          .map((text) => text.data)
          .whereType<String>()
          .where(canonicalDestinations.contains)
          .toList();
    }

    final desktopDestinations = find.byKey(
      const ValueKey<String>('workspace-desktop-destinations'),
    );

    Future<({_FakeTouchInApi api, _InMemoryTokenStorage tokenStorage})>
        pumpWorkspace(
      WidgetTester tester,
      AuthUserSummary user, {
      String route = '/settings',
      Size size = const Size(1280, 800),
      Map<int, Completer<AuthContext>>? pendingVerifications,
    }) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.binding.platformDispatcher.defaultRouteNameTestValue = route;
      addTearDown(() {
        tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
      });
      final tokenStorage = _InMemoryTokenStorage()
        ..savedSession = sessionFor(user);
      final api = _FakeTouchInApi(
        tokenStorage: tokenStorage,
        authContext: AuthContext(company: company, user: user),
        authContextRequestCompleters: pendingVerifications,
      );
      await tester.pumpWidget(MyApp(api: api, tokenStorage: tokenStorage));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 500));
      return (api: api, tokenStorage: tokenStorage);
    }

    for (final roleCase in roleCases) {
      testWidgets(
          '${roleCase.name}: desktop sidebar lists only available '
          'destinations', (tester) async {
        await pumpWorkspace(tester, roleCase.user);

        expect(find.byType(ThemeSettingsPage), findsOneWidget);
        expect(
          visibleDestinations(tester, desktopDestinations),
          roleCase.expected,
          reason: '${roleCase.name} on the desktop sidebar',
        );
        expect(find.text('Sair do Sistema'), findsOneWidget);
      });

      testWidgets(
          '${roleCase.name}: mobile drawer lists only available '
          'destinations', (tester) async {
        await pumpWorkspace(tester, roleCase.user, size: const Size(390, 844));
        expect(find.byType(ThemeSettingsPage), findsOneWidget);
        expect(desktopDestinations, findsNothing);

        tester.state<ScaffoldState>(find.byType(Scaffold).first).openDrawer();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));

        expect(
          visibleDestinations(tester, find.byType(Drawer)),
          roleCase.expected,
          reason: '${roleCase.name} on the mobile drawer',
        );
        expect(
          find.descendant(
            of: find.byType(Drawer),
            matching: find.text('Sair do Sistema'),
          ),
          findsOneWidget,
        );
      });
    }

    testWidgets(
        'route verification skeleton keeps the verified user navigation',
        (tester) async {
      final routeVerification = Completer<AuthContext>();
      final workspace = await pumpWorkspace(
        tester,
        employeeWithProfile,
        pendingVerifications: <int, Completer<AuthContext>>{
          2: routeVerification,
        },
      );
      expect(workspace.api.authContextRequests, 1);
      expect(
        visibleDestinations(tester, desktopDestinations),
        employeeDestinations,
      );

      WorkspaceRouterScope.maybeOf(
        tester.element(find.byType(ThemeSettingsPage)),
      )!
          .navigate('/kanban');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(workspace.api.authContextRequests, 2);
      expect(find.byKey(const ValueKey<String>('route-session-skeleton')),
          findsOneWidget);
      expect(
        visibleDestinations(tester, desktopDestinations),
        employeeDestinations,
        reason: 'the skeleton must not expose administrative destinations',
      );

      routeVerification.complete(
        const AuthContext(company: company, user: employeeWithProfile),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(ProjectKanbanPage), findsOneWidget);
      expect(
        visibleDestinations(tester, desktopDestinations),
        employeeDestinations,
      );
    });

    testWidgets(
        'signing out and authenticating as another role replaces navigation',
        (tester) async {
      final workspace = await pumpWorkspace(tester, adminWithoutProfile);
      expect(
        visibleDestinations(tester, desktopDestinations),
        administratorDestinations,
      );

      final router = WorkspaceRouterScope.maybeOf(
        tester.element(find.byType(ThemeSettingsPage)),
      )!;
      router.signedOut();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.byType(LoginPage), findsOneWidget);

      final employeeSession = sessionFor(employeeWithProfile);
      await workspace.tokenStorage.saveAuthSession(employeeSession);
      WorkspaceRouterScope.replaceWithAuthenticated(
        tester.element(find.byType(LoginPage)),
        employeeSession,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(TimeClockPage), findsOneWidget);
      expect(
        visibleDestinations(tester, desktopDestinations),
        employeeDestinations,
        reason: 'no destination of the previous administrator may remain',
      );
    });

    final landingCases = <({String name, AuthUserSummary user, Type page})>[
      (
        name: 'employee without employee profile',
        user: employeeWithoutProfile,
        page: ProjectTasksPage,
      ),
      (
        name: 'employee with employee profile',
        user: employeeWithProfile,
        page: TimeClockPage,
      ),
      (
        name: 'manager without employee profile',
        user: managerWithoutProfile,
        page: AdminEmployeesPage,
      ),
      (
        name: 'admin without employee profile',
        user: adminWithoutProfile,
        page: AdminEmployeesPage,
      ),
      (
        name: 'role the backend does not recognize',
        user: unrecognizedRoleWithProfile,
        page: ThemeSettingsPage,
      ),
    ];
    for (final landingCase in landingCases) {
      testWidgets('${landingCase.name} lands on an available destination',
          (tester) async {
        await pumpWorkspace(tester, landingCase.user, route: '/');
        await tester.pump(const Duration(milliseconds: 500));

        expect(find.byType(landingCase.page), findsOneWidget);
        if (landingCase.page != AdminEmployeesPage) {
          expect(find.byType(AdminEmployeesPage), findsNothing);
        }
      });
    }
  });
}

class _FakeTouchInApi extends TouchInApi {
  _FakeTouchInApi({
    required this.tokenStorage,
    this.authContext,
    this.authContextError,
    this.authContextResults,
    this.authContextCompleter,
    this.authContextRequestCompleters,
  }) : super(tokenStorage: tokenStorage);

  final TokenStorage tokenStorage;
  final AuthContext? authContext;
  final ApiException? authContextError;
  final List<Object>? authContextResults;
  final Completer<AuthContext>? authContextCompleter;
  final Map<int, Completer<AuthContext>>? authContextRequestCompleters;
  int authContextRequests = 0;

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
