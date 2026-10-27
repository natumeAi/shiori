// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Book {

@JsonKey(required: true, fromJson: positiveId) int get id;@JsonKey(required: true, fromJson: nullableId) int? get folderId;@JsonKey(required: true) String get title;@JsonKey(required: true) String? get author;@JsonKey(required: true) String? get description;@JsonKey(required: true) String? get publisher;@JsonKey(required: true) String? get language;@JsonKey(required: true) String? get identifier;@JsonKey(required: true) String get fileName;@JsonKey(required: true, fromJson: nonnegativeInteger) int get fileSize;@JsonKey(required: true) String? get coverPath;@JsonKey(required: true) String? get coverUrl;@JsonKey(required: true) String? get coverThumbnailSmallPath;@JsonKey(required: true) String? get coverThumbnailLargePath;@JsonKey(required: true) String? get coverThumbnailUrl;@JsonKey(required: true) String? get coverThumbnail2xUrl;@JsonKey(required: true) String? get coverThumbnailVersion;@JsonKey(required: true, fromJson: safeInteger) int get sortOrder;@JsonKey(required: true) ServerTimestamp get createdAt;@JsonKey(required: true) ServerTimestamp get updatedAt;
/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookCopyWith<Book> get copyWith => _$BookCopyWithImpl<Book>(this as Book, _$identity);

  /// Serializes this Book to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as Book;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Book&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.folderId, _this.folderId) || other.folderId == _this.folderId)&&(identical(other.title, _this.title) || other.title == _this.title)&&(identical(other.author, _this.author) || other.author == _this.author)&&(identical(other.description, _this.description) || other.description == _this.description)&&(identical(other.publisher, _this.publisher) || other.publisher == _this.publisher)&&(identical(other.language, _this.language) || other.language == _this.language)&&(identical(other.identifier, _this.identifier) || other.identifier == _this.identifier)&&(identical(other.fileName, _this.fileName) || other.fileName == _this.fileName)&&(identical(other.fileSize, _this.fileSize) || other.fileSize == _this.fileSize)&&(identical(other.coverPath, _this.coverPath) || other.coverPath == _this.coverPath)&&(identical(other.coverUrl, _this.coverUrl) || other.coverUrl == _this.coverUrl)&&(identical(other.coverThumbnailSmallPath, _this.coverThumbnailSmallPath) || other.coverThumbnailSmallPath == _this.coverThumbnailSmallPath)&&(identical(other.coverThumbnailLargePath, _this.coverThumbnailLargePath) || other.coverThumbnailLargePath == _this.coverThumbnailLargePath)&&(identical(other.coverThumbnailUrl, _this.coverThumbnailUrl) || other.coverThumbnailUrl == _this.coverThumbnailUrl)&&(identical(other.coverThumbnail2xUrl, _this.coverThumbnail2xUrl) || other.coverThumbnail2xUrl == _this.coverThumbnail2xUrl)&&(identical(other.coverThumbnailVersion, _this.coverThumbnailVersion) || other.coverThumbnailVersion == _this.coverThumbnailVersion)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder)&&(identical(other.createdAt, _this.createdAt) || other.createdAt == _this.createdAt)&&(identical(other.updatedAt, _this.updatedAt) || other.updatedAt == _this.updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as Book;
  return Object.hashAll([runtimeType,_this.id,_this.folderId,_this.title,_this.author,_this.description,_this.publisher,_this.language,_this.identifier,_this.fileName,_this.fileSize,_this.coverPath,_this.coverUrl,_this.coverThumbnailSmallPath,_this.coverThumbnailLargePath,_this.coverThumbnailUrl,_this.coverThumbnail2xUrl,_this.coverThumbnailVersion,_this.sortOrder,_this.createdAt,_this.updatedAt]);
}

@override
String toString() {
  final _this = this as Book;
  return 'Book(id: ${_this.id}, folderId: ${_this.folderId}, title: ${_this.title}, author: ${_this.author}, description: ${_this.description}, publisher: ${_this.publisher}, language: ${_this.language}, identifier: ${_this.identifier}, fileName: ${_this.fileName}, fileSize: ${_this.fileSize}, coverPath: ${_this.coverPath}, coverUrl: ${_this.coverUrl}, coverThumbnailSmallPath: ${_this.coverThumbnailSmallPath}, coverThumbnailLargePath: ${_this.coverThumbnailLargePath}, coverThumbnailUrl: ${_this.coverThumbnailUrl}, coverThumbnail2xUrl: ${_this.coverThumbnail2xUrl}, coverThumbnailVersion: ${_this.coverThumbnailVersion}, sortOrder: ${_this.sortOrder}, createdAt: ${_this.createdAt}, updatedAt: ${_this.updatedAt})';
}


}

