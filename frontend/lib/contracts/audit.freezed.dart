// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'audit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$AuditEventResponse {
  String get id;
  DateTime get timestamp;
  String get companyId;
  String? get actorUserId;
  String? get projectId;
  String get action;
  String get entityType;
  String get entityId;
  String get result;
  Map<String, dynamic>? get metadataPayload;
  String? get correlationId;

  /// Create a copy of AuditEventResponse
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $AuditEventResponseCopyWith<AuditEventResponse> get copyWith =>
      _$AuditEventResponseCopyWithImpl<AuditEventResponse>(
          this as AuditEventResponse, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is AuditEventResponse &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.companyId, companyId) ||
                other.companyId == companyId) &&
            (identical(other.actorUserId, actorUserId) ||
                other.actorUserId == actorUserId) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.entityType, entityType) ||
                other.entityType == entityType) &&
            (identical(other.entityId, entityId) ||
                other.entityId == entityId) &&
            (identical(other.result, result) || other.result == result) &&
            const DeepCollectionEquality()
                .equals(other.metadataPayload, metadataPayload) &&
            (identical(other.correlationId, correlationId) ||
                other.correlationId == correlationId));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      timestamp,
      companyId,
      actorUserId,
      projectId,
      action,
      entityType,
      entityId,
      result,
      const DeepCollectionEquality().hash(metadataPayload),
      correlationId);

  @override
  String toString() {
    return 'AuditEventResponse(id: $id, timestamp: $timestamp, companyId: $companyId, actorUserId: $actorUserId, projectId: $projectId, action: $action, entityType: $entityType, entityId: $entityId, result: $result, metadataPayload: $metadataPayload, correlationId: $correlationId)';
  }
}

/// @nodoc
abstract mixin class $AuditEventResponseCopyWith<$Res> {
  factory $AuditEventResponseCopyWith(
          AuditEventResponse value, $Res Function(AuditEventResponse) _then) =
      _$AuditEventResponseCopyWithImpl;
  @useResult
  $Res call(
      {String id,
      DateTime timestamp,
      String companyId,
      String? actorUserId,
      String? projectId,
      String action,
      String entityType,
      String entityId,
      String result,
      Map<String, dynamic>? metadataPayload,
      String? correlationId});
}

