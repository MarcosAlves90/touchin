import 'dart:async';

import 'package:touchin_flutter/contracts/location.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

export 'package:touchin_flutter/contracts/location.dart';

class PunchLocationService {
  const PunchLocationService({PunchLocationGateway? gateway})
      : _gateway = gateway ?? const GeolocatorPunchLocationGateway();

  final PunchLocationGateway _gateway;

  Future<PunchLocationResult> requestPermission() async {
    try {
      final servicesEnabled = await _gateway.isLocationServiceEnabled();
      if (!servicesEnabled) {
        return const PunchLocationResult.serviceDisabled();
      }

      final permission = await _gateway.checkPermission();
      if (_isGranted(permission)) {
        final probe = await _tryCapturePosition();
        if (probe != null) {
          return PunchLocationResult.ready(
            message:
                'Permissão concedida. A localização será anexada nas próximas batidas.',
            snapshot: probe,
          );
        }
        return const PunchLocationResult.checking();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine) {
        final requested = await _gateway.requestPermission();
        if (_isGranted(requested)) {
          final probe = await _tryCapturePosition();
          if (probe != null) {
            return PunchLocationResult.ready(
              message:
                  'Permissão concedida. A localização será anexada nas próximas batidas.',
              snapshot: probe,
            );
          }
          return const PunchLocationResult.checking();
        }

        final probe = await _tryCapturePosition();
        if (probe != null) {
          return PunchLocationResult.ready(
            message:
                'Permissão concedida. A localização será anexada nas próximas batidas.',
            snapshot: probe,
          );
        }

        return _mapPermission(requested);
      }

      if (permission == LocationPermission.deniedForever) {
        final probe = await _tryCapturePosition();
        if (probe != null) {
          return PunchLocationResult.ready(
            message:
                'Permissão concedida. A localização será anexada nas próximas batidas.',
            snapshot: probe,
          );
        }
      }

      return _mapPermission(permission);
    } catch (error) {
      return _mapError(error);
    }
  }

  Future<PunchLocationResult> captureForPunch() async {
    try {
      final position = await _gateway.getCurrentPosition(
        locationSettings: _locationSettings(),
      );

      return PunchLocationResult.ready(
        message: 'localização validada e vinculada a batida.',
        snapshot: PunchLocationSnapshot.fromPosition(position),
      );
    } catch (error) {
      if (error is PermissionDeniedException) {
        final permissionResult = await requestPermission();
        if (permissionResult.snapshot != null) {
          return permissionResult;
        }
        if (permissionResult.isReady) {
          try {
            final position = await _gateway.getCurrentPosition(
              locationSettings: _locationSettings(),
            );

            return PunchLocationResult.ready(
              message: 'localização validada e vinculada a batida.',
              snapshot: PunchLocationSnapshot.fromPosition(position),
            );
          } catch (retryError) {
            return _mapError(retryError);
          }
        }
        return permissionResult;
      }
      return _mapError(error);
    }
  }

  bool _isGranted(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<PunchLocationSnapshot?> _tryCapturePosition() async {
    try {
      final position = await _gateway.getCurrentPosition(
        locationSettings: _locationSettings(),
      );

      return PunchLocationSnapshot.fromPosition(position);
    } catch (error) {
      if (error is LocationServiceDisabledException) {
        return null;
      }

      return null;
    }
  }

  PunchLocationResult _mapPermission(LocationPermission permission) {
    return switch (permission) {
      LocationPermission.always ||
      LocationPermission.whileInUse =>
        const PunchLocationResult.ready(),
      LocationPermission.denied => const PunchLocationResult.permissionDenied(),
      LocationPermission.deniedForever =>
        const PunchLocationResult.permissionDeniedForever(),
      LocationPermission.unableToDetermine =>
        PunchLocationResult.permissionDeniedForever(
          message:
              'Não foi possível confirmar a permissão no navegador. Verifique o acesso ao local e tente novamente.',
        ),
    };
  }

  PunchLocationResult _mapError(Object error) {
    if (error is LocationServiceDisabledException) {
      return const PunchLocationResult.serviceDisabled();
    }

    if (error is PermissionDefinitionsNotFoundException) {
      return const PunchLocationResult.error(
        message:
            'A plataforma nao esta configurada para solicitar localização.',
      );
    }

    if (error is PermissionDeniedException) {
      return const PunchLocationResult.permissionDenied();
    }

    if (error is TimeoutException) {
      return const PunchLocationResult.error(
        message:
            'Tempo esgotado ao obter a localização. Tente novamente com melhor sinal.',
      );
    }

    if (error is UnsupportedError) {
      return PunchLocationResult.unsupported(
        message: kIsWeb
            ? 'No navegador, a geolocalização exige HTTPS ou localhost, alem da permissão do usuario.'
            : 'Este dispositivo nao oferece suporte a geolocalização.',
      );
    }

    return PunchLocationResult.error(
      message: kIsWeb
          ? 'Falha ao obter a localização. Verifique a permissão do navegador e se o site esta em HTTPS ou localhost.'
          : 'Falha ao obter a localização atual do dispositivo.',
    );
  }

  LocationSettings _locationSettings() {
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      timeLimit: Duration(seconds: 12),
    );
  }
}

abstract class PunchLocationGateway {
  const PunchLocationGateway();

  Future<bool> isLocationServiceEnabled();

  Future<LocationPermission> checkPermission();

  Future<LocationPermission> requestPermission();

  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  });
}

class GeolocatorPunchLocationGateway extends PunchLocationGateway {
  const GeolocatorPunchLocationGateway();

  @override
  Future<bool> isLocationServiceEnabled() {
    return Geolocator.isLocationServiceEnabled();
  }

  @override
  Future<LocationPermission> checkPermission() {
    return Geolocator.checkPermission();
  }

  @override
  Future<LocationPermission> requestPermission() {
    return Geolocator.requestPermission();
  }

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  }) {
    return Geolocator.getCurrentPosition(locationSettings: locationSettings);
  }
}
