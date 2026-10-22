// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'probe_declarations.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProbeDeclarations {

 String get deviceModel; DeclaredSetting get lowPowerMode; DeclaredSetting get limitFrameRate; DeclaredSetting get charging; DeclaredSetting get warm; String get source;
/// Create a copy of ProbeDeclarations
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProbeDeclarationsCopyWith<ProbeDeclarations> get copyWith => _$ProbeDeclarationsCopyWithImpl<ProbeDeclarations>(this as ProbeDeclarations, _$identity);

  /// Serializes this ProbeDeclarations to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProbeDeclarations;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProbeDeclarations&&(identical(other.deviceModel, _this.deviceModel) || other.deviceModel == _this.deviceModel)&&(identical(other.lowPowerMode, _this.lowPowerMode) || other.lowPowerMode == _this.lowPowerMode)&&(identical(other.limitFrameRate, _this.limitFrameRate) || other.limitFrameRate == _this.limitFrameRate)&&(identical(other.charging, _this.charging) || other.charging == _this.charging)&&(identical(other.warm, _this.warm) || other.warm == _this.warm)&&(identical(other.source, _this.source) || other.source == _this.source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProbeDeclarations;
  return Object.hash(runtimeType,_this.deviceModel,_this.lowPowerMode,_this.limitFrameRate,_this.charging,_this.warm,_this.source);
}

@override
String toString() {
  final _this = this as ProbeDeclarations;
  return 'ProbeDeclarations(deviceModel: ${_this.deviceModel}, lowPowerMode: ${_this.lowPowerMode}, limitFrameRate: ${_this.limitFrameRate}, charging: ${_this.charging}, warm: ${_this.warm}, source: ${_this.source})';
}


}

/// @nodoc
abstract mixin class $ProbeDeclarationsCopyWith<$Res>  {
  factory $ProbeDeclarationsCopyWith(ProbeDeclarations value, $Res Function(ProbeDeclarations) _then) = _$ProbeDeclarationsCopyWithImpl;
@useResult
$Res call({
 String deviceModel, DeclaredSetting lowPowerMode, DeclaredSetting limitFrameRate, DeclaredSetting charging, DeclaredSetting warm, String source
});




}
/// @nodoc
class _$ProbeDeclarationsCopyWithImpl<$Res>
    implements $ProbeDeclarationsCopyWith<$Res> {
  _$ProbeDeclarationsCopyWithImpl(this._self, this._then);

  final ProbeDeclarations _self;
  final $Res Function(ProbeDeclarations) _then;

/// Create a copy of ProbeDeclarations
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? deviceModel = null,Object? lowPowerMode = null,Object? limitFrameRate = null,Object? charging = null,Object? warm = null,Object? source = null,}) {
  return _then(ProbeDeclarations(
deviceModel: null == deviceModel ? _self.deviceModel : deviceModel // ignore: cast_nullable_to_non_nullable
as String,lowPowerMode: null == lowPowerMode ? _self.lowPowerMode : lowPowerMode // ignore: cast_nullable_to_non_nullable
as DeclaredSetting,limitFrameRate: null == limitFrameRate ? _self.limitFrameRate : limitFrameRate // ignore: cast_nullable_to_non_nullable
as DeclaredSetting,charging: null == charging ? _self.charging : charging // ignore: cast_nullable_to_non_nullable
as DeclaredSetting,warm: null == warm ? _self.warm : warm // ignore: cast_nullable_to_non_nullable
as DeclaredSetting,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [ProbeDeclarations].
extension ProbeDeclarationsPatterns on ProbeDeclarations {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProbeDeclarations value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProbeDeclarations() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProbeDeclarations value)  $default,){
final _that = this;
switch (_that) {
case _ProbeDeclarations():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProbeDeclarations value)?  $default,){
final _that = this;
switch (_that) {
case _ProbeDeclarations() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String deviceModel,  DeclaredSetting lowPowerMode,  DeclaredSetting limitFrameRate,  DeclaredSetting charging,  DeclaredSetting warm,  String source)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProbeDeclarations() when $default != null:
return $default(_that.deviceModel,_that.lowPowerMode,_that.limitFrameRate,_that.charging,_that.warm,_that.source);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String deviceModel,  DeclaredSetting lowPowerMode,  DeclaredSetting limitFrameRate,  DeclaredSetting charging,  DeclaredSetting warm,  String source)  $default,) {final _that = this;
switch (_that) {
case _ProbeDeclarations():
return $default(_that.deviceModel,_that.lowPowerMode,_that.limitFrameRate,_that.charging,_that.warm,_that.source);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String deviceModel,  DeclaredSetting lowPowerMode,  DeclaredSetting limitFrameRate,  DeclaredSetting charging,  DeclaredSetting warm,  String source)?  $default,) {final _that = this;
switch (_that) {
case _ProbeDeclarations() when $default != null:
return $default(_that.deviceModel,_that.lowPowerMode,_that.limitFrameRate,_that.charging,_that.warm,_that.source);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProbeDeclarations implements ProbeDeclarations {
  const _ProbeDeclarations({this.deviceModel = '', this.lowPowerMode = DeclaredSetting.unknown, this.limitFrameRate = DeclaredSetting.unknown, this.charging = DeclaredSetting.unknown, this.warm = DeclaredSetting.unknown, this.source = 'user_provided'});
  factory _ProbeDeclarations.fromJson(Map<String, dynamic> json) => _$ProbeDeclarationsFromJson(json);

@override@JsonKey() final  String deviceModel;
@override@JsonKey() final  DeclaredSetting lowPowerMode;
@override@JsonKey() final  DeclaredSetting limitFrameRate;
@override@JsonKey() final  DeclaredSetting charging;
@override@JsonKey() final  DeclaredSetting warm;
@override@JsonKey() final  String source;

/// Create a copy of ProbeDeclarations
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProbeDeclarationsCopyWith<_ProbeDeclarations> get copyWith => __$ProbeDeclarationsCopyWithImpl<_ProbeDeclarations>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProbeDeclarationsToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProbeDeclarations&&(identical(other.deviceModel, deviceModel) || other.deviceModel == deviceModel)&&(identical(other.lowPowerMode, lowPowerMode) || other.lowPowerMode == lowPowerMode)&&(identical(other.limitFrameRate, limitFrameRate) || other.limitFrameRate == limitFrameRate)&&(identical(other.charging, charging) || other.charging == charging)&&(identical(other.warm, warm) || other.warm == warm)&&(identical(other.source, source) || other.source == source));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,deviceModel,lowPowerMode,limitFrameRate,charging,warm,source);
}

@override
String toString() {
    return 'ProbeDeclarations(deviceModel: $deviceModel, lowPowerMode: $lowPowerMode, limitFrameRate: $limitFrameRate, charging: $charging, warm: $warm, source: $source)';
}


}

