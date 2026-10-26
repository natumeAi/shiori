// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'probe_saved_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ProbeSavedState {

 String get marker; DiagnosticRecord? get lastRecord;
/// Create a copy of ProbeSavedState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProbeSavedStateCopyWith<ProbeSavedState> get copyWith => _$ProbeSavedStateCopyWithImpl<ProbeSavedState>(this as ProbeSavedState, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as ProbeSavedState;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProbeSavedState&&(identical(other.marker, _this.marker) || other.marker == _this.marker)&&(identical(other.lastRecord, _this.lastRecord) || other.lastRecord == _this.lastRecord));
}


@override
int get hashCode {
  final _this = this as ProbeSavedState;
  return Object.hash(runtimeType,_this.marker,_this.lastRecord);
}

@override
String toString() {
  final _this = this as ProbeSavedState;
  return 'ProbeSavedState(marker: ${_this.marker}, lastRecord: ${_this.lastRecord})';
}


}

/// @nodoc
abstract mixin class $ProbeSavedStateCopyWith<$Res>  {
  factory $ProbeSavedStateCopyWith(ProbeSavedState value, $Res Function(ProbeSavedState) _then) = _$ProbeSavedStateCopyWithImpl;
@useResult
$Res call({
 String marker, DiagnosticRecord? lastRecord
});


$DiagnosticRecordCopyWith<$Res>? get lastRecord;

}
/// @nodoc
class _$ProbeSavedStateCopyWithImpl<$Res>
    implements $ProbeSavedStateCopyWith<$Res> {
  _$ProbeSavedStateCopyWithImpl(this._self, this._then);

  final ProbeSavedState _self;
  final $Res Function(ProbeSavedState) _then;

/// Create a copy of ProbeSavedState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? marker = null,Object? lastRecord = freezed,}) {
  return _then(ProbeSavedState(
marker: null == marker ? _self.marker : marker // ignore: cast_nullable_to_non_nullable
as String,lastRecord: freezed == lastRecord ? _self.lastRecord : lastRecord // ignore: cast_nullable_to_non_nullable
as DiagnosticRecord?,
  ));
}
/// Create a copy of ProbeSavedState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DiagnosticRecordCopyWith<$Res>? get lastRecord {
    if (_self.lastRecord == null) {
    return null;
  }

  return $DiagnosticRecordCopyWith<$Res>(_self.lastRecord!, (value) {
    return _then(_self.copyWith(lastRecord: value));
  });
}
}


/// Adds pattern-matching-related methods to [ProbeSavedState].
extension ProbeSavedStatePatterns on ProbeSavedState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProbeSavedState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProbeSavedState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProbeSavedState value)  $default,){
final _that = this;
switch (_that) {
case _ProbeSavedState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProbeSavedState value)?  $default,){
final _that = this;
switch (_that) {
case _ProbeSavedState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String marker,  DiagnosticRecord? lastRecord)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProbeSavedState() when $default != null:
return $default(_that.marker,_that.lastRecord);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String marker,  DiagnosticRecord? lastRecord)  $default,) {final _that = this;
switch (_that) {
case _ProbeSavedState():
return $default(_that.marker,_that.lastRecord);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String marker,  DiagnosticRecord? lastRecord)?  $default,) {final _that = this;
switch (_that) {
case _ProbeSavedState() when $default != null:
return $default(_that.marker,_that.lastRecord);case _:
  return null;

}
}

}

/// @nodoc


class _ProbeSavedState implements ProbeSavedState {
  const _ProbeSavedState({required this.marker, this.lastRecord});
  

@override final  String marker;
@override final  DiagnosticRecord? lastRecord;

/// Create a copy of ProbeSavedState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProbeSavedStateCopyWith<_ProbeSavedState> get copyWith => __$ProbeSavedStateCopyWithImpl<_ProbeSavedState>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProbeSavedState&&(identical(other.marker, marker) || other.marker == marker)&&(identical(other.lastRecord, lastRecord) || other.lastRecord == lastRecord));
}


@override
int get hashCode {
    return Object.hash(runtimeType,marker,lastRecord);
}

@override
String toString() {
    return 'ProbeSavedState(marker: $marker, lastRecord: $lastRecord)';
}


}

/// @nodoc
abstract mixin class _$ProbeSavedStateCopyWith<$Res> implements $ProbeSavedStateCopyWith<$Res> {
  factory _$ProbeSavedStateCopyWith(_ProbeSavedState value, $Res Function(_ProbeSavedState) _then) = __$ProbeSavedStateCopyWithImpl;
@override @useResult
$Res call({
 String marker, DiagnosticRecord? lastRecord
});


@override $DiagnosticRecordCopyWith<$Res>? get lastRecord;

}
/// @nodoc
class __$ProbeSavedStateCopyWithImpl<$Res>
    implements _$ProbeSavedStateCopyWith<$Res> {
  __$ProbeSavedStateCopyWithImpl(this._self, this._then);

  final _ProbeSavedState _self;
  final $Res Function(_ProbeSavedState) _then;

/// Create a copy of ProbeSavedState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? marker = null,Object? lastRecord = freezed,}) {
  return _then(_ProbeSavedState(
marker: null == marker ? _self.marker : marker // ignore: cast_nullable_to_non_nullable
as String,lastRecord: freezed == lastRecord ? _self.lastRecord : lastRecord // ignore: cast_nullable_to_non_nullable
as DiagnosticRecord?,
  ));
}

/// Create a copy of ProbeSavedState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DiagnosticRecordCopyWith<$Res>? get lastRecord {
    if (_self.lastRecord == null) {
    return null;
  }

  return $DiagnosticRecordCopyWith<$Res>(_self.lastRecord!, (value) {
    return _then(_self.copyWith(lastRecord: value));
  });
}
}

// dart format on
