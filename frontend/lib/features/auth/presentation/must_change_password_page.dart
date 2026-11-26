import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/navigation/workspace_router.dart';
import 'package:touchin_flutter/features/auth/presentation/auth_submission_mixin.dart';
import 'package:touchin_flutter/features/auth/presentation/widgets/auth_shell.dart';
import 'package:touchin_flutter/features/auth/presentation/logout_navigation.dart';
import 'package:flutter/material.dart';

class MustChangePasswordPage extends StatefulWidget {
  const MustChangePasswordPage({super.key, this.api});

  final TouchInApi? api;

  @override
  State<MustChangePasswordPage> createState() => _MustChangePasswordPageState();
}

class _MustChangePasswordPageState extends State<MustChangePasswordPage>
    with AuthSubmissionMixin<MustChangePasswordPage> {
  TouchInApi get _api => widget.api ?? TouchInApi();
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  bool _hasValidationErrors = false;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (isSubmitting) return;
    FocusScope.of(context).unfocus();

    final valid = _formKey.currentState!.validate();
    setState(() => _hasValidationErrors = !valid);
    if (!valid) {
      return;
    }

    // A previous error must not follow us to login, even when revalidation
    // signs out before the password-change response reaches this page.
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..removeCurrentSnackBar();
    final api = _api;
    final currentPassword = _currentPasswordController.text;
    final newPassword = _newPasswordController.text;
    final router = WorkspaceRouterScope.maybeOf(context);

    await submitAuthAction(
      action: () {
        Future<void> request([String? token]) => api.changePassword(
              currentPassword: currentPassword,
              newPassword: newPassword,
              sessionToken: token,
            );
        if (router == null) return request();
        return router.completeRequiredPasswordChange(
          request: request,
          clearCredentials: (token) =>
              api.clearLocalSession(expectedToken: token),
        );
      },
      onSuccess: (_) {
        if (router == null) {
          logoutFromWorkspace(context, api: api, requiredPasswordChanged: true);
        }
      },
      genericErrorMessage: 'Não foi possível redefinir sua senha.',
    );
  }

  static String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Informe uma nova senha.';
    }
    if (value.length < 8) {
      return 'A senha precisa ter ao menos 8 caracteres.';
    }
    return null;
  }

  String? _validateConfirm(String? value) {
    if (value == null || value.isEmpty) {
      return 'Confirme a nova senha.';
    }
    if (value != _newPasswordController.text) {
      return 'As senhas não conferem.';
    }
    return null;
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required bool obscure,
    required ValueChanged<bool> onToggleObscure,
    required String label,
    required String hint,
    required String? Function(String?)? validator,
    TextInputAction textInputAction = TextInputAction.next,
    VoidCallback? onFieldSubmitted,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      textInputAction: textInputAction,
      onFieldSubmitted:
          onFieldSubmitted != null ? (_) => onFieldSubmitted() : null,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: const Icon(Icons.lock_outline_rounded),
        suffixIcon: AuthPasswordVisibilityButton(
          fieldName: label.toLowerCase(),
          isObscured: obscure,
          onPressed: () => onToggleObscure(!obscure),
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      brandStep: '04',
      brandHeadline: 'Redefinição obrigatória de senha.',
      brandImageUrl: AuthBrandImages.changePassword,
      brandDescription:
          'Você está usando uma senha temporária. Crie uma nova senha para continuar.',
      brandTags: const [
        'E2E Encryption',
        'Segurança',
        'Cloud Native',
      ],
      formPanel: _buildFormPanel(context),
    );
  }

  Widget _buildFormPanel(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AuthFormFrame(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AuthPageHeading(title: 'Criar nova senha'),
            const SizedBox(height: 10),
            Text(
              'Defina uma senha forte e exclusiva para proteger sua conta.',
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            if (_hasValidationErrors) const AuthFormValidationMessage(),
            _buildPasswordField(
              controller: _currentPasswordController,
              obscure: _obscureCurrent,
              onToggleObscure: (v) => setState(() => _obscureCurrent = v),
              label: 'Senha atual (temporária)',
              hint: 'Digite a senha recebida por e-mail',
              validator: _validatePassword,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _newPasswordController,
              obscure: _obscureNew,
              onToggleObscure: (v) => setState(() => _obscureNew = v),
              label: 'Nova senha',
              hint: 'Mínimo de 8 caracteres',
              validator: _validatePassword,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _confirmPasswordController,
              obscure: _obscureConfirm,
              onToggleObscure: (v) => setState(() => _obscureConfirm = v),
              label: 'Confirmar nova senha',
              hint: 'Repita a nova senha',
              validator: _validateConfirm,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: _submit,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isSubmitting
                    ? null
                    : () {
                        _submit();
                      },
                child: isSubmitting
                    ? const AuthSubmissionIndicator(label: 'Redefinindo senha')
                    : const Text('Redefinir senha'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
