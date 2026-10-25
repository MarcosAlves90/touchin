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
  for (final entry in [
    (403, '{"detail":"This account is inactive."}', 'Esta conta está inativa.'),
    (403, '{"detail":"The company account is inactive."}', 'A conta da empresa está inativa.'),
    (403, '{"detail":"Permission denied."}', 'Você não tem permissão para acessar este recurso.'),
    (404, '{"detail":"Funcionário não encontrado."}', 'Funcionário não encontrado.'),
    (404, '{"code":"task_version_conflict","detail":"Task not found."}', 'Este card foi alterado em outra sessão. Revise a versão atual antes de salvar novamente.'),
  ]) {
    test('HTTP ${entry.$1} preserves domain JSON error ${entry.$3}', () async {
      final client = ApiClient(
        baseUrl: 'https://example.test/api/v1',
        client: MockClient((_) async => http.Response(entry.$2, entry.$1,
          headers: {'content-type': 'application/json'})),
      );
      await expectLater(client.get('/audit-events'), throwsA(isA<ApiException>()
          .having((e) => e.message, 'message', entry.$3)));
    });
  }

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

  test('proxy 404 HTML uses generic not-found fallback', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((_) async => http.Response('<html>private proxy error</html>', 404)),
    );
    await expectLater(client.get('/audit-events'), throwsA(isA<ApiException>()
        .having((e) => e.message, 'message', 'Recurso não encontrado.')
        .having((e) => e.statusCode, 'status', 404)));
  });

  test('server 503 JSON does not expose internal upstream detail', () async {
    final client = ApiClient(
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((_) async => http.Response(
        '{"detail":"internal database password"}', 503,
        headers: {'content-type': 'application/json'},
      )),
    );
    await expectLater(client.get('/audit-events'), throwsA(isA<ApiException>()
        .having((e) => e.message, 'message',
            'Serviço temporariamente indisponível. Tente novamente.')));
  });

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
