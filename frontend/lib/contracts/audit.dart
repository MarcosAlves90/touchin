import 'package:freezed_annotation/freezed_annotation.dart';

import 'contract_parsing.dart';

part 'audit.freezed.dart';

@freezed
abstract class AuditEventResponse with _$AuditEventResponse {
  const AuditEventResponse._();
  const factory AuditEventResponse({
    required String id,
    required DateTime timestamp,
    required String companyId,
    String? actorUserId,
    String? projectId,
    required String action,
    required String entityType,
    required String entityId,
    required String result,
    Map<String, dynamic>? metadataPayload,
    String? correlationId,
  }) = _AuditEventResponse;

  factory AuditEventResponse.fromJson(Map<String, dynamic> json) {
    return AuditEventResponse(
      id: requireString(json, 'id'),
      timestamp: requireDateTime(json, 'timestamp'),
      companyId: requireString(json, 'company_id'),
      actorUserId: optionalString(json, 'actor_user_id'),
      projectId: optionalString(json, 'project_id'),
      action: requireString(json, 'action'),
      entityType: requireString(json, 'entity_type'),
      entityId: requireString(json, 'entity_id'),
      result: requireString(json, 'result'),
      metadataPayload: optionalJsonMap(json, 'metadata_payload'),
      correlationId: optionalString(json, 'correlation_id'),
    );
  }
}
