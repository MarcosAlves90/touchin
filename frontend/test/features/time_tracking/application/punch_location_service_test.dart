import 'dart:async';

import 'package:touchin_flutter/features/time_tracking/application/punch_location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class _FakePunchLocationGateway extends PunchLocationGateway {
  _FakePunchLocationGateway({
    required this.servicesEnabled,
    required this.checkPermissionResult,
    required this.requestPermissionResult,
    required this.position,
    this.positionError,
  });

  final bool servicesEnabled;
  final LocationPermission checkPermissionResult;
  final LocationPermission requestPermissionResult;
  final Position position;
  final Object? positionError;

  int checkPermissionCalls = 0;
  int requestPermissionCalls = 0;
  int getCurrentPositionCalls = 0;

  @override
  Future<bool> isLocationServiceEnabled() async => servicesEnabled;

  @override
  Future<LocationPermission> checkPermission() async {
    checkPermissionCalls += 1;
    return checkPermissionResult;
  }

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls += 1;
    return requestPermissionResult;
  }

  @override
  Future<Position> getCurrentPosition({
    required LocationSettings locationSettings,
  }) async {
    getCurrentPositionCalls += 1;
    if (positionError != null) {
      throw positionError!;
    }
    return position;
  }
}

Position _position() {
  return Position(
    latitude: -23.55052,
    longitude: -46.63331,
    timestamp: DateTime.utc(2026, 5, 24, 13, 30),
    accuracy: 7.5,
    altitude: 760.0,
    altitudeAccuracy: 1.0,
    heading: 0.0,
    headingAccuracy: 0.0,
    speed: 0.0,
    speedAccuracy: 0.0,
  );
}

void main() {
  test(
    'requestPermission stays in checking state when permission is granted but position is unavailable',
    () async {
      final gateway = _FakePunchLocationGateway(
        servicesEnabled: true,
        checkPermissionResult: LocationPermission.whileInUse,
        requestPermissionResult: LocationPermission.whileInUse,
        position: _position(),
        positionError: TimeoutException('timeout'),
      );

      final service = PunchLocationService(gateway: gateway);
      final result = await service.requestPermission();

      expect(result.status, PunchLocationStatus.checking);
      expect(result.snapshot, isNull);
      expect(gateway.checkPermissionCalls, 1);
      expect(gateway.requestPermissionCalls, 0);
      expect(gateway.getCurrentPositionCalls, 1);
    },
  );

  test(
    'captureForPunch validates by position even when permission APIs lie',
    () async {
      final gateway = _FakePunchLocationGateway(
        servicesEnabled: true,
        checkPermissionResult: LocationPermission.denied,
        requestPermissionResult: LocationPermission.denied,
        position: _position(),
      );

      final service = PunchLocationService(gateway: gateway);
      final result = await service.captureForPunch();

      expect(result.isReady, isTrue);
      expect(result.snapshot, isNotNull);
      expect(result.snapshot?.latitude, closeTo(-23.55052, 0.00001));
      expect(gateway.checkPermissionCalls, 0);
      expect(gateway.requestPermissionCalls, 0);
      expect(gateway.getCurrentPositionCalls, 1);
    },
  );

  test(
    'requestPermission falls back to current position when permission APIs lie',
    () async {
      final gateway = _FakePunchLocationGateway(
        servicesEnabled: true,
        checkPermissionResult: LocationPermission.denied,
        requestPermissionResult: LocationPermission.denied,
        position: _position(),
      );

      final service = PunchLocationService(gateway: gateway);
      final result = await service.requestPermission();

      expect(result.isReady, isTrue);
      expect(result.snapshot, isNotNull);
      expect(result.snapshot?.latitude, closeTo(-23.55052, 0.00001));
      expect(gateway.checkPermissionCalls, 1);
      expect(gateway.requestPermissionCalls, 1);
      expect(gateway.getCurrentPositionCalls, 1);
    },
  );
}
