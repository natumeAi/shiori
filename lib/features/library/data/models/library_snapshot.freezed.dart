// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'library_snapshot.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LibrarySnapshot {

@JsonKey(required: true, fromJson: snapshotSchemaVersion) int get schemaVersion;@JsonKey(required: true, fromJson: nonnegativeInteger) int get version;@JsonKey(required: true) List<SnapshotBook> get books;@JsonKey(required: true) List<SnapshotFolder> get folders;@JsonKey(required: true) List<ShelfRef> get shelf;@JsonKey(required: true) List<RecentEntry> get recent;
/// Create a copy of LibrarySnapshot
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LibrarySnapshotCopyWith<LibrarySnapshot> get copyWith => _$LibrarySnapshotCopyWithImpl<LibrarySnapshot>(this as LibrarySnapshot, _$identity);

  /// Serializes this LibrarySnapshot to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as LibrarySnapshot;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LibrarySnapshot&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion)&&(identical(other.version, _this.version) || other.version == _this.version)&&const DeepCollectionEquality().equals(other.books, _this.books)&&const DeepCollectionEquality().equals(other.folders, _this.folders)&&const DeepCollectionEquality().equals(other.shelf, _this.shelf)&&const DeepCollectionEquality().equals(other.recent, _this.recent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as LibrarySnapshot;
  return Object.hash(runtimeType,_this.schemaVersion,_this.version,const DeepCollectionEquality().hash(_this.books),const DeepCollectionEquality().hash(_this.folders),const DeepCollectionEquality().hash(_this.shelf),const DeepCollectionEquality().hash(_this.recent));
}

@override
String toString() {
  final _this = this as LibrarySnapshot;
  return 'LibrarySnapshot(schemaVersion: ${_this.schemaVersion}, version: ${_this.version}, books: ${_this.books}, folders: ${_this.folders}, shelf: ${_this.shelf}, recent: ${_this.recent})';
}


}

/// @nodoc
abstract mixin class $LibrarySnapshotCopyWith<$Res>  {
  factory $LibrarySnapshotCopyWith(LibrarySnapshot value, $Res Function(LibrarySnapshot) _then) = _$LibrarySnapshotCopyWithImpl;
@useResult
$Res call({
@JsonKey(required: true, fromJson: snapshotSchemaVersion) int schemaVersion,@JsonKey(required: true, fromJson: nonnegativeInteger) int version,@JsonKey(required: true) List<SnapshotBook> books,@JsonKey(required: true) List<SnapshotFolder> folders,@JsonKey(required: true) List<ShelfRef> shelf,@JsonKey(required: true) List<RecentEntry> recent
});




}
/// @nodoc
class _$LibrarySnapshotCopyWithImpl<$Res>
    implements $LibrarySnapshotCopyWith<$Res> {
  _$LibrarySnapshotCopyWithImpl(this._self, this._then);

  final LibrarySnapshot _self;
  final $Res Function(LibrarySnapshot) _then;

/// Create a copy of LibrarySnapshot
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? version = null,Object? books = null,Object? folders = null,Object? shelf = null,Object? recent = null,}) {
  return _then(LibrarySnapshot(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,books: null == books ? _self.books : books // ignore: cast_nullable_to_non_nullable
as List<SnapshotBook>,folders: null == folders ? _self.folders : folders // ignore: cast_nullable_to_non_nullable
as List<SnapshotFolder>,shelf: null == shelf ? _self.shelf : shelf // ignore: cast_nullable_to_non_nullable
as List<ShelfRef>,recent: null == recent ? _self.recent : recent // ignore: cast_nullable_to_non_nullable
as List<RecentEntry>,
  ));
}

}


