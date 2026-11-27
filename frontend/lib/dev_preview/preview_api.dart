import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/core/network/api_client.dart';
import 'package:touchin_flutter/core/network/touchin_api.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:touchin_flutter/dev_preview/preview_controller.dart';
import 'package:touchin_flutter/dev_preview/preview_fixtures.dart';

/// No secure-storage method is inherited: this identity exists only in this
/// application's memory and is never a backend credential.
class PreviewTokenStorage extends TokenStorage {
  PreviewTokenStorage(this.controller, this.fixtures) {
    requireDeveloperPreview();
  }
  final PreviewController controller;
  final PreviewFixtures fixtures;

  @override
  Future<AuthSession> readAuthSession() async {
    final context = fixtures.context(controller.persona);
    return AuthSession(
        accessToken: 'preview-local-identity',
        tokenType: 'preview',
        expiresAt: DateTime.utc(2099),
        company: context.company,
        user: context.user);
  }

  @override
  Future<String?> readAccessToken() async => 'preview-local-identity';
  @override
  Future<void> saveAuthSession(AuthSession session) async => _unsupported();
  @override
  Future<void> saveAccessToken(String token) async => _unsupported();
  @override
  Future<void> clearAccessToken() async {}
  @override
  Future<void> clearSessionIfTokenMatches(String expectedToken) async {}

  Never _unsupported() =>
      throw UnsupportedError('Preview cannot persist sessions.');
}

/// Normal API parsers and request contracts run over a transport with no IO
/// client and no network fallback. Even an unsupported operation stays local.
class PreviewApi extends TouchInApi {
  PreviewApi(PreviewController controller, PreviewFixtures fixtures,
      PreviewTokenStorage storage)
      : controller = controller,
        fixtures = fixtures,
        super(
            client: ApiClient(
                client: PreviewTransport(controller, fixtures),
                tokenStorage: storage,
                baseUrl: 'http://preview.invalid/api/v1'),
            tokenStorage: storage) {
    requireDeveloperPreview();
  }
  final PreviewController controller;
  final PreviewFixtures fixtures;

  @override
  Future<AuthContext> getAuthContext() async {
    await controller.bootstrap();
    return fixtures.context(controller.persona);
  }

  @override
  Future<AuthContext> getAuthContextForToken(String token) => getAuthContext();
  @override
  Future<void> logout() async {}
}

class PreviewTransport extends http.BaseClient {
  PreviewTransport(this.controller, this.fixtures) {
    requireDeveloperPreview();
  }
  final PreviewController controller;
  final PreviewFixtures fixtures;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    // No super.send, socket or externally supplied client can be reached here.
    final path = request.url.path.replaceFirst('/api/v1', '');
    if (path == '/admin/ai-settings' || path == '/admin/ai-settings/test') {
      return _unsupported();
    }
    final raw = await request.finalize().bytesToString();
    final body =
        raw.isEmpty ? <String, dynamic>{} : jsonDecode(raw) as PreviewJson;
    final query = request.url.queryParameters;
    final revision = controller.pageRevision;
    final sessionRevision = controller.sessionRevision;
    await controller.beforeRequest();
    if (controller.pageRevision != revision ||
        controller.sessionRevision != sessionRevision) {
      throw ApiException('[Prévia] Cenário substituído.',
          code: 'preview_cancelled');
    }
    final result = _dispatch(request.method, path, body, query);
    final encoded = utf8.encode(jsonEncode(result));
    return http.StreamedResponse(Stream.value(encoded), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
  }

  Never _unsupported() => throw ApiException(
      '[Prévia] Esta operação não é simulada. Nenhum dado real foi enviado.',
      statusCode: 501,
      code: 'preview_unsupported');

