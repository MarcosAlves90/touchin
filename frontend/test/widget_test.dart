import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/main.dart';
import 'package:flutter/material.dart';
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
}

class _FakeTouchInApi extends TouchInApi {
  _FakeTouchInApi({
    required this.tokenStorage,
    this.authContext,
    this.authContextError,
  }) : super(tokenStorage: tokenStorage);

  final TokenStorage tokenStorage;
  final AuthContext? authContext;
  final ApiException? authContextError;
  int authContextRequests = 0;

  @override
  Future<AuthContext> getAuthContext() async {
    authContextRequests += 1;
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
