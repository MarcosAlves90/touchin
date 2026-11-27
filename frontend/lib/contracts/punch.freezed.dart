// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'punch.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PunchRecord {
  PunchType get type;
  DateTime get timestamp;
  String get detail;
  String? get projectId;
  String? get projectName;
  PunchWorkLog? get workLog;
  PunchLocationSnapshot? get location;

  /// Create a copy of PunchRecord
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PunchRecordCopyWith<PunchRecord> get copyWith =>
      _$PunchRecordCopyWithImpl<PunchRecord>(this as PunchRecord, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PunchRecord &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.detail, detail) || other.detail == detail) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.projectName, projectName) ||
                other.projectName == projectName) &&
            (identical(other.workLog, workLog) || other.workLog == workLog) &&
            (identical(other.location, location) ||
                other.location == location));
  }

  @override
  int get hashCode => Object.hash(runtimeType, type, timestamp, detail,
      projectId, projectName, workLog, location);

  @override
  String toString() {
    return 'PunchRecord(type: $type, timestamp: $timestamp, detail: $detail, projectId: $projectId, projectName: $projectName, workLog: $workLog, location: $location)';
  }
}

/// @nodoc
abstract mixin class $PunchRecordCopyWith<$Res> {
  factory $PunchRecordCopyWith(
          PunchRecord value, $Res Function(PunchRecord) _then) =
      _$PunchRecordCopyWithImpl;
  @useResult
  $Res call(
      {PunchType type,
      DateTime timestamp,
      String detail,
      String? projectId,
      String? projectName,
      PunchWorkLog? workLog,
      PunchLocationSnapshot? location});

  $PunchLocationSnapshotCopyWith<$Res>? get location;
}

/// @nodoc
class _$PunchRecordCopyWithImpl<$Res> implements $PunchRecordCopyWith<$Res> {
  _$PunchRecordCopyWithImpl(this._self, this._then);

  final PunchRecord _self;
  final $Res Function(PunchRecord) _then;

  /// Create a copy of PunchRecord
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? timestamp = null,
    Object? detail = null,
    Object? projectId = freezed,
    Object? projectName = freezed,
    Object? workLog = freezed,
    Object? location = freezed,
  }) {
    return _then(_self.copyWith(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as PunchType,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      detail: null == detail
          ? _self.detail
          : detail // ignore: cast_nullable_to_non_nullable
              as String,
      projectId: freezed == projectId
          ? _self.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      projectName: freezed == projectName
          ? _self.projectName
          : projectName // ignore: cast_nullable_to_non_nullable
              as String?,
      workLog: freezed == workLog
          ? _self.workLog
          : workLog // ignore: cast_nullable_to_non_nullable
              as PunchWorkLog?,
      location: freezed == location
          ? _self.location
          : location // ignore: cast_nullable_to_non_nullable
              as PunchLocationSnapshot?,
    ));
  }

  /// Create a copy of PunchRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PunchLocationSnapshotCopyWith<$Res>? get location {
    if (_self.location == null) {
      return null;
    }

    return $PunchLocationSnapshotCopyWith<$Res>(_self.location!, (value) {
      return _then(_self.copyWith(location: value));
    });
  }
}

