// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'snapshot_book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SnapshotBook {

@JsonKey(required: true, fromJson: positiveId) int get id;@JsonKey(required: true, fromJson: nullableId) int? get folderId;@JsonKey(required: true) String get title;@JsonKey(required: true) String? get author;@JsonKey(required: true) String? get identifier;@JsonKey(required: true) String get fileName;@JsonKey(required: true, fromJson: nonnegativeInteger) int get fileSize;@JsonKey(required: true) String? get coverPath;@JsonKey(required: true) String? get coverUrl;@JsonKey(required: true) String? get coverThumbnailUrl;@JsonKey(required: true) String? get coverThumbnail2xUrl;@JsonKey(required: true) String? get coverThumbnailVersion;@JsonKey(required: true, fromJson: safeInteger) int get sortOrder;@JsonKey(required: true) ServerTimestamp get createdAt;@JsonKey(required: true) ServerTimestamp get updatedAt;@JsonKey(required: true, fromJson: nullableProgress) double? get readingProgress;@JsonKey(required: true) ServerTimestamp? get readingUpdatedAt;
/// Create a copy of SnapshotBook
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SnapshotBookCopyWith<SnapshotBook> get copyWith => _$SnapshotBookCopyWithImpl<SnapshotBook>(this as SnapshotBook, _$identity);

  /// Serializes this SnapshotBook to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as SnapshotBook;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SnapshotBook&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.folderId, _this.folderId) || other.folderId == _this.folderId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.identifier, _this.identifier) || other.identifier == _this.identifier)&&(identical(other.fileName, _this.fileName) || other.fileName == _this.fileName)&&(identical(other.fileSize, _this.fileSize) || other.fileSize == _this.fileSize)&&(identical(other.coverPath, _this.coverPath) || other.coverPath == _this.coverPath)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.coverThumbnailUrl, _this.coverThumbnailUrl) || other.coverThumbnailUrl == _this.coverThumbnailUrl)&&(identical(other.coverThumbnail2xUrl, _this.coverThumbnail2xUrl) || other.coverThumbnail2xUrl == _this.coverThumbnail2xUrl)&&(identical(other.coverThumbnailVersion, _this.coverThumbnailVersion) || other.coverThumbnailVersion == _this.coverThumbnailVersion)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt)&&(identical(other.readingProgress, _this.readingProgress) || other.readingProgress == _this.readingProgress)&&(identical(other.readingUpdatedAt, _this.readingUpdatedAt) || other.readingUpdatedAt == _this.readingUpdatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as SnapshotBook;
  return Object.hash(runtimeType,_this.id,_this.folderId,_this.title,_this.author,_this.identifier,_this.fileName,_this.fileSize,_this.coverPath,_this.coverUrl,_this.coverThumbnailUrl,_this.coverThumbnail2xUrl,_this.coverThumbnailVersion,_this.sortOrder,_this.createdAt,_this.updatedAt,_this.readingProgress,_this.readingUpdatedAt);
}

@override
String toString() {
  final _this = this as SnapshotBook;
  return 'SnapshotBook(id: ${_this.id}, folderId: ${_this.folderId}, title: ${_this.title}, author: ${_this.author}, identifier: ${_this.identifier}, fileName: ${_this.fileName}, fileSize: ${_this.fileSize}, coverPath: ${_this.coverPath}, coverUrl: ${_this.coverUrl}, coverThumbnailUrl: ${_this.coverThumbnailUrl}, coverThumbnail2xUrl: ${_this.coverThumbnail2xUrl}, coverThumbnailVersion: ${_this.coverThumbnailVersion}, sortOrder: ${_this.sortOrder}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt}, readingProgress: ${_this.readingProgress}, readingUpdatedAt: ${_this.readingUpdatedAt})';
}


}

