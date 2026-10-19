import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/features/auth/presentation/auth_session_navigation.dart';

/// Route information is owned by Router, so the browser retains its forward
/// entry when the user goes back to a previously visited workspace.
class WorkspaceRouteParser extends RouteInformationParser<String> {
  @override
  Future<String> parseRouteInformation(
      RouteInformation routeInformation) async {
    final path = routeInformation.uri.path;
    return path.startsWith('/') && path.isNotEmpty ? path : '/';
  }

  @override
  RouteInformation restoreRouteInformation(String configuration) {
    return RouteInformation(uri: Uri(path: configuration));
  }
}

class WorkspaceRouter extends RouterDelegate<String>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<String> {
  WorkspaceRouter({required this.buildRoute, String initialPath = '/'})
      : _path = _normalize(initialPath);

  final Widget Function(BuildContext, String, AuthSession?) buildRoute;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  String _path;
  AuthSession? _newSession;

  @override
  String get currentConfiguration => _path;

  @override
  Future<void> setNewRoutePath(String configuration) async {
    final normalized = _normalize(configuration);
    if (_path == normalized && _newSession == null) return;
    _path = normalized;
    _newSession = null;
    notifyListeners();
  }

  static String _normalize(String route) =>
      route.startsWith('/') && route.isNotEmpty ? route : '/';

  void navigate(String route) {
    final next = _normalize(route);
    if (_path == next) return;
    _path = next;
    _newSession = null;
    notifyListeners();
  }

  void authenticate(AuthSession session) {
    final route = buildAuthenticatedWorkspaceRoute(session).settings.name!;
    _newSession = session;
    _path = route;
    notifyListeners();
  }

  void signedOut() {
    _newSession = null;
    _path = '/';
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: <Page<void>>[
        MaterialPage<void>(
          key: ValueKey<String>(_path),
          name: _path,
          child: buildRoute(context, _path, _newSession),
        ),
      ],
      onDidRemovePage: (page) {},
    );
  }
}

/// Keeps standalone widget tests using MaterialApp/Navigator compatible while
/// the production app uses a Router-owned browser history.
class WorkspaceRouterScope extends InheritedWidget {
  const WorkspaceRouterScope({
    super.key,
    required this.router,
    required super.child,
  });

  final WorkspaceRouter router;

  static WorkspaceRouter? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<WorkspaceRouterScope>()
      ?.router;

  static void replaceWithAuthenticated(
      BuildContext context, AuthSession session) {
    final router = maybeOf(context);
    if (router != null) {
      Router.neglect(context, () => router.authenticate(session));
    } else {
      Navigator.of(context).pushReplacement(
        buildAuthenticatedWorkspaceRoute(session),
      );
    }
  }

  @override
  bool updateShouldNotify(WorkspaceRouterScope oldWidget) =>
      router != oldWidget.router;
}
