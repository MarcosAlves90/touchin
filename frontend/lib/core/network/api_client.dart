import 'dart:convert';

import 'package:bunchin_flutter/core/config/app_config.dart';
import 'package:bunchin_flutter/core/storage/token_storage.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  ApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, message: $message)';
  }
}

class ApiClient {
  ApiClient({http.Client? client, TokenStorage? tokenStorage})
      : _client = client ?? http.Client(),
        _tokenStorage = tokenStorage ?? TokenStorage();

  final http.Client _client;
  final TokenStorage _tokenStorage;

  Uri _uri(String path) {
    final sanitizedPath = path.startsWith('/') ? path.substring(1) : path;
    return Uri.parse('${AppConfig.apiBaseUrl}/$sanitizedPath');
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
    final response = await _client.get(
      _uri(path).replace(
        queryParameters: queryParameters?.map(
          (key, value) => MapEntry(key, value?.toString()),
        ),
      ),
      headers: await _headers(withAuth: withAuth),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> post(
    String path, {
    Object? body,
    bool withAuth = false,
  }) async {
    final response = await _client.post(
      _uri(path),
      headers: await _headers(withAuth: withAuth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> put(
    String path, {
    Object? body,
    bool withAuth = false,
  }) async {
    final response = await _client.put(
      _uri(path),
      headers: await _headers(withAuth: withAuth),
      body: body == null ? null : jsonEncode(body),
    );
    return _decodeResponse(response);
  }

  Future<dynamic> delete(String path, {bool withAuth = false}) async {
    final response = await _client.delete(
      _uri(path),
      headers: await _headers(withAuth: withAuth),
    );
    return _decodeResponse(response);
  }

  dynamic _decodeResponse(http.Response response) {
    final hasBody = response.body.isNotEmpty;
    final parsedBody = hasBody ? jsonDecode(response.body) : null;

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return parsedBody;
    }

    final message = _translateMessage(
          _extractMessage(parsedBody) ?? 'Falha na comunicacao com a API.',
        ) ??
        'Falha na comunicacao com a API.';
    throw ApiException(message, statusCode: response.statusCode);
  }

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
      'The company account is inactive.' =>
        'A conta da empresa está inativa.',
      'This account is inactive.' => 'Esta conta está inativa.',
      'Project task employee limit is below current task membership.' =>
        'O limite por tarefa não pode ser menor que a quantidade de funcionários já associados a uma tarefa. Remova participantes antes de reduzir o limite.',
      _ => null,
    };
  }
}