/// @nodoc
abstract mixin class $SnapshotBookCopyWith<$Res>  {
  factory $SnapshotBookCopyWith(SnapshotBook value, $Res Function(SnapshotBook) _then) = _$SnapshotBookCopyWithImpl;
@useResult
$Res call({
@JsonKey(required: true, fromJson: positiveId) int id,@JsonKey(required: true, fromJson: nullableId) int? folderId,@JsonKey(required: true) String title,@JsonKey(required: true) String? author,@JsonKey(required: true) String? identifier,@JsonKey(required: true) String fileName,@JsonKey(required: true, fromJson: nonnegativeInteger) int fileSize,@JsonKey(required: true) String? coverPath,@JsonKey(required: true) String? coverUrl,@JsonKey(required: true) String? coverThumbnailUrl,@JsonKey(required: true) String? coverThumbnail2xUrl,@JsonKey(required: true) String? coverThumbnailVersion,@JsonKey(required: true, fromJson: safeInteger) int sortOrder,@JsonKey(required: true) ServerTimestamp createdAt,@JsonKey(required: true) ServerTimestamp updatedAt,@JsonKey(required: true, fromJson: nullableProgress) double? readingProgress,@JsonKey(required: true) ServerTimestamp? readingUpdatedAt
});




}
/// @nodoc
class _$SnapshotBookCopyWithImpl<$Res>
    implements $SnapshotBookCopyWith<$Res> {
  _$SnapshotBookCopyWithImpl(this._self, this._then);

  final SnapshotBook _self;
  final $Res Function(SnapshotBook) _then;

/// Create a copy of SnapshotBook
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? folderId = freezed,Object? title = null,Object? author = freezed,Object? identifier = freezed,Object? fileName = null,Object? fileSize = null,Object? coverPath = freezed,Object? coverUrl = freezed,Object? coverThumbnailUrl = freezed,Object? coverThumbnail2xUrl = freezed,Object? coverThumbnailVersion = freezed,Object? sortOrder = null,Object? createdAt = null,Object? updatedAt = null,Object? readingProgress = freezed,Object? readingUpdatedAt = freezed,}) {
  return _then(SnapshotBook(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,folderId: freezed == folderId ? _self.folderId : folderId // ignore: cast_nullable_to_non_nullable
as int?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,identifier: freezed == identifier ? _self.identifier : identifier // ignore: cast_nullable_to_non_nullable
as String?,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,coverPath: freezed == coverPath ? _self.coverPath : coverPath // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailUrl: freezed == coverThumbnailUrl ? _self.coverThumbnailUrl : coverThumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnail2xUrl: freezed == coverThumbnail2xUrl ? _self.coverThumbnail2xUrl : coverThumbnail2xUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailVersion: freezed == coverThumbnailVersion ? _self.coverThumbnailVersion : coverThumbnailVersion // ignore: cast_nullable_to_non_nullable
as String?,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,readingProgress: freezed == readingProgress ? _self.readingProgress : readingProgress // ignore: cast_nullable_to_non_nullable
as double?,readingUpdatedAt: freezed == readingUpdatedAt ? _self.readingUpdatedAt : readingUpdatedAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp?,
  ));
}

}