/// Adds pattern-matching-related methods to [LibrarySnapshot].
extension LibrarySnapshotPatterns on LibrarySnapshot {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LibrarySnapshot value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LibrarySnapshot() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LibrarySnapshot value)  $default,){
final _that = this;
switch (_that) {
case _LibrarySnapshot():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LibrarySnapshot value)?  $default,){
final _that = this;
switch (_that) {
case _LibrarySnapshot() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(required: true, fromJson: snapshotSchemaVersion)  int schemaVersion, @JsonKey(required: true, fromJson: nonnegativeInteger)  int version, @JsonKey(required: true)  List<SnapshotBook> books, @JsonKey(required: true)  List<SnapshotFolder> folders, @JsonKey(required: true)  List<ShelfRef> shelf, @JsonKey(required: true)  List<RecentEntry> recent)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LibrarySnapshot() when $default != null:
return $default(_that.schemaVersion,_that.version,_that.books,_that.folders,_that.shelf,_that.recent);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(required: true, fromJson: snapshotSchemaVersion)  int schemaVersion, @JsonKey(required: true, fromJson: nonnegativeInteger)  int version, @JsonKey(required: true)  List<SnapshotBook> books, @JsonKey(required: true)  List<SnapshotFolder> folders, @JsonKey(required: true)  List<ShelfRef> shelf, @JsonKey(required: true)  List<RecentEntry> recent)  $default,) {final _that = this;
switch (_that) {
case _LibrarySnapshot():
return $default(_that.schemaVersion,_that.version,_that.books,_that.folders,_that.shelf,_that.recent);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(required: true, fromJson: snapshotSchemaVersion)  int schemaVersion, @JsonKey(required: true, fromJson: nonnegativeInteger)  int version, @JsonKey(required: true)  List<SnapshotBook> books, @JsonKey(required: true)  List<SnapshotFolder> folders, @JsonKey(required: true)  List<ShelfRef> shelf, @JsonKey(required: true)  List<RecentEntry> recent)?  $default,) {final _that = this;
switch (_that) {
case _LibrarySnapshot() when $default != null:
return $default(_that.schemaVersion,_that.version,_that.books,_that.folders,_that.shelf,_that.recent);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LibrarySnapshot implements LibrarySnapshot {
  const _LibrarySnapshot({@JsonKey(required: true, fromJson: snapshotSchemaVersion) required this.schemaVersion, @JsonKey(required: true, fromJson: nonnegativeInteger) required this.version, @JsonKey(required: true) required  List<SnapshotBook> books, @JsonKey(required: true) required  List<SnapshotFolder> folders, @JsonKey(required: true) required  List<ShelfRef> shelf, @JsonKey(required: true) required  List<RecentEntry> recent}): _books = books,_folders = folders,_shelf = shelf,_recent = recent;
  factory _LibrarySnapshot.fromJson(Map<String, dynamic> json) => _$LibrarySnapshotFromJson(json);

@override@JsonKey(required: true, fromJson: snapshotSchemaVersion) final  int schemaVersion;
@override@JsonKey(required: true, fromJson: nonnegativeInteger) final  int version;
 final  List<SnapshotBook> _books;
@override@JsonKey(required: true) List<SnapshotBook> get books {
  if (_books is EqualUnmodifiableListView) return _books;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_books);
}

 final  List<SnapshotFolder> _folders;
@override@JsonKey(required: true) List<SnapshotFolder> get folders {
  if (_folders is EqualUnmodifiableListView) return _folders;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_folders);
}

 final  List<ShelfRef> _shelf;
@override@JsonKey(required: true) List<ShelfRef> get shelf {
  if (_shelf is EqualUnmodifiableListView) return _shelf;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_shelf);
}

 final  List<RecentEntry> _recent;
@override@JsonKey(required: true) List<RecentEntry> get recent {
  if (_recent is EqualUnmodifiableListView) return _recent;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recent);
}


/// Create a copy of LibrarySnapshot
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LibrarySnapshotCopyWith<_LibrarySnapshot> get copyWith => __$LibrarySnapshotCopyWithImpl<_LibrarySnapshot>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LibrarySnapshotToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _LibrarySnapshot&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.version, version) || other.version == version)&&const DeepCollectionEquality().equals(other.books, _books)&&const DeepCollectionEquality().equals(other.folders, _folders)&&const DeepCollectionEquality().equals(other.shelf, _shelf)&&const DeepCollectionEquality().equals(other.recent, _recent));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,schemaVersion,version,const DeepCollectionEquality().hash(_books),const DeepCollectionEquality().hash(_folders),const DeepCollectionEquality().hash(_shelf),const DeepCollectionEquality().hash(_recent));
}

@override
String toString() {
    return 'LibrarySnapshot(schemaVersion: $schemaVersion, version: $version, books: $books, folders: $folders, shelf: $shelf, recent: $recent)';
}


}

/// @nodoc
abstract mixin class _$LibrarySnapshotCopyWith<$Res> implements $LibrarySnapshotCopyWith<$Res> {
  factory _$LibrarySnapshotCopyWith(_LibrarySnapshot value, $Res Function(_LibrarySnapshot) _then) = __$LibrarySnapshotCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(required: true, fromJson: snapshotSchemaVersion) int schemaVersion,@JsonKey(required: true, fromJson: nonnegativeInteger) int version,@JsonKey(required: true) List<SnapshotBook> books,@JsonKey(required: true) List<SnapshotFolder> folders,@JsonKey(required: true) List<ShelfRef> shelf,@JsonKey(required: true) List<RecentEntry> recent
});




}
/// @nodoc
class __$LibrarySnapshotCopyWithImpl<$Res>
    implements _$LibrarySnapshotCopyWith<$Res> {
  __$LibrarySnapshotCopyWithImpl(this._self, this._then);

  final _LibrarySnapshot _self;
  final $Res Function(_LibrarySnapshot) _then;

/// Create a copy of LibrarySnapshot
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? version = null,Object? books = null,Object? folders = null,Object? shelf = null,Object? recent = null,}) {
  return _then(_LibrarySnapshot(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,version: null == version ? _self.version : version // ignore: cast_nullable_to_non_nullable
as int,books: null == books ? _self._books : books // ignore: cast_nullable_to_non_nullable
as List<SnapshotBook>,folders: null == folders ? _self._folders : folders // ignore: cast_nullable_to_non_nullable
as List<SnapshotFolder>,shelf: null == shelf ? _self._shelf : shelf // ignore: cast_nullable_to_non_nullable
as List<ShelfRef>,recent: null == recent ? _self._recent : recent // ignore: cast_nullable_to_non_nullable
as List<RecentEntry>,
  ));
}


}

// dart format on
