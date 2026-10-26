// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'motion_sample.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$MotionSample {

 int get frameNumber; int get schedulerUs; int get rawSchedulerUs; int get monotonicUs; double get progress;
/// Create a copy of MotionSample
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$MotionSampleCopyWith<MotionSample> get copyWith => _$MotionSampleCopyWithImpl<MotionSample>(this as MotionSample, _$identity);

  /// Serializes this MotionSample to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as MotionSample;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is MotionSample&&(identical(other.frameNumber, _this.frameNumber) || other.frameNumber == _this.frameNumber)&&(identical(other.schedulerUs, _this.schedulerUs) || other.schedulerUs == _this.schedulerUs)&&(identical(other.rawSchedulerUs, _this.rawSchedulerUs) || other.rawSchedulerUs == _this.rawSchedulerUs)&&(identical(other.monotonicUs, _this.monotonicUs) || other.monotonicUs == _this.monotonicUs)&&(identical(other.progress, _this.progress) || other.progress == _this.progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as MotionSample;
  return Object.hash(runtimeType,_this.frameNumber,_this.schedulerUs,_this.rawSchedulerUs,_this.monotonicUs,_this.progress);
}

@override
String toString() {
  final _this = this as MotionSample;
  return 'MotionSample(frameNumber: ${_this.frameNumber}, schedulerUs: ${_this.schedulerUs}, rawSchedulerUs: ${_this.rawSchedulerUs}, monotonicUs: ${_this.monotonicUs}, progress: ${_this.progress})';
}


}

/// @nodoc
abstract mixin class $MotionSampleCopyWith<$Res>  {
  factory $MotionSampleCopyWith(MotionSample value, $Res Function(MotionSample) _then) = _$MotionSampleCopyWithImpl;
@useResult
$Res call({
 int frameNumber, int schedulerUs, int rawSchedulerUs, int monotonicUs, double progress
});




}
/// @nodoc
class _$MotionSampleCopyWithImpl<$Res>
    implements $MotionSampleCopyWith<$Res> {
  _$MotionSampleCopyWithImpl(this._self, this._then);

  final MotionSample _self;
  final $Res Function(MotionSample) _then;

/// Create a copy of MotionSample
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? frameNumber = null,Object? schedulerUs = null,Object? rawSchedulerUs = null,Object? monotonicUs = null,Object? progress = null,}) {
  return _then(MotionSample(
frameNumber: null == frameNumber ? _self.frameNumber : frameNumber // ignore: cast_nullable_to_non_nullable
as int,schedulerUs: null == schedulerUs ? _self.schedulerUs : schedulerUs // ignore: cast_nullable_to_non_nullable
as int,rawSchedulerUs: null == rawSchedulerUs ? _self.rawSchedulerUs : rawSchedulerUs // ignore: cast_nullable_to_non_nullable
as int,monotonicUs: null == monotonicUs ? _self.monotonicUs : monotonicUs // ignore: cast_nullable_to_non_nullable
as int,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [MotionSample].
extension MotionSamplePatterns on MotionSample {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _MotionSample value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _MotionSample() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _MotionSample value)  $default,){
final _that = this;
switch (_that) {
case _MotionSample():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _MotionSample value)?  $default,){
final _that = this;
switch (_that) {
case _MotionSample() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int frameNumber,  int schedulerUs,  int rawSchedulerUs,  int monotonicUs,  double progress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _MotionSample() when $default != null:
return $default(_that.frameNumber,_that.schedulerUs,_that.rawSchedulerUs,_that.monotonicUs,_that.progress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int frameNumber,  int schedulerUs,  int rawSchedulerUs,  int monotonicUs,  double progress)  $default,) {final _that = this;
switch (_that) {
case _MotionSample():
return $default(_that.frameNumber,_that.schedulerUs,_that.rawSchedulerUs,_that.monotonicUs,_that.progress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int frameNumber,  int schedulerUs,  int rawSchedulerUs,  int monotonicUs,  double progress)?  $default,) {final _that = this;
switch (_that) {
case _MotionSample() when $default != null:
return $default(_that.frameNumber,_that.schedulerUs,_that.rawSchedulerUs,_that.monotonicUs,_that.progress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _MotionSample implements MotionSample {
  const _MotionSample({required this.frameNumber, required this.schedulerUs, required this.rawSchedulerUs, required this.monotonicUs, required this.progress});
  factory _MotionSample.fromJson(Map<String, dynamic> json) => _$MotionSampleFromJson(json);

@override final  int frameNumber;
@override final  int schedulerUs;
@override final  int rawSchedulerUs;
@override final  int monotonicUs;
@override final  double progress;

/// Create a copy of MotionSample
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$MotionSampleCopyWith<_MotionSample> get copyWith => __$MotionSampleCopyWithImpl<_MotionSample>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$MotionSampleToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _MotionSample&&(identical(other.frameNumber, frameNumber) || other.frameNumber == frameNumber)&&(identical(other.schedulerUs, schedulerUs) || other.schedulerUs == schedulerUs)&&(identical(other.rawSchedulerUs, rawSchedulerUs) || other.rawSchedulerUs == rawSchedulerUs)&&(identical(other.monotonicUs, monotonicUs) || other.monotonicUs == monotonicUs)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,frameNumber,schedulerUs,rawSchedulerUs,monotonicUs,progress);
}

@override
String toString() {
    return 'MotionSample(frameNumber: $frameNumber, schedulerUs: $schedulerUs, rawSchedulerUs: $rawSchedulerUs, monotonicUs: $monotonicUs, progress: $progress)';
}


}

/// @nodoc
abstract mixin class _$MotionSampleCopyWith<$Res> implements $MotionSampleCopyWith<$Res> {
  factory _$MotionSampleCopyWith(_MotionSample value, $Res Function(_MotionSample) _then) = __$MotionSampleCopyWithImpl;
@override @useResult
$Res call({
 int frameNumber, int schedulerUs, int rawSchedulerUs, int monotonicUs, double progress
});




}
/// @nodoc
class __$MotionSampleCopyWithImpl<$Res>
    implements _$MotionSampleCopyWith<$Res> {
  __$MotionSampleCopyWithImpl(this._self, this._then);

  final _MotionSample _self;
  final $Res Function(_MotionSample) _then;

/// Create a copy of MotionSample
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? frameNumber = null,Object? schedulerUs = null,Object? rawSchedulerUs = null,Object? monotonicUs = null,Object? progress = null,}) {
  return _then(_MotionSample(
frameNumber: null == frameNumber ? _self.frameNumber : frameNumber // ignore: cast_nullable_to_non_nullable
as int,schedulerUs: null == schedulerUs ? _self.schedulerUs : schedulerUs // ignore: cast_nullable_to_non_nullable
as int,rawSchedulerUs: null == rawSchedulerUs ? _self.rawSchedulerUs : rawSchedulerUs // ignore: cast_nullable_to_non_nullable
as int,monotonicUs: null == monotonicUs ? _self.monotonicUs : monotonicUs // ignore: cast_nullable_to_non_nullable
as int,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