/// Adds pattern-matching-related methods to [PunchRecord].
extension PunchRecordPatterns on PunchRecord {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_PunchRecord value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PunchRecord() when $default != null:
        return $default(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>(
    TResult Function(_PunchRecord value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PunchRecord():
        return $default(_that);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_PunchRecord value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PunchRecord() when $default != null:
        return $default(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            PunchType type,
            DateTime timestamp,
            String detail,
            String? projectId,
            String? projectName,
            PunchWorkLog? workLog,
            PunchLocationSnapshot? location)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PunchRecord() when $default != null:
        return $default(_that.type, _that.timestamp, _that.detail,
            _that.projectId, _that.projectName, _that.workLog, _that.location);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>(
    TResult Function(
            PunchType type,
            DateTime timestamp,
            String detail,
            String? projectId,
            String? projectName,
            PunchWorkLog? workLog,
            PunchLocationSnapshot? location)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PunchRecord():
        return $default(_that.type, _that.timestamp, _that.detail,
            _that.projectId, _that.projectName, _that.workLog, _that.location);
      case _:
        throw StateError('Unexpected subclass');
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            PunchType type,
            DateTime timestamp,
            String detail,
            String? projectId,
            String? projectName,
            PunchWorkLog? workLog,
            PunchLocationSnapshot? location)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PunchRecord() when $default != null:
        return $default(_that.type, _that.timestamp, _that.detail,
            _that.projectId, _that.projectName, _that.workLog, _that.location);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PunchRecord extends PunchRecord {
  const _PunchRecord(
      {required this.type,
      required this.timestamp,
      required this.detail,
      this.projectId,
      this.projectName,
      this.workLog,
      this.location})
      : super._();

  @override
  final PunchType type;
  @override
  final DateTime timestamp;
  @override
  final String detail;
  @override
  final String? projectId;
  @override
  final String? projectName;
  @override
  final PunchWorkLog? workLog;
  @override
  final PunchLocationSnapshot? location;

  /// Create a copy of PunchRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PunchRecordCopyWith<_PunchRecord> get copyWith =>
      __$PunchRecordCopyWithImpl<_PunchRecord>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PunchRecord &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.detail, detail) || other.detail == detail) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.projectName, projectName) ||
                other.projectName == projectName) &&
            (identical(other.workLog, workLog) || other.workLog == workLog) &&
            (identical(other.location, location) ||
                other.location == location));
  }

  @override
  int get hashCode => Object.hash(runtimeType, type, timestamp, detail,
      projectId, projectName, workLog, location);

  @override
  String toString() {
    return 'PunchRecord(type: $type, timestamp: $timestamp, detail: $detail, projectId: $projectId, projectName: $projectName, workLog: $workLog, location: $location)';
  }
}

/// @nodoc
abstract mixin class _$PunchRecordCopyWith<$Res>
    implements $PunchRecordCopyWith<$Res> {
  factory _$PunchRecordCopyWith(
          _PunchRecord value, $Res Function(_PunchRecord) _then) =
      __$PunchRecordCopyWithImpl;
  @override
  @useResult
  $Res call(
      {PunchType type,
      DateTime timestamp,
      String detail,
      String? projectId,
      String? projectName,
      PunchWorkLog? workLog,
      PunchLocationSnapshot? location});

  @override
  $PunchLocationSnapshotCopyWith<$Res>? get location;
}

/// @nodoc
class __$PunchRecordCopyWithImpl<$Res> implements _$PunchRecordCopyWith<$Res> {
  __$PunchRecordCopyWithImpl(this._self, this._then);

  final _PunchRecord _self;
  final $Res Function(_PunchRecord) _then;

  /// Create a copy of PunchRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? type = null,
    Object? timestamp = null,
    Object? detail = null,
    Object? projectId = freezed,
    Object? projectName = freezed,
    Object? workLog = freezed,
    Object? location = freezed,
  }) {
    return _then(_PunchRecord(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as PunchType,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      detail: null == detail
          ? _self.detail
          : detail // ignore: cast_nullable_to_non_nullable
              as String,
      projectId: freezed == projectId
          ? _self.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      projectName: freezed == projectName
          ? _self.projectName
          : projectName // ignore: cast_nullable_to_non_nullable
              as String?,
      workLog: freezed == workLog
          ? _self.workLog
          : workLog // ignore: cast_nullable_to_non_nullable
              as PunchWorkLog?,
      location: freezed == location
          ? _self.location
          : location // ignore: cast_nullable_to_non_nullable
              as PunchLocationSnapshot?,
    ));
  }

  /// Create a copy of PunchRecord
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $PunchLocationSnapshotCopyWith<$Res>? get location {
    if (_self.location == null) {
      return null;
    }

    return $PunchLocationSnapshotCopyWith<$Res>(_self.location!, (value) {
      return _then(_self.copyWith(location: value));
    });
  }
}

// dart format on
