// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'employee.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$EmployeeProfile {
  String get id;
  bool? get hasAccount;
  String? get accessRole;
  String get name;
  String get role;
  String get department;
  String get email;
  String get phone;
  String get unit;
  TimeOfDay get expectedShiftStart;
  TimeOfDay get expectedShiftEnd;
  EmployeeStatus get status;
  EmployeeWorkMode get workMode;
  RoleLevel get roleLevel;
  bool get requiresLocationOnPunch;
  bool get trustedDeviceRequired;
  int get todayWorkedMinutes;
  int get pendingAdjustments;
  DateTime? get lastPunchAt;
  String get notes;

  /// Create a copy of EmployeeProfile
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $EmployeeProfileCopyWith<EmployeeProfile> get copyWith =>
      _$EmployeeProfileCopyWithImpl<EmployeeProfile>(
          this as EmployeeProfile, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is EmployeeProfile &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.hasAccount, hasAccount) ||
                other.hasAccount == hasAccount) &&
            (identical(other.accessRole, accessRole) ||
                other.accessRole == accessRole) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.department, department) ||
                other.department == department) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.expectedShiftStart, expectedShiftStart) ||
                other.expectedShiftStart == expectedShiftStart) &&
            (identical(other.expectedShiftEnd, expectedShiftEnd) ||
                other.expectedShiftEnd == expectedShiftEnd) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.workMode, workMode) ||
                other.workMode == workMode) &&
            (identical(other.roleLevel, roleLevel) ||
                other.roleLevel == roleLevel) &&
            (identical(
                    other.requiresLocationOnPunch, requiresLocationOnPunch) ||
                other.requiresLocationOnPunch == requiresLocationOnPunch) &&
            (identical(other.trustedDeviceRequired, trustedDeviceRequired) ||
                other.trustedDeviceRequired == trustedDeviceRequired) &&
            (identical(other.todayWorkedMinutes, todayWorkedMinutes) ||
                other.todayWorkedMinutes == todayWorkedMinutes) &&
            (identical(other.pendingAdjustments, pendingAdjustments) ||
                other.pendingAdjustments == pendingAdjustments) &&
            (identical(other.lastPunchAt, lastPunchAt) ||
                other.lastPunchAt == lastPunchAt) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        hasAccount,
        accessRole,
        name,
        role,
        department,
        email,
        phone,
        unit,
        expectedShiftStart,
        expectedShiftEnd,
        status,
        workMode,
        roleLevel,
        requiresLocationOnPunch,
        trustedDeviceRequired,
        todayWorkedMinutes,
        pendingAdjustments,
        lastPunchAt,
        notes
      ]);

  @override
  String toString() {
    return 'EmployeeProfile(id: $id, hasAccount: $hasAccount, accessRole: $accessRole, name: $name, role: $role, department: $department, email: $email, phone: $phone, unit: $unit, expectedShiftStart: $expectedShiftStart, expectedShiftEnd: $expectedShiftEnd, status: $status, workMode: $workMode, roleLevel: $roleLevel, requiresLocationOnPunch: $requiresLocationOnPunch, trustedDeviceRequired: $trustedDeviceRequired, todayWorkedMinutes: $todayWorkedMinutes, pendingAdjustments: $pendingAdjustments, lastPunchAt: $lastPunchAt, notes: $notes)';
  }
}

/// @nodoc
abstract mixin class $EmployeeProfileCopyWith<$Res> {
  factory $EmployeeProfileCopyWith(
          EmployeeProfile value, $Res Function(EmployeeProfile) _then) =
      _$EmployeeProfileCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      bool? hasAccount,
      String? accessRole,
      String name,
      String role,
      String department,
      String email,
      String phone,
      String unit,
      TimeOfDay expectedShiftStart,
      TimeOfDay expectedShiftEnd,
      EmployeeStatus status,
      EmployeeWorkMode workMode,
      RoleLevel roleLevel,
      bool requiresLocationOnPunch,
      bool trustedDeviceRequired,
      int todayWorkedMinutes,
      int pendingAdjustments,
      DateTime? lastPunchAt,
      String notes});
}

