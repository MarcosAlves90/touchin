import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/core/navigation/workspace_router.dart';
import 'package:touchin_flutter/main.dart';

void main() {
  testWidgets('browser router supports bidirectional history', (tester) async {
    tester.binding.platformDispatcher.defaultRouteNameTestValue =
        '/admin/employees';
    addTearDown(() {
      tester.binding.platformDispatcher.defaultRouteNameTestValue = '/';
    });
    final storage = _MemoryStorage()
      ..session = AuthSession(
        accessToken: 'test',
        tokenType: 'bearer',
        expiresAt: DateTime.utc(2099),
        company: _company,
        user: _user,
      );
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
    expect(router.currentConfiguration, '/projects');

    // Popstate-style route updates must restore the content associated with
    // the browser URL without accidentally pushing another history entry.
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        const MethodCall('pushRouteInformation', {
          'location': '/admin/employees',
        }),
      ),
      (_) {},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.currentConfiguration, '/admin/employees');
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      'flutter/navigation',
      const JSONMethodCodec().encodeMethodCall(
        const MethodCall('pushRouteInformation', {
          'location': '/projects',
        }),
      ),
      (_) {},
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));
    expect(router.currentConfiguration, '/projects');
  });
}

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

class _MemoryStorage extends TokenStorage {
  AuthSession? session;

  @override
  Future<AuthSession?> readAuthSession() async => session;

  @override
  Future<void> clearAccessToken() async => session = null;
}
