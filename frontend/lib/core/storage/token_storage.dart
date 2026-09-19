import 'dart:convert';

import 'package:touchin_flutter/contracts/auth.dart';
import 'package:touchin_flutter/contracts/contract_parsing.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorage {
  TokenStorage({FlutterSecureStorage? secureStorage})
    : _secureStorage = secureStorage ?? const FlutterSecureStorage();

  static const String _tokenKey = 'access_token';
  static const String _sessionKey = 'auth_session';
  final FlutterSecureStorage _secureStorage;

  Future<void> saveAccessToken(String token) {
    return _secureStorage.write(key: _tokenKey, value: token);
  }

  Future<void> saveAuthSession(AuthSession session) async {
    await _secureStorage.write(key: _tokenKey, value: session.accessToken);
    await _secureStorage.write(
      key: _sessionKey,
      value: jsonEncode(_encodeSession(session)),
    );
  }

  Future<String?> readAccessToken() {
    return _secureStorage.read(key: _tokenKey);
  }

  Future<AuthSession?> readAuthSession() async {
    final rawSession = await _secureStorage.read(key: _sessionKey);
    if (rawSession == null || rawSession.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawSession);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      return AuthSession.fromJson(decoded);
    } on FormatException {
      return null;
    } on ContractParsingException {
      return null;
    } on TypeError {
      return null;
    }
  }

  Future<void> clearAccessToken() {
    return Future.wait([
      _secureStorage.delete(key: _tokenKey),
      _secureStorage.delete(key: _sessionKey),
    ]).then((_) {});
  }

  Map<String, dynamic> _encodeSession(AuthSession session) {
    return <String, dynamic>{
      'accessToken': session.accessToken,
      'tokenType': session.tokenType,
      'expiresAt': session.expiresAt.toUtc().toIso8601String(),
      'mustChangePassword': session.mustChangePassword,
      'company': <String, dynamic>{
        'id': session.company.id,
        'legalName': session.company.legalName,
        'tradeName': session.company.tradeName,
        'cnpjMasked': session.company.cnpjMasked,
        'emailMasked': session.company.emailMasked,
        'phoneMasked': session.company.phoneMasked,
      },
      'user': <String, dynamic>{
        'id': session.user.id,
        'email': session.user.email,
        'role': session.user.role,
        'employeeId': session.user.employeeId,
      },
    };
  }
}
