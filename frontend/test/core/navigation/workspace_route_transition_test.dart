import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/core/navigation/workspace_router.dart';

void main() {
  testWidgets(
    'workspace route transitions are zero after the first workspace route',
    (tester) async {
      final router = WorkspaceRouter(
        initialPath: '/time-clock',
        buildRoute: (_, path, __) => Scaffold(
          body: Center(child: Text(path)),
        ),
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

      expect(find.text('/time-clock'), findsOneWidget);
      router.navigate('/projects');
      await tester.pump();
      await tester.pumpAndSettle();
      expect(find.text('/projects'), findsOneWidget);
      final destination = ModalRoute.of(tester.element(find.text('/projects')))!;
      expect(
        destination.transitionDuration,
        Duration.zero,
        reason: 'workspace_route_transition_missing',
      );
      expect(destination.animation!.value, 1);
      expect(find.text('/time-clock'), findsNothing);
    },
  );
}
