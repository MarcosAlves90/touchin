import 'package:flutter_test/flutter_test.dart';
import 'package:touchin_flutter/contracts/audit.dart';
import 'package:touchin_flutter/features/admin/presentation/admin_audit_page_widgets.dart';

String _two(int value) => value.toString().padLeft(2, '0');

void main() {
  test('audit timestamps with UTC offset render in local time', () {
    final instant = DateTime.utc(2026, 10, 27, 22, 34, 21, 527, 917);
    final event = AuditEventResponse.fromJson(<String, dynamic>{
      'id': 'evt-utc',
      'timestamp': '2026-10-27T22:34:21.527917Z',
      'company_id': 'company-touchin',
      'actor_user_id': 'user-marina',
      'project_id': null,
      'action': 'project.created',
      'entity_type': 'project',
      'entity_id': 'project-utc',
      'result': 'success',
      'metadata_payload': null,
      'correlation_id': null,
    });

    expect(event.timestamp.isAtSameMomentAs(instant), isTrue);
    expect(event.timestamp.isUtc, isFalse);

    final local = instant.toLocal();
    expect(
      auditLocalDateTime(event.timestamp),
      '${_two(local.day)}/${_two(local.month)}/${local.year} '
      '${_two(local.hour)}:${_two(local.minute)}:${_two(local.second)}',
    );
    expect(auditUtcTimestamp(event.timestamp), '2026-10-27T22:34:21Z');
    if (local.timeZoneOffset != Duration.zero) {
      expect(auditLocalTime(event.timestamp), isNot('22:34:21'));
    }
  });
}
