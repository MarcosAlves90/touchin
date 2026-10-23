import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
import 'package:touchin_flutter/features/auth/presentation/logout_navigation.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('browser Back restores the previous workspace screen',
      (tester) async {
    Route<void> workspaceRoute(RouteSettings settings) =>
        MaterialPageRoute<void>(
          settings: settings,
          builder: (_) => WorkspaceScaffold(
            sidebar: const SizedBox(height: 32),
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
      await tester.tap(find.text(label));
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
            sidebar: const SizedBox(height: 32),
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
      await tester.tap(find.text(label));
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
            sidebar: const SizedBox(height: 1200),
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
            sidebar: const SizedBox(height: 1200),
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
            sidebar: const SizedBox(height: 32),
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
