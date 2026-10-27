// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_response.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BookResponse {

@JsonKey(required: true) Book get book;
/// Create a copy of BookResponse
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookResponseCopyWith<BookResponse> get copyWith => _$BookResponseCopyWithImpl<BookResponse>(this as BookResponse, _$identity);

  /// Serializes this BookResponse to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as BookResponse;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookResponse&&(identical(other.book, _this.book) || other.book == _this.book));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as BookResponse;
  return Object.hash(runtimeType,_this.book);
}

@override
String toString() {
  final _this = this as BookResponse;
  return 'BookResponse(book: ${_this.book})';
}


}

/// @nodoc
abstract mixin class $BookResponseCopyWith<$Res>  {
  factory $BookResponseCopyWith(BookResponse value, $Res Function(BookResponse) _then) = _$BookResponseCopyWithImpl;
@useResult
$Res call({
@JsonKey(required: true) Book book
});


$BookCopyWith<$Res> get book;

}
/// @nodoc
class _$BookResponseCopyWithImpl<$Res>
    implements $BookResponseCopyWith<$Res> {
  _$BookResponseCopyWithImpl(this._self, this._then);

  final BookResponse _self;
  final $Res Function(BookResponse) _then;

/// Create a copy of BookResponse
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? book = null,}) {
  return _then(BookResponse(
book: null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as Book,
  ));
}
/// Create a copy of BookResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookCopyWith<$Res> get book {
  
  return $BookCopyWith<$Res>(_self.book, (value) {
    return _then(_self.copyWith(book: value));
  });
}
}


/// Adds pattern-matching-related methods to [BookResponse].
extension BookResponsePatterns on BookResponse {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BookResponse value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BookResponse() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BookResponse value)  $default,){
final _that = this;
switch (_that) {
case _BookResponse():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BookResponse value)?  $default,){
final _that = this;
switch (_that) {
case _BookResponse() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function(@JsonKey(required: true)  Book book)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BookResponse() when $default != null:
return $default(_that.book);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function(@JsonKey(required: true)  Book book)  $default,) {final _that = this;
switch (_that) {
case _BookResponse():
return $default(_that.book);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function(@JsonKey(required: true)  Book book)?  $default,) {final _that = this;
switch (_that) {
case _BookResponse() when $default != null:
return $default(_that.book);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BookResponse implements BookResponse {
  const _BookResponse({@JsonKey(required: true) required this.book});
  factory _BookResponse.fromJson(Map<String, dynamic> json) => _$BookResponseFromJson(json);

@override@JsonKey(required: true) final  Book book;

/// Create a copy of BookResponse
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BookResponseCopyWith<_BookResponse> get copyWith => __$BookResponseCopyWithImpl<_BookResponse>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BookResponseToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _BookResponse&&(identical(other.book, book) || other.book == book));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,book);
}

@override
String toString() {
    return 'BookResponse(book: $book)';
}


}

/// @nodoc
abstract mixin class _$BookResponseCopyWith<$Res> implements $BookResponseCopyWith<$Res> {
  factory _$BookResponseCopyWith(_BookResponse value, $Res Function(_BookResponse) _then) = __$BookResponseCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(required: true) Book book
});


@override $BookCopyWith<$Res> get book;

}
/// @nodoc
class __$BookResponseCopyWithImpl<$Res>
    implements _$BookResponseCopyWith<$Res> {
  __$BookResponseCopyWithImpl(this._self, this._then);

  final _BookResponse _self;
  final $Res Function(_BookResponse) _then;

/// Create a copy of BookResponse
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? book = null,}) {
  return _then(_BookResponse(
book: null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as Book,
  ));
}

/// Create a copy of BookResponse
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookCopyWith<$Res> get book {
  
  return $BookCopyWith<$Res>(_self.book, (value) {
    return _then(_self.copyWith(book: value));
  });
}
}

// dart format on
