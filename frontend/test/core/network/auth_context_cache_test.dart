import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';

void main() {
  test('verified auth context is reused across API instances by token',
      () async {
    final storage = _TokenStorage();
    var requests = 0;
    final client = ApiClient(
      tokenStorage: storage,
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async {
        expect(request.url.path, '/api/v1/auth/me');
        requests++;
        return http.Response(jsonEncode(_authContext), 200);
      }),
    );
    TouchInApi.invalidateAuthContext();
    addTearDown(TouchInApi.invalidateAuthContext);

    final first = TouchInApi(client: client, tokenStorage: storage);
    final second = TouchInApi(client: client, tokenStorage: storage);
    final (left, right) = await (
      first.getAuthContext(),
      second.getAuthContext(),
    ).wait;
    expect(left.user.id, 'usr-1');
    expect(right.user.id, 'usr-1');
    expect(requests, 1, reason: 'parallel auth checks share an in-flight read');

    await second.getAuthContext();
    expect(requests, 1, reason: 'navigation must reuse verified context');

    storage.token = 'different-session';
    await second.getAuthContext();
    expect(requests, 2, reason: 'a different token cannot use prior context');

    TouchInApi.invalidateAuthContext(token: 'different-session');
    await first.getAuthContext();
    expect(requests, 3, reason: 'explicit revocation checks must reach server');
  });

  test('resource 403 signals revalidation with its originating token',
      () async {
    final storage = _TokenStorage();
    String? rejectedToken;
    AuthRejectionEvents.onRejected = (token) => rejectedToken = token;
    addTearDown(() => AuthRejectionEvents.onRejected = null);
    final client = ApiClient(
      tokenStorage: storage,
      baseUrl: 'https://example.test/api/v1',
      client: MockClient((request) async => http.Response(
            jsonEncode({'detail': 'Permission denied.'}),
            403,
          )),
    );

    await expectLater(
        client.get('/projects', withAuth: true), throwsA(isA<ApiException>()));
    expect(rejectedToken, 'initial-session');
  });

  test(
      'reset verification binds auth/me to captured token despite a later login',
      () async {
    final storage = _TokenStorage();
    final bearerTokens = <String?>[];
    final api = TouchInApi(
      tokenStorage: storage,
      client: ApiClient(
        tokenStorage: storage,
        baseUrl: 'https://example.test/api/v1',
        client: MockClient((request) async {
          expect(request.url.path, '/api/v1/auth/me');
          bearerTokens.add(request.headers['Authorization']);
          return http.Response(jsonEncode(_authContext), 200);
        }),
      ),
    );
    storage.token = 'newer-login';
    final context = await api.getAuthContextForToken('login-before-reset');
    expect(context.user.id, 'usr-1');
    expect(bearerTokens, ['Bearer login-before-reset']);
  });
}

class _TokenStorage extends TokenStorage {
  String token = 'initial-session';

  @override
  Future<String?> readAccessToken() async => token;
}

const _authContext = <String, dynamic>{
  'company': {
    'id': 'cmp-1',
    'legalName': 'Empresa Teste',
    'tradeName': 'Empresa',
    'cnpjMasked': '**.***.***/****-**',
    'emailMasked': 'te***@example.test',
    'phoneMasked': '***',
  },
  'user': {
    'id': 'usr-1',
    'email': 'test@example.test',
    'role': 'admin',
    'employeeId': null,
  },
};