/// @nodoc
class _$AuditEventResponseCopyWithImpl<$Res>
    implements $AuditEventResponseCopyWith<$Res> {
  _$AuditEventResponseCopyWithImpl(this._self, this._then);

  final AuditEventResponse _self;
  final $Res Function(AuditEventResponse) _then;

  /// Create a copy of AuditEventResponse
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? id = null,
    Object? timestamp = null,
    Object? companyId = null,
    Object? actorUserId = freezed,
    Object? projectId = freezed,
    Object? action = null,
    Object? entityType = null,
    Object? entityId = null,
    Object? result = null,
    Object? metadataPayload = freezed,
    Object? correlationId = freezed,
  }) {
    return _then(_self.copyWith(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      companyId: null == companyId
          ? _self.companyId
          : companyId // ignore: cast_nullable_to_non_nullable
              as String,
      actorUserId: freezed == actorUserId
          ? _self.actorUserId
          : actorUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      projectId: freezed == projectId
          ? _self.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      action: null == action
          ? _self.action
          : action // ignore: cast_nullable_to_non_nullable
              as String,
      entityType: null == entityType
          ? _self.entityType
          : entityType // ignore: cast_nullable_to_non_nullable
              as String,
      entityId: null == entityId
          ? _self.entityId
          : entityId // ignore: cast_nullable_to_non_nullable
              as String,
      result: null == result
          ? _self.result
          : result // ignore: cast_nullable_to_non_nullable
              as String,
      metadataPayload: freezed == metadataPayload
          ? _self.metadataPayload
          : metadataPayload // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      correlationId: freezed == correlationId
          ? _self.correlationId
          : correlationId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [AuditEventResponse].
extension AuditEventResponsePatterns on AuditEventResponse {
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
    TResult Function(_AuditEventResponse value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AuditEventResponse() when $default != null:
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
    TResult Function(_AuditEventResponse value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AuditEventResponse():
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
    TResult? Function(_AuditEventResponse value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AuditEventResponse() when $default != null:
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
            DateTime timestamp,
            String companyId,
            String? actorUserId,
            String? projectId,
            String action,
            String entityType,
            String entityId,
            String result,
            Map<String, dynamic>? metadataPayload,
            String? correlationId)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _AuditEventResponse() when $default != null:
        return $default(
            _that.id,
            _that.timestamp,
            _that.companyId,
            _that.actorUserId,
            _that.projectId,
            _that.action,
            _that.entityType,
            _that.entityId,
            _that.result,
            _that.metadataPayload,
            _that.correlationId);
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
            DateTime timestamp,
            String companyId,
            String? actorUserId,
            String? projectId,
            String action,
            String entityType,
            String entityId,
            String result,
            Map<String, dynamic>? metadataPayload,
            String? correlationId)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AuditEventResponse():
        return $default(
            _that.id,
            _that.timestamp,
            _that.companyId,
            _that.actorUserId,
            _that.projectId,
            _that.action,
            _that.entityType,
            _that.entityId,
            _that.result,
            _that.metadataPayload,
            _that.correlationId);
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
            DateTime timestamp,
            String companyId,
            String? actorUserId,
            String? projectId,
            String action,
            String entityType,
            String entityId,
            String result,
            Map<String, dynamic>? metadataPayload,
            String? correlationId)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _AuditEventResponse() when $default != null:
        return $default(
            _that.id,
            _that.timestamp,
            _that.companyId,
            _that.actorUserId,
            _that.projectId,
            _that.action,
            _that.entityType,
            _that.entityId,
            _that.result,
            _that.metadataPayload,
            _that.correlationId);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _AuditEventResponse extends AuditEventResponse {
  const _AuditEventResponse(
      {required this.id,
      required this.timestamp,
      required this.companyId,
      required this.actorUserId,
      required this.projectId,
      required this.action,
      required this.entityType,
      required this.entityId,
      required this.result,
      required final Map<String, dynamic>? metadataPayload,
      required this.correlationId})
      : _metadataPayload = metadataPayload,
        super._();

  @override
  final String id;
  @override
  final DateTime timestamp;
  @override
  final String companyId;
  @override
  final String? actorUserId;
  @override
  final String? projectId;
  @override
  final String action;
  @override
  final String entityType;
  @override
  final String entityId;
  @override
  final String result;
  final Map<String, dynamic>? _metadataPayload;
  @override
  Map<String, dynamic>? get metadataPayload {
    final value = _metadataPayload;
    if (value == null) return null;
    if (_metadataPayload is EqualUnmodifiableMapView) return _metadataPayload;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(value);
  }

  @override
  final String? correlationId;

  /// Create a copy of AuditEventResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$AuditEventResponseCopyWith<_AuditEventResponse> get copyWith =>
      __$AuditEventResponseCopyWithImpl<_AuditEventResponse>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _AuditEventResponse &&
            (identical(other.id, id) || other.id == id) &&
            (identical(other.timestamp, timestamp) ||
                other.timestamp == timestamp) &&
            (identical(other.companyId, companyId) ||
                other.companyId == companyId) &&
            (identical(other.actorUserId, actorUserId) ||
                other.actorUserId == actorUserId) &&
            (identical(other.projectId, projectId) ||
                other.projectId == projectId) &&
            (identical(other.action, action) || other.action == action) &&
            (identical(other.entityType, entityType) ||
                other.entityType == entityType) &&
            (identical(other.entityId, entityId) ||
                other.entityId == entityId) &&
            (identical(other.result, result) || other.result == result) &&
            const DeepCollectionEquality()
                .equals(other._metadataPayload, _metadataPayload) &&
            (identical(other.correlationId, correlationId) ||
                other.correlationId == correlationId));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      id,
      timestamp,
      companyId,
      actorUserId,
      projectId,
      action,
      entityType,
      entityId,
      result,
      const DeepCollectionEquality().hash(_metadataPayload),
      correlationId);

  @override
  String toString() {
    return 'AuditEventResponse(id: $id, timestamp: $timestamp, companyId: $companyId, actorUserId: $actorUserId, projectId: $projectId, action: $action, entityType: $entityType, entityId: $entityId, result: $result, metadataPayload: $metadataPayload, correlationId: $correlationId)';
  }
}

/// @nodoc
abstract mixin class _$AuditEventResponseCopyWith<$Res>
    implements $AuditEventResponseCopyWith<$Res> {
  factory _$AuditEventResponseCopyWith(
          _AuditEventResponse value, $Res Function(_AuditEventResponse) _then) =
      __$AuditEventResponseCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String id,
      DateTime timestamp,
      String companyId,
      String? actorUserId,
      String? projectId,
      String action,
      String entityType,
      String entityId,
      String result,
      Map<String, dynamic>? metadataPayload,
      String? correlationId});
}

/// @nodoc
class __$AuditEventResponseCopyWithImpl<$Res>
    implements _$AuditEventResponseCopyWith<$Res> {
  __$AuditEventResponseCopyWithImpl(this._self, this._then);

  final _AuditEventResponse _self;
  final $Res Function(_AuditEventResponse) _then;

  /// Create a copy of AuditEventResponse
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? id = null,
    Object? timestamp = null,
    Object? companyId = null,
    Object? actorUserId = freezed,
    Object? projectId = freezed,
    Object? action = null,
    Object? entityType = null,
    Object? entityId = null,
    Object? result = null,
    Object? metadataPayload = freezed,
    Object? correlationId = freezed,
  }) {
    return _then(_AuditEventResponse(
      id: null == id
          ? _self.id
          : id // ignore: cast_nullable_to_non_nullable
              as String,
      timestamp: null == timestamp
          ? _self.timestamp
          : timestamp // ignore: cast_nullable_to_non_nullable
              as DateTime,
      companyId: null == companyId
          ? _self.companyId
          : companyId // ignore: cast_nullable_to_non_nullable
              as String,
      actorUserId: freezed == actorUserId
          ? _self.actorUserId
          : actorUserId // ignore: cast_nullable_to_non_nullable
              as String?,
      projectId: freezed == projectId
          ? _self.projectId
          : projectId // ignore: cast_nullable_to_non_nullable
              as String?,
      action: null == action
          ? _self.action
          : action // ignore: cast_nullable_to_non_nullable
              as String,
      entityType: null == entityType
          ? _self.entityType
          : entityType // ignore: cast_nullable_to_non_nullable
              as String,
      entityId: null == entityId
          ? _self.entityId
          : entityId // ignore: cast_nullable_to_non_nullable
              as String,
      result: null == result
          ? _self.result
          : result // ignore: cast_nullable_to_non_nullable
              as String,
      metadataPayload: freezed == metadataPayload
          ? _self._metadataPayload
          : metadataPayload // ignore: cast_nullable_to_non_nullable
              as Map<String, dynamic>?,
      correlationId: freezed == correlationId
          ? _self.correlationId
          : correlationId // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
