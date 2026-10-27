// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reading_position.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReadingPosition {

@JsonKey(required: true, fromJson: positiveId) int get bookId;@JsonKey(required: true) String? get cfi;@JsonKey(required: true, fromJson: progressValue) double get progress;@JsonKey(required: true) String? get chapterHref;@JsonKey(required: true) String? get chapterLabel;@JsonKey(required: true, fromJson: nullableCount) int? get chapterCount;@JsonKey(required: true, fromJson: nullableIndex) int? get chapterIndex;@JsonKey(required: true) ServerTimestamp get updatedAt;
/// Create a copy of ReadingPosition
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReadingPositionCopyWith<ReadingPosition> get copyWith => _$ReadingPositionCopyWithImpl<ReadingPosition>(this as ReadingPosition, _$identity);

  /// Serializes this ReadingPosition to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReadingPosition;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReadingPosition&&(identical(other.bookId, _this.bookId) || other.bookId == _this.bookId)&&(identical(other.cfi, _this.cfi) || other.cfi == _this.cfi)&&(identical(other.progress, _this.progress) || other.progress == _this.progress)&&(identical(other.chapterHref, _this.chapterHref) || other.chapterHref == _this.chapterHref)&&(identical(other.chapterLabel, _this.chapterLabel) || other.chapterLabel == _this.chapterLabel)&&(identical(other.chapterCount, _this.chapterCount) || other.chapterCount == _this.chapterCount)&&(identical(other.chapterIndex, _this.chapterIndex) || other.chapterIndex == _this.chapterIndex)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReadingPosition;
  return Object.hash(runtimeType,_this.bookId,_this.cfi,_this.progress,_this.chapterHref,_this.chapterLabel,_this.chapterCount,_this.chapterIndex,_this.updatedAt);
}

@override
String toString() {
  final _this = this as ReadingPosition;
  return 'ReadingPosition(bookId: ${_this.bookId}, cfi: ${_this.cfi}, progress: ${_this.progress}, chapterHref: ${_this.chapterHref}, chapterLabel: ${_this.chapterLabel}, chapterCount: ${_this.chapterCount}, chapterIndex: ${_this.chapterIndex}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $ReadingPositionCopyWith<$Res>  {
  factory $ReadingPositionCopyWith(ReadingPosition value, $Res Function(ReadingPosition) _then) = _$ReadingPositionCopyWithImpl;
@useResult
$Res call({
@JsonKey(required: true, fromJson: positiveId) int bookId,@JsonKey(required: true) String? cfi,@JsonKey(required: true, fromJson: progressValue) double progress,@JsonKey(required: true) String? chapterHref,@JsonKey(required: true) String? chapterLabel,@JsonKey(required: true, fromJson: nullableCount) int? chapterCount,@JsonKey(required: true, fromJson: nullableIndex) int? chapterIndex,@JsonKey(required: true) ServerTimestamp updatedAt
});




}
/// @nodoc
class _$ReadingPositionCopyWithImpl<$Res>
    implements $ReadingPositionCopyWith<$Res> {
  _$ReadingPositionCopyWithImpl(this._self, this._then);

  final ReadingPosition _self;
  final $Res Function(ReadingPosition) _then;

/// Create a copy of ReadingPosition
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookId = null,Object? cfi = freezed,Object? progress = null,Object? chapterHref = freezed,Object? chapterLabel = freezed,Object? chapterCount = freezed,Object? chapterIndex = freezed,Object? updatedAt = null,}) {
  return _then(ReadingPosition(
bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,cfi: freezed == cfi ? _self.cfi : cfi // ignore: cast_nullable_to_non_nullable
as String?,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,chapterHref: freezed == chapterHref ? _self.chapterHref : chapterHref // ignore: cast_nullable_to_non_nullable
as String?,chapterLabel: freezed == chapterLabel ? _self.chapterLabel : chapterLabel // ignore: cast_nullable_to_non_nullable
as String?,chapterCount: freezed == chapterCount ? _self.chapterCount : chapterCount // ignore: cast_nullable_to_non_nullable
as int?,chapterIndex: freezed == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,
  ));
}

}


