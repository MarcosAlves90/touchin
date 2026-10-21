import 'dart:math';

import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/features/auth/presentation/auth_session_navigation.dart';

/// Route information is owned by Router, so the browser retains its forward
/// entry when the user goes back to a previously visited workspace.
class WorkspaceLocation {
  const WorkspaceLocation(this.path, [this.entryId]);

  final String path;
  final String? entryId;

  @override
  bool operator ==(Object other) =>
      other is WorkspaceLocation &&
      other.path == path &&
      other.entryId == entryId;

  @override
  int get hashCode => Object.hash(path, entryId);
}

class WorkspaceRouteParser extends RouteInformationParser<WorkspaceLocation> {
  @override
  Future<WorkspaceLocation> parseRouteInformation(
      RouteInformation routeInformation) async {
    final path = routeInformation.uri.path;
    return WorkspaceLocation(
      path.startsWith('/') && path.isNotEmpty ? path : '/',
      routeInformation.state is String
          ? routeInformation.state! as String
          : null,
    );
  }

  @override
  RouteInformation restoreRouteInformation(WorkspaceLocation configuration) {
    return RouteInformation(
      uri: Uri(path: configuration.path),
      state: configuration.entryId,
    );
  }
}

class WorkspaceRouter extends RouterDelegate<WorkspaceLocation>
    with ChangeNotifier, PopNavigatorRouterDelegateMixin<WorkspaceLocation> {
  WorkspaceRouter({required this.buildRoute, String initialPath = '/'})
      : _history = <String>[_normalize(initialPath)],
        _entryIds = <String>[],
        _entrySessions = <AuthSession?>[null] {
    _entryIds.add(_newEntryId());
  }

  final Widget Function(BuildContext, String, AuthSession?) buildRoute;

  @override
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  final List<String> _history;
  final List<String> _entryIds;
  final String _entryNamespace = _newEntryNamespace();
  int _nextEntryId = 1;
  bool _initialRouteReceived = false;
  // An already-mounted history page keeps its session bootstrap identity when
  // a new route becomes active; otherwise navigating triggers redundant auth.
  final List<AuthSession?> _entrySessions;
  int _currentIndex = 0;
  int _sessionGeneration = 0;
  bool _sessionRevoked = false;
  int get sessionGeneration => _sessionGeneration;
  bool get sessionRevoked => _sessionRevoked;

  String get _path => _history[_currentIndex];

  @override
  WorkspaceLocation get currentConfiguration =>
      WorkspaceLocation(_path, _entryIds[_currentIndex]);

  @override
  Future<void> setNewRoutePath(WorkspaceLocation configuration) async {
    final normalized = _normalize(configuration.path);
    final id = configuration.entryId;
    if (!_initialRouteReceived) {
      _initialRouteReceived = true;
      if (id != null && _history.length == 1) {
        // The browser owns this initial entry after a reload. Adopt its ID
        // instead of inserting the same page again into Navigator's stack.
        _history[0] = normalized;
        _entryIds[0] = id;
        notifyListeners();
        return;
      }
    }
    if (id != null) {
      final match = _entryIds.indexOf(id);
      if (match >= 0) {
        if (match == _currentIndex) return;
        _currentIndex = match;
        notifyListeners();
        return;
      }
    }
    if (_path == normalized && id == null) return;
    // Browser history moves between existing entries. Keep the forward branch
    // until a new navigation is explicitly requested by the user.
    final previous = _history.lastIndexOf(normalized, _currentIndex - 1);
    final following = _history.indexOf(normalized, _currentIndex + 1);
    if (id != null) {
      _push(normalized, entryId: id);
    } else if (previous >= 0) {
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

  static String _newEntryNamespace() {
    final random = Random.secure();
    return List<String>.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  String _newEntryId() {
    String id;
    do {
      id = 'entry-$_entryNamespace-${_nextEntryId++}';
    } while (_entryIds.contains(id));
    return id;
  }

  void navigate(String route) {
    final next = _normalize(route);
    if (_path == next) return;
    _push(next);
    notifyListeners();
  }

  void _push(String path, {String? entryId}) {
    _history.removeRange(_currentIndex + 1, _history.length);
    _entryIds.removeRange(_currentIndex + 1, _entryIds.length);
    _entrySessions.removeRange(_currentIndex + 1, _entrySessions.length);
    _history.add(path);
    _entryIds.add(entryId ?? _newEntryId());
    _entrySessions.add(null);
    _currentIndex++;
  }

  void _replaceHistory(String path, [AuthSession? session]) {
    _history
      ..clear()
      ..add(path);
    _entryIds
      ..clear()
      ..add(_newEntryId());
    _entrySessions
      ..clear()
      ..add(session);
    _currentIndex = 0;
  }

  void authenticate(AuthSession session) {
    _sessionRevoked = false;
    _sessionGeneration++;
    final route = buildAuthenticatedWorkspaceRoute(session).settings.name!;
    _replaceHistory(route, session);
    notifyListeners();
  }

  void signedOut() {
    _sessionGeneration++;
    _sessionRevoked = true;
    _replaceHistory('/');
    notifyListeners();
  }

  void revokeSession() {
    if (_sessionRevoked) return;
    signedOut();
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
