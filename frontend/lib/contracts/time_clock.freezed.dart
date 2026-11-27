// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'time_clock.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$CreatePunchRequest {
  PunchType get type;
  String? get projectId;
  PunchLocationSnapshot? get location;
  WorkLogPayload? get workLog;

  /// Create a copy of CreatePunchRequest
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $CreatePunchRequestCopyWith<CreatePunchRequest> get copyWith =>
      _$CreatePunchRequestCopyWithImpl<CreatePunchRequest>(
          this as CreatePunchRequest, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is CreatePunchRequest &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.workLog, workLog) || other.workLog == workLog));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, type, projectId, location, workLog);

  @override
  String toString() {
    return 'CreatePunchRequest(type: $type, projectId: $projectId, location: $location, workLog: $workLog)';
  }
}

/// @nodoc
abstract mixin class $CreatePunchRequestCopyWith<$Res> {
  factory $CreatePunchRequestCopyWith(
          CreatePunchRequest value, $Res Function(CreatePunchRequest) _then) =
      _$CreatePunchRequestCopyWithImpl;
  @useResult
  $Res call(
      {PunchType type,
      String? projectId,
      PunchLocationSnapshot? location,
      WorkLogPayload? workLog});

  $PunchLocationSnapshotCopyWith<$Res>? get location;
}

/// @nodoc
class _$CreatePunchRequestCopyWithImpl<$Res>
    implements $CreatePunchRequestCopyWith<$Res> {
  _$CreatePunchRequestCopyWithImpl(this._self, this._then);

  final CreatePunchRequest _self;
  final $Res Function(CreatePunchRequest) _then;

  /// Create a copy of CreatePunchRequest
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? type = null,
    Object? projectId = freezed,
    Object? location = freezed,
    Object? workLog = freezed,
  }) {
    return _then(_self.copyWith(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as PunchType,
      projectId: freezed == projectId
          ? _self.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      location: freezed == location
          ? _self.location
          : location // ignore: cast_nullable_to_non_nullable
              as PunchLocationSnapshot?,
      workLog: freezed == workLog
          ? _self.workLog
          : workLog // ignore: cast_nullable_to_non_nullable
              as WorkLogPayload?,
    ));
  }

  /// Create a copy of CreatePunchRequest
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

/// Adds pattern-matching-related methods to [CreatePunchRequest].
extension CreatePunchRequestPatterns on CreatePunchRequest {
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
    TResult Function(_CreatePunchRequest value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CreatePunchRequest() when $default != null:
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
    TResult Function(_CreatePunchRequest value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreatePunchRequest():
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
    TResult? Function(_CreatePunchRequest value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreatePunchRequest() when $default != null:
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
    TResult Function(PunchType type, String? projectId,
            PunchLocationSnapshot? location, WorkLogPayload? workLog)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _CreatePunchRequest() when $default != null:
        return $default(
            _that.type, _that.projectId, _that.location, _that.workLog);
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
    TResult Function(PunchType type, String? projectId,
            PunchLocationSnapshot? location, WorkLogPayload? workLog)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreatePunchRequest():
        return $default(
            _that.type, _that.projectId, _that.location, _that.workLog);
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
    TResult? Function(PunchType type, String? projectId,
            PunchLocationSnapshot? location, WorkLogPayload? workLog)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _CreatePunchRequest() when $default != null:
        return $default(
            _that.type, _that.projectId, _that.location, _that.workLog);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _CreatePunchRequest extends CreatePunchRequest {
  const _CreatePunchRequest(
      {required this.type, this.projectId, this.location, this.workLog})
      : super._();

  @override
  final PunchType type;
  @override
  final String? projectId;
  @override
  final PunchLocationSnapshot? location;
  @override
  final WorkLogPayload? workLog;

  /// Create a copy of CreatePunchRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$CreatePunchRequestCopyWith<_CreatePunchRequest> get copyWith =>
      __$CreatePunchRequestCopyWithImpl<_CreatePunchRequest>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _CreatePunchRequest &&
            (identical(other.type, type) || other.type == type) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.location, location) ||
                other.location == location) &&
            (identical(other.workLog, workLog) || other.workLog == workLog));
  }

