// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'snapshot_folder.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SnapshotFolder {

@JsonKey(required: true, fromJson: positiveId) int get id;@JsonKey(required: true) String get name;@JsonKey(required: true, fromJson: safeInteger) int get sortOrder;@JsonKey(required: true, fromJson: nonnegativeInteger) int get bookCount;@JsonKey(required: true, fromJson: idList) List<int> get bookIds;@JsonKey(required: true, fromJson: idList) List<int> get previewBookIds;@JsonKey(required: true) ServerTimestamp get createdAt;@JsonKey(required: true) ServerTimestamp get updatedAt;
/// Create a copy of SnapshotFolder
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SnapshotFolderCopyWith<SnapshotFolder> get copyWith => _$SnapshotFolderCopyWithImpl<SnapshotFolder>(this as SnapshotFolder, _$identity);

  /// Serializes this SnapshotFolder to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SnapshotFolder;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SnapshotFolder&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.name, _this.name) || other.name == _this.name)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.bookCount, _this.bookCount) || other.bookCount == _this.bookCount)&&const DeepCollectionEquality().equals(other.bookIds, _this.bookIds)&&const DeepCollectionEquality().equals(other.previewBookIds, _this.previewBookIds)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SnapshotFolder;
  return Object.hash(runtimeType,_this.id,_this.name,_this.sortOrder,_this.bookCount,const DeepCollectionEquality().hash(_this.bookIds),const DeepCollectionEquality().hash(_this.previewBookIds),_this.createdAt,_this.updatedAt);
}

@override
String toString() {
  final _this = this as SnapshotFolder;
  return 'SnapshotFolder(id: ${_this.id}, name: ${_this.name}, sortOrder: ${_this.sortOrder}, bookCount: ${_this.bookCount}, bookIds: ${_this.bookIds}, previewBookIds: ${_this.previewBookIds}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $SnapshotFolderCopyWith<$Res>  {
  factory $SnapshotFolderCopyWith(SnapshotFolder value, $Res Function(SnapshotFolder) _then) = _$SnapshotFolderCopyWithImpl;
@useResult
$Res call({
@JsonKey(required: true, fromJson: positiveId) int id,@JsonKey(required: true) String name,@JsonKey(required: true, fromJson: safeInteger) int sortOrder,@JsonKey(required: true, fromJson: nonnegativeInteger) int bookCount,@JsonKey(required: true, fromJson: idList) List<int> bookIds,@JsonKey(required: true, fromJson: idList) List<int> previewBookIds,@JsonKey(required: true) ServerTimestamp createdAt,@JsonKey(required: true) ServerTimestamp updatedAt
});




}
/// @nodoc
class _$SnapshotFolderCopyWithImpl<$Res>
    implements $SnapshotFolderCopyWith<$Res> {
  _$SnapshotFolderCopyWithImpl(this._self, this._then);

  final SnapshotFolder _self;
  final $Res Function(SnapshotFolder) _then;

/// Create a copy of SnapshotFolder
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? sortOrder = null,Object? bookCount = null,Object? bookIds = null,Object? previewBookIds = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(SnapshotFolder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,bookCount: null == bookCount ? _self.bookCount : bookCount // ignore: cast_nullable_to_non_nullable
as int,bookIds: null == bookIds ? _self.bookIds : bookIds // ignore: cast_nullable_to_non_nullable
as List<int>,previewBookIds: null == previewBookIds ? _self.previewBookIds : previewBookIds // ignore: cast_nullable_to_non_nullable
as List<int>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,
  ));
}

}