/// @nodoc
class _$EmployeeProfileCopyWithImpl<$Res>
    implements $EmployeeProfileCopyWith<$Res> {
  _$EmployeeProfileCopyWithImpl(this._self, this._then);

  final EmployeeProfile _self;
  final $Res Function(EmployeeProfile) _then;

  /// Create a copy of EmployeeProfile
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? hasAccount = freezed,
    Object? accessRole = freezed,
    Object? name = null,
    Object? role = null,
    Object? department = null,
    Object? email = null,
    Object? phone = null,
    Object? unit = null,
    Object? expectedShiftStart = null,
    Object? expectedShiftEnd = null,
    Object? status = null,
    Object? workMode = null,
    Object? roleLevel = null,
    Object? requiresLocationOnPunch = null,
    Object? trustedDeviceRequired = null,
    Object? todayWorkedMinutes = null,
    Object? pendingAdjustments = null,
    Object? lastPunchAt = freezed,
    Object? notes = null,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      hasAccount: freezed == hasAccount
          ? _self.hasAccount
          : hasAccount // ignore: cast_nullable_to_non_nullable
              as bool?,
      accessRole: freezed == accessRole
          ? _self.accessRole
          : accessRole // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      department: null == department
          ? _self.department
          : department // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _self.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _self.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      expectedShiftStart: null == expectedShiftStart
          ? _self.expectedShiftStart
          : expectedShiftStart // ignore: cast_nullable_to_non_nullable
              as TimeOfDay,
      expectedShiftEnd: null == expectedShiftEnd
          ? _self.expectedShiftEnd
          : expectedShiftEnd // ignore: cast_nullable_to_non_nullable
              as TimeOfDay,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as EmployeeStatus,
      workMode: null == workMode
          ? _self.workMode
          : workMode // ignore: cast_nullable_to_non_nullable
              as EmployeeWorkMode,
      roleLevel: null == roleLevel
          ? _self.roleLevel
          : roleLevel // ignore: cast_nullable_to_non_nullable
              as RoleLevel,
      requiresLocationOnPunch: null == requiresLocationOnPunch
          ? _self.requiresLocationOnPunch
          : requiresLocationOnPunch // ignore: cast_nullable_to_non_nullable
              as bool,
      trustedDeviceRequired: null == trustedDeviceRequired
          ? _self.trustedDeviceRequired
          : trustedDeviceRequired // ignore: cast_nullable_to_non_nullable
              as bool,
      todayWorkedMinutes: null == todayWorkedMinutes
          ? _self.todayWorkedMinutes
          : todayWorkedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      pendingAdjustments: null == pendingAdjustments
          ? _self.pendingAdjustments
          : pendingAdjustments // ignore: cast_nullable_to_non_nullable
              as int,
      lastPunchAt: freezed == lastPunchAt
          ? _self.lastPunchAt
          : lastPunchAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      notes: null == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

/// Adds pattern-matching-related methods to [EmployeeProfile].
extension EmployeeProfilePatterns on EmployeeProfile {
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
    TResult Function(_EmployeeProfile value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _EmployeeProfile() when $default != null:
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
    TResult Function(_EmployeeProfile value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _EmployeeProfile():
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
    TResult? Function(_EmployeeProfile value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _EmployeeProfile() when $default != null:
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
            bool? hasAccount,
            String? accessRole,
            String name,
            String role,
            String department,
            String email,
            String phone,
            String unit,
            TimeOfDay expectedShiftStart,
            TimeOfDay expectedShiftEnd,
            EmployeeStatus status,
            EmployeeWorkMode workMode,
            RoleLevel roleLevel,
            bool requiresLocationOnPunch,
            bool trustedDeviceRequired,
            int todayWorkedMinutes,
            int pendingAdjustments,
            DateTime? lastPunchAt,
            String notes)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _EmployeeProfile() when $default != null:
        return $default(
            _that.id,
            _that.hasAccount,
            _that.accessRole,
            _that.name,
            _that.role,
            _that.department,
            _that.email,
            _that.phone,
            _that.unit,
            _that.expectedShiftStart,
            _that.expectedShiftEnd,
            _that.status,
            _that.workMode,
            _that.roleLevel,
            _that.requiresLocationOnPunch,
            _that.trustedDeviceRequired,
            _that.todayWorkedMinutes,
            _that.pendingAdjustments,
            _that.lastPunchAt,
            _that.notes);
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
            bool? hasAccount,
            String? accessRole,
            String name,
            String role,
            String department,
            String email,
            String phone,
            String unit,
            TimeOfDay expectedShiftStart,
            TimeOfDay expectedShiftEnd,
            EmployeeStatus status,
            EmployeeWorkMode workMode,
            RoleLevel roleLevel,
            bool requiresLocationOnPunch,
            bool trustedDeviceRequired,
            int todayWorkedMinutes,
            int pendingAdjustments,
            DateTime? lastPunchAt,
            String notes)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _EmployeeProfile():
        return $default(
            _that.id,
            _that.hasAccount,
            _that.accessRole,
            _that.name,
            _that.role,
            _that.department,
            _that.email,
            _that.phone,
            _that.unit,
            _that.expectedShiftStart,
            _that.expectedShiftEnd,
            _that.status,
            _that.workMode,
            _that.roleLevel,
            _that.requiresLocationOnPunch,
            _that.trustedDeviceRequired,
            _that.todayWorkedMinutes,
            _that.pendingAdjustments,
            _that.lastPunchAt,
            _that.notes);
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
            bool? hasAccount,
            String? accessRole,
            String name,
            String role,
            String department,
            String email,
            String phone,
            String unit,
            TimeOfDay expectedShiftStart,
            TimeOfDay expectedShiftEnd,
            EmployeeStatus status,
            EmployeeWorkMode workMode,
            RoleLevel roleLevel,
            bool requiresLocationOnPunch,
            bool trustedDeviceRequired,
            int todayWorkedMinutes,
            int pendingAdjustments,
            DateTime? lastPunchAt,
            String notes)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _EmployeeProfile() when $default != null:
        return $default(
            _that.id,
            _that.hasAccount,
            _that.accessRole,
            _that.name,
            _that.role,
            _that.department,
            _that.email,
            _that.phone,
            _that.unit,
            _that.expectedShiftStart,
            _that.expectedShiftEnd,
            _that.status,
            _that.workMode,
            _that.roleLevel,
            _that.requiresLocationOnPunch,
            _that.trustedDeviceRequired,
            _that.todayWorkedMinutes,
            _that.pendingAdjustments,
            _that.lastPunchAt,
            _that.notes);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _EmployeeProfile extends EmployeeProfile {
  const _EmployeeProfile(
      {required this.id,
      this.hasAccount = null,
      this.accessRole = null,
      required this.name,
      required this.role,
      required this.department,
      required this.email,
      required this.phone,
      required this.unit,
      required this.expectedShiftStart,
      required this.expectedShiftEnd,
      required this.status,
      required this.workMode,
      required this.roleLevel,
      required this.requiresLocationOnPunch,
      required this.trustedDeviceRequired,
      required this.todayWorkedMinutes,
      required this.pendingAdjustments,
      required this.lastPunchAt,
      required this.notes})
      : super._();

  @override
  final String id;
  @override
  @JsonKey()
  final bool? hasAccount;
  @override
  @JsonKey()
  final String? accessRole;
  @override
  final String name;
  @override
  final String role;
  @override
  final String department;
  @override
  final String email;
  @override
  final String phone;
  @override
  final String unit;
  @override
  final TimeOfDay expectedShiftStart;
  @override
  final TimeOfDay expectedShiftEnd;
  @override
  final EmployeeStatus status;
  @override
  final EmployeeWorkMode workMode;
  @override
  final RoleLevel roleLevel;
  @override
  final bool requiresLocationOnPunch;
  @override
  final bool trustedDeviceRequired;
  @override
  final int todayWorkedMinutes;
  @override
  final int pendingAdjustments;
  @override
  final DateTime? lastPunchAt;
  @override
  final String notes;

  /// Create a copy of EmployeeProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$EmployeeProfileCopyWith<_EmployeeProfile> get copyWith =>
      __$EmployeeProfileCopyWithImpl<_EmployeeProfile>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _EmployeeProfile &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.hasAccount, hasAccount) ||
                other.hasAccount == hasAccount) &&
            (identical(other.accessRole, accessRole) ||
                other.accessRole == accessRole) &&
            (identical(other.name, name) || other.name == name) &&
            (identical(other.role, role) || other.role == role) &&
            (identical(other.department, department) ||
                other.department == department) &&
            (identical(other.email, email) || other.email == email) &&
            (identical(other.phone, phone) || other.phone == phone) &&
            (identical(other.unit, unit) || other.unit == unit) &&
            (identical(other.expectedShiftStart, expectedShiftStart) ||
                other.expectedShiftStart == expectedShiftStart) &&
            (identical(other.expectedShiftEnd, expectedShiftEnd) ||
                other.expectedShiftEnd == expectedShiftEnd) &&
            (identical(other.status, status) || other.status == status) &&
            (identical(other.workMode, workMode) ||
                other.workMode == workMode) &&
            (identical(other.roleLevel, roleLevel) ||
                other.roleLevel == roleLevel) &&
            (identical(
                    other.requiresLocationOnPunch, requiresLocationOnPunch) ||
                other.requiresLocationOnPunch == requiresLocationOnPunch) &&
            (identical(other.trustedDeviceRequired, trustedDeviceRequired) ||
                other.trustedDeviceRequired == trustedDeviceRequired) &&
            (identical(other.todayWorkedMinutes, todayWorkedMinutes) ||
                other.todayWorkedMinutes == todayWorkedMinutes) &&
            (identical(other.pendingAdjustments, pendingAdjustments) ||
                other.pendingAdjustments == pendingAdjustments) &&
            (identical(other.lastPunchAt, lastPunchAt) ||
                other.lastPunchAt == lastPunchAt) &&
            (identical(other.notes, notes) || other.notes == notes));
  }

  @override
  int get hashCode => Object.hashAll([
        runtimeType,
        id,
        hasAccount,
        accessRole,
        name,
        role,
        department,
        email,
        phone,
        unit,
        expectedShiftStart,
        expectedShiftEnd,
        status,
        workMode,
        roleLevel,
        requiresLocationOnPunch,
        trustedDeviceRequired,
        todayWorkedMinutes,
        pendingAdjustments,
        lastPunchAt,
        notes
      ]);

  @override
  String toString() {
    return 'EmployeeProfile(id: $id, hasAccount: $hasAccount, accessRole: $accessRole, name: $name, role: $role, department: $department, email: $email, phone: $phone, unit: $unit, expectedShiftStart: $expectedShiftStart, expectedShiftEnd: $expectedShiftEnd, status: $status, workMode: $workMode, roleLevel: $roleLevel, requiresLocationOnPunch: $requiresLocationOnPunch, trustedDeviceRequired: $trustedDeviceRequired, todayWorkedMinutes: $todayWorkedMinutes, pendingAdjustments: $pendingAdjustments, lastPunchAt: $lastPunchAt, notes: $notes)';
  }
}

