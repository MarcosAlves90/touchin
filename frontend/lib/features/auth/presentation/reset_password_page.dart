import 'dart:async';

import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/navigation/workspace_router.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/features/auth/presentation/auth_submission_mixin.dart';
import 'package:touchin_flutter/features/auth/presentation/widgets/auth_shell.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({
    super.key,
    required this.token,
    this.api,
    this.tokenStorage,
  });
  final String token;
  final TouchInApi? api;
  final TokenStorage? tokenStorage;

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage>
    with AuthSubmissionMixin<ResetPasswordPage> {
  TouchInApi get _api => widget.api ?? TouchInApi();
  TokenStorage get _tokenStorage => widget.tokenStorage ?? TokenStorage();
  final _formKey = GlobalKey<FormState>();
  final _newPassword = TextEditingController();
  final _confirmPassword = TextEditingController();
  bool _completed = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _newPassword.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _backToLogin() async {
    final router = WorkspaceRouterScope.maybeOf(context);
    if (_completed) {
      if (router != null) {
        Router.neglect(context, () {
          if (router.verifiedSession == null) {
            router.signedOut();
          } else {
            // A new login may have taken place after this reset completed.
            router.navigate('/');
          }
        });
        return;
      }
    }
    if (router != null) {
      Router.neglect(context, () => router.navigate('/'));
    } else {
      Navigator.of(context).pushReplacementNamed('/');
    }
  }

  Future<void> _submit() async {
    if (isSubmitting || !_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    final router = WorkspaceRouterScope.maybeOf(context);
    final generation = router?.sessionGeneration;
    final currentToken = router?.verifiedSession?.accessToken ??
        await _tokenStorage.readAccessToken();
    if (!mounted) return;
    final api = _api;
    final tokenStorage = _tokenStorage;
    await submitAuthAction<void>(
      action: () async {
        await api.confirmPasswordReset(
          token: widget.token,
          newPassword: _newPassword.text,
        );
        // Revoking the authenticated router is independent of this page's
        // lifecycle: Back may dispose it while the server reset is in flight.
        if (router != null && generation != null) {
          final activeToken = router.verifiedSession?.accessToken;
          if (router.sessionGeneration == generation &&
              (activeToken == null || activeToken == currentToken)) {
            router.passwordResetConfirmed(
              expectedGeneration: generation,
              expectedToken: currentToken,
            );
          } else {
            // A login completed during the request. The server may have
            // revoked its token before returning this reset confirmation.
            // Conceal it synchronously, then consult /auth/me to determine
            // whether it was issued before or after the reset committed.
            final newer = router.verifiedSession;
            if (newer != null) {
              final checkGeneration =
                  router.beginPasswordResetVerification(newer);
              if (checkGeneration != null) {
                unawaited(_verifyConcurrentResetSession(
                  api: api,
                  tokenStorage: tokenStorage,
                  router: router,
                  session: newer,
                  generation: checkGeneration,
                ));
              }
            }
          }
        }
        if (currentToken != null) {
          TouchInApi.invalidateAuthContext(token: currentToken);
          try {
            await tokenStorage.clearSessionIfTokenMatches(currentToken);
          } catch (_) {
            // Backend reset already succeeded. Do not turn success into a
            // misleading error; the router still blocks the revoked session.
          }
        }
      },
      onSuccess: (_) => setState(() => _completed = true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      brandStep: '03',
      brandHeadline: 'Defina uma nova senha.',
      brandImageUrl: AuthBrandImages.forgotPassword,
      brandDescription:
          'Use o link recebido por e-mail para atualizar seu acesso.',
      brandTags: const ['Segurança', 'Privacidade', 'Cloud Native'],
      formPanel: AuthFormFrame(
        child: _completed ? _successPanel() : _passwordForm(),
      ),
    );
  }

  Widget _successPanel() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AuthPageHeading(title: 'Senha atualizada'),
          const SizedBox(height: 20),
          const Text(
              'Sua senha foi redefinida. Entre novamente com a nova senha.'),
          const SizedBox(height: 24),
          ElevatedButton(
              onPressed: _backToLogin, child: const Text('Ir para login')),
        ],
      );

  Widget _passwordForm() => Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthPageHeading(title: 'Redefinir senha', onBack: _backToLogin),
            const SizedBox(height: 12),
            const Text(
                'O link expira em 30 minutos e só pode ser utilizado uma vez.'),
            const SizedBox(height: 20),
            if (widget.token.length < 32)
              const Text('Link inválido ou incompleto. Solicite um novo link.'),
            _passwordInput(),
            const SizedBox(height: 12),
            _confirmInput(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  isSubmitting || widget.token.length < 32 ? null : _submit,
              child: isSubmitting
                  ? const AuthSubmissionIndicator(label: 'Redefinindo')
                  : const Text('Salvar nova senha'),
            ),
          ],
        ),
      );

  Widget _passwordInput() => TextFormField(
        controller: _newPassword,
        obscureText: !_showPassword,
        textInputAction: TextInputAction.next,
        autofillHints: const [AutofillHints.newPassword],
        decoration: InputDecoration(
          labelText: 'Nova senha',
          prefixIcon: const Icon(Icons.lock_outline_rounded),
          suffixIcon: IconButton(
            tooltip: _showPassword ? 'Ocultar senha' : 'Mostrar senha',
            icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
            onPressed: () => setState(() => _showPassword = !_showPassword),
          ),
        ),
        validator: (value) =>
            value == null || value.length < 8 || value.length > 128
                ? 'A senha deve ter de 8 a 128 caracteres.'
                : null,
      );

  Widget _confirmInput() => TextFormField(
        controller: _confirmPassword,
        obscureText: !_showPassword,
        textInputAction: TextInputAction.done,
        onFieldSubmitted: (_) => _submit(),
        autofillHints: const [AutofillHints.newPassword],
        decoration: const InputDecoration(
          labelText: 'Confirmar nova senha',
          prefixIcon: Icon(Icons.lock_outline_rounded),
        ),
        validator: (value) =>
            value != _newPassword.text ? 'As senhas não conferem.' : null,
      );
}

/// Deliberately independent of ResetPasswordPage's mounted State: the user
/// can leave the form while either reset or /auth/me is still in flight.
Future<void> _verifyConcurrentResetSession({
  required TouchInApi api,
  required TokenStorage tokenStorage,
  required WorkspaceRouter router,
  required AuthSession session,
  required int generation,
}) async {
  final token = session.accessToken;
  TouchInApi.invalidateAuthContext(token: token);
  try {
    final context = await api.getAuthContextForToken(token);
    if (!router.isCurrentPasswordResetVerification(generation, token)) return;
    TouchInApi.rememberAuthContext(token, context);
    router.acceptPasswordResetVerification(
      generation,
      session.copyWith(company: context.company, user: context.user),
    );
  } on ApiException catch (error) {
    if (!router.isCurrentPasswordResetVerification(generation, token)) return;
    // This is the response to /auth/me itself, not a resource-level 403.
    if (error.statusCode == 401 || error.statusCode == 403) {
      if (router.revokePasswordResetVerification(generation, token)) {
        try {
          await tokenStorage.clearSessionIfTokenMatches(token);
        } catch (_) {
          // The revoked session stays inaccessible even if storage fails.
        }
      }
    } else {
      router.failPasswordResetVerification(generation, token);
    }
  } catch (_) {
    router.failPasswordResetVerification(generation, token);
  }
}