/// Adds pattern-matching-related methods to [SnapshotFolder].
extension SnapshotFolderPatterns on SnapshotFolder {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SnapshotFolder value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SnapshotFolder() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SnapshotFolder value)  $default,){
final _that = this;
switch (_that) {
case _SnapshotFolder():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SnapshotFolder value)?  $default,){
final _that = this;
switch (_that) {
case _SnapshotFolder() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true)  String name, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder, @JsonKey(required: true, fromJson: nonnegativeInteger)  int bookCount, @JsonKey(required: true, fromJson: idList)  List<int> bookIds, @JsonKey(required: true, fromJson: idList)  List<int> previewBookIds, @JsonKey(required: true)  ServerTimestamp createdAt, @JsonKey(required: true)  ServerTimestamp updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SnapshotFolder() when $default != null:
return $default(_that.id,_that.name,_that.sortOrder,_that.bookCount,_that.bookIds,_that.previewBookIds,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true)  String name, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder, @JsonKey(required: true, fromJson: nonnegativeInteger)  int bookCount, @JsonKey(required: true, fromJson: idList)  List<int> bookIds, @JsonKey(required: true, fromJson: idList)  List<int> previewBookIds, @JsonKey(required: true)  ServerTimestamp createdAt, @JsonKey(required: true)  ServerTimestamp updatedAt)  $default,) {final _that = this;
switch (_that) {
case _SnapshotFolder():
return $default(_that.id,_that.name,_that.sortOrder,_that.bookCount,_that.bookIds,_that.previewBookIds,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true)  String name, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder, @JsonKey(required: true, fromJson: nonnegativeInteger)  int bookCount, @JsonKey(required: true, fromJson: idList)  List<int> bookIds, @JsonKey(required: true, fromJson: idList)  List<int> previewBookIds, @JsonKey(required: true)  ServerTimestamp createdAt, @JsonKey(required: true)  ServerTimestamp updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _SnapshotFolder() when $default != null:
return $default(_that.id,_that.name,_that.sortOrder,_that.bookCount,_that.bookIds,_that.previewBookIds,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@ServerTimestampConverter()
class _SnapshotFolder implements SnapshotFolder {
  const _SnapshotFolder({@JsonKey(required: true, fromJson: positiveId) required this.id, @JsonKey(required: true) required this.name, @JsonKey(required: true, fromJson: safeInteger) required this.sortOrder, @JsonKey(required: true, fromJson: nonnegativeInteger) required this.bookCount, @JsonKey(required: true, fromJson: idList) required  List<int> bookIds, @JsonKey(required: true, fromJson: idList) required  List<int> previewBookIds, @JsonKey(required: true) required this.createdAt, @JsonKey(required: true) required this.updatedAt}): _bookIds = bookIds,_previewBookIds = previewBookIds;
  factory _SnapshotFolder.fromJson(Map<String, dynamic> json) => _$SnapshotFolderFromJson(json);

@override@JsonKey(required: true, fromJson: positiveId) final  int id;
@override@JsonKey(required: true) final  String name;
@override@JsonKey(required: true, fromJson: safeInteger) final  int sortOrder;
@override@JsonKey(required: true, fromJson: nonnegativeInteger) final  int bookCount;
 final  List<int> _bookIds;
@override@JsonKey(required: true, fromJson: idList) List<int> get bookIds {
  if (_bookIds is EqualUnmodifiableListView) return _bookIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_bookIds);
}

 final  List<int> _previewBookIds;
@override@JsonKey(required: true, fromJson: idList) List<int> get previewBookIds {
  if (_previewBookIds is EqualUnmodifiableListView) return _previewBookIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_previewBookIds);
}

@override@JsonKey(required: true) final  ServerTimestamp createdAt;
@override@JsonKey(required: true) final  ServerTimestamp updatedAt;

/// Create a copy of SnapshotFolder
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SnapshotFolderCopyWith<_SnapshotFolder> get copyWith => __$SnapshotFolderCopyWithImpl<_SnapshotFolder>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SnapshotFolderToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SnapshotFolder&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.bookCount, bookCount) || other.bookCount == bookCount)&&const DeepCollectionEquality().equals(other.bookIds, _bookIds)&&const DeepCollectionEquality().equals(other.previewBookIds, _previewBookIds)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,name,sortOrder,bookCount,const DeepCollectionEquality().hash(_bookIds),const DeepCollectionEquality().hash(_previewBookIds),createdAt,updatedAt);
}

@override
String toString() {
    return 'SnapshotFolder(id: $id, name: $name, sortOrder: $sortOrder, bookCount: $bookCount, bookIds: $bookIds, previewBookIds: $previewBookIds, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$SnapshotFolderCopyWith<$Res> implements $SnapshotFolderCopyWith<$Res> {
  factory _$SnapshotFolderCopyWith(_SnapshotFolder value, $Res Function(_SnapshotFolder) _then) = __$SnapshotFolderCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(required: true, fromJson: positiveId) int id,@JsonKey(required: true) String name,@JsonKey(required: true, fromJson: safeInteger) int sortOrder,@JsonKey(required: true, fromJson: nonnegativeInteger) int bookCount,@JsonKey(required: true, fromJson: idList) List<int> bookIds,@JsonKey(required: true, fromJson: idList) List<int> previewBookIds,@JsonKey(required: true) ServerTimestamp createdAt,@JsonKey(required: true) ServerTimestamp updatedAt
});




}
/// @nodoc
class __$SnapshotFolderCopyWithImpl<$Res>
    implements _$SnapshotFolderCopyWith<$Res> {
  __$SnapshotFolderCopyWithImpl(this._self, this._then);

  final _SnapshotFolder _self;
  final $Res Function(_SnapshotFolder) _then;

/// Create a copy of SnapshotFolder
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? sortOrder = null,Object? bookCount = null,Object? bookIds = null,Object? previewBookIds = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_SnapshotFolder(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,bookCount: null == bookCount ? _self.bookCount : bookCount // ignore: cast_nullable_to_non_nullable
as int,bookIds: null == bookIds ? _self._bookIds : bookIds // ignore: cast_nullable_to_non_nullable
as List<int>,previewBookIds: null == previewBookIds ? _self._previewBookIds : previewBookIds // ignore: cast_nullable_to_non_nullable
as List<int>,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,
  ));
}


}

// dart format on