  dynamic _dispatch(
      String method, String path, PreviewJson body, Map<String, String> query) {
    final parts = path.split('/').where((part) => part.isNotEmpty).toList();
    final empty = controller.data == PreviewData.empty;
    if (parts.isEmpty) return _unsupported();
    if (parts.first == 'auth') return _unsupported();
    final managerial = controller.persona != PreviewPersona.employee;
    final ownProjects = parts.length == 3 &&
        parts.first == 'employees' &&
        parts[1] == 'preview-employee-1' &&
        parts[2] == 'projects' &&
        method == 'GET';
    if (!managerial &&
        !ownProjects &&
        (parts.first == 'employees' || parts.first == 'audit-events')) {
      throw ApiException('[Prévia] Este perfil fictício não tem acesso.',
          statusCode: 403);
    }
    if (parts.first == 'employees') {
      if (method == 'GET' && parts.length == 3 && parts[2] == 'projects') {
        final ids = fixtures.projectMembers
            .where((m) => m['employeeId'] == parts[1])
            .map((m) => m['projectId'])
            .toSet();
        return empty
            ? <PreviewJson>[]
            : fixtures.projects.where((p) => ids.contains(p['id'])).toList();
      }
      return _collection(method, parts, body, empty ? [] : fixtures.employees,
          fixtures.employees, 'employee',
          defaults: {
            ...fixtures.employees.first,
            'todayWorkedMinutes': 0,
            'pendingAdjustments': 0,
            'lastPunchAt': null,
          });
    }
    if (parts.first == 'projects') {
      if (parts.length <= 2) {
        final listed = fixtures.projects
            .where((p) =>
                query['status'] == null || query['status'] == p['status'])
            .toList();
        if (method == 'DELETE' && parts.length == 2) {
          final id = parts[1];
          final taskIds = fixtures.tasks
              .where((t) => t['projectId'] == id)
              .map((t) => t['id'])
              .toSet();
          fixtures.taskMembers
              .removeWhere((m) => taskIds.contains(m['taskId']));
          fixtures.tasks.removeWhere((t) => t['projectId'] == id);
          fixtures.columns.removeWhere((c) => c['projectId'] == id);
          fixtures.projectMembers.removeWhere((m) => m['projectId'] == id);
        }
        return _collection(method, parts, body, empty ? [] : listed,
            fixtures.projects, 'project',
            defaults: {
              'createdAt': PreviewFixtures.date,
              'updatedAt': PreviewFixtures.date,
              'status': 'active'
            });
      }
      final projectId = parts[1];
      if (parts[2] == 'kanban') {
        return _kanban(method, parts, body, projectId, empty);
      }
      if (parts[2] == 'members') {
        return _members(method, parts.skip(3).toList(), body,
            fixtures.projectMembers, 'projectId', projectId, empty);
      }
      if (parts[2] == 'tasks') {
        if (parts.length > 4 && parts[4] == 'members') {
          return _members(method, parts.skip(5).toList(), body,
              fixtures.taskMembers, 'taskId', parts[3], empty);
        }
        final taskParts = parts.skip(2).toList();
        final columnId = body['columnId'] ??
            fixtures.columns
                .firstWhere((c) => c['projectId'] == projectId)['id'];
        final result = _collection(
            method,
            taskParts,
            {
              ...body,
              if (method == 'POST') 'kanbanColumnId': columnId,
            },
            empty
                ? []
                : fixtures.tasks
                    .where((t) => t['projectId'] == projectId)
                    .toList(),
            fixtures.tasks,
            'task',
            defaults: {
              'projectId': projectId,
              'parentTaskId': null,
              'kanbanColumnId': columnId,
              'kanbanPosition': fixtures.tasks.length,
              'revision': 1,
              'createdAt': PreviewFixtures.date,
              'updatedAt': PreviewFixtures.date,
            });
        if (method != 'GET') fixtures.kanbanVersion++;
        return result;
      }
    }
    if (parts.first == 'time-clock') {
      return _timeClock(method, parts, body, query, empty);
    }
    if (parts.first == 'audit-events' && parts.length == 1 && method == 'GET') {
      final filtered = fixtures.audit.where((event) {
        for (final field in [
          'actor_user_id',
          'action',
          'entity_type',
          'entity_id',
          'project_id',
          'result'
        ]) {
          if (query[field] != null && query[field] != event[field]) {
            return false;
          }
        }
        final timestamp = DateTime.parse(event['timestamp'] as String);
        final start = DateTime.tryParse(query['start_date'] ?? '');
        final end = DateTime.tryParse(query['end_date'] ?? '');
        return (start == null || !timestamp.isBefore(start)) &&
            (end == null || timestamp.isBefore(end));
      }).toList();
      return _page(empty ? [] : filtered, query)['records'];
    }
    return _unsupported();
  }

