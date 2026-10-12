import 'dart:async';
import 'dart:io';

import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/features/auth/presentation/auth_session_navigation.dart';
import 'package:touchin_flutter/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
    unawaited(
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .pushReplacement(
            buildAuthenticatedWorkspaceRoute(session),
          ),
    );
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
}

class _FakeTouchInApi extends TouchInApi {
  _FakeTouchInApi({
    required this.tokenStorage,
    this.authContext,
    this.authContextError,
    this.authContextResults,
  }) : super(tokenStorage: tokenStorage);

  final TokenStorage tokenStorage;
  final AuthContext? authContext;
  final ApiException? authContextError;
  final List<Object>? authContextResults;
  int authContextRequests = 0;

  @override
  Future<AuthContext> getAuthContext() async {
    authContextRequests += 1;
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
}