  @override
  int get hashCode =>
      Object.hash(runtimeType, type, projectId, location, workLog);

  @override
  String toString() {
    return 'CreatePunchRequest(type: $type, projectId: $projectId, location: $location, workLog: $workLog)';
  }
}

/// @nodoc
abstract mixin class _$CreatePunchRequestCopyWith<$Res>
    implements $CreatePunchRequestCopyWith<$Res> {
  factory _$CreatePunchRequestCopyWith(
          _CreatePunchRequest value, $Res Function(_CreatePunchRequest) _then) =
      __$CreatePunchRequestCopyWithImpl;
  @override
  @useResult
  $Res call(
      {PunchType type,
      String? projectId,
      PunchLocationSnapshot? location,
      WorkLogPayload? workLog});

  @override
  $PunchLocationSnapshotCopyWith<$Res>? get location;
}

/// @nodoc
class __$CreatePunchRequestCopyWithImpl<$Res>
    implements _$CreatePunchRequestCopyWith<$Res> {
  __$CreatePunchRequestCopyWithImpl(this._self, this._then);

  final _CreatePunchRequest _self;
  final $Res Function(_CreatePunchRequest) _then;

  /// Create a copy of CreatePunchRequest
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? type = null,
    Object? projectId = freezed,
    Object? location = freezed,
    Object? workLog = freezed,
  }) {
    return _then(_CreatePunchRequest(
      type: null == type
          ? _self.type
          : type // ignore: cast_nullable_to_non_nullable
              as PunchType,
      projectId: freezed == projectId
          ? _self.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      location: freezed == location
          ? _self.location
          : location // ignore: cast_nullable_to_non_nullable
              as PunchLocationSnapshot?,
      workLog: freezed == workLog
          ? _self.workLog
          : workLog // ignore: cast_nullable_to_non_nullable
              as WorkLogPayload?,
    ));
  }

  /// Create a copy of CreatePunchRequest
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

/// @nodoc
mixin _$TimeClockEmployeeSummary {
  String get id;
  String get name;
  String get unit;
  EmployeeStatus get status;
  EmployeeWorkMode get workMode;
  bool get requiresLocationOnPunch;
  bool get trustedDeviceRequired;

  /// Create a copy of TimeClockEmployeeSummary
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TimeClockEmployeeSummaryCopyWith<TimeClockEmployeeSummary> get copyWith =>
      _$TimeClockEmployeeSummaryCopyWithImpl<TimeClockEmployeeSummary>(
          this as TimeClockEmployeeSummary, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TimeClockEmployeeSummary &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.workMode, workMode) ||
                other.workMode == workMode) &&
            (identical(
                    other.requiresLocationOnPunch, requiresLocationOnPunch) ||
                other.requiresLocationOnPunch == requiresLocationOnPunch) &&
            (identical(other.trustedDeviceRequired, trustedDeviceRequired) ||
                other.trustedDeviceRequired == trustedDeviceRequired));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, name, unit, status, workMode,
      requiresLocationOnPunch, trustedDeviceRequired);

  @override
  String toString() {
    return 'TimeClockEmployeeSummary(id: $id, name: $name, unit: $unit, status: $status, workMode: $workMode, requiresLocationOnPunch: $requiresLocationOnPunch, trustedDeviceRequired: $trustedDeviceRequired)';
  }
}

/// @nodoc
abstract mixin class $TimeClockEmployeeSummaryCopyWith<$Res> {
  factory $TimeClockEmployeeSummaryCopyWith(TimeClockEmployeeSummary value,
          $Res Function(TimeClockEmployeeSummary) _then) =
      _$TimeClockEmployeeSummaryCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      String name,
      String unit,
      EmployeeStatus status,
      EmployeeWorkMode workMode,
      bool requiresLocationOnPunch,
      bool trustedDeviceRequired});
}

