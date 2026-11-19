import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/network/app_dependencies.dart';
import 'package:touchin_flutter/features/auth/presentation/login_page.dart';
import 'package:flutter/material.dart';
import 'package:touchin_flutter/core/navigation/workspace_router.dart';

Route<void> buildLoggedOutRoute() {
  return MaterialPageRoute<void>(
    builder: (_) => const LoginPage(),
  );
}

Future<void> logoutFromWorkspace(
  BuildContext context, {
  TouchInApi? api,
}) async {
  final dependencies = AppDependencies.maybeOf(context);
  if (dependencies?.onLogout case final onLogout?) {
    onLogout();
    return;
  }
  try {
    await (api ?? dependencies?.api ?? TouchInApi()).logout();
  } on ApiException {
    // O token local ja foi limpo; nao mantenha a sessão ativa por erro remoto.
  } catch (_) {
    // Falhas inesperadas do servidor nao devem bloquear o logout local.
  }

  if (!context.mounted) {
    return;
  }

  final router = WorkspaceRouterScope.maybeOf(context);
  if (router != null) {
    Router.neglect(context, router.signedOut);
    return;
  }

  Navigator.of(context).pushAndRemoveUntil(
    buildLoggedOutRoute(),
    (route) => false,
  );
}