/// @nodoc
abstract mixin class _$ProbeDeclarationsCopyWith<$Res> implements $ProbeDeclarationsCopyWith<$Res> {
  factory _$ProbeDeclarationsCopyWith(_ProbeDeclarations value, $Res Function(_ProbeDeclarations) _then) = __$ProbeDeclarationsCopyWithImpl;
@override @useResult
$Res call({
 String deviceModel, DeclaredSetting lowPowerMode, DeclaredSetting limitFrameRate, DeclaredSetting charging, DeclaredSetting warm, String source
});




}
/// @nodoc
class __$ProbeDeclarationsCopyWithImpl<$Res>
    implements _$ProbeDeclarationsCopyWith<$Res> {
  __$ProbeDeclarationsCopyWithImpl(this._self, this._then);

  final _ProbeDeclarations _self;
  final $Res Function(_ProbeDeclarations) _then;

/// Create a copy of ProbeDeclarations
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? deviceModel = null,Object? lowPowerMode = null,Object? limitFrameRate = null,Object? charging = null,Object? warm = null,Object? source = null,}) {
  return _then(_ProbeDeclarations(
deviceModel: null == deviceModel ? _self.deviceModel : deviceModel // ignore: cast_nullable_to_non_nullable
as String,lowPowerMode: null == lowPowerMode ? _self.lowPowerMode : lowPowerMode // ignore: cast_nullable_to_non_nullable
as DeclaredSetting,limitFrameRate: null == limitFrameRate ? _self.limitFrameRate : limitFrameRate // ignore: cast_nullable_to_non_nullable
as DeclaredSetting,charging: null == charging ? _self.charging : charging // ignore: cast_nullable_to_non_nullable
as DeclaredSetting,warm: null == warm ? _self.warm : warm // ignore: cast_nullable_to_non_nullable
as DeclaredSetting,source: null == source ? _self.source : source // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
