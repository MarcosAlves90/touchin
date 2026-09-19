import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_employees_page.dart';
import 'package:touchin_flutter/features/auth/presentation/auth_submission_mixin.dart';
import 'package:touchin_flutter/features/auth/presentation/widgets/auth_shell.dart';
import 'package:flutter/material.dart';

class MustChangePasswordPage extends StatefulWidget {
  const MustChangePasswordPage({super.key});

  @override
  State<MustChangePasswordPage> createState() => _MustChangePasswordPageState();
}

class _MustChangePasswordPageState extends State<MustChangePasswordPage>
    with AuthSubmissionMixin<MustChangePasswordPage> {
  final TouchInApi _api = TouchInApi();
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    await submitAuthAction(
      action: () {
        return _api.changePassword(
          currentPassword: _currentPasswordController.text,
          newPassword: _newPasswordController.text,
        );
      },
      onSuccess: (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Senha redefinida com sucesso.'),
          ),
        );

        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => const AdminEmployeesPage(),
          ),
        );
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
      return 'As senhas nao conferem.';
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
        suffixIcon: IconButton(
          onPressed: () => onToggleObscure(!obscure),
          icon: Icon(
            obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
          ),
        ),
      ),
      validator: validator,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthShell(
      brandHeadline: 'Redefinição obrigatória de senha.',
      brandDescription:
          'Você está usando uma senha temporária. Crie uma nova senha para continuar.',
      brandTags: const [
        'E2E Encryption',
        'Seguranca',
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
            _buildPasswordField(
              controller: _currentPasswordController,
              obscure: _obscureCurrent,
              onToggleObscure: (v) => setState(() => _obscureCurrent = v),
              label: 'Senha atual (temporaria)',
              hint: 'Digite a senha recebida por e-mail',
              validator: _validatePassword,
            ),
            const SizedBox(height: 16),
            _buildPasswordField(
              controller: _newPasswordController,
              obscure: _obscureNew,
              onToggleObscure: (v) => setState(() => _obscureNew = v),
              label: 'Nova senha',
              hint: 'Minimo de 8 caracteres',
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
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Redefinir senha'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