/// @nodoc
abstract mixin class _$EmployeeProfileCopyWith<$Res>
    implements $EmployeeProfileCopyWith<$Res> {
  factory _$EmployeeProfileCopyWith(
          _EmployeeProfile value, $Res Function(_EmployeeProfile) _then) =
      __$EmployeeProfileCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      bool? hasAccount,
      String? accessRole,
      String name,
      String role,
      String department,
      String email,
      String phone,
      String unit,
      TimeOfDay expectedShiftStart,
      TimeOfDay expectedShiftEnd,
      EmployeeStatus status,
      EmployeeWorkMode workMode,
      RoleLevel roleLevel,
      bool requiresLocationOnPunch,
      bool trustedDeviceRequired,
      int todayWorkedMinutes,
      int pendingAdjustments,
      DateTime? lastPunchAt,
      String notes});
}

/// @nodoc
class __$EmployeeProfileCopyWithImpl<$Res>
    implements _$EmployeeProfileCopyWith<$Res> {
  __$EmployeeProfileCopyWithImpl(this._self, this._then);

  final _EmployeeProfile _self;
  final $Res Function(_EmployeeProfile) _then;

  /// Create a copy of EmployeeProfile
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? hasAccount = freezed,
    Object? accessRole = freezed,
    Object? name = null,
    Object? role = null,
    Object? department = null,
    Object? email = null,
    Object? phone = null,
    Object? unit = null,
    Object? expectedShiftStart = null,
    Object? expectedShiftEnd = null,
    Object? status = null,
    Object? workMode = null,
    Object? roleLevel = null,
    Object? requiresLocationOnPunch = null,
    Object? trustedDeviceRequired = null,
    Object? todayWorkedMinutes = null,
    Object? pendingAdjustments = null,
    Object? lastPunchAt = freezed,
    Object? notes = null,
  }) {
    return _then(_EmployeeProfile(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      hasAccount: freezed == hasAccount
          ? _self.hasAccount
          : hasAccount // ignore: cast_nullable_to_non_nullable
              as bool?,
      accessRole: freezed == accessRole
          ? _self.accessRole
          : accessRole // ignore: cast_nullable_to_non_nullable
              as String?,
      name: null == name
          ? _self.name
          : name // ignore: cast_nullable_to_non_nullable
              as String,
      role: null == role
          ? _self.role
          : role // ignore: cast_nullable_to_non_nullable
              as String,
      department: null == department
          ? _self.department
          : department // ignore: cast_nullable_to_non_nullable
              as String,
      email: null == email
          ? _self.email
          : email // ignore: cast_nullable_to_non_nullable
              as String,
      phone: null == phone
          ? _self.phone
          : phone // ignore: cast_nullable_to_non_nullable
              as String,
      unit: null == unit
          ? _self.unit
          : unit // ignore: cast_nullable_to_non_nullable
              as String,
      expectedShiftStart: null == expectedShiftStart
          ? _self.expectedShiftStart
          : expectedShiftStart // ignore: cast_nullable_to_non_nullable
              as TimeOfDay,
      expectedShiftEnd: null == expectedShiftEnd
          ? _self.expectedShiftEnd
          : expectedShiftEnd // ignore: cast_nullable_to_non_nullable
              as TimeOfDay,
      status: null == status
          ? _self.status
          : status // ignore: cast_nullable_to_non_nullable
              as EmployeeStatus,
      workMode: null == workMode
          ? _self.workMode
          : workMode // ignore: cast_nullable_to_non_nullable
              as EmployeeWorkMode,
      roleLevel: null == roleLevel
          ? _self.roleLevel
          : roleLevel // ignore: cast_nullable_to_non_nullable
              as RoleLevel,
      requiresLocationOnPunch: null == requiresLocationOnPunch
          ? _self.requiresLocationOnPunch
          : requiresLocationOnPunch // ignore: cast_nullable_to_non_nullable
              as bool,
      trustedDeviceRequired: null == trustedDeviceRequired
          ? _self.trustedDeviceRequired
          : trustedDeviceRequired // ignore: cast_nullable_to_non_nullable
              as bool,
      todayWorkedMinutes: null == todayWorkedMinutes
          ? _self.todayWorkedMinutes
          : todayWorkedMinutes // ignore: cast_nullable_to_non_nullable
              as int,
      pendingAdjustments: null == pendingAdjustments
          ? _self.pendingAdjustments
          : pendingAdjustments // ignore: cast_nullable_to_non_nullable
              as int,
      lastPunchAt: freezed == lastPunchAt
          ? _self.lastPunchAt
          : lastPunchAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      notes: null == notes
          ? _self.notes
          : notes // ignore: cast_nullable_to_non_nullable
              as String,
    ));
  }
}

// dart format on
