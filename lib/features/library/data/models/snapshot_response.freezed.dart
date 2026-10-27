// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'snapshot_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SnapshotResponse {

@JsonKey(required: true) LibrarySnapshot get snapshot;
/// Create a copy of SnapshotResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SnapshotResponseCopyWith<SnapshotResponse> get copyWith => _$SnapshotResponseCopyWithImpl<SnapshotResponse>(this as SnapshotResponse, _$identity);

  /// Serializes this SnapshotResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SnapshotResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SnapshotResponse&&(identical(other.snapshot, _this.snapshot) || other.snapshot == _this.snapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SnapshotResponse;
  return Object.hash(runtimeType,_this.snapshot);
}

@override
String toString() {
  final _this = this as SnapshotResponse;
  return 'SnapshotResponse(snapshot: ${_this.snapshot})';
}


}

/// @nodoc
abstract mixin class $SnapshotResponseCopyWith<$Res>  {
  factory $SnapshotResponseCopyWith(SnapshotResponse value, $Res Function(SnapshotResponse) _then) = _$SnapshotResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(required: true) LibrarySnapshot snapshot
});


$LibrarySnapshotCopyWith<$Res> get snapshot;

}
/// @nodoc
class _$SnapshotResponseCopyWithImpl<$Res>
    implements $SnapshotResponseCopyWith<$Res> {
  _$SnapshotResponseCopyWithImpl(this._self, this._then);

  final SnapshotResponse _self;
  final $Res Function(SnapshotResponse) _then;

/// Create a copy of SnapshotResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? snapshot = null,}) {
  return _then(SnapshotResponse(
snapshot: null == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as LibrarySnapshot,
  ));
}
/// Create a copy of SnapshotResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibrarySnapshotCopyWith<$Res> get snapshot {
  
  return $LibrarySnapshotCopyWith<$Res>(_self.snapshot, (value) {
    return _then(_self.copyWith(snapshot: value));
  });
}
}


/// Adds pattern-matching-related methods to [SnapshotResponse].
extension SnapshotResponsePatterns on SnapshotResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SnapshotResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SnapshotResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SnapshotResponse value)  $default,){
final _that = this;
switch (_that) {
case _SnapshotResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SnapshotResponse value)?  $default,){
final _that = this;
switch (_that) {
case _SnapshotResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(required: true)  LibrarySnapshot snapshot)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SnapshotResponse() when $default != null:
return $default(_that.snapshot);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(required: true)  LibrarySnapshot snapshot)  $default,) {final _that = this;
switch (_that) {
case _SnapshotResponse():
return $default(_that.snapshot);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(required: true)  LibrarySnapshot snapshot)?  $default,) {final _that = this;
switch (_that) {
case _SnapshotResponse() when $default != null:
return $default(_that.snapshot);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SnapshotResponse implements SnapshotResponse {
  const _SnapshotResponse({@JsonKey(required: true) required this.snapshot});
  factory _SnapshotResponse.fromJson(Map<String, dynamic> json) => _$SnapshotResponseFromJson(json);

@override@JsonKey(required: true) final  LibrarySnapshot snapshot;

/// Create a copy of SnapshotResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SnapshotResponseCopyWith<_SnapshotResponse> get copyWith => __$SnapshotResponseCopyWithImpl<_SnapshotResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SnapshotResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SnapshotResponse&&(identical(other.snapshot, snapshot) || other.snapshot == snapshot));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,snapshot);
}

@override
String toString() {
    return 'SnapshotResponse(snapshot: $snapshot)';
}


}

/// @nodoc
abstract mixin class _$SnapshotResponseCopyWith<$Res> implements $SnapshotResponseCopyWith<$Res> {
  factory _$SnapshotResponseCopyWith(_SnapshotResponse value, $Res Function(_SnapshotResponse) _then) = __$SnapshotResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(required: true) LibrarySnapshot snapshot
});


@override $LibrarySnapshotCopyWith<$Res> get snapshot;

}
/// @nodoc
class __$SnapshotResponseCopyWithImpl<$Res>
    implements _$SnapshotResponseCopyWith<$Res> {
  __$SnapshotResponseCopyWithImpl(this._self, this._then);

  final _SnapshotResponse _self;
  final $Res Function(_SnapshotResponse) _then;

/// Create a copy of SnapshotResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? snapshot = null,}) {
  return _then(_SnapshotResponse(
snapshot: null == snapshot ? _self.snapshot : snapshot // ignore: cast_nullable_to_non_nullable
as LibrarySnapshot,
  ));
}

/// Create a copy of SnapshotResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LibrarySnapshotCopyWith<$Res> get snapshot {
  
  return $LibrarySnapshotCopyWith<$Res>(_self.snapshot, (value) {
    return _then(_self.copyWith(snapshot: value));
  });
}
}

// dart format on
