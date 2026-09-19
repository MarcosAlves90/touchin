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
  late final Future<AuthSession?> _bootstrapFuture = _bootstrapSession();

  TouchInApi get _api => widget.api ?? TouchInApi();

  TokenStorage get _tokenStorage => widget.tokenStorage ?? TokenStorage();

  Future<AuthSession?> _bootstrapSession() async {
    final persistedSession = await _tokenStorage.readAuthSession();
    if (persistedSession == null) {
      return null;
    }

    final now = DateTime.now().toUtc();
    if (!persistedSession.expiresAt.isAfter(now)) {
      await _tokenStorage.clearAccessToken();
      return null;
    }

    try {
      final authContext = await _api.getAuthContext();
      return persistedSession.copyWith(
        company: authContext.company,
        user: authContext.user,
      );
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        await _tokenStorage.clearAccessToken();
      }
      return null;
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
          home: FutureBuilder<AuthSession?>(
            future: _bootstrapFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const _StartupSplash();
              }

              final session = snapshot.data;
              if (session != null) {
                return _BootstrapSessionView(session: session);
              }

              return const LoginPage();
            },
          ),
        );
      },
    );
  }
}

class _BootstrapSessionView extends StatelessWidget {
  const _BootstrapSessionView({required this.session});

  final AuthSession session;

  @override
  Widget build(BuildContext context) {
    final route = buildAuthenticatedWorkspaceRoute(session)
        as MaterialPageRoute<void>;
    return route.builder(context);
  }
}

class _StartupSplash extends StatelessWidget {
  const _StartupSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
