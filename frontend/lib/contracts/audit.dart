import 'dart:typed_data';

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
    String? actorName,
    String? projectId,
    String? projectName,
    required String action,
    required String entityType,
    required String entityId,
    String? entityName,
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
      actorName: optionalString(json, 'actor_name'),
      projectId: optionalString(json, 'project_id'),
      projectName: optionalString(json, 'project_name'),
      action: requireString(json, 'action'),
      entityType: requireString(json, 'entity_type'),
      entityId: requireString(json, 'entity_id'),
      entityName: optionalString(json, 'entity_name'),
      result: requireString(json, 'result'),
      metadataPayload: optionalJsonMap(json, 'metadata_payload'),
      correlationId: optionalString(json, 'correlation_id'),
    );
  }
}

class AuditCsvExport {
  const AuditCsvExport({
    required this.filename,
    required this.bytes,
    required this.rowCount,
  });

  final String filename;
  final Uint8List bytes;
  final int? rowCount;
}
