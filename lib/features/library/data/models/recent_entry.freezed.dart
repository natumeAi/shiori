// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'recent_entry.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$RecentEntry {

@JsonKey(required: true, fromJson: positiveId) int get bookId;@JsonKey(required: true) ReadingPosition get progress;
/// Create a copy of RecentEntry
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RecentEntryCopyWith<RecentEntry> get copyWith => _$RecentEntryCopyWithImpl<RecentEntry>(this as RecentEntry, _$identity);

  /// Serializes this RecentEntry to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as RecentEntry;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RecentEntry&&(identical(other.bookId, _this.bookId) || other.bookId == _this.bookId)&&(identical(other.progress, _this.progress) || other.progress == _this.progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as RecentEntry;
  return Object.hash(runtimeType,_this.bookId,_this.progress);
}

@override
String toString() {
  final _this = this as RecentEntry;
  return 'RecentEntry(bookId: ${_this.bookId}, progress: ${_this.progress})';
}


}

/// @nodoc
abstract mixin class $RecentEntryCopyWith<$Res>  {
  factory $RecentEntryCopyWith(RecentEntry value, $Res Function(RecentEntry) _then) = _$RecentEntryCopyWithImpl;
@useResult
$Res call({
@JsonKey(required: true, fromJson: positiveId) int bookId,@JsonKey(required: true) ReadingPosition progress
});


$ReadingPositionCopyWith<$Res> get progress;

}
/// @nodoc
class _$RecentEntryCopyWithImpl<$Res>
    implements $RecentEntryCopyWith<$Res> {
  _$RecentEntryCopyWithImpl(this._self, this._then);

  final RecentEntry _self;
  final $Res Function(RecentEntry) _then;

/// Create a copy of RecentEntry
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? bookId = null,Object? progress = null,}) {
  return _then(RecentEntry(
bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as ReadingPosition,
  ));
}
/// Create a copy of RecentEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReadingPositionCopyWith<$Res> get progress {
  
  return $ReadingPositionCopyWith<$Res>(_self.progress, (value) {
    return _then(_self.copyWith(progress: value));
  });
}
}


/// Adds pattern-matching-related methods to [RecentEntry].
extension RecentEntryPatterns on RecentEntry {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RecentEntry value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RecentEntry() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RecentEntry value)  $default,){
final _that = this;
switch (_that) {
case _RecentEntry():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RecentEntry value)?  $default,){
final _that = this;
switch (_that) {
case _RecentEntry() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(required: true, fromJson: positiveId)  int bookId, @JsonKey(required: true)  ReadingPosition progress)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RecentEntry() when $default != null:
return $default(_that.bookId,_that.progress);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(required: true, fromJson: positiveId)  int bookId, @JsonKey(required: true)  ReadingPosition progress)  $default,) {final _that = this;
switch (_that) {
case _RecentEntry():
return $default(_that.bookId,_that.progress);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(required: true, fromJson: positiveId)  int bookId, @JsonKey(required: true)  ReadingPosition progress)?  $default,) {final _that = this;
switch (_that) {
case _RecentEntry() when $default != null:
return $default(_that.bookId,_that.progress);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _RecentEntry implements RecentEntry {
  const _RecentEntry({@JsonKey(required: true, fromJson: positiveId) required this.bookId, @JsonKey(required: true) required this.progress});
  factory _RecentEntry.fromJson(Map<String, dynamic> json) => _$RecentEntryFromJson(json);

@override@JsonKey(required: true, fromJson: positiveId) final  int bookId;
@override@JsonKey(required: true) final  ReadingPosition progress;

/// Create a copy of RecentEntry
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RecentEntryCopyWith<_RecentEntry> get copyWith => __$RecentEntryCopyWithImpl<_RecentEntry>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$RecentEntryToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _RecentEntry&&(identical(other.bookId, bookId) || other.bookId == bookId)&&(identical(other.progress, progress) || other.progress == progress));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,bookId,progress);
}

@override
String toString() {
    return 'RecentEntry(bookId: $bookId, progress: $progress)';
}


}

/// @nodoc
abstract mixin class _$RecentEntryCopyWith<$Res> implements $RecentEntryCopyWith<$Res> {
  factory _$RecentEntryCopyWith(_RecentEntry value, $Res Function(_RecentEntry) _then) = __$RecentEntryCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(required: true, fromJson: positiveId) int bookId,@JsonKey(required: true) ReadingPosition progress
});


@override $ReadingPositionCopyWith<$Res> get progress;

}
/// @nodoc
class __$RecentEntryCopyWithImpl<$Res>
    implements _$RecentEntryCopyWith<$Res> {
  __$RecentEntryCopyWithImpl(this._self, this._then);

  final _RecentEntry _self;
  final $Res Function(_RecentEntry) _then;

/// Create a copy of RecentEntry
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? bookId = null,Object? progress = null,}) {
  return _then(_RecentEntry(
bookId: null == bookId ? _self.bookId : bookId // ignore: cast_nullable_to_non_nullable
as int,progress: null == progress ? _self.progress : progress // ignore: cast_nullable_to_non_nullable
as ReadingPosition,
  ));
}

/// Create a copy of RecentEntry
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ReadingPositionCopyWith<$Res> get progress {
  
  return $ReadingPositionCopyWith<$Res>(_self.progress, (value) {
    return _then(_self.copyWith(progress: value));
  });
}
}

// dart format on
