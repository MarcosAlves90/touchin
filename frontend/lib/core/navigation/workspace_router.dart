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
      : _history = <String>[_normalize(initialPath)],
        _entrySessions = <AuthSession?>[null];

  final Widget Function(BuildContext, String, AuthSession?) buildRoute;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final List<String> _history;
  // An already-mounted history page keeps its session bootstrap identity when
  // a new route becomes active; otherwise navigating triggers redundant auth.
  final List<AuthSession?> _entrySessions;
  int _currentIndex = 0;

  String get _path => _history[_currentIndex];

  @override
  String get currentConfiguration => _path;

  @override
  Future<void> setNewRoutePath(String configuration) async {
    final normalized = _normalize(configuration);
    if (_path == normalized) return;
    // Browser history moves between existing entries. Keep the forward branch
    // until a new navigation is explicitly requested by the user.
    final previous = _history.lastIndexOf(normalized, _currentIndex - 1);
    final following = _history.indexOf(normalized, _currentIndex + 1);
    if (previous >= 0) {
      _currentIndex = previous;
    } else if (following >= 0) {
      _currentIndex = following;
    } else {
      _push(normalized);
    }
    notifyListeners();
  }

  static String _normalize(String route) =>
      route.startsWith('/') && route.isNotEmpty ? route : '/';

  void navigate(String route) {
    final next = _normalize(route);
    if (_path == next) return;
    _push(next);
    notifyListeners();
  }

  void _push(String path) {
    _history.removeRange(_currentIndex + 1, _history.length);
    _entrySessions.removeRange(_currentIndex + 1, _entrySessions.length);
    _history.add(path);
    _entrySessions.add(null);
    _currentIndex++;
  }

  void _replaceHistory(String path, [AuthSession? session]) {
    _history
      ..clear()
      ..add(path);
    _entrySessions
      ..clear()
      ..add(session);
    _currentIndex = 0;
  }

  void authenticate(AuthSession session) {
    final route = buildAuthenticatedWorkspaceRoute(session).settings.name!;
    _replaceHistory(route, session);
    notifyListeners();
  }

  void signedOut() {
    _replaceHistory('/');
    notifyListeners();
  }

  void _didRemovePage(Page<Object?> page) {
    // A native Back pop removes the active page. Pages discarded when the
    // browser changes its history position must not pop a second entry.
    if (page.key != ValueKey<String>('$_currentIndex:$_path') ||
        _currentIndex == 0) {
      return;
    }
    _currentIndex--;
    notifyListeners();
  }

  @override
  Widget build(BuildContext context) {
    return Navigator(
      key: navigatorKey,
      pages: <Page<void>>[
        for (var index = 0; index <= _currentIndex; index++)
          MaterialPage<void>(
            key: ValueKey<String>('$index:${_history[index]}'),
            name: _history[index],
            child: buildRoute(
              context,
              _history[index],
              _entrySessions[index],
            ),
          ),
      ],
      onDidRemovePage: _didRemovePage,
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
      router.authenticate(session);
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
