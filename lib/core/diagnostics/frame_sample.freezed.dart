// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'frame_sample.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$FrameSample {

 int get frameNumber; int get vsyncUs; int get buildStartUs; int get buildFinishUs; int get rasterStartUs; int get rasterFinishUs; int get rasterFinishWallUs; int get arrivalMonotonicUs;
/// Create a copy of FrameSample
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FrameSampleCopyWith<FrameSample> get copyWith => _$FrameSampleCopyWithImpl<FrameSample>(this as FrameSample, _$identity);

  /// Serializes this FrameSample to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as FrameSample;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FrameSample&&(identical(other.frameNumber, _this.frameNumber) || other.frameNumber == _this.frameNumber)&&(identical(other.vsyncUs, _this.vsyncUs) || other.vsyncUs == _this.vsyncUs)&&(identical(other.buildStartUs, _this.buildStartUs) || other.buildStartUs == _this.buildStartUs)&&(identical(other.buildFinishUs, _this.buildFinishUs) || other.buildFinishUs == _this.buildFinishUs)&&(identical(other.rasterStartUs, _this.rasterStartUs) || other.rasterStartUs == _this.rasterStartUs)&&(identical(other.rasterFinishUs, _this.rasterFinishUs) || other.rasterFinishUs == _this.rasterFinishUs)&&(identical(other.rasterFinishWallUs, _this.rasterFinishWallUs) || other.rasterFinishWallUs == _this.rasterFinishWallUs)&&(identical(other.arrivalMonotonicUs, _this.arrivalMonotonicUs) || other.arrivalMonotonicUs == _this.arrivalMonotonicUs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as FrameSample;
  return Object.hash(runtimeType,_this.frameNumber,_this.vsyncUs,_this.buildStartUs,_this.buildFinishUs,_this.rasterStartUs,_this.rasterFinishUs,_this.rasterFinishWallUs,_this.arrivalMonotonicUs);
}

@override
String toString() {
  final _this = this as FrameSample;
  return 'FrameSample(frameNumber: ${_this.frameNumber}, vsyncUs: ${_this.vsyncUs}, buildStartUs: ${_this.buildStartUs}, buildFinishUs: ${_this.buildFinishUs}, rasterStartUs: ${_this.rasterStartUs}, rasterFinishUs: ${_this.rasterFinishUs}, rasterFinishWallUs: ${_this.rasterFinishWallUs}, arrivalMonotonicUs: ${_this.arrivalMonotonicUs})';
}


}

/// @nodoc
abstract mixin class $FrameSampleCopyWith<$Res>  {
  factory $FrameSampleCopyWith(FrameSample value, $Res Function(FrameSample) _then) = _$FrameSampleCopyWithImpl;
@useResult
$Res call({
 int frameNumber, int vsyncUs, int buildStartUs, int buildFinishUs, int rasterStartUs, int rasterFinishUs, int rasterFinishWallUs, int arrivalMonotonicUs
});




}
/// @nodoc
class _$FrameSampleCopyWithImpl<$Res>
    implements $FrameSampleCopyWith<$Res> {
  _$FrameSampleCopyWithImpl(this._self, this._then);

  final FrameSample _self;
  final $Res Function(FrameSample) _then;

/// Create a copy of FrameSample
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? frameNumber = null,Object? vsyncUs = null,Object? buildStartUs = null,Object? buildFinishUs = null,Object? rasterStartUs = null,Object? rasterFinishUs = null,Object? rasterFinishWallUs = null,Object? arrivalMonotonicUs = null,}) {
  return _then(FrameSample(
frameNumber: null == frameNumber ? _self.frameNumber : frameNumber // ignore: cast_nullable_to_non_nullable
as int,vsyncUs: null == vsyncUs ? _self.vsyncUs : vsyncUs // ignore: cast_nullable_to_non_nullable
as int,buildStartUs: null == buildStartUs ? _self.buildStartUs : buildStartUs // ignore: cast_nullable_to_non_nullable
as int,buildFinishUs: null == buildFinishUs ? _self.buildFinishUs : buildFinishUs // ignore: cast_nullable_to_non_nullable
as int,rasterStartUs: null == rasterStartUs ? _self.rasterStartUs : rasterStartUs // ignore: cast_nullable_to_non_nullable
as int,rasterFinishUs: null == rasterFinishUs ? _self.rasterFinishUs : rasterFinishUs // ignore: cast_nullable_to_non_nullable
as int,rasterFinishWallUs: null == rasterFinishWallUs ? _self.rasterFinishWallUs : rasterFinishWallUs // ignore: cast_nullable_to_non_nullable
as int,arrivalMonotonicUs: null == arrivalMonotonicUs ? _self.arrivalMonotonicUs : arrivalMonotonicUs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FrameSample].
extension FrameSamplePatterns on FrameSample {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FrameSample value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FrameSample() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FrameSample value)  $default,){
final _that = this;
switch (_that) {
case _FrameSample():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FrameSample value)?  $default,){
final _that = this;
switch (_that) {
case _FrameSample() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int frameNumber,  int vsyncUs,  int buildStartUs,  int buildFinishUs,  int rasterStartUs,  int rasterFinishUs,  int rasterFinishWallUs,  int arrivalMonotonicUs)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FrameSample() when $default != null:
return $default(_that.frameNumber,_that.vsyncUs,_that.buildStartUs,_that.buildFinishUs,_that.rasterStartUs,_that.rasterFinishUs,_that.rasterFinishWallUs,_that.arrivalMonotonicUs);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int frameNumber,  int vsyncUs,  int buildStartUs,  int buildFinishUs,  int rasterStartUs,  int rasterFinishUs,  int rasterFinishWallUs,  int arrivalMonotonicUs)  $default,) {final _that = this;
switch (_that) {
case _FrameSample():
return $default(_that.frameNumber,_that.vsyncUs,_that.buildStartUs,_that.buildFinishUs,_that.rasterStartUs,_that.rasterFinishUs,_that.rasterFinishWallUs,_that.arrivalMonotonicUs);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int frameNumber,  int vsyncUs,  int buildStartUs,  int buildFinishUs,  int rasterStartUs,  int rasterFinishUs,  int rasterFinishWallUs,  int arrivalMonotonicUs)?  $default,) {final _that = this;
switch (_that) {
case _FrameSample() when $default != null:
return $default(_that.frameNumber,_that.vsyncUs,_that.buildStartUs,_that.buildFinishUs,_that.rasterStartUs,_that.rasterFinishUs,_that.rasterFinishWallUs,_that.arrivalMonotonicUs);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FrameSample implements FrameSample {
  const _FrameSample({required this.frameNumber, required this.vsyncUs, required this.buildStartUs, required this.buildFinishUs, required this.rasterStartUs, required this.rasterFinishUs, required this.rasterFinishWallUs, required this.arrivalMonotonicUs});
  factory _FrameSample.fromJson(Map<String, dynamic> json) => _$FrameSampleFromJson(json);

@override final  int frameNumber;
@override final  int vsyncUs;
@override final  int buildStartUs;
@override final  int buildFinishUs;
@override final  int rasterStartUs;
@override final  int rasterFinishUs;
@override final  int rasterFinishWallUs;
@override final  int arrivalMonotonicUs;

/// Create a copy of FrameSample
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FrameSampleCopyWith<_FrameSample> get copyWith => __$FrameSampleCopyWithImpl<_FrameSample>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FrameSampleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _FrameSample&&(identical(other.frameNumber, frameNumber) || other.frameNumber == frameNumber)&&(identical(other.vsyncUs, vsyncUs) || other.vsyncUs == vsyncUs)&&(identical(other.buildStartUs, buildStartUs) || other.buildStartUs == buildStartUs)&&(identical(other.buildFinishUs, buildFinishUs) || other.buildFinishUs == buildFinishUs)&&(identical(other.rasterStartUs, rasterStartUs) || other.rasterStartUs == rasterStartUs)&&(identical(other.rasterFinishUs, rasterFinishUs) || other.rasterFinishUs == rasterFinishUs)&&(identical(other.rasterFinishWallUs, rasterFinishWallUs) || other.rasterFinishWallUs == rasterFinishWallUs)&&(identical(other.arrivalMonotonicUs, arrivalMonotonicUs) || other.arrivalMonotonicUs == arrivalMonotonicUs));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,frameNumber,vsyncUs,buildStartUs,buildFinishUs,rasterStartUs,rasterFinishUs,rasterFinishWallUs,arrivalMonotonicUs);
}