/// @nodoc
class _$TimeClockEmployeeSummaryCopyWithImpl<$Res>
    implements $TimeClockEmployeeSummaryCopyWith<$Res> {
  _$TimeClockEmployeeSummaryCopyWithImpl(this._self, this._then);

  final TimeClockEmployeeSummary _self;
  final $Res Function(TimeClockEmployeeSummary) _then;

  /// Create a copy of TimeClockEmployeeSummary
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? unit = null,
    Object? status = null,
    Object? workMode = null,
    Object? requiresLocationOnPunch = null,
    Object? trustedDeviceRequired = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as EmployeeStatus,
      workMode: null == workMode
          ? _self.workMode
          : workMode // ignore: cast_nullable_to_non_nullable
              as EmployeeWorkMode,
      requiresLocationOnPunch: null == requiresLocationOnPunch
          ? _self.requiresLocationOnPunch
          : requiresLocationOnPunch // ignore: cast_nullable_to_non_nullable
              as bool,
      trustedDeviceRequired: null == trustedDeviceRequired
          ? _self.trustedDeviceRequired
          : trustedDeviceRequired // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// Adds pattern-matching-related methods to [TimeClockEmployeeSummary].
extension TimeClockEmployeeSummaryPatterns on TimeClockEmployeeSummary {
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
    TResult Function(_TimeClockEmployeeSummary value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TimeClockEmployeeSummary() when $default != null:
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
    TResult Function(_TimeClockEmployeeSummary value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TimeClockEmployeeSummary():
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
    TResult? Function(_TimeClockEmployeeSummary value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TimeClockEmployeeSummary() when $default != null:
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
            String id,
            String name,
            String unit,
            EmployeeStatus status,
            EmployeeWorkMode workMode,
            bool requiresLocationOnPunch,
            bool trustedDeviceRequired)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TimeClockEmployeeSummary() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.unit,
            _that.status,
            _that.workMode,
            _that.requiresLocationOnPunch,
            _that.trustedDeviceRequired);
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
            String id,
            String name,
            String unit,
            EmployeeStatus status,
            EmployeeWorkMode workMode,
            bool requiresLocationOnPunch,
            bool trustedDeviceRequired)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TimeClockEmployeeSummary():
        return $default(
            _that.id,
            _that.name,
            _that.unit,
            _that.status,
            _that.workMode,
            _that.requiresLocationOnPunch,
            _that.trustedDeviceRequired);
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
            String id,
            String name,
            String unit,
            EmployeeStatus status,
            EmployeeWorkMode workMode,
            bool requiresLocationOnPunch,
            bool trustedDeviceRequired)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TimeClockEmployeeSummary() when $default != null:
        return $default(
            _that.id,
            _that.name,
            _that.unit,
            _that.status,
            _that.workMode,
            _that.requiresLocationOnPunch,
            _that.trustedDeviceRequired);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _TimeClockEmployeeSummary extends TimeClockEmployeeSummary {
  const _TimeClockEmployeeSummary(
      {required this.id,
      required this.name,
      required this.unit,
      required this.status,
      required this.workMode,
      required this.requiresLocationOnPunch,
      required this.trustedDeviceRequired})
      : super._();

  @override
  final String id;
  @override
  final String name;
  @override
  final String unit;
  @override
  final EmployeeStatus status;
  @override
  final EmployeeWorkMode workMode;
  @override
  final bool requiresLocationOnPunch;
  @override
  final bool trustedDeviceRequired;

  /// Create a copy of TimeClockEmployeeSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TimeClockEmployeeSummaryCopyWith<_TimeClockEmployeeSummary> get copyWith =>
      __$TimeClockEmployeeSummaryCopyWithImpl<_TimeClockEmployeeSummary>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TimeClockEmployeeSummary &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.workMode, workMode) ||
                other.workMode == workMode) &&
            (identical(
                    other.requiresLocationOnPunch, requiresLocationOnPunch) ||
                other.requiresLocationOnPunch == requiresLocationOnPunch) &&
            (identical(other.trustedDeviceRequired, trustedDeviceRequired) ||
                other.trustedDeviceRequired == trustedDeviceRequired));
  }

  @override
  int get hashCode => Object.hash(runtimeType, id, name, unit, status, workMode,
      requiresLocationOnPunch, trustedDeviceRequired);

  @override
  String toString() {
    return 'TimeClockEmployeeSummary(id: $id, name: $name, unit: $unit, status: $status, workMode: $workMode, requiresLocationOnPunch: $requiresLocationOnPunch, trustedDeviceRequired: $trustedDeviceRequired)';
  }
}

