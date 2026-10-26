import 'dart:async';

import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/core/navigation/workspace_router.dart';
import 'package:touchin_flutter/core/theme/theme_mode_controller.dart';
import 'package:touchin_flutter/features/auth/presentation/auth_session_navigation.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
import 'package:touchin_flutter/features/auth/presentation/reset_password_page.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_skeleton.dart';
import 'package:touchin_flutter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeModeController.instance.load();
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.api, this.tokenStorage});

  final TouchInApi? api;
  final TokenStorage? tokenStorage;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  static const _revalidationInterval = Duration(minutes: 5);
  Timer? _revalidationTimer;
  String? _scheduledSessionToken;
  Future<void>? _revalidationInFlight;
  String? _revalidatingToken;
  Future<_SessionBootstrapResult>? _bootstrapInFlight;
  bool _startupResolved = false;
  late final WorkspaceRouter _router = WorkspaceRouter(
    initialPath: WidgetsBinding.instance.platformDispatcher.defaultRouteName,
    buildRoute: (context, path, session) => _SessionGate(
      key: ValueKey<String>(path),
      routeName: path,
      initialSession: session,
      isStartup: !_startupResolved,
      onStartupResolved: _markStartupResolved,
      bootstrap: _bootstrapSession,
      revalidate: _revalidateActiveSession,
      router: _router,
    ),
  );
  final WorkspaceRouteParser _routeParser = WorkspaceRouteParser();
  TouchInApi get _api => widget.api ?? TouchInApi();

  TokenStorage get _tokenStorage => widget.tokenStorage ?? TokenStorage();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _router.addListener(_onRouterChanged);
    AuthRejectionEvents.onRejected = _onProtectedRequestRejected;
  }

  void _onRouterChanged() {
    final session = _router.verifiedSession;
    if (session == null) {
      _revalidationTimer?.cancel();
      _revalidationTimer = null;
      _scheduledSessionToken = null;
      TouchInApi.invalidateAuthContext();
      return;
    }
    if (_scheduledSessionToken == session.accessToken) return;
    _scheduleRevalidation(session);
  }

  void _scheduleRevalidation(AuthSession session) {
    _revalidationTimer?.cancel();
    _scheduledSessionToken = session.accessToken;
    final remaining = session.expiresAt.difference(DateTime.now().toUtc());
    final delay = remaining < _revalidationInterval
        ? (remaining.isNegative ? Duration.zero : remaining)
        : _revalidationInterval;
    _revalidationTimer = Timer(delay, () {
      _scheduledSessionToken = null;
      unawaited(_revalidateActiveSession());
    });
  }

  void _onProtectedRequestRejected(String token) {
    if (_router.verifiedSession?.accessToken == token) {
      unawaited(_revalidateActiveSession());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _router.verifiedSession != null) {
      unawaited(_revalidateActiveSession());
    }
  }

  Future<void> _revalidateActiveSession() {
    final token = _router.verifiedSession?.accessToken;
    final pending = _revalidationInFlight;
    if (pending != null && token == _revalidatingToken) return pending;
    final request = _performRevalidation();
    _revalidatingToken = token;
    _revalidationInFlight = request;
    request.whenComplete(() {
      if (identical(_revalidationInFlight, request)) {
        _revalidationInFlight = null;
        _revalidatingToken = null;
      }
    });
    return request;
  }

  Future<void> _performRevalidation() async {
    final session = _router.verifiedSession;
    if (session == null || _router.sessionRevoked) return;
    final generation = _router.sessionGeneration;
    final token = session.accessToken;
    _router.beginRevalidation();
    if (!session.expiresAt.isAfter(DateTime.now().toUtc())) {
      _router.revokeSession();
      await _clearRejectedSession(token);
      return;
    }
    // Every explicit validation reaches the server, even if a page reused its
    // session context. Concurrent page loads share the same in-flight read.
    TouchInApi.invalidateAuthContext(token: token);
    try {
      final context = await _api.getAuthContext();
      if (generation != _router.sessionGeneration ||
          _router.verifiedSession?.accessToken != token) {
        return;
      }
      TouchInApi.rememberAuthContext(token, context);
      _router.restoreVerifiedSession(session.copyWith(
        company: context.company,
        user: context.user,
      ));
      _scheduleRevalidation(session);
    } on ApiException catch (error) {
      if (generation != _router.sessionGeneration ||
          _router.verifiedSession?.accessToken != token) {
        return;
      }
      if (error.statusCode == 401 || error.statusCode == 403) {
        _router.revokeSession();
        await _clearRejectedSession(token);
      } else {
        _router.failRevalidation();
      }
    } catch (_) {
      if (generation == _router.sessionGeneration &&
          _router.verifiedSession?.accessToken == token) {
        _router.failRevalidation();
      }
    }
  }

  Future<void> _clearRejectedSession(String rejectedToken) async {
    try {
      await _tokenStorage.clearSessionIfTokenMatches(rejectedToken);
    } catch (_) {
      // Keep protected content inaccessible if local storage cannot be cleared.
    }
  }

  Future<_SessionBootstrapResult> _bootstrapSession() {
    return _bootstrapInFlight ??= _performBootstrap().whenComplete(() {
      _bootstrapInFlight = null;
    });
  }

  Future<_SessionBootstrapResult> _performBootstrap() async {
    final generation = _router.sessionGeneration;
    AuthSession? persistedSession;
    try {
      persistedSession = await _tokenStorage.readAuthSession();
    } catch (_) {
      return const _SessionBootstrapResult.unauthenticated();
    }

    if (persistedSession == null) {
      return const _SessionBootstrapResult.unauthenticated();
    }
    if (generation != _router.sessionGeneration || _router.sessionRevoked) {
      return const _SessionBootstrapResult.unauthenticated();
    }

    final now = DateTime.now().toUtc();
    if (!persistedSession.expiresAt.isAfter(now)) {
      try {
        if (generation == _router.sessionGeneration) {
          await _tokenStorage.clearSessionIfTokenMatches(
            persistedSession.accessToken,
          );
        }
      } catch (_) {
        // Continue to login when browser storage cannot be cleared.
      }
      return const _SessionBootstrapResult.unauthenticated();
    }

    try {
      TouchInApi.invalidateAuthContext(token: persistedSession.accessToken);
      final authContext = await _api.getAuthContext();
      if (generation != _router.sessionGeneration) {
        return const _SessionBootstrapResult.unauthenticated();
      }
      final verified = persistedSession.copyWith(
        company: authContext.company,
        user: authContext.user,
      );
      TouchInApi.rememberAuthContext(verified.accessToken, authContext);
      _router.restoreVerifiedSession(verified);
      return _SessionBootstrapResult.authenticated(verified);
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        if (generation != _router.sessionGeneration) {
          return const _SessionBootstrapResult.unauthenticated();
        }
        _router.revokeSession();
        try {
          await _tokenStorage.clearSessionIfTokenMatches(
            persistedSession.accessToken,
          );
        } catch (_) {
          // The rejected session still must not reach protected content.
        }
        return const _SessionBootstrapResult.unauthenticated();
      }
      return const _SessionBootstrapResult.unavailable();
    } catch (_) {
      return const _SessionBootstrapResult.unavailable();
    }
  }

  void _markStartupResolved() {
    if (!mounted || _startupResolved) return;
    setState(() => _startupResolved = true);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeModeController.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'TouchIn',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeModeController.instance.mode,
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('pt', 'BR')],
          locale: const Locale('pt', 'BR'),
          routerDelegate: _router,
          routeInformationParser: _routeParser,
          backButtonDispatcher: RootBackButtonDispatcher(),
          builder: (context, child) => WorkspaceRouterScope(
            router: _router,
            child: child!,
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _router.removeListener(_onRouterChanged);
    _revalidationTimer?.cancel();
    if (AuthRejectionEvents.onRejected == _onProtectedRequestRejected) {
      AuthRejectionEvents.onRejected = null;
    }
    _router.dispose();
    super.dispose();
  }
}