/// @nodoc
abstract mixin class $BookCopyWith<$Res>  {
  factory $BookCopyWith(Book value, $Res Function(Book) _then) = _$BookCopyWithImpl;
@useResult
$Res call({
@JsonKey(required: true, fromJson: positiveId) int id,@JsonKey(required: true, fromJson: nullableId) int? folderId,@JsonKey(required: true) String title,@JsonKey(required: true) String? author,@JsonKey(required: true) String? description,@JsonKey(required: true) String? publisher,@JsonKey(required: true) String? language,@JsonKey(required: true) String? identifier,@JsonKey(required: true) String fileName,@JsonKey(required: true, fromJson: nonnegativeInteger) int fileSize,@JsonKey(required: true) String? coverPath,@JsonKey(required: true) String? coverUrl,@JsonKey(required: true) String? coverThumbnailSmallPath,@JsonKey(required: true) String? coverThumbnailLargePath,@JsonKey(required: true) String? coverThumbnailUrl,@JsonKey(required: true) String? coverThumbnail2xUrl,@JsonKey(required: true) String? coverThumbnailVersion,@JsonKey(required: true, fromJson: safeInteger) int sortOrder,@JsonKey(required: true) ServerTimestamp createdAt,@JsonKey(required: true) ServerTimestamp updatedAt
});




}
/// @nodoc
class _$BookCopyWithImpl<$Res>
    implements $BookCopyWith<$Res> {
  _$BookCopyWithImpl(this._self, this._then);

  final Book _self;
  final $Res Function(Book) _then;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? folderId = freezed,Object? title = null,Object? author = freezed,Object? description = freezed,Object? publisher = freezed,Object? language = freezed,Object? identifier = freezed,Object? fileName = null,Object? fileSize = null,Object? coverPath = freezed,Object? coverUrl = freezed,Object? coverThumbnailSmallPath = freezed,Object? coverThumbnailLargePath = freezed,Object? coverThumbnailUrl = freezed,Object? coverThumbnail2xUrl = freezed,Object? coverThumbnailVersion = freezed,Object? sortOrder = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(Book(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,folderId: freezed == folderId ? _self.folderId : folderId // ignore: cast_nullable_to_non_nullable
as int?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,publisher: freezed == publisher ? _self.publisher : publisher // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,identifier: freezed == identifier ? _self.identifier : identifier // ignore: cast_nullable_to_non_nullable
as String?,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,coverPath: freezed == coverPath ? _self.coverPath : coverPath // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailSmallPath: freezed == coverThumbnailSmallPath ? _self.coverThumbnailSmallPath : coverThumbnailSmallPath // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailLargePath: freezed == coverThumbnailLargePath ? _self.coverThumbnailLargePath : coverThumbnailLargePath // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailUrl: freezed == coverThumbnailUrl ? _self.coverThumbnailUrl : coverThumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnail2xUrl: freezed == coverThumbnail2xUrl ? _self.coverThumbnail2xUrl : coverThumbnail2xUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailVersion: freezed == coverThumbnailVersion ? _self.coverThumbnailVersion : coverThumbnailVersion // ignore: cast_nullable_to_non_nullable
as String?,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,
  ));
}

}


