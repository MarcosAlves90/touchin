import 'dart:async';

import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/employee.dart';
import 'package:touchin_flutter/contracts/location.dart';
import 'package:touchin_flutter/contracts/punch.dart';
import 'package:touchin_flutter/contracts/time_clock.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

const _validCredentialFixture = 'fixture-auth-value';
const _invalidCredentialFixture = 'invalid-auth-value';

void main() {
  test('login posts credentials contract and stores session token', () async {
    final client = _FakeApiClient(
      postResponses: {
        '/auth/login': _authSessionResponse(),
      },
    );
    final tokenStorage = _InMemoryTokenStorage();
    final api = TouchInApi(client: client, tokenStorage: tokenStorage);

    final session = await api.login(
      credentials: const LoginCredentials(
        email: 'marina.costa@touchin.com',
        password: _validCredentialFixture,
        keepConnected: true,
      ),
    );

    expect(session.accessToken, 'token-123');
    expect(session.user.isAdmin, isTrue);
    expect(tokenStorage.savedToken, 'token-123');
    expect(tokenStorage.savedSession?.user.email, 'marina.costa@touchin.com');
    expect(client.lastPath, '/auth/login');
    expect(client.lastBody, <String, dynamic>{
      'email': 'marina.costa@touchin.com',
      'password': _validCredentialFixture,
      'keepConnected': true,
    });
  });

  test('login invalid credentials are translated to pt-BR', () async {
    final apiClient = ApiClient(
      client: _FakeHttpClient(
        responses: {
          'POST http://localhost:8071/api/v1/auth/login': http.Response(
            '{"detail":"Invalid email or password."}',
            401,
            headers: {'content-type': 'application/json'},
          ),
        },
      ),
    );
    final api = TouchInApi(
      client: apiClient,
      tokenStorage: _InMemoryTokenStorage(),
    );

    await expectLater(
      api.login(
        credentials: const LoginCredentials(
          email: 'marina.costa@touchin.com',
          password: _invalidCredentialFixture,
          keepConnected: true,
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'E-mail ou senha inválidos.',
        ),
      ),
    );
  });

  test('auth context expired token is translated to pt-BR', () async {
    final tokenStorage = _InMemoryTokenStorage()..savedToken = 'token-123';
    final apiClient = ApiClient(
      tokenStorage: tokenStorage,
      client: _FakeHttpClient(
        responses: {
          'GET http://localhost:8071/api/v1/auth/me': http.Response(
            '{"detail":"Invalid or expired access token."}',
            401,
            headers: {'content-type': 'application/json'},
          ),
        },
      ),
    );
    final api = TouchInApi(client: apiClient, tokenStorage: tokenStorage);

    await expectLater(
      api.getAuthContext(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Sessão expirada. Faça login novamente.',
        ),
      ),
    );
  });

  test('registerCompany posts payload contract and parses full session',
      () async {
    final client = _FakeApiClient(
      postResponses: {
        '/auth/register-company': _authSessionResponse(),
      },
    );
    final tokenStorage = _InMemoryTokenStorage();
    final api = TouchInApi(client: client, tokenStorage: tokenStorage);

    final session = await api.registerCompany(
      draft: const CompanyRegistrationDraft(
        companyName: 'TouchIn Tecnologia LTDA',
        tradeName: 'TouchIn',
        cnpj: '12.345.678/0001-90',
        email: 'contato@touchin.com',
        phone: '(11) 99999-0000',
        password: _validCredentialFixture,
        acceptTerms: true,
      ),
    );

    expect(session.company.tradeName, 'TouchIn');
    expect(session.user.email, 'marina.costa@touchin.com');
    expect(tokenStorage.savedSession?.company.tradeName, 'TouchIn');
    expect(client.lastPath, '/auth/register-company');
    expect(client.lastBody, <String, dynamic>{
      'companyName': 'TouchIn Tecnologia LTDA',
      'tradeName': 'TouchIn',
      'cnpj': '12.345.678/0001-90',
      'email': 'contato@touchin.com',
      'phone': '(11) 99999-0000',
      'password': _validCredentialFixture,
      'acceptTerms': true,
    });
  });

  test('logout calls backend endpoint and clears local token', () async {
    final client = _FakeApiClient(
      postResponses: {
        '/auth/logout': null,
      },
    );
    final tokenStorage = _InMemoryTokenStorage()..savedToken = 'token-123';
    final api = TouchInApi(client: client, tokenStorage: tokenStorage);

    await api.logout();

    expect(client.lastPath, '/auth/logout');
    expect(client.lastWithAuth, isTrue);
    expect(tokenStorage.clearCalled, isTrue);
    expect(tokenStorage.savedToken, isNull);
  });

  test('logout clears local token even when backend logout fails', () async {
    final client = _FakeApiClient(
      postErrors: {
        '/auth/logout':
            ApiException('Falha ao encerrar sessao.', statusCode: 500),
      },
    );
    final tokenStorage = _InMemoryTokenStorage()..savedToken = 'token-123';
    final api = TouchInApi(client: client, tokenStorage: tokenStorage);

    await expectLater(
      api.logout(),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          'Falha ao encerrar sessao.',
        ),
      ),
    );
    expect(tokenStorage.clearCalled, isTrue);
    expect(tokenStorage.savedToken, isNull);
  });

  test('getAuthContext parses masked company summary', () async {
    final client = _FakeApiClient(
      getResponses: {
        '/auth/me': _authContextResponse(),
      },
    );
    final api =
        TouchInApi(client: client, tokenStorage: _InMemoryTokenStorage());

    final context = await api.getAuthContext();

    expect(context.company.tradeName, 'TouchIn');
    expect(context.company.cnpjMasked, '12.***.***/****-90');
    expect(context.user.isAdmin, isTrue);
    expect(client.lastPath, '/auth/me');
    expect(client.lastWithAuth, isTrue);
  });

  test('listEmployees parses backend payload through employee contract',
      () async {
    final client = _FakeApiClient(
      getResponses: {
        '/employees': <dynamic>[
          {
            'id': 'emp-01',
            'name': 'Marina Costa',
            'role': 'Gerente de Operacoes',
            'department': 'Operacoes',
            'email': 'marina.costa@touchin.com',
            'phone': '(11) 99123-1001',
            'unit': 'Matriz Paulista',
            'expectedShiftStart': '09:00',
            'expectedShiftEnd': '18:00',
            'status': 'active',
            'workMode': 'onsite',
            'roleLevel': 'leadership',
            'requiresLocationOnPunch': true,
            'trustedDeviceRequired': true,
            'todayWorkedMinutes': 120,
            'pendingAdjustments': 0,
            'lastPunchAt': '2026-04-26T12:00:00Z',
            'notes': 'Responsavel pela operacao.',
          },
        ],
      },
    );
    final api =
        TouchInApi(client: client, tokenStorage: _InMemoryTokenStorage());

    final employees = await api.listEmployees();

    expect(employees, hasLength(1));
    expect(employees.first.id, 'emp-01');
    expect(employees.first.status, EmployeeStatus.active);
    expect(employees.first.roleLevel, RoleLevel.leadership);
  });

  test('createEmployee and updateEmployee use employee contract payload',
      () async {
    final employeeResponse = {
      'id': 'emp-99',
      'name': 'Renata Souza',
      'role': 'Analista Financeira',
      'department': 'Financeiro',
      'email': 'renata.souza@touchin.com',
      'phone': '(11) 94444-6060',
      'unit': 'Backoffice Centro',
      'expectedShiftStart': '08:00',
      'expectedShiftEnd': '17:00',
      'status': 'active',
      'workMode': 'hybrid',
      'roleLevel': 'specialist',
      'requiresLocationOnPunch': false,
      'trustedDeviceRequired': true,
      'todayWorkedMinutes': 0,
      'pendingAdjustments': 0,
      'lastPunchAt': null,
      'notes': 'Nova contratacao.',
    };
    final client = _FakeApiClient(
      postResponses: {
        '/employees': employeeResponse,
      },
      putResponses: {
        '/employees/emp-99': {
          ...employeeResponse,
          'role': 'Analista Financeira Senior',
          'workMode': 'remote',
        },
      },
    );
    final api =
        TouchInApi(client: client, tokenStorage: _InMemoryTokenStorage());
    final draft = const EmployeeDraft(
      name: 'Renata Souza',
      role: 'Analista Financeira',
      department: 'Financeiro',
      email: 'renata.souza@touchin.com',
      phone: '(11) 94444-6060',
      unit: 'Backoffice Centro',
      expectedShiftStart: TimeOfDay(hour: 8, minute: 0),
      expectedShiftEnd: TimeOfDay(hour: 17, minute: 0),
      status: EmployeeStatus.active,
      workMode: EmployeeWorkMode.hybrid,
      roleLevel: RoleLevel.specialist,
      requiresLocationOnPunch: false,
      trustedDeviceRequired: true,
      notes: 'Nova contratacao.',
    );

    final created = await api.createEmployee(draft);
    final updated = await api.updateEmployee(
      'emp-99',
      draft.copyWith(
        role: 'Analista Financeira Senior',
        workMode: EmployeeWorkMode.remote,
      ),
    );

    expect(created.id, 'emp-99');
    expect(updated.role, 'Analista Financeira Senior');
    expect(updated.workMode, EmployeeWorkMode.remote);
    expect(client.lastPath, '/employees/emp-99');
    expect(client.lastWithAuth, isTrue);
    expect(client.lastBody, <String, dynamic>{
      'name': 'Renata Souza',
      'role': 'Analista Financeira Senior',
      'department': 'Financeiro',
      'email': 'renata.souza@touchin.com',
      'phone': '(11) 94444-6060',
      'unit': 'Backoffice Centro',
      'expectedShiftStart': '08:00',
      'expectedShiftEnd': '17:00',
      'status': 'active',
      'workMode': 'remote',
      'roleLevel': 'specialist',
      'requiresLocationOnPunch': false,
      'trustedDeviceRequired': true,
      'notes': 'Nova contratacao.',
    });
  });

  test('deleteEmployee calls employees endpoint with auth', () async {
    final client = _FakeApiClient(
      deleteResponses: {
        '/employees/emp-99': null,
      },
    );
    final api =
        TouchInApi(client: client, tokenStorage: _InMemoryTokenStorage());

    await api.deleteEmployee('emp-99');

    expect(client.lastPath, '/employees/emp-99');
    expect(client.lastWithAuth, isTrue);
  });

  test('time clock endpoints use time-clock contracts end-to-end', () async {
    final client = _FakeApiClient(
      getResponses: {
        '/time-clock/me?page=1&limit=4': {
          'employee': {
            'id': 'emp-01',
            'name': 'Marina Costa',
            'unit': 'Matriz Paulista',
            'status': 'active',
            'workMode': 'onsite',
            'requiresLocationOnPunch': true,
            'trustedDeviceRequired': true,
          },
          'currentStatus': 'working',
          'todayWorkedMinutes': 245,
          'todayBreakMinutes': 15,
          'firstCheckInAt': '2026-04-26T11:00:00Z',
          'lastPunchAt': '2026-04-26T14:30:00Z',
          'records': [
            {
              'type': 'checkIn',
              'timestamp': '2026-04-26T11:00:00Z',
              'detail': 'Entrada registrada.',
              'location': {
                'latitude': -23.5632,
                'longitude': -46.6545,
                'accuracyMeters': 12,
                'capturedAt': '2026-04-26T11:00:00Z',
              },
            },
          ],
          'recordsPage': 1,
          'recordsPageSize': 4,
          'recordsTotal': 1,
          'recordsTotalPages': 1,
          'recordsHasPrevious': false,
          'recordsHasNext': false,
        },
        '/time-clock/employees/emp-02/punches?page=2&limit=2': {
          'records': [
            {
              'id': 'punch-02',
              'employeeId': 'emp-02',
              'type': 'checkIn',
              'timestamp': '2026-04-25T11:00:00Z',
              'detail': 'Segundo registro.',
              'projectId': null,
              'location': null,
            },
          ],
          'recordsPage': 2,
          'recordsPageSize': 2,
          'recordsTotal': 3,
          'recordsTotalPages': 2,
          'recordsHasPrevious': true,
          'recordsHasNext': false,
        },
      },
      postResponses: {
        '/time-clock/me/punches': {
          'type': 'checkOut',
          'timestamp': '2026-04-26T18:00:00Z',
          'detail': 'Saida registrada.',
          'location': {
            'latitude': -23.5632,
            'longitude': -46.6545,
            'accuracyMeters': 12,
            'capturedAt': '2026-04-26T18:00:00Z',
          },
        },
      },
    );
    final api =
        TouchInApi(client: client, tokenStorage: _InMemoryTokenStorage());

    final state = await api.getMyTimeClockState();
    final punch = await api.createPunch(
      request: CreatePunchRequest(
        type: PunchType.checkOut,
        location: PunchLocationSnapshot(
          latitude: -23.5632,
          longitude: -46.6545,
          accuracyMeters: 12,
          capturedAt: DateTime.parse('2026-04-26T18:00:00Z'),
        ),
      ),
    );
    expect(client.lastPath, '/time-clock/me/punches');

    final managedPunchPage = await api.listManagedPunches(
      'emp-02',
      page: 2,
      limit: 2,
    );

    expect(state.employee.name, 'Marina Costa');
    expect(state.currentStatus, ShiftStatus.working);
    expect(state.records.single.type, PunchType.checkIn);
    expect(punch.type, PunchType.checkOut);

    expect(managedPunchPage.recordsPage, 2);
    expect(managedPunchPage.records.single.id, 'punch-02');
    expect(managedPunchPage.recordsHasNext, isFalse);
    expect(
        client.lastPath, '/time-clock/employees/emp-02/punches?page=2&limit=2');
    expect(client.lastBody, <String, dynamic>{
      'type': 'checkOut',
      'location': {
        'latitude': -23.5632,
        'longitude': -46.6545,
        'accuracyMeters': 12.0,
        'capturedAt': '2026-04-26T18:00:00.000Z',
      },
    });
  });

  test('invalid contract response becomes ApiException', () async {
    final client = _FakeApiClient(
      postResponses: {
        '/auth/login': <String, dynamic>{'tokenType': 'bearer'},
      },
    );
    final api =
        TouchInApi(client: client, tokenStorage: _InMemoryTokenStorage());

    expect(
      () => api.login(
        credentials: const LoginCredentials(
          email: 'marina.costa@touchin.com',
          password: _validCredentialFixture,
          keepConnected: true,
        ),
      ),
      throwsA(
        isA<ApiException>().having(
          (error) => error.message,
          'message',
          contains('Contrato invalido'),
        ),
      ),
    );
  });
}