/// Adds pattern-matching-related methods to [SnapshotBook].
extension SnapshotBookPatterns on SnapshotBook {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SnapshotBook value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SnapshotBook() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SnapshotBook value)  $default,){
final _that = this;
switch (_that) {
case _SnapshotBook():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SnapshotBook value)?  $default,){
final _that = this;
switch (_that) {
case _SnapshotBook() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true, fromJson: nullableId)  int? folderId, @JsonKey(required: true)  String title, @JsonKey(required: true)  String? author, @JsonKey(required: true)  String? identifier, @JsonKey(required: true)  String fileName, @JsonKey(required: true, fromJson: nonnegativeInteger)  int fileSize, @JsonKey(required: true)  String? coverPath, @JsonKey(required: true)  String? coverUrl, @JsonKey(required: true)  String? coverThumbnailUrl, @JsonKey(required: true)  String? coverThumbnail2xUrl, @JsonKey(required: true)  String? coverThumbnailVersion, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder, @JsonKey(required: true)  ServerTimestamp createdAt, @JsonKey(required: true)  ServerTimestamp updatedAt, @JsonKey(required: true, fromJson: nullableProgress)  double? readingProgress, @JsonKey(required: true)  ServerTimestamp? readingUpdatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SnapshotBook() when $default != null:
return $default(_that.id,_that.folderId,_that.title,_that.author,_that.identifier,_that.fileName,_that.fileSize,_that.coverPath,_that.coverUrl,_that.coverThumbnailUrl,_that.coverThumbnail2xUrl,_that.coverThumbnailVersion,_that.sortOrder,_that.createdAt,_that.updatedAt,_that.readingProgress,_that.readingUpdatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true, fromJson: nullableId)  int? folderId, @JsonKey(required: true)  String title, @JsonKey(required: true)  String? author, @JsonKey(required: true)  String? identifier, @JsonKey(required: true)  String fileName, @JsonKey(required: true, fromJson: nonnegativeInteger)  int fileSize, @JsonKey(required: true)  String? coverPath, @JsonKey(required: true)  String? coverUrl, @JsonKey(required: true)  String? coverThumbnailUrl, @JsonKey(required: true)  String? coverThumbnail2xUrl, @JsonKey(required: true)  String? coverThumbnailVersion, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder, @JsonKey(required: true)  ServerTimestamp createdAt, @JsonKey(required: true)  ServerTimestamp updatedAt, @JsonKey(required: true, fromJson: nullableProgress)  double? readingProgress, @JsonKey(required: true)  ServerTimestamp? readingUpdatedAt)  $default,) {final _that = this;
switch (_that) {
case _SnapshotBook():
return $default(_that.id,_that.folderId,_that.title,_that.author,_that.identifier,_that.fileName,_that.fileSize,_that.coverPath,_that.coverUrl,_that.coverThumbnailUrl,_that.coverThumbnail2xUrl,_that.coverThumbnailVersion,_that.sortOrder,_that.createdAt,_that.updatedAt,_that.readingProgress,_that.readingUpdatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true, fromJson: nullableId)  int? folderId, @JsonKey(required: true)  String title, @JsonKey(required: true)  String? author, @JsonKey(required: true)  String? identifier, @JsonKey(required: true)  String fileName, @JsonKey(required: true, fromJson: nonnegativeInteger)  int fileSize, @JsonKey(required: true)  String? coverPath, @JsonKey(required: true)  String? coverUrl, @JsonKey(required: true)  String? coverThumbnailUrl, @JsonKey(required: true)  String? coverThumbnail2xUrl, @JsonKey(required: true)  String? coverThumbnailVersion, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder, @JsonKey(required: true)  ServerTimestamp createdAt, @JsonKey(required: true)  ServerTimestamp updatedAt, @JsonKey(required: true, fromJson: nullableProgress)  double? readingProgress, @JsonKey(required: true)  ServerTimestamp? readingUpdatedAt)?  $default,) {final _that = this;
switch (_that) {
case _SnapshotBook() when $default != null:
return $default(_that.id,_that.folderId,_that.title,_that.author,_that.identifier,_that.fileName,_that.fileSize,_that.coverPath,_that.coverUrl,_that.coverThumbnailUrl,_that.coverThumbnail2xUrl,_that.coverThumbnailVersion,_that.sortOrder,_that.createdAt,_that.updatedAt,_that.readingProgress,_that.readingUpdatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@ServerTimestampConverter()
class _SnapshotBook implements SnapshotBook {
  const _SnapshotBook({@JsonKey(required: true, fromJson: positiveId) required this.id, @JsonKey(required: true, fromJson: nullableId) required this.folderId, @JsonKey(required: true) required this.title, @JsonKey(required: true) required this.author, @JsonKey(required: true) required this.identifier, @JsonKey(required: true) required this.fileName, @JsonKey(required: true, fromJson: nonnegativeInteger) required this.fileSize, @JsonKey(required: true) required this.coverPath, @JsonKey(required: true) required this.coverUrl, @JsonKey(required: true) required this.coverThumbnailUrl, @JsonKey(required: true) required this.coverThumbnail2xUrl, @JsonKey(required: true) required this.coverThumbnailVersion, @JsonKey(required: true, fromJson: safeInteger) required this.sortOrder, @JsonKey(required: true) required this.createdAt, @JsonKey(required: true) required this.updatedAt, @JsonKey(required: true, fromJson: nullableProgress) required this.readingProgress, @JsonKey(required: true) required this.readingUpdatedAt});
  factory _SnapshotBook.fromJson(Map<String, dynamic> json) => _$SnapshotBookFromJson(json);

@override@JsonKey(required: true, fromJson: positiveId) final  int id;
@override@JsonKey(required: true, fromJson: nullableId) final  int? folderId;
@override@JsonKey(required: true) final  String title;
@override@JsonKey(required: true) final  String? author;
@override@JsonKey(required: true) final  String? identifier;
@override@JsonKey(required: true) final  String fileName;
@override@JsonKey(required: true, fromJson: nonnegativeInteger) final  int fileSize;
@override@JsonKey(required: true) final  String? coverPath;
@override@JsonKey(required: true) final  String? coverUrl;
@override@JsonKey(required: true) final  String? coverThumbnailUrl;
@override@JsonKey(required: true) final  String? coverThumbnail2xUrl;
@override@JsonKey(required: true) final  String? coverThumbnailVersion;
@override@JsonKey(required: true, fromJson: safeInteger) final  int sortOrder;
@override@JsonKey(required: true) final  ServerTimestamp createdAt;
@override@JsonKey(required: true) final  ServerTimestamp updatedAt;
@override@JsonKey(required: true, fromJson: nullableProgress) final  double? readingProgress;
@override@JsonKey(required: true) final  ServerTimestamp? readingUpdatedAt;

/// Create a copy of SnapshotBook
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SnapshotBookCopyWith<_SnapshotBook> get copyWith => __$SnapshotBookCopyWithImpl<_SnapshotBook>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SnapshotBookToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _SnapshotBook&&(identical(other.id, id) || other.id == id)&&(identical(other.folderId, folderId) || other.folderId == folderId)&&(identical(other.title, title) || other.title == title)&&(identical(other.author, author) || other.author == author)&&(identical(other.identifier, identifier) || other.identifier == identifier)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.coverPath, coverPath) || other.coverPath == coverPath)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.coverThumbnailUrl, coverThumbnailUrl) || other.coverThumbnailUrl == coverThumbnailUrl)&&(identical(other.coverThumbnail2xUrl, coverThumbnail2xUrl) || other.coverThumbnail2xUrl == coverThumbnail2xUrl)&&(identical(other.coverThumbnailVersion, coverThumbnailVersion) || other.coverThumbnailVersion == coverThumbnailVersion)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt)&&(identical(other.readingProgress, readingProgress) || other.readingProgress == readingProgress)&&(identical(other.readingUpdatedAt, readingUpdatedAt) || other.readingUpdatedAt == readingUpdatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,folderId,title,author,identifier,fileName,fileSize,coverPath,coverUrl,coverThumbnailUrl,coverThumbnail2xUrl,coverThumbnailVersion,sortOrder,createdAt,updatedAt,readingProgress,readingUpdatedAt);
}