  dynamic _collection(String method, List<String> parts, PreviewJson body,
      List<PreviewJson> listed, List<PreviewJson> state, String kind,
      {PreviewJson defaults = const {}}) {
    if (method == 'GET' && parts.length == 1) return listed;
    if (method == 'POST' && parts.length == 1) {
      final created = <String, dynamic>{
        ...defaults,
        ...body,
        if (kind == 'task')
          'cardNumber':
              fixtures.nextCardNumber(defaults['projectId'] as String),
        'id': fixtures.nextId(kind)
      };
      state.add(created);
      if (kind == 'project') {
        fixtures.columns.add({
          'id': '${created['id']}-column-0',
          'projectId': created['id'],
          'name': 'A fazer',
          'position': 0,
          'createdAt': PreviewFixtures.date,
          'updatedAt': PreviewFixtures.date
        });
      }
      return created;
    }
    if (parts.length != 2) return _unsupported();
    final found = state.where((item) => item['id'] == parts[1]).firstOrNull;
    if (found == null) {
      throw ApiException('[Prévia] Registro inexistente.', statusCode: 404);
    }
    if (method == 'DELETE') {
      state.remove(found);
      if (kind == 'employee') {
        fixtures.taskMembers.removeWhere((m) => m['employeeId'] == found['id']);
        fixtures.projectMembers
            .removeWhere((m) => m['employeeId'] == found['id']);
        fixtures.punches.removeWhere((m) => m['employeeId'] == found['id']);
      }
      if (kind == 'task') {
        fixtures.taskMembers.removeWhere((m) => m['taskId'] == found['id']);
        for (final task in fixtures.tasks) {
          if (task['parentTaskId'] == found['id']) task['parentTaskId'] = null;
        }
      }
      return null;
    }
    if (method == 'PUT') {
      found.addAll(body);
      if (kind == 'employee') {
        for (final member in [
          ...fixtures.taskMembers,
          ...fixtures.projectMembers
        ]) {
          if (member['employeeId'] == found['id']) {
            member['employeeName'] = found['name'];
          }
        }
      }
      if (found.containsKey('revision')) {
        found['revision'] = (found['revision'] as int) + 1;
      }
      return found;
    }
    return _unsupported();
  }

  dynamic _members(String method, List<String> parts, PreviewJson body,
      List<PreviewJson> state, String ownerKey, String ownerId, bool empty) {
    if (method == 'GET') {
      return empty
          ? <PreviewJson>[]
          : state.where((m) => m[ownerKey] == ownerId).toList();
    }
    final employeeId = parts.firstOrNull == 'me'
        ? 'preview-employee-1'
        : parts.firstOrNull ?? body['employeeId'] as String?;
    final existing = state
        .where((m) => m[ownerKey] == ownerId && m['employeeId'] == employeeId)
        .firstOrNull;
    if (method == 'DELETE') {
      state.remove(existing);
      return null;
    }
    if (method != 'POST') return _unsupported();
    final employee =
        fixtures.employees.firstWhere((e) => e['id'] == employeeId);
    final member = existing ??
        <String, dynamic>{
          ownerKey: ownerId,
          'employeeId': employeeId,
          'employeeName': employee['name'],
          'createdAt': PreviewFixtures.date
        };
    if (existing == null) state.add(member);
    return member;
  }