class _SessionGate extends StatefulWidget {
  const _SessionGate({
    super.key,
    required this.routeName,
    required this.initialSession,
    required this.isStartup,
    required this.onStartupResolved,
    required this.bootstrap,
    required this.revalidate,
    required this.router,
  });

  final String routeName;
  final AuthSession? initialSession;
  final bool isStartup;
  final VoidCallback onStartupResolved;
  final Future<_SessionBootstrapResult> Function() bootstrap;
  final Future<void> Function() revalidate;
  final WorkspaceRouter router;

  @override
  State<_SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<_SessionGate> {
  late Future<_SessionBootstrapResult> _future;

  @override
  void initState() {
    super.initState();
    _future = _resolveSession();
  }

  @override
  void didUpdateWidget(_SessionGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSession != oldWidget.initialSession) {
      _future = _resolveSession();
    }
  }

  void _redirectIfRequired(AuthSession session) {
    if (widget.routeName != '/' &&
        (!session.mustChangePassword ||
            widget.routeName == '/must-change-password')) {
      return;
    }
    final generation = widget.router.sessionGeneration;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          generation == widget.router.sessionGeneration &&
          !widget.router.sessionRevoked) {
        Router.neglect(context, () => widget.router.authenticate(session));
      }
    });
  }

  Future<_SessionBootstrapResult> _resolveSession() async {
    if (Uri.parse(widget.routeName).path == '/reset-password') {
      return const _SessionBootstrapResult.unauthenticated();
    }
    final isStartup = widget.isStartup;
    final result = widget.initialSession == null || widget.router.sessionRevoked
        ? await widget.bootstrap()
        : _SessionBootstrapResult.authenticated(widget.initialSession!);
    if (isStartup && result.status != _SessionBootstrapStatus.unavailable) {
      widget.onStartupResolved();
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (Uri.parse(widget.routeName).path == '/reset-password') {
      final token = Uri.parse(widget.routeName).queryParameters['token'] ??
          Uri.parse(Uri.base.fragment).queryParameters['token'] ??
          '';
      return ResetPasswordPage(token: token);
    }
    if (widget.router.verifyingSession) return const _StartupSplash();
    if (widget.router.verificationUnavailable) {
      return _SessionVerificationError(onRetry: widget.revalidate);
    }
    final existing = widget.initialSession;
    if (!widget.router.sessionRevoked &&
        existing != null &&
        existing.expiresAt.isAfter(DateTime.now().toUtc())) {
      _redirectIfRequired(existing);
      return _BootstrapSessionView(
          session: existing, routeName: widget.routeName);
    }
    return FutureBuilder<_SessionBootstrapResult>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return widget.isStartup
              ? const _StartupSplash()
              : const _RouteSessionSkeleton();
        }
        final result = snapshot.data;
        if (snapshot.hasError ||
            result == null ||
            result.status == _SessionBootstrapStatus.unavailable) {
          void onRetry() {
            setState(() {
              _future = _resolveSession();
            });
          }

          return widget.isStartup
              ? _SessionVerificationError(onRetry: onRetry)
              : _RouteSessionVerificationError(onRetry: onRetry);
        }
        final session = result.session;
        if (session != null) {
          _redirectIfRequired(session);
          return _BootstrapSessionView(
            session: session,
            routeName: widget.routeName,
          );
        }
        return const LoginPage();
      },
    );
  }
}

