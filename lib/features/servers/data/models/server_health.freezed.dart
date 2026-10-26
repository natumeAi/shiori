// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_health.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ServerHealth {

 String get status; String get service; String get database;
/// Create a copy of ServerHealth
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerHealthCopyWith<ServerHealth> get copyWith => _$ServerHealthCopyWithImpl<ServerHealth>(this as ServerHealth, _$identity);

  /// Serializes this ServerHealth to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ServerHealth;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerHealth&&(identical(other.status, _this.status) || other.status == _this.status)&&(identical(other.service, _this.service) || other.service == _this.service)&&(identical(other.database, _this.database) || other.database == _this.database));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ServerHealth;
  return Object.hash(runtimeType,_this.status,_this.service,_this.database);
}

@override
String toString() {
  final _this = this as ServerHealth;
  return 'ServerHealth(status: ${_this.status}, service: ${_this.service}, database: ${_this.database})';
}


}

/// @nodoc
abstract mixin class $ServerHealthCopyWith<$Res>  {
  factory $ServerHealthCopyWith(ServerHealth value, $Res Function(ServerHealth) _then) = _$ServerHealthCopyWithImpl;
@useResult
$Res call({
 String status, String service, String database
});




}
/// @nodoc
class _$ServerHealthCopyWithImpl<$Res>
    implements $ServerHealthCopyWith<$Res> {
  _$ServerHealthCopyWithImpl(this._self, this._then);

  final ServerHealth _self;
  final $Res Function(ServerHealth) _then;

/// Create a copy of ServerHealth
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? service = null,Object? database = null,}) {
  return _then(ServerHealth(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as String,database: null == database ? _self.database : database // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ServerHealth].
extension ServerHealthPatterns on ServerHealth {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServerHealth value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServerHealth() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServerHealth value)  $default,){
final _that = this;
switch (_that) {
case _ServerHealth():
return $default(_that);case _:
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServerHealth value)?  $default,){
final _that = this;
switch (_that) {
case _ServerHealth() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String status,  String service,  String database)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServerHealth() when $default != null:
return $default(_that.status,_that.service,_that.database);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String status,  String service,  String database)  $default,) {final _that = this;
switch (_that) {
case _ServerHealth():
return $default(_that.status,_that.service,_that.database);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String status,  String service,  String database)?  $default,) {final _that = this;
switch (_that) {
case _ServerHealth() when $default != null:
return $default(_that.status,_that.service,_that.database);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ServerHealth extends ServerHealth {
  const _ServerHealth({required this.status, required this.service, required this.database}): super._();
  factory _ServerHealth.fromJson(Map<String, dynamic> json) => _$ServerHealthFromJson(json);

@override final  String status;
@override final  String service;
@override final  String database;

/// Create a copy of ServerHealth
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServerHealthCopyWith<_ServerHealth> get copyWith => __$ServerHealthCopyWithImpl<_ServerHealth>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ServerHealthToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServerHealth&&(identical(other.status, status) || other.status == status)&&(identical(other.service, service) || other.service == service)&&(identical(other.database, database) || other.database == database));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,status,service,database);
}

@override
String toString() {
    return 'ServerHealth(status: $status, service: $service, database: $database)';
}


}

/// @nodoc
abstract mixin class _$ServerHealthCopyWith<$Res> implements $ServerHealthCopyWith<$Res> {
  factory _$ServerHealthCopyWith(_ServerHealth value, $Res Function(_ServerHealth) _then) = __$ServerHealthCopyWithImpl;
@override @useResult
$Res call({
 String status, String service, String database
});




}
/// @nodoc
class __$ServerHealthCopyWithImpl<$Res>
    implements _$ServerHealthCopyWith<$Res> {
  __$ServerHealthCopyWithImpl(this._self, this._then);

  final _ServerHealth _self;
  final $Res Function(_ServerHealth) _then;

/// Create a copy of ServerHealth
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? service = null,Object? database = null,}) {
  return _then(_ServerHealth(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,service: null == service ? _self.service : service // ignore: cast_nullable_to_non_nullable
as String,database: null == database ? _self.database : database // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