  dynamic _kanban(String method, List<String> parts, PreviewJson body,
      String projectId, bool empty) {
    if (method == 'GET') return fixtures.board(projectId, empty: empty);
    if (body['expectedVersion'] != null &&
        body['expectedVersion'] != fixtures.kanbanVersion) {
      throw ApiException('[Prévia] Versão do quadro alterada. Recarregue.',
          statusCode: 409);
    }
    if (parts.length >= 4 && parts[3] == 'columns') {
      if (method == 'POST') {
        fixtures.columns.add({
          'id': fixtures.nextId('column'),
          'projectId': projectId,
          'name': body['name'],
          'position': fixtures.columns.length,
          'createdAt': PreviewFixtures.date,
          'updatedAt': PreviewFixtures.date
        });
      } else if (parts.length == 5 && parts[4] == 'order') {
        final ids = body['columnIds'] as List<dynamic>;
        final ordered = fixtures.columns
            .where((c) => c['projectId'] == projectId)
            .toList()
          ..sort(
              (a, b) => ids.indexOf(a['id']).compareTo(ids.indexOf(b['id'])));
        fixtures.columns.removeWhere((c) => c['projectId'] == projectId);
        fixtures.columns.addAll(ordered);
        for (final column in ordered) {
          column['position'] = ids.indexOf(column['id']);
        }
      } else if (parts.length == 5) {
        final column = fixtures.columns.firstWhere((c) => c['id'] == parts[4]);
        if (method == 'DELETE') {
          if (fixtures.columns
                  .where((c) => c['projectId'] == projectId)
                  .length <=
              1) {
            throw ApiException(
                '[Prévia] A última coluna do quadro não pode ser removida.',
                statusCode: 409);
          }
          if (fixtures.tasks.any((t) => t['kanbanColumnId'] == column['id'])) {
            throw ApiException(
                '[Prévia] Mova os cards antes de remover a coluna.',
                statusCode: 409);
          }
          fixtures.columns.remove(column);
        } else {
          column['name'] = body['name'];
        }
      } else {
        return _unsupported();
      }
    } else if (parts.length == 5 &&
        parts[3] == 'cards' &&
        parts[4] == 'order') {
      for (final column in body['columns'] as List<dynamic>) {
        final ids = column['taskIds'] as List<dynamic>;
        for (var index = 0; index < ids.length; index++) {
          final task = fixtures.tasks.firstWhere(
              (t) => t['id'] == ids[index] && t['projectId'] == projectId);
          task['kanbanColumnId'] = column['columnId'];
          task['kanbanPosition'] = index;
        }
      }
      fixtures.tasks.sort((a, b) =>
          (a['kanbanPosition'] as int).compareTo(b['kanbanPosition'] as int));
    } else if (parts.length == 7 && parts[5] == 'assignees') {
      _members(method, [parts[6]], body, fixtures.taskMembers, 'taskId',
          parts[4], false);
      return fixtures
          .card(fixtures.tasks.firstWhere((t) => t['id'] == parts[4]));
    } else {
      return _unsupported();
    }
    fixtures.kanbanVersion++;
    return fixtures.board(projectId);
  }

  PreviewJson _page(List<PreviewJson> records, Map<String, String> query) {
    final page = (int.tryParse(query['page'] ?? '') ?? 1).clamp(1, 100000);
    final limit = (int.tryParse(query['limit'] ?? '') ?? 4).clamp(1, 500);
    final pages = ((records.length + limit - 1) ~/ limit).clamp(1, 100000);
    return {
      'records': records.skip((page - 1) * limit).take(limit).toList(),
      'recordsPage': page,
      'recordsPageSize': limit,
      'recordsTotal': records.length,
      'recordsTotalPages': pages,
      'recordsHasPrevious': page > 1,
      'recordsHasNext': page < pages
    };
  }

  dynamic _timeClock(String method, List<String> parts, PreviewJson body,
      Map<String, String> query, bool empty) {
    final employeeId = parts[1] == 'me' ? 'preview-employee-1' : parts[2];
    final records = fixtures.punches
        .where((p) => p['employeeId'] == employeeId)
        .toList()
      ..sort((a, b) =>
          (b['timestamp'] as String).compareTo(a['timestamp'] as String));
    if (method == 'GET') {
      final page = _page(empty ? [] : records, query);
      if (parts[1] != 'me') return page;
      final employee =
          fixtures.employees.firstWhere((e) => e['id'] == employeeId);
      final latest = records.firstOrNull;
      final status = empty || latest == null
          ? 'checkedOut'
          : switch (latest['type']) {
              'checkIn' || 'breakEnd' => 'working',
              'breakStart' => 'onBreak',
              _ => 'checkedOut'
            };
      return {
        ...page,
        'employee': employee,
        'currentStatus': status,
        'todayWorkedMinutes': empty ? 0 : 420,
        'todayBreakMinutes': empty ? 0 : 60,
        'firstCheckInAt': empty ? null : PreviewFixtures.date,
        'lastPunchAt': empty ? null : latest?['timestamp']
      };
    }
    final isMe = parts[1] == 'me';
    final result = _collection(
        method,
        ['punches', if (parts.length > (isMe ? 3 : 4)) parts.last],
        body,
        records,
        fixtures.punches,
        'punch',
        defaults: {
          'employeeId': employeeId,
          'timestamp': DateTime.parse(
                  records.firstOrNull?['timestamp'] as String? ??
                      PreviewFixtures.date)
              .add(const Duration(minutes: 1))
              .toIso8601String(),
          'detail': 'Registro fictício local',
          'projectId': null,
          'location': null
        });
    return result;
  }
}