/// Adds pattern-matching-related methods to [ReadingPosition].
extension ReadingPositionPatterns on ReadingPosition {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReadingPosition value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReadingPosition() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReadingPosition value)  $default,){
final _that = this;
switch (_that) {
case _ReadingPosition():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReadingPosition value)?  $default,){
final _that = this;
switch (_that) {
case _ReadingPosition() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(required: true, fromJson: positiveId)  int bookId, @JsonKey(required: true)  String? cfi, @JsonKey(required: true, fromJson: progressValue)  double progress, @JsonKey(required: true)  String? chapterHref, @JsonKey(required: true)  String? chapterLabel, @JsonKey(required: true, fromJson: nullableCount)  int? chapterCount, @JsonKey(required: true, fromJson: nullableIndex)  int? chapterIndex, @JsonKey(required: true)  ServerTimestamp updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReadingPosition() when $default != null:
return $default(_that.bookId,_that.cfi,_that.progress,_that.chapterHref,_that.chapterLabel,_that.chapterCount,_that.chapterIndex,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(required: true, fromJson: positiveId)  int bookId, @JsonKey(required: true)  String? cfi, @JsonKey(required: true, fromJson: progressValue)  double progress, @JsonKey(required: true)  String? chapterHref, @JsonKey(required: true)  String? chapterLabel, @JsonKey(required: true, fromJson: nullableCount)  int? chapterCount, @JsonKey(required: true, fromJson: nullableIndex)  int? chapterIndex, @JsonKey(required: true)  ServerTimestamp updatedAt)  $default,) {final _that = this;
switch (_that) {
case _ReadingPosition():
return $default(_that.bookId,_that.cfi,_that.progress,_that.chapterHref,_that.chapterLabel,_that.chapterCount,_that.chapterIndex,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(required: true, fromJson: positiveId)  int bookId, @JsonKey(required: true)  String? cfi, @JsonKey(required: true, fromJson: progressValue)  double progress, @JsonKey(required: true)  String? chapterHref, @JsonKey(required: true)  String? chapterLabel, @JsonKey(required: true, fromJson: nullableCount)  int? chapterCount, @JsonKey(required: true, fromJson: nullableIndex)  int? chapterIndex, @JsonKey(required: true)  ServerTimestamp updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _ReadingPosition() when $default != null:
return $default(_that.bookId,_that.cfi,_that.progress,_that.chapterHref,_that.chapterLabel,_that.chapterCount,_that.chapterIndex,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@ServerTimestampConverter()
class _ReadingPosition implements ReadingPosition {
  const _ReadingPosition({@JsonKey(required: true, fromJson: positiveId) required this.bookId, @JsonKey(required: true) required this.cfi, @JsonKey(required: true, fromJson: progressValue) required this.progress, @JsonKey(required: true) required this.chapterHref, @JsonKey(required: true) required this.chapterLabel, @JsonKey(required: true, fromJson: nullableCount) required this.chapterCount, @JsonKey(required: true, fromJson: nullableIndex) required this.chapterIndex, @JsonKey(required: true) required this.updatedAt});
  factory _ReadingPosition.fromJson(Map<String, dynamic> json) => _$ReadingPositionFromJson(json);

@override@JsonKey(required: true, fromJson: positiveId) final  int bookId;
@override@JsonKey(required: true) final  String? cfi;
@override@JsonKey(required: true, fromJson: progressValue) final  double progress;
@override@JsonKey(required: true) final  String? chapterHref;
@override@JsonKey(required: true) final  String? chapterLabel;
@override@JsonKey(required: true, fromJson: nullableCount) final  int? chapterCount;
@override@JsonKey(required: true, fromJson: nullableIndex) final  int? chapterIndex;
@override@JsonKey(required: true) final  ServerTimestamp updatedAt;

/// Create a copy of ReadingPosition
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReadingPositionCopyWith<_ReadingPosition> get copyWith => __$ReadingPositionCopyWithImpl<_ReadingPosition>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReadingPositionToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReadingPosition&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.cfi, cfi) || other.cfi == cfi)&&(identical(other.progress, progress) || other.progress == progress)&&(identical(other.chapterHref, chapterHref) || other.chapterHref == chapterHref)&&(identical(other.chapterLabel, chapterLabel) || other.chapterLabel == chapterLabel)&&(identical(other.chapterCount, chapterCount) || other.chapterCount == chapterCount)&&(identical(other.chapterIndex, chapterIndex) || other.chapterIndex == chapterIndex)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,bookId,cfi,progress,chapterHref,chapterLabel,chapterCount,chapterIndex,updatedAt);
}

@override
String toString() {
    return 'ReadingPosition(bookId: $bookId, cfi: $cfi, progress: $progress, chapterHref: $chapterHref, chapterLabel: $chapterLabel, chapterCount: $chapterCount, chapterIndex: $chapterIndex, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$ReadingPositionCopyWith<$Res> implements $ReadingPositionCopyWith<$Res> {
  factory _$ReadingPositionCopyWith(_ReadingPosition value, $Res Function(_ReadingPosition) _then) = __$ReadingPositionCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(required: true, fromJson: positiveId) int bookId,@JsonKey(required: true) String? cfi,@JsonKey(required: true, fromJson: progressValue) double progress,@JsonKey(required: true) String? chapterHref,@JsonKey(required: true) String? chapterLabel,@JsonKey(required: true, fromJson: nullableCount) int? chapterCount,@JsonKey(required: true, fromJson: nullableIndex) int? chapterIndex,@JsonKey(required: true) ServerTimestamp updatedAt
});




}
/// @nodoc
class __$ReadingPositionCopyWithImpl<$Res>
    implements _$ReadingPositionCopyWith<$Res> {
  __$ReadingPositionCopyWithImpl(this._self, this._then);

  final _ReadingPosition _self;
  final $Res Function(_ReadingPosition) _then;

/// Create a copy of ReadingPosition
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookId = null,Object? cfi = freezed,Object? progress = null,Object? chapterHref = freezed,Object? chapterLabel = freezed,Object? chapterCount = freezed,Object? chapterIndex = freezed,Object? updatedAt = null,}) {
  return _then(_ReadingPosition(
bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,cfi: freezed == cfi ? _self.cfi : cfi // ignore: cast_nullable_to_non_nullable
as String?,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as double,chapterHref: freezed == chapterHref ? _self.chapterHref : chapterHref // ignore: cast_nullable_to_non_nullable
as String?,chapterLabel: freezed == chapterLabel ? _self.chapterLabel : chapterLabel // ignore: cast_nullable_to_non_nullable
as String?,chapterCount: freezed == chapterCount ? _self.chapterCount : chapterCount // ignore: cast_nullable_to_non_nullable
as int?,chapterIndex: freezed == chapterIndex ? _self.chapterIndex : chapterIndex // ignore: cast_nullable_to_non_nullable
as int?,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,
  ));
}


}

// dart format on
