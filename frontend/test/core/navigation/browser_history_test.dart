import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/core/navigation/workspace_router.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_page.dart';
import 'package:touchin_flutter/features/projects/presentation/project_tasks_page.dart';
import 'package:touchin_flutter/features/settings/presentation/settings_page.dart';
import 'package:touchin_flutter/main.dart';

void main() {
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

class _MemoryStorage extends TokenStorage {
  AuthSession? session;

  @override
  Future<AuthSession?> readAuthSession() async => session;

  @override
  Future<void> clearAccessToken() async => session = null;
}
