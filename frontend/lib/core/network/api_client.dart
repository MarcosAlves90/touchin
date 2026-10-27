import 'dart:convert';

import 'package:touchin_flutter/core/config/app_config.dart';
import 'package:touchin_flutter/core/storage/token_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code});

  final String message;
  final int? statusCode;
  final String? code;

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, message: $message)';
  }
}

/// A rejected authenticated request triggers an authoritative /auth/me check.
/// A resource-level 403 alone cannot prove that the session was revoked.
class AuthRejectionEvents {
  static void Function(String token)? onRejected;
}

class ApiClient {
  ApiClient({http.Client? client, TokenStorage? tokenStorage, String? baseUrl})
      : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage(),
        _baseUrl =
            (baseUrl ?? AppConfig.apiBaseUrl).replaceFirst(RegExp(r'/+$'), '');

  final http.Client _client;
  final TokenStorage _tokenStorage;
  final String _baseUrl;

  Uri _uri(String path) {
    final sanitizedPath = path.replaceFirst(RegExp(r'^/+'), '');
    return Uri.parse('$_baseUrl/$sanitizedPath');
  }

  Future<Map<String, String>> _headers({bool withAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (withAuth) {
      final token = await _tokenStorage.readAccessToken();
      if (token == null || token.isEmpty) {
        throw ApiException('Sessão expirada. Faça login novamente.');
      }
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  Future<dynamic> get(
    String path, {
    bool withAuth = false,
    Map<String, Object?>? queryParameters,
  }) async {
    final headers = await _headers(withAuth: withAuth);
    return _getWithHeaders(path, headers, queryParameters);
  }

  /// Read using a captured token without changing the existing GET contract.
  Future<dynamic> getWithAuthToken(String path, String token) async {
    final headers = await _headers();
    headers['Authorization'] = 'Bearer $token';
    return _getWithHeaders(path, headers, null);
  }

  Future<dynamic> _getWithHeaders(
    String path,
    Map<String, String> headers,
    Map<String, Object?>? queryParameters,
  ) async {
    final response = await _client.get(
      _uri(path).replace(
        queryParameters: queryParameters?.map(
          (key, value) => MapEntry(key, value?.toString()),
        ),
      ),
      headers: headers,
    );
    return _decodeResponse(response,
        authToken: path == '/auth/me' ? null : headers['Authorization']);
  }

  Future<http.Response> getRaw(
    String path, {
    bool withAuth = false,
    Map<String, Object?>? queryParameters,
    String? accept,
  }) async {
    final headers = await _headers(withAuth: withAuth);
    if (accept != null) {
      headers['Accept'] = accept;
    }
    final response = await _client.get(
      _uri(path).replace(
        queryParameters: queryParameters?.map(
          (key, value) => MapEntry(key, value?.toString()),
        ),
      ),
      headers: headers,
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      _decodeResponse(response);
    }
    return response;
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    bool withAuth = false,
  }) async {
    final headers = await _headers(withAuth: withAuth);
    final response = await _client.post(
      _uri(path),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response, authToken: headers['Authorization']);
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    bool withAuth = false,
  }) async {
    final headers = await _headers(withAuth: withAuth);
    final response = await _client.put(
      _uri(path),
      headers: headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response, authToken: headers['Authorization']);
  }

  Future<dynamic> delete(String path, {bool withAuth = false}) async {
    final headers = await _headers(withAuth: withAuth);
    final response = await _client.delete(
      _uri(path),
      headers: headers,
    );
    return _decodeResponse(response, authToken: headers['Authorization']);
  }

  dynamic _decodeResponse(http.Response response, {String? authToken}) {
    final isSuccess = response.statusCode >= 200 && response.statusCode < 300;
    dynamic parsedBody;
    if (response.body.trim().isNotEmpty) {
      try {
        parsedBody = jsonDecode(response.body);
      } on FormatException {
        if (isSuccess) {
          throw ApiException('Resposta inválida do servidor.',
              statusCode: response.statusCode);
        }
        // Proxies can return HTML or plain text for error statuses.
      }
    }

    if (isSuccess) {
      return parsedBody;
    }

    if ((response.statusCode == 401 || response.statusCode == 403) &&
        authToken != null &&
        authToken.startsWith('Bearer ')) {
      AuthRejectionEvents.onRejected?.call(authToken.substring(7));
    }

    final code =
        parsedBody is Map<String, dynamic> && parsedBody['code'] is String
            ? parsedBody['code'] as String
            : null;
    final detail = _extractMessage(parsedBody);
    final message = response.statusCode >= 500
        ? 'Serviço temporariamente indisponível. Tente novamente.'
        : _translateErrorCode(code) ??
            (detail == null ? null : _translateMessage(detail) ?? detail) ??
            (response.statusCode == 403
                ? 'Você não tem permissão para acessar este recurso.'
                : response.statusCode == 404
                    ? 'Recurso não encontrado.'
                    : 'Não foi possível concluir a solicitação.');
    throw ApiException(message, statusCode: response.statusCode, code: code);
  }

  String? _translateErrorCode(String? code) => switch (code) {
        'task_version_conflict' =>
          'Este card foi alterado em outra sessão. Revise a versão atual antes de salvar novamente.',
        'kanban_version_conflict' =>
          'O quadro mudou em outra sessão. Recarregue antes de mover cards.',
        'kanban_snapshot_conflict' =>
          'O quadro mudou durante a leitura. Tente recarregar.',
        'task_creation_key_conflict' =>
          'Esta tentativa de criação já foi processada com outros dados. Confira o quadro antes de criar novamente.',
        _ => null,
      };

  String? _extractMessage(dynamic parsedBody) {
    if (parsedBody is Map<String, dynamic>) {
      final detail = parsedBody['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
      final message = parsedBody['message'];
      if (message is String && message.isNotEmpty) {
        return message;
      }
    }
    return null;
  }

  String? _translateMessage(String message) {
    return switch (message) {
      'Invalid email or password.' => 'E-mail ou senha inválidos.',
      'Invalid password.' => 'Senha inválida.',
      'Invalid or expired access token.' =>
        'Sessão expirada. Faça login novamente.',
      'The account associated with this token is unavailable.' =>
        'A sessão autenticada não está mais disponível.',
      'The company account is inactive.' => 'A conta da empresa está inativa.',
      'This account is inactive.' => 'Esta conta está inativa.',
      'Permission denied.' =>
        'Você não tem permissão para acessar este recurso.',
      'Admin privileges are required for this operation.' =>
        'Privilégios de administrador são necessários para esta operação.',
      'Project task employee limit is below current task membership.' =>
        'O limite por tarefa não pode ser menor que a quantidade de funcionários já associados a uma tarefa. Remova participantes antes de reduzir o limite.',
      _ => null,
    };
  }
}
