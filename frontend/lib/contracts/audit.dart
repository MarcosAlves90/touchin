import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:touchin_flutter/contracts/contract_parsing.dart';

part 'audit.freezed.dart';

@freezed
abstract class AuditEventResponse with _$AuditEventResponse {
  const AuditEventResponse._();

  const factory AuditEventResponse({
    required String id,
    required DateTime timestamp,
    required String companyId,
    required String? actorUserId,
    required String? projectId,
    required String action,
    required String entityType,
    required String entityId,
    required String result,
    required Map<String, dynamic>? metadataPayload,
    required String? correlationId,
  }) = _AuditEventResponse;

  factory AuditEventResponse.fromJson(Map<String, dynamic> json) {
    return AuditEventResponse(
      id: requireString(json, 'id'),
      timestamp: DateTime.parse(requireString(json, 'timestamp')).toLocal(),
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