Map<String, dynamic> _authSessionResponse() {
  return <String, dynamic>{
    'accessToken': 'token-123',
    'tokenType': 'bearer',
    'expiresAt': '2026-04-26T18:00:00Z',
    'company': {
      'id': 'cmp-01',
      'legalName': 'TouchIn Tecnologia LTDA',
      'tradeName': 'TouchIn',
      'cnpjMasked': '12.***.***/****-90',
      'emailMasked': 'co*****@touchin.com',
      'phoneMasked': '11*****0000',
    },
    'user': {
      'id': 'usr-01',
      'email': 'marina.costa@touchin.com',
      'role': 'admin',
      'employeeId': null,
    },
  };
}

Map<String, dynamic> _authContextResponse() {
  return <String, dynamic>{
    'company': {
      'id': 'cmp-01',
      'legalName': 'TouchIn Tecnologia LTDA',
      'tradeName': 'TouchIn',
      'cnpjMasked': '12.***.***/****-90',
      'emailMasked': 'co*****@touchin.com',
      'phoneMasked': '11*****0000',
    },
    'user': {
      'id': 'usr-01',
      'email': 'marina.costa@touchin.com',
      'role': 'admin',
      'employeeId': null,
    },
  };
}

class _FakeApiClient extends ApiClient {
  _FakeApiClient({
    this.getResponses = const <String, dynamic>{},
    this.postResponses = const <String, dynamic>{},
    this.postErrors = const <String, Object>{},
    this.putResponses = const <String, dynamic>{},
    this.deleteResponses = const <String, dynamic>{},
  });

