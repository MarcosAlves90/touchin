import 'package:touchin_flutter/contracts/contract_parsing.dart';

class CompanyAISettings {
  const CompanyAISettings({
    required this.enabled,
    required this.providerBaseUrl,
    required this.modelId,
    required this.apiKeyConfigured,
    required this.privacyAcknowledged,
  });

  final bool enabled;
  final String providerBaseUrl;
  final String modelId;
  final bool apiKeyConfigured;
  final bool privacyAcknowledged;

  factory CompanyAISettings.fromJson(JsonMap json) => CompanyAISettings(
        enabled: requireBool(json, 'enabled'),
        providerBaseUrl: requireString(json, 'providerBaseUrl'),
        modelId: requireString(json, 'modelId'),
        apiKeyConfigured: requireBool(json, 'apiKeyConfigured'),
        privacyAcknowledged: requireBool(json, 'privacyAcknowledged'),
      );
}

class CompanyAISettingsDraft {
  const CompanyAISettingsDraft({
    required this.enabled,
    required this.providerBaseUrl,
    required this.modelId,
    required this.privacyAcknowledged,
    this.apiKey,
    this.removeApiKey = false,
  });

  final bool enabled;
  final String providerBaseUrl;
  final String modelId;
  final bool privacyAcknowledged;
  final String? apiKey;
  final bool removeApiKey;

  JsonMap toApiJson() => <String, dynamic>{
        'enabled': enabled,
        'providerBaseUrl': providerBaseUrl.trim(),
        'modelId': modelId.trim(),
        'privacyAcknowledged': privacyAcknowledged,
        if (apiKey != null && apiKey!.trim().isNotEmpty)
          'apiKey': apiKey!.trim(),
        'removeApiKey': removeApiKey,
      };
}

class ProviderConnectionResult {
  const ProviderConnectionResult(
      {required this.success, required this.message});

  final bool success;
  final String message;

  factory ProviderConnectionResult.fromJson(JsonMap json) =>
      ProviderConnectionResult(
        success: requireBool(json, 'success'),
        message: requireString(json, 'message'),
      );
}
