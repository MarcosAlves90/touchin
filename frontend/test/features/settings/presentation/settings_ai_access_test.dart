import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/navigation/workspace_destinations.dart';
import 'package:touchin_flutter/features/auth/presentation/auth_session_navigation.dart';

void main() {
  testWidgets('AI settings section is available only to company admins',
      (tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final scenario in <(String, bool)>[
      ('admin', true),
      ('super_admin', true),
      ('manager', false),
      ('employee', false),
    ]) {
      final route = buildAuthenticatedWorkspaceRoute(
        _session(scenario.$1),
        routeName: '/settings',
      ) as MaterialPageRoute<void>;

      await tester.pumpWidget(
        MaterialApp(home: Builder(builder: route.builder)),
      );
      await tester.pump();

      expect(
        find.text('Sugestões de tarefas com IA'),
        scenario.$2 ? findsOneWidget : findsNothing,
        reason:
            'AI_SETTINGS_SECTION_VISIBLE_ONLY_WITH_COMPANIES_MANAGE_${scenario.$1}',
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  test('legacy AI settings route redirects admins to general settings', () {
    final route = buildAuthenticatedWorkspaceRoute(
      _session('admin'),
      routeName: '/admin/ai-settings',
    ) as MaterialPageRoute<void>;

    expect(
      route.settings.name,
      '/settings',
      reason: 'LEGACY_AI_SETTINGS_ROUTE_REDIRECTS_TO_SETTINGS',
    );
  });

  test('legacy AI settings route is unavailable to non-admin roles', () {
    for (final role in <String>['manager', 'employee']) {
      final route = buildAuthenticatedWorkspaceRoute(
        _session(role),
        routeName: '/admin/ai-settings',
      ) as MaterialPageRoute<void>;

      expect(route.settings.name, '/time-clock');
    }
  });

  test('AI settings is not a separate workspace destination', () {
    expect(
      workspaceDestinations.any(
        (destination) => destination.route == '/admin/ai-settings',
      ),
      isFalse,
      reason: 'AI_SETTINGS_IS_NOT_A_SEPARATE_WORKSPACE_DESTINATION',
    );
    expect(
      workspaceDestinations
          .any((destination) => destination.route == '/settings'),
      isTrue,
    );
  });
}

AuthSession _session(String role) {
  final employeeId =
      role == 'employee' || role == 'manager' ? 'emp-$role' : null;
  return AuthSession(
    accessToken: 'token-$role',
    tokenType: 'bearer',
    expiresAt: DateTime.utc(2027),
    company: const AuthCompanySummary(
      id: 'cmp-01',
      legalName: 'TouchIn Tecnologia LTDA',
      tradeName: 'TouchIn',
      cnpjMasked: '12.***.***/****-90',
      emailMasked: 'co*****@touchin.com',
      phoneMasked: '11*****0000',
    ),
    user: AuthUserSummary(
      id: 'usr-$role',
      email: '$role@touchin.com',
      role: role,
      employeeId: employeeId,
    ),
  );
}
