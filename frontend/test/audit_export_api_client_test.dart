import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';

class _TokenStorage extends TokenStorage {
  @override
  Future<String?> readAccessToken() async => 'test-token';
}

TouchInApi buildApi(MockClient client) => TouchInApi(
  client: ApiClient(
    baseUrl: 'https://example.test/api/v1',
    tokenStorage: _TokenStorage(),
    client: client,
  ),
);

void main() {
  test(
    'audit export reuses list filters and path without pagination',
    () async {
      Uri? received;
      String? accept;
      final api = buildApi(
        MockClient((request) async {
          received = request.url;
          accept = request.headers['Accept'];
          expect(request.headers['Authorization'], 'Bearer test-token');
          return http.Response.bytes(
            Uint8List.fromList([0xEF, 0xBB, 0xBF, 0x61]),
            200,
            headers: {
              'content-type': 'text/csv; charset=utf-8',
              'content-disposition':
                  'attachment; filename="audit-events-20261020T120000Z.csv"',
              'x-audit-export-rows': '130',
            },
          );
        }),
      );

      final export = await api.exportAuditEvents(
        startDate: DateTime(2026, 3, 8),
        endDate: DateTime(2026, 3, 9),
        actorUserId: 'user-1',
        action: 'card.moved',
        entityType: 'card',
        entityId: 'card-1',
        projectId: 'proj-1',
        result: 'success',
      );

      expect(received!.path, '/api/v1/audit-events/export');
      expect(received!.queryParameters, {
        'start_date': '2026-03-08T00:00:00.000Z',
        'end_date': '2026-03-10T00:00:00.000Z',
        'actor_user_id': 'user-1',
        'action': 'card.moved',
        'entity_type': 'card',
        'entity_id': 'card-1',
        'project_id': 'proj-1',
        'result': 'success',
      });
      expect(received!.queryParameters.containsKey('page'), isFalse);
      expect(received!.queryParameters.containsKey('limit'), isFalse);
      expect(accept, 'text/csv');
      expect(export.filename, 'audit-events-20261020T120000Z.csv');
      expect(export.rowCount, 130);
      expect(export.bytes, [0xEF, 0xBB, 0xBF, 0x61]);
    },
  );

  test(
    'audit export falls back to a safe filename and unknown row count',
    () async {
      final api = buildApi(
        MockClient(
          (_) async => http.Response(
            'timestamp_utc\r\n',
            200,
            headers: {'content-type': 'text/csv'},
          ),
        ),
      );

      final export = await api.exportAuditEvents();

      expect(export.filename, 'audit-events.csv');
      expect(export.rowCount, isNull);
    },
  );

  test(
    'audit export strips path separators from the server filename',
    () async {
      final api = buildApi(
        MockClient(
          (_) async => http.Response(
            'timestamp_utc\r\n',
            200,
            headers: {
              'content-disposition':
                  'attachment; filename="../../private/audit.csv"',
            },
          ),
        ),
      );

      final export = await api.exportAuditEvents();

      expect(export.filename, 'audit.csv');
    },
  );

  test(
    'audit export surfaces permission errors without returning bytes',
    () async {
      final api = buildApi(
        MockClient(
          (_) async => http.Response(
            '{"detail":"Permission denied."}',
            403,
            headers: {'content-type': 'application/json'},
          ),
        ),
      );

      await expectLater(
        api.exportAuditEvents(),
        throwsA(
          isA<ApiException>()
              .having((error) => error.statusCode, 'statusCode', 403)
              .having(
                (error) => error.message,
                'message',
                'Você não tem permissão para acessar este recurso.',
              ),
        ),
      );
    },
  );
}