  final Map<String, dynamic> getResponses;
  final Map<String, dynamic> postResponses;
  final Map<String, Object> postErrors;
  final Map<String, dynamic> putResponses;
  final Map<String, dynamic> deleteResponses;

  String? lastPath;
  Object? lastBody;
  bool? lastWithAuth;

  @override
  Future<dynamic> get(
    String path, {
    bool withAuth = false,
    Map<String, Object?>? queryParameters,
  }) async {
    final lookupPath = _lookupPath(path, queryParameters);
    lastPath = lookupPath;
    lastWithAuth = withAuth;
    if (!getResponses.containsKey(lookupPath)) {
      throw StateError('No fake GET response registered for $lookupPath');
    }
    return getResponses[lookupPath];
  }

  @override
  Future<dynamic> post(
    String path, {
    Object? body,
    bool withAuth = false,
  }) async {
    lastPath = path;
    lastBody = body;
    lastWithAuth = withAuth;
    if (postErrors.containsKey(path)) {
      throw postErrors[path]!;
    }
    if (!postResponses.containsKey(path)) {
      throw StateError('No fake POST response registered for $path');
    }
    return postResponses[path];
  }

  @override
  Future<dynamic> put(
    String path, {
    Object? body,
    bool withAuth = false,
  }) async {
    lastPath = path;
    lastBody = body;
    lastWithAuth = withAuth;
    if (!putResponses.containsKey(path)) {
      throw StateError('No fake PUT response registered for $path');
    }
    return putResponses[path];
  }