@override
String toString() {
    return 'SnapshotBook(id: $id, folderId: $folderId, title: $title, author: $author, identifier: $identifier, fileName: $fileName, fileSize: $fileSize, coverPath: $coverPath, coverUrl: $coverUrl, coverThumbnailUrl: $coverThumbnailUrl, coverThumbnail2xUrl: $coverThumbnail2xUrl, coverThumbnailVersion: $coverThumbnailVersion, sortOrder: $sortOrder, createdAt: $createdAt, updatedAt: $updatedAt, readingProgress: $readingProgress, readingUpdatedAt: $readingUpdatedAt)';
}


}

/// @nodoc
abstract mixin class _$SnapshotBookCopyWith<$Res> implements $SnapshotBookCopyWith<$Res> {
  factory _$SnapshotBookCopyWith(_SnapshotBook value, $Res Function(_SnapshotBook) _then) = __$SnapshotBookCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(required: true, fromJson: positiveId) int id,@JsonKey(required: true, fromJson: nullableId) int? folderId,@JsonKey(required: true) String title,@JsonKey(required: true) String? author,@JsonKey(required: true) String? identifier,@JsonKey(required: true) String fileName,@JsonKey(required: true, fromJson: nonnegativeInteger) int fileSize,@JsonKey(required: true) String? coverPath,@JsonKey(required: true) String? coverUrl,@JsonKey(required: true) String? coverThumbnailUrl,@JsonKey(required: true) String? coverThumbnail2xUrl,@JsonKey(required: true) String? coverThumbnailVersion,@JsonKey(required: true, fromJson: safeInteger) int sortOrder,@JsonKey(required: true) ServerTimestamp createdAt,@JsonKey(required: true) ServerTimestamp updatedAt,@JsonKey(required: true, fromJson: nullableProgress) double? readingProgress,@JsonKey(required: true) ServerTimestamp? readingUpdatedAt
});




}
/// @nodoc
class __$SnapshotBookCopyWithImpl<$Res>
    implements _$SnapshotBookCopyWith<$Res> {
  __$SnapshotBookCopyWithImpl(this._self, this._then);

  final _SnapshotBook _self;
  final $Res Function(_SnapshotBook) _then;

/// Create a copy of SnapshotBook
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? folderId = freezed,Object? title = null,Object? author = freezed,Object? identifier = freezed,Object? fileName = null,Object? fileSize = null,Object? coverPath = freezed,Object? coverUrl = freezed,Object? coverThumbnailUrl = freezed,Object? coverThumbnail2xUrl = freezed,Object? coverThumbnailVersion = freezed,Object? sortOrder = null,Object? createdAt = null,Object? updatedAt = null,Object? readingProgress = freezed,Object? readingUpdatedAt = freezed,}) {
  return _then(_SnapshotBook(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,folderId: freezed == folderId ? _self.folderId : folderId // ignore: cast_nullable_to_non_nullable
as int?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,identifier: freezed == identifier ? _self.identifier : identifier // ignore: cast_nullable_to_non_nullable
as String?,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,coverPath: freezed == coverPath ? _self.coverPath : coverPath // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailUrl: freezed == coverThumbnailUrl ? _self.coverThumbnailUrl : coverThumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnail2xUrl: freezed == coverThumbnail2xUrl ? _self.coverThumbnail2xUrl : coverThumbnail2xUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailVersion: freezed == coverThumbnailVersion ? _self.coverThumbnailVersion : coverThumbnailVersion // ignore: cast_nullable_to_non_nullable
as String?,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,readingProgress: freezed == readingProgress ? _self.readingProgress : readingProgress // ignore: cast_nullable_to_non_nullable
as double?,readingUpdatedAt: freezed == readingUpdatedAt ? _self.readingUpdatedAt : readingUpdatedAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp?,
  ));
}


}

// dart format on
