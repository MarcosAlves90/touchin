import 'package:touchin_flutter/contracts/contract_parsing.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:touchin_flutter/contracts/location.dart';
import 'package:flutter/material.dart';

part 'punch.freezed.dart';

enum ShiftStatus { checkedOut, working, onBreak }

enum PunchType { checkIn, breakStart, breakEnd, checkOut }

ShiftStatus shiftStatusFromApi(String value) {
  return switch (value) {
    'checkedOut' => ShiftStatus.checkedOut,
    'working' => ShiftStatus.working,
    'onBreak' => ShiftStatus.onBreak,
    _ => throw ContractParsingException(
        'Unsupported shift status value: $value',
      ),
  };
}

PunchType punchTypeFromApi(String value) {
  return switch (value) {
    'checkIn' => PunchType.checkIn,
    'breakStart' => PunchType.breakStart,
    'breakEnd' => PunchType.breakEnd,
    'checkOut' => PunchType.checkOut,
    _ => throw ContractParsingException(
        'Unsupported punch type value: $value',
      ),
  };
}

String punchTypeToApi(PunchType value) {
  return switch (value) {
    PunchType.checkIn => 'checkIn',
    PunchType.breakStart => 'breakStart',
    PunchType.breakEnd => 'breakEnd',
    PunchType.checkOut => 'checkOut',
  };
}

@freezed
abstract class PunchRecord with _$PunchRecord {
  const PunchRecord._();

  const factory PunchRecord({
    required PunchType type,
    required DateTime timestamp,
    required String detail,
    PunchLocationSnapshot? location,
  }) = _PunchRecord;

  factory PunchRecord.fromJson(JsonMap json) {
    final rawLocation = json['location'];

    return PunchRecord(
      type: punchTypeFromApi(requireString(json, 'type')),
      timestamp: requireDateTime(json, 'timestamp'),
      detail: requireString(json, 'detail'),
      location: rawLocation == null
          ? null
          : PunchLocationSnapshot.fromJson(
              requireJsonMap(rawLocation, 'location'),
            ),
    );
  }

  String get title {
    return switch (type) {
      PunchType.checkIn => 'Entrada',
      PunchType.breakStart => 'Pausa',
      PunchType.breakEnd => 'Retorno',
      PunchType.checkOut => 'Saída',
    };
  }

  IconData get icon {
    return switch (type) {
      PunchType.checkIn => Icons.login_rounded,
      PunchType.breakStart => Icons.pause_circle_outline_rounded,
      PunchType.breakEnd => Icons.play_circle_outline_rounded,
      PunchType.checkOut => Icons.logout_rounded,
    };
  }
}