/// @nodoc
abstract mixin class _$TimeClockEmployeeSummaryCopyWith<$Res>
    implements $TimeClockEmployeeSummaryCopyWith<$Res> {
  factory _$TimeClockEmployeeSummaryCopyWith(_TimeClockEmployeeSummary value,
          $Res Function(_TimeClockEmployeeSummary) _then) =
      __$TimeClockEmployeeSummaryCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      String name,
      String unit,
      EmployeeStatus status,
      EmployeeWorkMode workMode,
      bool requiresLocationOnPunch,
      bool trustedDeviceRequired});
}

/// @nodoc
class __$TimeClockEmployeeSummaryCopyWithImpl<$Res>
    implements _$TimeClockEmployeeSummaryCopyWith<$Res> {
  __$TimeClockEmployeeSummaryCopyWithImpl(this._self, this._then);

  final _TimeClockEmployeeSummary _self;
  final $Res Function(_TimeClockEmployeeSummary) _then;

  /// Create a copy of TimeClockEmployeeSummary
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? name = null,
    Object? unit = null,
    Object? status = null,
    Object? workMode = null,
    Object? requiresLocationOnPunch = null,
    Object? trustedDeviceRequired = null,
  }) {
    return _then(_TimeClockEmployeeSummary(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as EmployeeStatus,
      workMode: null == workMode
          ? _self.workMode
          : workMode // ignore: cast_nullable_to_non_nullable
              as EmployeeWorkMode,
      requiresLocationOnPunch: null == requiresLocationOnPunch
          ? _self.requiresLocationOnPunch
          : requiresLocationOnPunch // ignore: cast_nullable_to_non_nullable
              as bool,
      trustedDeviceRequired: null == trustedDeviceRequired
          ? _self.trustedDeviceRequired
          : trustedDeviceRequired // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc
mixin _$TimeClockState {
  TimeClockEmployeeSummary get employee;
  ShiftStatus get currentStatus;
  int get todayWorkedMinutes;
  int get todayBreakMinutes;
  DateTime? get firstCheckInAt;
  DateTime? get lastPunchAt;
  List<PunchRecord> get records;
  int get recordsPage;
  int get recordsPageSize;
  int get recordsTotal;
  int get recordsTotalPages;
  bool get recordsHasPrevious;
  bool get recordsHasNext;

  /// Create a copy of TimeClockState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $TimeClockStateCopyWith<TimeClockState> get copyWith =>
      _$TimeClockStateCopyWithImpl<TimeClockState>(
          this as TimeClockState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is TimeClockState &&
            (identical(other.employee, employee) ||
                other.employee == employee) &&
            (identical(other.currentStatus, currentStatus) ||
                other.currentStatus == currentStatus) &&
            (identical(other.todayWorkedMinutes, todayWorkedMinutes) ||
                other.todayWorkedMinutes == todayWorkedMinutes) &&
            (identical(other.todayBreakMinutes, todayBreakMinutes) ||
                other.todayBreakMinutes == todayBreakMinutes) &&
            (identical(other.firstCheckInAt, firstCheckInAt) ||
                other.firstCheckInAt == firstCheckInAt) &&
            (identical(other.lastPunchAt, lastPunchAt) ||
                other.lastPunchAt == lastPunchAt) &&
            const DeepCollectionEquality().equals(other.records, records) &&
            (identical(other.recordsPage, recordsPage) ||
                other.recordsPage == recordsPage) &&
            (identical(other.recordsPageSize, recordsPageSize) ||
                other.recordsPageSize == recordsPageSize) &&
            (identical(other.recordsTotal, recordsTotal) ||
                other.recordsTotal == recordsTotal) &&
            (identical(other.recordsTotalPages, recordsTotalPages) ||
                other.recordsTotalPages == recordsTotalPages) &&
            (identical(other.recordsHasPrevious, recordsHasPrevious) ||
                other.recordsHasPrevious == recordsHasPrevious) &&
            (identical(other.recordsHasNext, recordsHasNext) ||
                other.recordsHasNext == recordsHasNext));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      employee,
      currentStatus,
      todayWorkedMinutes,
      todayBreakMinutes,
      firstCheckInAt,
      lastPunchAt,
      const DeepCollectionEquality().hash(records),
      recordsPage,
      recordsPageSize,
      recordsTotal,
      recordsTotalPages,
      recordsHasPrevious,
      recordsHasNext);

  @override
  String toString() {
    return 'TimeClockState(employee: $employee, currentStatus: $currentStatus, todayWorkedMinutes: $todayWorkedMinutes, todayBreakMinutes: $todayBreakMinutes, firstCheckInAt: $firstCheckInAt, lastPunchAt: $lastPunchAt, records: $records, recordsPage: $recordsPage, recordsPageSize: $recordsPageSize, recordsTotal: $recordsTotal, recordsTotalPages: $recordsTotalPages, recordsHasPrevious: $recordsHasPrevious, recordsHasNext: $recordsHasNext)';
  }
}

/// @nodoc
abstract mixin class $TimeClockStateCopyWith<$Res> {
  factory $TimeClockStateCopyWith(
          TimeClockState value, $Res Function(TimeClockState) _then) =
      _$TimeClockStateCopyWithImpl;
  @useResult
  $Res call(
      {TimeClockEmployeeSummary employee,
      ShiftStatus currentStatus,
      int todayWorkedMinutes,
      int todayBreakMinutes,
      DateTime? firstCheckInAt,
      DateTime? lastPunchAt,
      List<PunchRecord> records,
      int recordsPage,
      int recordsPageSize,
      int recordsTotal,
      int recordsTotalPages,
      bool recordsHasPrevious,
      bool recordsHasNext});

  $TimeClockEmployeeSummaryCopyWith<$Res> get employee;
}

/// @nodoc
class _$TimeClockStateCopyWithImpl<$Res>
    implements $TimeClockStateCopyWith<$Res> {
  _$TimeClockStateCopyWithImpl(this._self, this._then);

  final TimeClockState _self;
  final $Res Function(TimeClockState) _then;

  /// Create a copy of TimeClockState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? employee = null,
    Object? currentStatus = null,
    Object? todayWorkedMinutes = null,
    Object? todayBreakMinutes = null,
    Object? firstCheckInAt = freezed,
    Object? lastPunchAt = freezed,
    Object? records = null,
    Object? recordsPage = null,
    Object? recordsPageSize = null,
    Object? recordsTotal = null,
    Object? recordsTotalPages = null,
    Object? recordsHasPrevious = null,
    Object? recordsHasNext = null,
  }) {
    return _then(_self.copyWith(
      employee: null == employee
          ? _self.employee
          : employee // ignore: cast_nullable_to_non_nullable
              as TimeClockEmployeeSummary,
      currentStatus: null == currentStatus
          ? _self.currentStatus
          : currentStatus // ignore: cast_nullable_to_non_nullable
              as ShiftStatus,
      todayWorkedMinutes: null == todayWorkedMinutes
          ? _self.todayWorkedMinutes
          : todayWorkedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      todayBreakMinutes: null == todayBreakMinutes
          ? _self.todayBreakMinutes
          : todayBreakMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      firstCheckInAt: freezed == firstCheckInAt
          ? _self.firstCheckInAt
          : firstCheckInAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastPunchAt: freezed == lastPunchAt
          ? _self.lastPunchAt
          : lastPunchAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      records: null == records
          ? _self.records
          : records // ignore: cast_nullable_to_non_nullable
              as List<PunchRecord>,
      recordsPage: null == recordsPage
          ? _self.recordsPage
          : recordsPage // ignore: cast_nullable_to_non_nullable
              as int,
      recordsPageSize: null == recordsPageSize
          ? _self.recordsPageSize
          : recordsPageSize // ignore: cast_nullable_to_non_nullable
              as int,
      recordsTotal: null == recordsTotal
          ? _self.recordsTotal
          : recordsTotal // ignore: cast_nullable_to_non_nullable
              as int,
      recordsTotalPages: null == recordsTotalPages
          ? _self.recordsTotalPages
          : recordsTotalPages // ignore: cast_nullable_to_non_nullable
              as int,
      recordsHasPrevious: null == recordsHasPrevious
          ? _self.recordsHasPrevious
          : recordsHasPrevious // ignore: cast_nullable_to_non_nullable
              as bool,
      recordsHasNext: null == recordsHasNext
          ? _self.recordsHasNext
          : recordsHasNext // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of TimeClockState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TimeClockEmployeeSummaryCopyWith<$Res> get employee {
    return $TimeClockEmployeeSummaryCopyWith<$Res>(_self.employee, (value) {
      return _then(_self.copyWith(employee: value));
    });
  }
}

/// Adds pattern-matching-related methods to [TimeClockState].
extension TimeClockStatePatterns on TimeClockState {
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
    TResult Function(_TimeClockState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TimeClockState() when $default != null:
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
    TResult Function(_TimeClockState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TimeClockState():
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
    TResult? Function(_TimeClockState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TimeClockState() when $default != null:
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
            TimeClockEmployeeSummary employee,
            ShiftStatus currentStatus,
            int todayWorkedMinutes,
            int todayBreakMinutes,
            DateTime? firstCheckInAt,
            DateTime? lastPunchAt,
            List<PunchRecord> records,
            int recordsPage,
            int recordsPageSize,
            int recordsTotal,
            int recordsTotalPages,
            bool recordsHasPrevious,
            bool recordsHasNext)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _TimeClockState() when $default != null:
        return $default(
            _that.employee,
            _that.currentStatus,
            _that.todayWorkedMinutes,
            _that.todayBreakMinutes,
            _that.firstCheckInAt,
            _that.lastPunchAt,
            _that.records,
            _that.recordsPage,
            _that.recordsPageSize,
            _that.recordsTotal,
            _that.recordsTotalPages,
            _that.recordsHasPrevious,
            _that.recordsHasNext);
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
            TimeClockEmployeeSummary employee,
            ShiftStatus currentStatus,
            int todayWorkedMinutes,
            int todayBreakMinutes,
            DateTime? firstCheckInAt,
            DateTime? lastPunchAt,
            List<PunchRecord> records,
            int recordsPage,
            int recordsPageSize,
            int recordsTotal,
            int recordsTotalPages,
            bool recordsHasPrevious,
            bool recordsHasNext)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TimeClockState():
        return $default(
            _that.employee,
            _that.currentStatus,
            _that.todayWorkedMinutes,
            _that.todayBreakMinutes,
            _that.firstCheckInAt,
            _that.lastPunchAt,
            _that.records,
            _that.recordsPage,
            _that.recordsPageSize,
            _that.recordsTotal,
            _that.recordsTotalPages,
            _that.recordsHasPrevious,
            _that.recordsHasNext);
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
            TimeClockEmployeeSummary employee,
            ShiftStatus currentStatus,
            int todayWorkedMinutes,
            int todayBreakMinutes,
            DateTime? firstCheckInAt,
            DateTime? lastPunchAt,
            List<PunchRecord> records,
            int recordsPage,
            int recordsPageSize,
            int recordsTotal,
            int recordsTotalPages,
            bool recordsHasPrevious,
            bool recordsHasNext)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _TimeClockState() when $default != null:
        return $default(
            _that.employee,
            _that.currentStatus,
            _that.todayWorkedMinutes,
            _that.todayBreakMinutes,
            _that.firstCheckInAt,
            _that.lastPunchAt,
            _that.records,
            _that.recordsPage,
            _that.recordsPageSize,
            _that.recordsTotal,
            _that.recordsTotalPages,
            _that.recordsHasPrevious,
            _that.recordsHasNext);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _TimeClockState extends TimeClockState {
  const _TimeClockState(
      {required this.employee,
      required this.currentStatus,
      required this.todayWorkedMinutes,
      required this.todayBreakMinutes,
      required this.firstCheckInAt,
      required this.lastPunchAt,
      required final List<PunchRecord> records,
      required this.recordsPage,
      required this.recordsPageSize,
      required this.recordsTotal,
      required this.recordsTotalPages,
      required this.recordsHasPrevious,
      required this.recordsHasNext})
      : _records = records,
        super._();

  @override
  final TimeClockEmployeeSummary employee;
  @override
  final ShiftStatus currentStatus;
  @override
  final int todayWorkedMinutes;
  @override
  final int todayBreakMinutes;
  @override
  final DateTime? firstCheckInAt;
  @override
  final DateTime? lastPunchAt;
  final List<PunchRecord> _records;
  @override
  List<PunchRecord> get records {
    if (_records is EqualUnmodifiableListView) return _records;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_records);
  }

  @override
  final int recordsPage;
  @override
  final int recordsPageSize;
  @override
  final int recordsTotal;
  @override
  final int recordsTotalPages;
  @override
  final bool recordsHasPrevious;
  @override
  final bool recordsHasNext;

  /// Create a copy of TimeClockState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$TimeClockStateCopyWith<_TimeClockState> get copyWith =>
      __$TimeClockStateCopyWithImpl<_TimeClockState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _TimeClockState &&
            (identical(other.employee, employee) ||
                other.employee == employee) &&
            (identical(other.currentStatus, currentStatus) ||
                other.currentStatus == currentStatus) &&
            (identical(other.todayWorkedMinutes, todayWorkedMinutes) ||
                other.todayWorkedMinutes == todayWorkedMinutes) &&
            (identical(other.todayBreakMinutes, todayBreakMinutes) ||
                other.todayBreakMinutes == todayBreakMinutes) &&
            (identical(other.firstCheckInAt, firstCheckInAt) ||
                other.firstCheckInAt == firstCheckInAt) &&
            (identical(other.lastPunchAt, lastPunchAt) ||
                other.lastPunchAt == lastPunchAt) &&
            const DeepCollectionEquality().equals(other._records, _records) &&
            (identical(other.recordsPage, recordsPage) ||
                other.recordsPage == recordsPage) &&
            (identical(other.recordsPageSize, recordsPageSize) ||
                other.recordsPageSize == recordsPageSize) &&
            (identical(other.recordsTotal, recordsTotal) ||
                other.recordsTotal == recordsTotal) &&
            (identical(other.recordsTotalPages, recordsTotalPages) ||
                other.recordsTotalPages == recordsTotalPages) &&
            (identical(other.recordsHasPrevious, recordsHasPrevious) ||
                other.recordsHasPrevious == recordsHasPrevious) &&
            (identical(other.recordsHasNext, recordsHasNext) ||
                other.recordsHasNext == recordsHasNext));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      employee,
      currentStatus,
      todayWorkedMinutes,
      todayBreakMinutes,
      firstCheckInAt,
      lastPunchAt,
      const DeepCollectionEquality().hash(_records),
      recordsPage,
      recordsPageSize,
      recordsTotal,
      recordsTotalPages,
      recordsHasPrevious,
      recordsHasNext);

  @override
  String toString() {
    return 'TimeClockState(employee: $employee, currentStatus: $currentStatus, todayWorkedMinutes: $todayWorkedMinutes, todayBreakMinutes: $todayBreakMinutes, firstCheckInAt: $firstCheckInAt, lastPunchAt: $lastPunchAt, records: $records, recordsPage: $recordsPage, recordsPageSize: $recordsPageSize, recordsTotal: $recordsTotal, recordsTotalPages: $recordsTotalPages, recordsHasPrevious: $recordsHasPrevious, recordsHasNext: $recordsHasNext)';
  }
}

