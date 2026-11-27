import 'package:touchin_flutter/contracts/contract_parsing.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'auth.freezed.dart';

@freezed
abstract class LoginCredentials with _$LoginCredentials {
  const LoginCredentials._();

  const factory LoginCredentials({
    required String email,
    required String password,
    @Default(true) bool keepConnected,
  }) = _LoginCredentials;

  JsonMap toApiJson() {
    return {
      'email': email,
      'password': password,
      'keepConnected': keepConnected,
    };
  }
}

@freezed
abstract class CompanyRegistrationDraft with _$CompanyRegistrationDraft {
  const CompanyRegistrationDraft._();

  const factory CompanyRegistrationDraft({
    required String companyName,
    required String tradeName,
    required String cnpj,
    required String email,
    required String phone,
    required String password,
    required bool acceptTerms,
  }) = _CompanyRegistrationDraft;

  JsonMap toApiJson() {
    return {
      'companyName': companyName,
      'tradeName': tradeName,
      'cnpj': cnpj,
      'email': email,
      'phone': phone,
      'password': password,
      'acceptTerms': acceptTerms,
    };
  }
}

@freezed
abstract class AuthCompanySummary with _$AuthCompanySummary {
  const AuthCompanySummary._();

  const factory AuthCompanySummary({
    required String id,
    required String legalName,
    required String tradeName,
    required String cnpjMasked,
    required String emailMasked,
    required String phoneMasked,
  }) = _AuthCompanySummary;

  factory AuthCompanySummary.fromJson(JsonMap json) {
    return AuthCompanySummary(
      id: requireString(json, 'id'),
      legalName: requireString(json, 'legalName'),
      tradeName: requireString(json, 'tradeName'),
      cnpjMasked: requireString(json, 'cnpjMasked'),
      emailMasked: requireString(json, 'emailMasked'),
      phoneMasked: requireString(json, 'phoneMasked'),
    );
  }
}

@freezed
abstract class AuthUserSummary with _$AuthUserSummary {
  const AuthUserSummary._();

  const factory AuthUserSummary({
    required String id,
    required String email,
    required String role,
    String? employeeId,
  }) = _AuthUserSummary;

  factory AuthUserSummary.fromJson(JsonMap json) {
    return AuthUserSummary(
      id: requireString(json, 'id'),
      email: requireString(json, 'email'),
      role: requireString(json, 'role'),
      employeeId: optionalString(json, 'employeeId'),
    );
  }

  bool get isAdmin => role == 'admin';

  bool get isSuperAdmin => role == 'super_admin';

  bool get isManager => role == 'manager';

  bool get isEmployee => role == 'employee';

  bool get hasAdminWorkspaceAccess => isAdmin || isSuperAdmin;

  bool get hasEmployeeProfile => (employeeId ?? '').isNotEmpty;

  String get workspaceAccessLabel {
    if (isSuperAdmin) {
      return 'Perfil super administrador';
    }
    if (isAdmin) {
      return 'Perfil administrador';
    }
    if (isManager) {
      return 'Perfil gerencial';
    }
    return 'Acesso autenticado';
  }
}

@freezed
abstract class AuthSession with _$AuthSession {
  const AuthSession._();

  const factory AuthSession({
    required String accessToken,
    required String tokenType,
    required DateTime expiresAt,
    @Default(false) bool mustChangePassword,
    required AuthCompanySummary company,
    required AuthUserSummary user,
  }) = _AuthSession;

  factory AuthSession.fromJson(JsonMap json) {
    return AuthSession(
      accessToken: requireString(json, 'accessToken'),
      tokenType: requireString(json, 'tokenType'),
      expiresAt: requireDateTime(json, 'expiresAt'),
      mustChangePassword: json['mustChangePassword'] == true,
      company: AuthCompanySummary.fromJson(
        requireJsonMap(json['company'], 'company'),
      ),
      user: AuthUserSummary.fromJson(requireJsonMap(json['user'], 'user')),
    );
  }
}

@freezed
abstract class AuthContext with _$AuthContext {
  const AuthContext._();

  const factory AuthContext({
    required AuthCompanySummary company,
    required AuthUserSummary user,
  }) = _AuthContext;

  factory AuthContext.fromJson(JsonMap json) {
    return AuthContext(
      company: AuthCompanySummary.fromJson(
        requireJsonMap(json['company'], 'company'),
      ),
      user: AuthUserSummary.fromJson(requireJsonMap(json['user'], 'user')),
    );
  }
}