  @override
  Future<dynamic> delete(String path, {bool withAuth = false}) async {
    lastPath = path;
    lastWithAuth = withAuth;
    if (!deleteResponses.containsKey(path)) {
      throw StateError('No fake DELETE response registered for $path');
    }
    return deleteResponses[path];
  }

  String _lookupPath(
    String path,
    Map<String, Object?>? queryParameters,
  ) {
    if (queryParameters == null || queryParameters.isEmpty) {
      return path;
    }

    final query = Uri(
        queryParameters: queryParameters.map(
      (key, value) => MapEntry(key, value?.toString()),
    )).query;
    return '$path?$query';
  }
}

class _FakeHttpClient extends http.BaseClient {
  _FakeHttpClient({required this.responses});

  final Map<String, http.Response> responses;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final key =
        '${request.method.toUpperCase()} ${request.url.scheme}://${request.url.authority}${request.url.path}${request.url.hasQuery ? '?${request.url.query}' : ''}';
    final response = responses[key];
    if (response == null) {
      throw StateError('No fake HTTP response registered for $key');
    }
    return http.StreamedResponse(
      Stream<List<int>>.fromIterable([response.bodyBytes]),
      response.statusCode,
      headers: response.headers,
      reasonPhrase: response.reasonPhrase,
      request: request,
    );
  }
}

class _InMemoryTokenStorage extends TokenStorage {
  String? savedToken;
  AuthSession? savedSession;
  bool clearCalled = false;

  @override
  Future<void> saveAccessToken(String token) async {
    savedToken = token;
  }

  @override
  Future<void> saveAuthSession(AuthSession session) async {
    savedToken = session.accessToken;
    savedSession = session;
  }

  @override
  Future<String?> readAccessToken() async {
    return savedToken ?? savedSession?.accessToken;
  }

  @override
  Future<AuthSession?> readAuthSession() async {
    return savedSession;
  }

  @override
  Future<void> clearAccessToken() async {
    clearCalled = true;
    savedToken = null;
    savedSession = null;
  }
}
