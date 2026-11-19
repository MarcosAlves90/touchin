import 'dart:async';

import 'package:flutter/material.dart';
import 'package:touchin_flutter/contracts/ai_settings.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_shell.dart';
import 'package:touchin_flutter/features/shared/presentation/widgets/workspace_skeleton.dart';

class AdminAISettingsSection extends StatefulWidget {
  const AdminAISettingsSection({super.key, this.api});

  final TouchInApi? api;

  @override
  State<AdminAISettingsSection> createState() => _AdminAISettingsSectionState();
}

class _AdminAISettingsSectionState extends State<AdminAISettingsSection> {
  late final TouchInApi _api = widget.api ?? TouchInApi();
  final _urlController = TextEditingController();
  final _modelController = TextEditingController();
  final _keyController = TextEditingController();
  bool _enabled = false;
  bool _privacyAcknowledged = false;
  bool _removeKey = false;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _keyConfigured = false;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _urlController.dispose();
    _modelController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final settings = await _api.getCompanyAISettings();
      if (!mounted) return;
      setState(() {
        _urlController.text = settings.providerBaseUrl;
        _modelController.text = settings.modelId;
        _enabled = settings.enabled;
        _privacyAcknowledged = settings.privacyAcknowledged;
        _keyConfigured = settings.apiKeyConfigured;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = 'Não foi possível carregar as configurações da empresa.';
        _messageIsError = true;
      });
    }
  }

  String? _providerValidationMessage({required String action}) {
    if (_urlController.text.trim().isEmpty ||
        _modelController.text.trim().isEmpty) {
      return 'Informe a URL base do provedor e o modelo antes de $action.';
    }
    return null;
  }

  Future<void> _testConnection() async {
    final validationMessage =
        _providerValidationMessage(action: 'testar a conexão');
    if (validationMessage != null) {
      setState(() {
        _message = validationMessage;
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _testing = true;
      _message = null;
      _messageIsError = false;
    });
    try {
      final result = await _api.testCompanyAIProvider(
        providerBaseUrl: _urlController.text,
        modelId: _modelController.text,
        apiKey: _keyController.text,
      );
      if (!mounted) return;
      setState(() {
        _message = result.message;
        _messageIsError = !result.success;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'Não foi possível validar a conexão. Revise os dados e tente novamente.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final validationMessage = _providerValidationMessage(action: 'salvar');
    if (validationMessage != null) {
      setState(() {
        _message = validationMessage;
        _messageIsError = true;
      });
      return;
    }

    setState(() {
      _saving = true;
      _message = null;
      _messageIsError = false;
    });
    try {
      final saved = await _api.saveCompanyAISettings(
        CompanyAISettingsDraft(
          enabled: _enabled && !_removeKey,
          providerBaseUrl: _urlController.text,
          modelId: _modelController.text,
          privacyAcknowledged: _privacyAcknowledged,
          apiKey: _keyController.text,
          removeApiKey: _removeKey,
        ),
      );
      if (!mounted) return;
      setState(() {
        _enabled = saved.enabled;
        _keyConfigured = saved.apiKeyConfigured;
        _privacyAcknowledged = saved.privacyAcknowledged;
        _keyController.clear();
        _removeKey = false;
        _message = 'Configurações salvas.';
        _messageIsError = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'Não foi possível salvar. Verifique os dados e a confirmação de privacidade.';
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildContent(context);
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            'Sugestões de tarefas com IA',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Configure um provedor de embeddings compatível com a API OpenAI para sugerir tarefas relacionadas ao registro de atividades.',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: colors.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        if (_loading)
          const WorkspaceSkeletonRegion(
            label: 'Carregando configurações',
            child: WorkspaceSkeletonPanel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  WorkspaceSkeleton.line(width: 200, height: 24),
                  SizedBox(height: 16),
                  WorkspaceSkeleton.line(height: 12),
                  SizedBox(height: 16),
                  WorkspaceSkeleton.line(height: 48),
                  SizedBox(height: 12),
                  WorkspaceSkeleton.line(height: 48),
                  SizedBox(height: 12),
                  WorkspaceSkeleton.line(height: 48),
                ],
              ),
            ),
          )
        else
          WorkspaceSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Configuração da empresa',
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Desativado por padrão. Use um endpoint HTTPS público na porta 443 que implemente POST /v1/embeddings.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const Key('ai-provider-url'),
                  controller: _urlController,
                  keyboardType: TextInputType.url,
                  decoration: const InputDecoration(
                    labelText: 'URL base do provedor',
                    hintText: 'https://api.exemplo.com/v1',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('ai-embedding-model'),
                  controller: _modelController,
                  decoration: const InputDecoration(
                    labelText: 'Modelo de embeddings',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  key: const Key('ai-provider-key'),
                  controller: _keyController,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: _keyConfigured
                        ? 'Nova chave (vazio mantém a atual)'
                        : 'Chave da API',
                    helperText: _keyConfigured
                        ? 'A chave armazenada nunca é exibida.'
                        : 'Armazenada criptografada no servidor.',
                  ),
                ),
                if (_keyConfigured)
                  CheckboxListTile(
                    key: const Key('ai-remove-provider-key'),
                    contentPadding: EdgeInsets.zero,
                    value: _removeKey,
                    title: const Text('Remover a chave armazenada'),
                    onChanged: (value) => setState(() {
                      _removeKey = value ?? false;
                      if (_removeKey) _enabled = false;
                    }),
                  ),
                SwitchListTile(
                  key: const Key('ai-recommendations-enabled'),
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  title: const Text('Ativar sugestões para esta empresa'),
                  subtitle: const Text(
                      'Desativar impede novas chamadas ao provedor.'),
                  onChanged: (value) => setState(() => _enabled = value),
                ),
                CheckboxListTile(
                  key: const Key('ai-privacy-acknowledgement'),
                  contentPadding: EdgeInsets.zero,
                  value: _privacyAcknowledged,
                  onChanged: (value) =>
                      setState(() => _privacyAcknowledged = value ?? false),
                  title: const Text('Confirmo o compartilhamento de dados'),
                  subtitle: const Text(
                    'Quando habilitada, a descrição do trabalho e nomes/descrições das tarefas do projeto selecionado serão enviados ao provedor configurado para calcular similaridade. Não envie senhas, dados pessoais ou informações sensíveis. O provedor pode processar dados fora do TouchIn e aplicar cobrança/retenção próprias.',
                  ),
                ),
                const SizedBox(height: 12),
                if (_message != null) ...[
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _message!,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: _messageIsError ? colors.error : colors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  alignment: WrapAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loading || _saving || _testing
                          ? null
                          : _testConnection,
                      icon: const Icon(Icons.wifi_tethering),
                      label: Text(
                          _testing ? 'Testando conexão…' : 'Testar conexão'),
                    ),
                    FilledButton.icon(
                      onPressed: _loading || _saving || _testing ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: Text(_saving ? 'Salvando…' : 'Salvar'),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }
}
