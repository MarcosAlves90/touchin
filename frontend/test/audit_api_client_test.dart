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

void main() {
  test('audit URL uses /api/v1 exactly once with or without trailing slash', () async {
    for (final base in [
      'https://example.test/api/v1',
      'https://example.test/api/v1/',
    ]) {
      Uri? received;
      final api = TouchInApi(
        client: ApiClient(
          baseUrl: base,
          tokenStorage: _TokenStorage(),
          client: MockClient((request) async {
            received = request.url;
            expect(request.headers['Authorization'], 'Bearer test-token');
            return http.Response('[]', 200, headers: {'content-type': 'application/json'});
          }),
        ),
      );
      await api.listAuditEvents(page: 2, limit: 25);
      expect(received!.path, '/api/v1/audit-events');
      expect(received!.queryParameters['page'], '2');
      expect(received!.queryParameters['limit'], '25');
    }
  });

  for (final response in [
    http.Response('<html>not found</html>', 404),
    http.Response('', 503),
    http.Response('temporary upstream error', 502),
  ]) {
    test('preserves HTTP ${response.statusCode} for non-JSON or empty errors', () async {
      final client = ApiClient(
        baseUrl: 'https://example.test/api/v1',
        client: MockClient((_) async => response),
      );
      await expectLater(
        client.get('/audit-events'),
        throwsA(isA<ApiException>()
            .having((error) => error.statusCode, 'statusCode', response.statusCode)
            .having((error) => error.message, 'safe message', isNot(contains('<html>')))),
      );
    });
  }

  test('preserves 403 and hides proxy body', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((_) async => http.Response('<html>denied</html>', 403)),
    );
    await expectLater(client.get('/audit-events'), throwsA(isA<ApiException>()
        .having((error) => error.statusCode, 'statusCode', 403)
        .having((error) => error.message, 'message', contains('permissão'))));
  });
}
