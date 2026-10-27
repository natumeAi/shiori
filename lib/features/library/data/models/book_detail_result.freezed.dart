// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'book_detail_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$BookDetailResult {

 BookKey get key;
/// Create a copy of BookDetailResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookDetailResultCopyWith<BookDetailResult> get copyWith => _$BookDetailResultCopyWithImpl<BookDetailResult>(this as BookDetailResult, _$identity);



@override
bool operator ==(Object other) {
  final _this = this as BookDetailResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BookDetailResult&&(identical(other.key, _this.key) || other.key == _this.key));
}


@override
int get hashCode {
  final _this = this as BookDetailResult;
  return Object.hash(runtimeType,_this.key);
}

@override
String toString() {
  final _this = this as BookDetailResult;
  return 'BookDetailResult(key: ${_this.key})';
}


}

/// @nodoc
abstract mixin class $BookDetailResultCopyWith<$Res>  {
  factory $BookDetailResultCopyWith(BookDetailResult value, $Res Function(BookDetailResult) _then) = _$BookDetailResultCopyWithImpl;
@useResult
$Res call({
 BookKey key
});




}
/// @nodoc
class _$BookDetailResultCopyWithImpl<$Res>
    implements $BookDetailResultCopyWith<$Res> {
  _$BookDetailResultCopyWithImpl(this._self, this._then);

  final BookDetailResult _self;
  final $Res Function(BookDetailResult) _then;

/// Create a copy of BookDetailResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? key = null,}) {
  return _then(_self.copyWith(
key: null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as BookKey,
  ));
}

}


/// Adds pattern-matching-related methods to [BookDetailResult].
extension BookDetailResultPatterns on BookDetailResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( BookAvailable value)?  available,TResult Function( BookUnavailable value)?  unavailable,required TResult orElse(),}){
final _that = this;
switch (_that) {
case BookAvailable() when available != null:
return available(_that);case BookUnavailable() when unavailable != null:
return unavailable(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( BookAvailable value)  available,required TResult Function( BookUnavailable value)  unavailable,}){
final _that = this;
switch (_that) {
case BookAvailable():
return available(_that);case BookUnavailable():
return unavailable(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( BookAvailable value)?  available,TResult? Function( BookUnavailable value)?  unavailable,}){
final _that = this;
switch (_that) {
case BookAvailable() when available != null:
return available(_that);case BookUnavailable() when unavailable != null:
return unavailable(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( BookKey key,  Book book)?  available,TResult Function( BookKey key)?  unavailable,required TResult orElse(),}) {final _that = this;
switch (_that) {
case BookAvailable() when available != null:
return available(_that.key,_that.book);case BookUnavailable() when unavailable != null:
return unavailable(_that.key);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( BookKey key,  Book book)  available,required TResult Function( BookKey key)  unavailable,}) {final _that = this;
switch (_that) {
case BookAvailable():
return available(_that.key,_that.book);case BookUnavailable():
return unavailable(_that.key);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( BookKey key,  Book book)?  available,TResult? Function( BookKey key)?  unavailable,}) {final _that = this;
switch (_that) {
case BookAvailable() when available != null:
return available(_that.key,_that.book);case BookUnavailable() when unavailable != null:
return unavailable(_that.key);case _:
  return null;

}
}

}

/// @nodoc


class BookAvailable implements BookDetailResult {
  const BookAvailable(this.key, this.book);
  

@override final  BookKey key;
 final  Book book;

/// Create a copy of BookDetailResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookAvailableCopyWith<BookAvailable> get copyWith => _$BookAvailableCopyWithImpl<BookAvailable>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookAvailable&&(identical(other.key, key) || other.key == key)&&(identical(other.book, book) || other.book == book));
}


@override
int get hashCode {
    return Object.hash(runtimeType,key,book);
}

@override
String toString() {
    return 'BookDetailResult.available(key: $key, book: $book)';
}


}

/// @nodoc
abstract mixin class $BookAvailableCopyWith<$Res> implements $BookDetailResultCopyWith<$Res> {
  factory $BookAvailableCopyWith(BookAvailable value, $Res Function(BookAvailable) _then) = _$BookAvailableCopyWithImpl;
@override @useResult
$Res call({
 BookKey key, Book book
});


$BookCopyWith<$Res> get book;

}
/// @nodoc
class _$BookAvailableCopyWithImpl<$Res>
    implements $BookAvailableCopyWith<$Res> {
  _$BookAvailableCopyWithImpl(this._self, this._then);

  final BookAvailable _self;
  final $Res Function(BookAvailable) _then;

/// Create a copy of BookDetailResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,Object? book = null,}) {
  return _then(BookAvailable(
null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as BookKey,null == book ? _self.book : book // ignore: cast_nullable_to_non_nullable
as Book,
  ));
}

/// Create a copy of BookDetailResult
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$BookCopyWith<$Res> get book {
  
  return $BookCopyWith<$Res>(_self.book, (value) {
    return _then(_self.copyWith(book: value));
  });
}
}

/// @nodoc


class BookUnavailable implements BookDetailResult {
  const BookUnavailable(this.key);
  

@override final  BookKey key;

/// Create a copy of BookDetailResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BookUnavailableCopyWith<BookUnavailable> get copyWith => _$BookUnavailableCopyWithImpl<BookUnavailable>(this, _$identity);



@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is BookUnavailable&&(identical(other.key, key) || other.key == key));
}


@override
int get hashCode {
    return Object.hash(runtimeType,key);
}

@override
String toString() {
    return 'BookDetailResult.unavailable(key: $key)';
}


}

/// @nodoc
abstract mixin class $BookUnavailableCopyWith<$Res> implements $BookDetailResultCopyWith<$Res> {
  factory $BookUnavailableCopyWith(BookUnavailable value, $Res Function(BookUnavailable) _then) = _$BookUnavailableCopyWithImpl;
@override @useResult
$Res call({
 BookKey key
});




}
/// @nodoc
class _$BookUnavailableCopyWithImpl<$Res>
    implements $BookUnavailableCopyWith<$Res> {
  _$BookUnavailableCopyWithImpl(this._self, this._then);

  final BookUnavailable _self;
  final $Res Function(BookUnavailable) _then;

/// Create a copy of BookDetailResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? key = null,}) {
  return _then(BookUnavailable(
null == key ? _self.key : key // ignore: cast_nullable_to_non_nullable
as BookKey,
  ));
}


}

// dart format on
