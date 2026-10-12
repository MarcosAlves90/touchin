import 'dart:async';

import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/core/theme/theme_mode_controller.dart';
import 'package:touchin_flutter/features/auth/presentation/auth_session_navigation.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
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

class _MyAppState extends State<MyApp> {
  TouchInApi get _api => widget.api ?? TouchInApi();

  TokenStorage get _tokenStorage => widget.tokenStorage ?? TokenStorage();

  Future<_SessionBootstrapResult> _bootstrapSession() async {
    AuthSession? persistedSession;
    try {
      persistedSession = await _tokenStorage.readAuthSession();
    } catch (_) {
      return const _SessionBootstrapResult.unauthenticated();
    }

    if (persistedSession == null) {
      return const _SessionBootstrapResult.unauthenticated();
    }

    final now = DateTime.now().toUtc();
    if (!persistedSession.expiresAt.isAfter(now)) {
      try {
        await _tokenStorage.clearAccessToken();
      } catch (_) {
        // Continue to login when browser storage cannot be cleared.
      }
      return const _SessionBootstrapResult.unauthenticated();
    }

    try {
      final authContext = await _api.getAuthContext();
      return _SessionBootstrapResult.authenticated(
        persistedSession.copyWith(
          company: authContext.company,
          user: authContext.user,
        ),
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        try {
          await _tokenStorage.clearAccessToken();
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

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeModeController.instance,
      builder: (context, _) {
        return MaterialApp(
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
          onGenerateRoute: _buildRoute,
          onGenerateInitialRoutes: (initialRoute) => <Route<void>>[
            _buildRoute(RouteSettings(name: initialRoute)),
          ],
        );
      },
    );
  }

  Route<void> _buildRoute(RouteSettings settings) {
    final sessionFuture = _bootstrapSession();
    return MaterialPageRoute<void>(
      settings: settings,
      builder: (context) => FutureBuilder<_SessionBootstrapResult>(
        future: sessionFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const _StartupSplash();
          }

          final result = snapshot.data;
          if (snapshot.hasError ||
              result == null ||
              result.status == _SessionBootstrapStatus.unavailable) {
            return _SessionVerificationError(
              onRetry: () {
                Navigator.of(context).pushReplacement(_buildRoute(settings));
              },
            );
          }

          final session = result.session;
          if (session != null) {
            return _BootstrapSessionView(
              session: session,
              routeName: settings.name,
            );
          }

          return const LoginPage();
        },
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