class _RouteSessionSkeleton extends StatelessWidget {
  const _RouteSessionSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return WorkspaceScaffold(
      sidebar: const WorkspaceSidebar(
        title: 'Carregando página',
        description: 'Estamos validando sua sessão para abrir este espaço.',
        summaryChildren: <Widget>[],
        highlightChips: <Widget>[],
      ),
      contentBuilder: (context, _) => WorkspaceSkeletonRegion(
        label: 'Carregando conteúdo da página',
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            key: const ValueKey<String>('route-session-skeleton'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const WorkspaceSkeleton(width: 240, height: 32),
              const SizedBox(height: 12),
              const WorkspaceSkeleton(width: 360, height: 16),
              const SizedBox(height: 28),
              for (var index = 0; index < 3; index++) ...<Widget>[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.zero,
                    border: Border.all(color: colorScheme.outlineVariant),
                  ),
                  child: Row(
                    children: <Widget>[
                      const WorkspaceSkeleton(
                        width: 44,
                        height: 44,
                        shape: WorkspaceSkeletonShape.circle,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const FractionallySizedBox(
                              widthFactor: 0.6,
                              alignment: Alignment.centerLeft,
                              child: WorkspaceSkeleton(height: 16),
                            ),
                            const SizedBox(height: 10),
                            const FractionallySizedBox(
                              widthFactor: 0.85,
                              alignment: Alignment.centerLeft,
                              child: WorkspaceSkeleton(height: 12),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RouteSessionVerificationError extends StatelessWidget {
  const _RouteSessionVerificationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return WorkspaceScaffold(
      sidebar: const WorkspaceSidebar(
        title: 'Página indisponível',
        description:
            'A navegação continua disponível enquanto você tenta de novo.',
        summaryChildren: <Widget>[],
        highlightChips: <Widget>[],
      ),
      contentBuilder: (context, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Não foi possível validar sua sessão',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Verifique sua conexão e tente novamente.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _SessionBootstrapStatus { authenticated, unauthenticated, unavailable }

class _SessionBootstrapResult {
  const _SessionBootstrapResult.authenticated(AuthSession session)
      : this._(_SessionBootstrapStatus.authenticated, session);

  const _SessionBootstrapResult.unauthenticated()
      : this._(_SessionBootstrapStatus.unauthenticated, null);

  const _SessionBootstrapResult.unavailable()
      : this._(_SessionBootstrapStatus.unavailable, null);

  const _SessionBootstrapResult._(this.status, this.session);

  final _SessionBootstrapStatus status;
  final AuthSession? session;
}

class _BootstrapSessionView extends StatelessWidget {
  const _BootstrapSessionView({required this.session, this.routeName});

  final AuthSession session;
  final String? routeName;

  @override
  Widget build(BuildContext context) {
    final route = buildAuthenticatedWorkspaceRoute(
      session,
      routeName: routeName,
    ) as MaterialPageRoute<void>;
    return route.builder(context);
  }
}

class _SessionVerificationError extends StatelessWidget {
  const _SessionVerificationError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Icon(
                  Icons.cloud_off_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(height: 16),
                Text(
                  'Não foi possível validar sua sessão',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Verifique sua conexão e tente novamente.',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: onRetry,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StartupSplash extends StatefulWidget {
  const _StartupSplash();

  @override
  State<_StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<_StartupSplash> {
  static const _statusMessages = <String>[
    'Escrevendo documentos',
    'Organizando rotinas',
    'Alinhando os planetas',
    'Preparando tudo por aqui',
  ];

  late final Timer _statusTimer;
  int _statusIndex = 0;
  int _dotCount = 0;
  int _ticks = 0;

  @override
  void initState() {
    super.initState();
    _statusTimer = Timer.periodic(const Duration(milliseconds: 500), (_) {
      setState(() {
        _ticks += 1;
        _dotCount = _ticks % 4;
        if (_ticks % 6 == 0) {
          _statusIndex = (_statusIndex + 1) % _statusMessages.length;
        }
      });
    });
  }

  @override
  void dispose() {
    _statusTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              'Aguardando o servidor',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  _statusMessages[_statusIndex],
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  '.' * _dotCount,
                  key: const ValueKey<String>('startup-status-dots'),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