/// Adds pattern-matching-related methods to [Book].
extension BookPatterns on Book {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Book value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Book() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Book value)  $default,){
final _that = this;
switch (_that) {
case _Book():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Book value)?  $default,){
final _that = this;
switch (_that) {
case _Book() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true, fromJson: nullableId)  int? folderId, @JsonKey(required: true)  String title, @JsonKey(required: true)  String? author, @JsonKey(required: true)  String? description, @JsonKey(required: true)  String? publisher, @JsonKey(required: true)  String? language, @JsonKey(required: true)  String? identifier, @JsonKey(required: true)  String fileName, @JsonKey(required: true, fromJson: nonnegativeInteger)  int fileSize, @JsonKey(required: true)  String? coverPath, @JsonKey(required: true)  String? coverUrl, @JsonKey(required: true)  String? coverThumbnailSmallPath, @JsonKey(required: true)  String? coverThumbnailLargePath, @JsonKey(required: true)  String? coverThumbnailUrl, @JsonKey(required: true)  String? coverThumbnail2xUrl, @JsonKey(required: true)  String? coverThumbnailVersion, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder, @JsonKey(required: true)  ServerTimestamp createdAt, @JsonKey(required: true)  ServerTimestamp updatedAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Book() when $default != null:
return $default(_that.id,_that.folderId,_that.title,_that.author,_that.description,_that.publisher,_that.language,_that.identifier,_that.fileName,_that.fileSize,_that.coverPath,_that.coverUrl,_that.coverThumbnailSmallPath,_that.coverThumbnailLargePath,_that.coverThumbnailUrl,_that.coverThumbnail2xUrl,_that.coverThumbnailVersion,_that.sortOrder,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true, fromJson: nullableId)  int? folderId, @JsonKey(required: true)  String title, @JsonKey(required: true)  String? author, @JsonKey(required: true)  String? description, @JsonKey(required: true)  String? publisher, @JsonKey(required: true)  String? language, @JsonKey(required: true)  String? identifier, @JsonKey(required: true)  String fileName, @JsonKey(required: true, fromJson: nonnegativeInteger)  int fileSize, @JsonKey(required: true)  String? coverPath, @JsonKey(required: true)  String? coverUrl, @JsonKey(required: true)  String? coverThumbnailSmallPath, @JsonKey(required: true)  String? coverThumbnailLargePath, @JsonKey(required: true)  String? coverThumbnailUrl, @JsonKey(required: true)  String? coverThumbnail2xUrl, @JsonKey(required: true)  String? coverThumbnailVersion, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder, @JsonKey(required: true)  ServerTimestamp createdAt, @JsonKey(required: true)  ServerTimestamp updatedAt)  $default,) {final _that = this;
switch (_that) {
case _Book():
return $default(_that.id,_that.folderId,_that.title,_that.author,_that.description,_that.publisher,_that.language,_that.identifier,_that.fileName,_that.fileSize,_that.coverPath,_that.coverUrl,_that.coverThumbnailSmallPath,_that.coverThumbnailLargePath,_that.coverThumbnailUrl,_that.coverThumbnail2xUrl,_that.coverThumbnailVersion,_that.sortOrder,_that.createdAt,_that.updatedAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true, fromJson: nullableId)  int? folderId, @JsonKey(required: true)  String title, @JsonKey(required: true)  String? author, @JsonKey(required: true)  String? description, @JsonKey(required: true)  String? publisher, @JsonKey(required: true)  String? language, @JsonKey(required: true)  String? identifier, @JsonKey(required: true)  String fileName, @JsonKey(required: true, fromJson: nonnegativeInteger)  int fileSize, @JsonKey(required: true)  String? coverPath, @JsonKey(required: true)  String? coverUrl, @JsonKey(required: true)  String? coverThumbnailSmallPath, @JsonKey(required: true)  String? coverThumbnailLargePath, @JsonKey(required: true)  String? coverThumbnailUrl, @JsonKey(required: true)  String? coverThumbnail2xUrl, @JsonKey(required: true)  String? coverThumbnailVersion, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder, @JsonKey(required: true)  ServerTimestamp createdAt, @JsonKey(required: true)  ServerTimestamp updatedAt)?  $default,) {final _that = this;
switch (_that) {
case _Book() when $default != null:
return $default(_that.id,_that.folderId,_that.title,_that.author,_that.description,_that.publisher,_that.language,_that.identifier,_that.fileName,_that.fileSize,_that.coverPath,_that.coverUrl,_that.coverThumbnailSmallPath,_that.coverThumbnailLargePath,_that.coverThumbnailUrl,_that.coverThumbnail2xUrl,_that.coverThumbnailVersion,_that.sortOrder,_that.createdAt,_that.updatedAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()
@ServerTimestampConverter()
class _Book implements Book {
  const _Book({@JsonKey(required: true, fromJson: positiveId) required this.id, @JsonKey(required: true, fromJson: nullableId) required this.folderId, @JsonKey(required: true) required this.title, @JsonKey(required: true) required this.author, @JsonKey(required: true) required this.description, @JsonKey(required: true) required this.publisher, @JsonKey(required: true) required this.language, @JsonKey(required: true) required this.identifier, @JsonKey(required: true) required this.fileName, @JsonKey(required: true, fromJson: nonnegativeInteger) required this.fileSize, @JsonKey(required: true) required this.coverPath, @JsonKey(required: true) required this.coverUrl, @JsonKey(required: true) required this.coverThumbnailSmallPath, @JsonKey(required: true) required this.coverThumbnailLargePath, @JsonKey(required: true) required this.coverThumbnailUrl, @JsonKey(required: true) required this.coverThumbnail2xUrl, @JsonKey(required: true) required this.coverThumbnailVersion, @JsonKey(required: true, fromJson: safeInteger) required this.sortOrder, @JsonKey(required: true) required this.createdAt, @JsonKey(required: true) required this.updatedAt});
  factory _Book.fromJson(Map<String, dynamic> json) => _$BookFromJson(json);

@override@JsonKey(required: true, fromJson: positiveId) final  int id;
@override@JsonKey(required: true, fromJson: nullableId) final  int? folderId;
@override@JsonKey(required: true) final  String title;
@override@JsonKey(required: true) final  String? author;
@override@JsonKey(required: true) final  String? description;
@override@JsonKey(required: true) final  String? publisher;
@override@JsonKey(required: true) final  String? language;
@override@JsonKey(required: true) final  String? identifier;
@override@JsonKey(required: true) final  String fileName;
@override@JsonKey(required: true, fromJson: nonnegativeInteger) final  int fileSize;
@override@JsonKey(required: true) final  String? coverPath;
@override@JsonKey(required: true) final  String? coverUrl;
@override@JsonKey(required: true) final  String? coverThumbnailSmallPath;
@override@JsonKey(required: true) final  String? coverThumbnailLargePath;
@override@JsonKey(required: true) final  String? coverThumbnailUrl;
@override@JsonKey(required: true) final  String? coverThumbnail2xUrl;
@override@JsonKey(required: true) final  String? coverThumbnailVersion;
@override@JsonKey(required: true, fromJson: safeInteger) final  int sortOrder;
@override@JsonKey(required: true) final  ServerTimestamp createdAt;
@override@JsonKey(required: true) final  ServerTimestamp updatedAt;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookCopyWith<_Book> get copyWith => __$BookCopyWithImpl<_Book>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _Book&&(identical(other.id, id) || other.id == id)&&(identical(other.folderId, folderId) || other.folderId == folderId)&&(identical(other.title, title) || other.title == title)&&(identical(other.author, author) || other.author == author)&&(identical(other.description, description) || other.description == description)&&(identical(other.publisher, publisher) || other.publisher == publisher)&&(identical(other.language, language) || other.language == language)&&(identical(other.identifier, identifier) || other.identifier == identifier)&&(identical(other.fileName, fileName) || other.fileName == fileName)&&(identical(other.fileSize, fileSize) || other.fileSize == fileSize)&&(identical(other.coverPath, coverPath) || other.coverPath == coverPath)&&(identical(other.coverUrl, coverUrl) || other.coverUrl == coverUrl)&&(identical(other.coverThumbnailSmallPath, coverThumbnailSmallPath) || other.coverThumbnailSmallPath == coverThumbnailSmallPath)&&(identical(other.coverThumbnailLargePath, coverThumbnailLargePath) || other.coverThumbnailLargePath == coverThumbnailLargePath)&&(identical(other.coverThumbnailUrl, coverThumbnailUrl) || other.coverThumbnailUrl == coverThumbnailUrl)&&(identical(other.coverThumbnail2xUrl, coverThumbnail2xUrl) || other.coverThumbnail2xUrl == coverThumbnail2xUrl)&&(identical(other.coverThumbnailVersion, coverThumbnailVersion) || other.coverThumbnailVersion == coverThumbnailVersion)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&(identical(other.updatedAt, updatedAt) || other.updatedAt == updatedAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,id,folderId,title,author,description,publisher,language,identifier,fileName,fileSize,coverPath,coverUrl,coverThumbnailSmallPath,coverThumbnailLargePath,coverThumbnailUrl,coverThumbnail2xUrl,coverThumbnailVersion,sortOrder,createdAt,updatedAt]);
}

@override
String toString() {
    return 'Book(id: $id, folderId: $folderId, title: $title, author: $author, description: $description, publisher: $publisher, language: $language, identifier: $identifier, fileName: $fileName, fileSize: $fileSize, coverPath: $coverPath, coverUrl: $coverUrl, coverThumbnailSmallPath: $coverThumbnailSmallPath, coverThumbnailLargePath: $coverThumbnailLargePath, coverThumbnailUrl: $coverThumbnailUrl, coverThumbnail2xUrl: $coverThumbnail2xUrl, coverThumbnailVersion: $coverThumbnailVersion, sortOrder: $sortOrder, createdAt: $createdAt, updatedAt: $updatedAt)';
}


}

/// @nodoc
abstract mixin class _$BookCopyWith<$Res> implements $BookCopyWith<$Res> {
  factory _$BookCopyWith(_Book value, $Res Function(_Book) _then) = __$BookCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(required: true, fromJson: positiveId) int id,@JsonKey(required: true, fromJson: nullableId) int? folderId,@JsonKey(required: true) String title,@JsonKey(required: true) String? author,@JsonKey(required: true) String? description,@JsonKey(required: true) String? publisher,@JsonKey(required: true) String? language,@JsonKey(required: true) String? identifier,@JsonKey(required: true) String fileName,@JsonKey(required: true, fromJson: nonnegativeInteger) int fileSize,@JsonKey(required: true) String? coverPath,@JsonKey(required: true) String? coverUrl,@JsonKey(required: true) String? coverThumbnailSmallPath,@JsonKey(required: true) String? coverThumbnailLargePath,@JsonKey(required: true) String? coverThumbnailUrl,@JsonKey(required: true) String? coverThumbnail2xUrl,@JsonKey(required: true) String? coverThumbnailVersion,@JsonKey(required: true, fromJson: safeInteger) int sortOrder,@JsonKey(required: true) ServerTimestamp createdAt,@JsonKey(required: true) ServerTimestamp updatedAt
});




}
/// @nodoc
class __$BookCopyWithImpl<$Res>
    implements _$BookCopyWith<$Res> {
  __$BookCopyWithImpl(this._self, this._then);

  final _Book _self;
  final $Res Function(_Book) _then;

/// Create a copy of Book
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? folderId = freezed,Object? title = null,Object? author = freezed,Object? description = freezed,Object? publisher = freezed,Object? language = freezed,Object? identifier = freezed,Object? fileName = null,Object? fileSize = null,Object? coverPath = freezed,Object? coverUrl = freezed,Object? coverThumbnailSmallPath = freezed,Object? coverThumbnailLargePath = freezed,Object? coverThumbnailUrl = freezed,Object? coverThumbnail2xUrl = freezed,Object? coverThumbnailVersion = freezed,Object? sortOrder = null,Object? createdAt = null,Object? updatedAt = null,}) {
  return _then(_Book(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,folderId: freezed == folderId ? _self.folderId : folderId // ignore: cast_nullable_to_non_nullable
as int?,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,author: freezed == author ? _self.author : author // ignore: cast_nullable_to_non_nullable
as String?,description: freezed == description ? _self.description : description // ignore: cast_nullable_to_non_nullable
as String?,publisher: freezed == publisher ? _self.publisher : publisher // ignore: cast_nullable_to_non_nullable
as String?,language: freezed == language ? _self.language : language // ignore: cast_nullable_to_non_nullable
as String?,identifier: freezed == identifier ? _self.identifier : identifier // ignore: cast_nullable_to_non_nullable
as String?,fileName: null == fileName ? _self.fileName : fileName // ignore: cast_nullable_to_non_nullable
as String,fileSize: null == fileSize ? _self.fileSize : fileSize // ignore: cast_nullable_to_non_nullable
as int,coverPath: freezed == coverPath ? _self.coverPath : coverPath // ignore: cast_nullable_to_non_nullable
as String?,coverUrl: freezed == coverUrl ? _self.coverUrl : coverUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailSmallPath: freezed == coverThumbnailSmallPath ? _self.coverThumbnailSmallPath : coverThumbnailSmallPath // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailLargePath: freezed == coverThumbnailLargePath ? _self.coverThumbnailLargePath : coverThumbnailLargePath // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailUrl: freezed == coverThumbnailUrl ? _self.coverThumbnailUrl : coverThumbnailUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnail2xUrl: freezed == coverThumbnail2xUrl ? _self.coverThumbnail2xUrl : coverThumbnail2xUrl // ignore: cast_nullable_to_non_nullable
as String?,coverThumbnailVersion: freezed == coverThumbnailVersion ? _self.coverThumbnailVersion : coverThumbnailVersion // ignore: cast_nullable_to_non_nullable
as String?,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,updatedAt: null == updatedAt ? _self.updatedAt : updatedAt // ignore: cast_nullable_to_non_nullable
as ServerTimestamp,
  ));
}


}

// dart format on
