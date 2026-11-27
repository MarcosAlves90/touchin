import 'package:touchin_flutter/contracts/contract_parsing.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:geolocator/geolocator.dart';

part 'location.freezed.dart';

enum PunchLocationStatus {
  checking,
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  unsupported,
  error,
}

@freezed
abstract class PunchLocationSnapshot with _$PunchLocationSnapshot {
  const PunchLocationSnapshot._();

  const factory PunchLocationSnapshot({
    required double latitude,
    required double longitude,
    required double accuracyMeters,
    required DateTime capturedAt,
  }) = _PunchLocationSnapshot;

  factory PunchLocationSnapshot.fromJson(JsonMap json) {
    return PunchLocationSnapshot(
      latitude: requireDouble(json, 'latitude'),
      longitude: requireDouble(json, 'longitude'),
      accuracyMeters: requireDouble(json, 'accuracyMeters'),
      capturedAt: requireDateTime(json, 'capturedAt'),
    );
  }

  factory PunchLocationSnapshot.fromPosition(Position position) {
    return PunchLocationSnapshot(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracyMeters: position.accuracy,
      capturedAt: position.timestamp,
    );
  }

  JsonMap toApiJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'accuracyMeters': accuracyMeters,
      'capturedAt': capturedAt.toUtc().toIso8601String(),
    };
  }
}

@freezed
abstract class PunchLocationResult with _$PunchLocationResult {
  const PunchLocationResult._();

  const factory PunchLocationResult.checking() = _PunchLocationChecking;

  const factory PunchLocationResult.ready({
    @Default(
        'Permissão concedida. A localização será anexada nas próximas batidas.')
    String message,
    PunchLocationSnapshot? snapshot,
  }) = _PunchLocationReady;

  const factory PunchLocationResult.serviceDisabled() =
      _PunchLocationServiceDisabled;

  const factory PunchLocationResult.permissionDenied() =
      _PunchLocationPermissionDenied;

  const factory PunchLocationResult.permissionDeniedForever({
    @Default(
        'A permissão de localização foi bloqueada. Reabilite o acesso nas configurações do dispositivo ou do navegador.')
    String message,
  }) = _PunchLocationPermissionDeniedForever;

  const factory PunchLocationResult.unsupported({
    @Default('Este ambiente nao oferece suporte a geolocalização.')
    String message,
  }) = _PunchLocationUnsupported;

  const factory PunchLocationResult.error({
    required String message,
    PunchLocationSnapshot? snapshot,
  }) = _PunchLocationError;

  PunchLocationStatus get status => when(
        checking: () => PunchLocationStatus.checking,
        ready: (_, snapshot) => PunchLocationStatus.ready,
        serviceDisabled: () => PunchLocationStatus.serviceDisabled,
        permissionDenied: () => PunchLocationStatus.permissionDenied,
        permissionDeniedForever: (_) =>
            PunchLocationStatus.permissionDeniedForever,
        unsupported: (_) => PunchLocationStatus.unsupported,
        error: (_, snapshot) => PunchLocationStatus.error,
      );

  String get message => when(
        checking: () => 'Validando permissão de localização.',
        ready: (message, _) => message,
        serviceDisabled: () =>
            'Os serviços de localização estão desativados. Ative-os para registrar o ponto.',
        permissionDenied: () =>
            'A permissão de localização foi negada. Sem ela, a batida nao é registrada.',
        permissionDeniedForever: (message) => message,
        unsupported: (message) => message,
        error: (message, _) => message,
      );

  PunchLocationSnapshot? get snapshot => when(
        checking: () => null,
        ready: (_, snapshot) => snapshot,
        serviceDisabled: () => null,
        permissionDenied: () => null,
        permissionDeniedForever: (_) => null,
        unsupported: (_) => null,
        error: (_, snapshot) => snapshot,
      );

  bool get isReady => status == PunchLocationStatus.ready;
}