@override
String toString() {
    return 'FrameSample(frameNumber: $frameNumber, vsyncUs: $vsyncUs, buildStartUs: $buildStartUs, buildFinishUs: $buildFinishUs, rasterStartUs: $rasterStartUs, rasterFinishUs: $rasterFinishUs, rasterFinishWallUs: $rasterFinishWallUs, arrivalMonotonicUs: $arrivalMonotonicUs)';
}


}

/// @nodoc
abstract mixin class _$FrameSampleCopyWith<$Res> implements $FrameSampleCopyWith<$Res> {
  factory _$FrameSampleCopyWith(_FrameSample value, $Res Function(_FrameSample) _then) = __$FrameSampleCopyWithImpl;
@override @useResult
$Res call({
 int frameNumber, int vsyncUs, int buildStartUs, int buildFinishUs, int rasterStartUs, int rasterFinishUs, int rasterFinishWallUs, int arrivalMonotonicUs
});




}
/// @nodoc
class __$FrameSampleCopyWithImpl<$Res>
    implements _$FrameSampleCopyWith<$Res> {
  __$FrameSampleCopyWithImpl(this._self, this._then);

  final _FrameSample _self;
  final $Res Function(_FrameSample) _then;

/// Create a copy of FrameSample
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? frameNumber = null,Object? vsyncUs = null,Object? buildStartUs = null,Object? buildFinishUs = null,Object? rasterStartUs = null,Object? rasterFinishUs = null,Object? rasterFinishWallUs = null,Object? arrivalMonotonicUs = null,}) {
  return _then(_FrameSample(
frameNumber: null == frameNumber ? _self.frameNumber : frameNumber // ignore: cast_nullable_to_non_nullable
as int,vsyncUs: null == vsyncUs ? _self.vsyncUs : vsyncUs // ignore: cast_nullable_to_non_nullable
as int,buildStartUs: null == buildStartUs ? _self.buildStartUs : buildStartUs // ignore: cast_nullable_to_non_nullable
as int,buildFinishUs: null == buildFinishUs ? _self.buildFinishUs : buildFinishUs // ignore: cast_nullable_to_non_nullable
as int,rasterStartUs: null == rasterStartUs ? _self.rasterStartUs : rasterStartUs // ignore: cast_nullable_to_non_nullable
as int,rasterFinishUs: null == rasterFinishUs ? _self.rasterFinishUs : rasterFinishUs // ignore: cast_nullable_to_non_nullable
as int,rasterFinishWallUs: null == rasterFinishWallUs ? _self.rasterFinishWallUs : rasterFinishWallUs // ignore: cast_nullable_to_non_nullable
as int,arrivalMonotonicUs: null == arrivalMonotonicUs ? _self.arrivalMonotonicUs : arrivalMonotonicUs // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