/// @nodoc
abstract mixin class _$TimeClockStateCopyWith<$Res>
    implements $TimeClockStateCopyWith<$Res> {
  factory _$TimeClockStateCopyWith(
          _TimeClockState value, $Res Function(_TimeClockState) _then) =
      __$TimeClockStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {TimeClockEmployeeSummary employee,
      ShiftStatus currentStatus,
      int todayWorkedMinutes,
      int todayBreakMinutes,
      DateTime? firstCheckInAt,
      DateTime? lastPunchAt,
      List<PunchRecord> records,
      int recordsPage,
      int recordsPageSize,
      int recordsTotal,
      int recordsTotalPages,
      bool recordsHasPrevious,
      bool recordsHasNext});

  @override
  $TimeClockEmployeeSummaryCopyWith<$Res> get employee;
}

/// @nodoc
class __$TimeClockStateCopyWithImpl<$Res>
    implements _$TimeClockStateCopyWith<$Res> {
  __$TimeClockStateCopyWithImpl(this._self, this._then);

  final _TimeClockState _self;
  final $Res Function(_TimeClockState) _then;

  /// Create a copy of TimeClockState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? employee = null,
    Object? currentStatus = null,
    Object? todayWorkedMinutes = null,
    Object? todayBreakMinutes = null,
    Object? firstCheckInAt = freezed,
    Object? lastPunchAt = freezed,
    Object? records = null,
    Object? recordsPage = null,
    Object? recordsPageSize = null,
    Object? recordsTotal = null,
    Object? recordsTotalPages = null,
    Object? recordsHasPrevious = null,
    Object? recordsHasNext = null,
  }) {
    return _then(_TimeClockState(
      employee: null == employee
          ? _self.employee
          : employee // ignore: cast_nullable_to_non_nullable
              as TimeClockEmployeeSummary,
      currentStatus: null == currentStatus
          ? _self.currentStatus
          : currentStatus // ignore: cast_nullable_to_non_nullable
              as ShiftStatus,
      todayWorkedMinutes: null == todayWorkedMinutes
          ? _self.todayWorkedMinutes
          : todayWorkedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      todayBreakMinutes: null == todayBreakMinutes
          ? _self.todayBreakMinutes
          : todayBreakMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      firstCheckInAt: freezed == firstCheckInAt
          ? _self.firstCheckInAt
          : firstCheckInAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      lastPunchAt: freezed == lastPunchAt
          ? _self.lastPunchAt
          : lastPunchAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      records: null == records
          ? _self._records
          : records // ignore: cast_nullable_to_non_nullable
              as List<PunchRecord>,
      recordsPage: null == recordsPage
          ? _self.recordsPage
          : recordsPage // ignore: cast_nullable_to_non_nullable
              as int,
      recordsPageSize: null == recordsPageSize
          ? _self.recordsPageSize
          : recordsPageSize // ignore: cast_nullable_to_non_nullable
              as int,
      recordsTotal: null == recordsTotal
          ? _self.recordsTotal
          : recordsTotal // ignore: cast_nullable_to_non_nullable
              as int,
      recordsTotalPages: null == recordsTotalPages
          ? _self.recordsTotalPages
          : recordsTotalPages // ignore: cast_nullable_to_non_nullable
              as int,
      recordsHasPrevious: null == recordsHasPrevious
          ? _self.recordsHasPrevious
          : recordsHasPrevious // ignore: cast_nullable_to_non_nullable
              as bool,
      recordsHasNext: null == recordsHasNext
          ? _self.recordsHasNext
          : recordsHasNext // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }

  /// Create a copy of TimeClockState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $TimeClockEmployeeSummaryCopyWith<$Res> get employee {
    return $TimeClockEmployeeSummaryCopyWith<$Res>(_self.employee, (value) {
      return _then(_self.copyWith(employee: value));
    });
  }
}

// dart format on
