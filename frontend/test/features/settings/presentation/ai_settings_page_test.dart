import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/ai_settings.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/features/settings/presentation/ai_settings_page.dart';

class _SettingsApi extends TouchInApi {
  _SettingsApi({required this.initial});

  final CompanyAISettings initial;
  CompanyAISettingsDraft? savedDraft;
  int connectionTests = 0;

  @override
  Future<CompanyAISettings> getCompanyAISettings() async => initial;

  @override
  Future<CompanyAISettings> saveCompanyAISettings(
    CompanyAISettingsDraft draft,
  ) async {
    savedDraft = draft;
    return CompanyAISettings(
      enabled: draft.enabled,
      providerBaseUrl: draft.providerBaseUrl,
      modelId: draft.modelId,
      apiKeyConfigured: draft.apiKey != null ||
          (initial.apiKeyConfigured && !draft.removeApiKey),
      privacyAcknowledged: draft.privacyAcknowledged,
    );
  }

  @override
  Future<ProviderConnectionResult> testCompanyAIProvider({
    required String providerBaseUrl,
    required String modelId,
    String? apiKey,
  }) async {
    connectionTests += 1;
    return const ProviderConnectionResult(
      success: true,
      message: 'Conexão validada.',
    );
  }
}

Future<void> _pumpSettingsPage(
  WidgetTester tester,
  _SettingsApi api,
) async {
  tester.view.physicalSize = const Size(1365, 1100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(home: AdminAISettingsSection(api: api)),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'AI settings can be embedded without a separate workspace shell',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(1440, 1100));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final api = _SettingsApi(
        initial: const CompanyAISettings(
          enabled: false,
          providerBaseUrl: '',
          modelId: '',
          apiKeyConfigured: false,
          privacyAcknowledged: false,
        ),
      );

      await tester
          .pumpWidget(MaterialApp(home: AdminAISettingsSection(api: api)));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey<String>('workspace-desktop-destinations')),
        findsNothing,
        reason: 'AI_SETTINGS_EMBEDDED_NO_SEPARATE_WORKSPACE_SHELL',
      );
      expect(find.text('Sugestões de tarefas com IA'), findsOneWidget);
    },
  );

  testWidgets(
      'configuration is masked and enabling requires a saved acknowledgement',
      (tester) async {
    final api = _SettingsApi(
      initial: const CompanyAISettings(
        enabled: false,
        providerBaseUrl: '',
        modelId: '',
        apiKeyConfigured: true,
        privacyAcknowledged: false,
      ),
    );
    await _pumpSettingsPage(tester, api);

    expect(find.textContaining('Desativado por padrão'), findsOneWidget);
    expect(find.text('A chave armazenada nunca é exibida.'), findsOneWidget);
    expect(find.textContaining('provider-secret'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.byKey(const Key('ai-provider-key')))
          .obscureText,
      isTrue,
    );
    expect(find.textContaining('cobrança/retenção próprias'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('ai-provider-url')),
      'https://provider.example/v1',
    );
    await tester.enterText(
      find.byKey(const Key('ai-embedding-model')),
      'synthetic-embedding-model',
    );
    await tester.enterText(
      find.byKey(const Key('ai-provider-key')),
      'replacement-test-key',
    );
    await tester.tap(find.byKey(const Key('ai-recommendations-enabled')));
    await tester.pump();
    await tester
        .ensureVisible(find.byKey(const Key('ai-privacy-acknowledgement')));
    await tester.tap(find.byKey(const Key('ai-privacy-acknowledgement')));
    await tester.pump();
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(api.savedDraft, isNotNull);
    expect(api.savedDraft!.enabled, isTrue);
    expect(api.savedDraft!.privacyAcknowledged, isTrue);
    expect(api.savedDraft!.apiKey, 'replacement-test-key');
    expect(api.savedDraft!.providerBaseUrl, 'https://provider.example/v1');
    expect(find.text('Configurações salvas.'), findsOneWidget);
  });

  testWidgets('saving blank provider settings shows required fields',
      (tester) async {
    final api = _SettingsApi(
      initial: const CompanyAISettings(
        enabled: false,
        providerBaseUrl: '',
        modelId: '',
        apiKeyConfigured: false,
        privacyAcknowledged: false,
      ),
    );
    await _pumpSettingsPage(tester, api);

    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(api.savedDraft, isNull);
    expect(
      find.text('Informe a URL base do provedor e o modelo antes de salvar.'),
      findsOneWidget,
    );
  });

  testWidgets('testing blank provider settings shows required fields',
      (tester) async {
    final api = _SettingsApi(
      initial: const CompanyAISettings(
        enabled: false,
        providerBaseUrl: '',
        modelId: '',
        apiKeyConfigured: false,
        privacyAcknowledged: false,
      ),
    );
    await _pumpSettingsPage(tester, api);

    await tester.ensureVisible(find.text('Testar conexão'));
    await tester.tap(find.text('Testar conexão'));
    await tester.pumpAndSettle();

    expect(api.connectionTests, 0);
    expect(
      find.text(
        'Informe a URL base do provedor e o modelo antes de testar a conexão.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('removing a stored key also disables the feature',
      (tester) async {
    final api = _SettingsApi(
      initial: const CompanyAISettings(
        enabled: true,
        providerBaseUrl: 'https://provider.example/v1',
        modelId: 'model',
        apiKeyConfigured: true,
        privacyAcknowledged: true,
      ),
    );
    await _pumpSettingsPage(tester, api);

    await tester.ensureVisible(find.byKey(const Key('ai-remove-provider-key')));
    await tester.tap(find.byKey(const Key('ai-remove-provider-key')));
    await tester.pump();
    await tester.ensureVisible(find.text('Salvar'));
    await tester.tap(find.text('Salvar'));
    await tester.pumpAndSettle();

    expect(api.savedDraft!.removeApiKey, isTrue);
    expect(api.savedDraft!.enabled, isFalse);
  });
}
