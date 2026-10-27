// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'shelf_ref.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;
ShelfRef _$ShelfRefFromJson(
  Map<String, dynamic> json
) {
        switch (json['type']) {
                  case 'book':
          return ShelfBookRef.fromJson(
            json
          );
                case 'folder':
          return ShelfFolderRef.fromJson(
            json
          );
        
          default:
            throw CheckedFromJsonException(
  json,
  'type',
  'ShelfRef',
  'Invalid union type "${json['type']}"!'
);
        }
      
}

/// @nodoc
mixin _$ShelfRef {

@JsonKey(required: true, fromJson: positiveId) int get id;@JsonKey(required: true, fromJson: safeInteger) int get sortOrder;
/// Create a copy of ShelfRef
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShelfRefCopyWith<ShelfRef> get copyWith => _$ShelfRefCopyWithImpl<ShelfRef>(this as ShelfRef, _$identity);

  /// Serializes this ShelfRef to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ShelfRef;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ShelfRef&&(identical(other.id, _this.id) || other.id == _this.id)&&(identical(other.sortOrder, _this.sortOrder) || other.sortOrder == _this.sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ShelfRef;
  return Object.hash(runtimeType,_this.id,_this.sortOrder);
}

@override
String toString() {
  final _this = this as ShelfRef;
  return 'ShelfRef(id: ${_this.id}, sortOrder: ${_this.sortOrder})';
}


}

/// @nodoc
abstract mixin class $ShelfRefCopyWith<$Res>  {
  factory $ShelfRefCopyWith(ShelfRef value, $Res Function(ShelfRef) _then) = _$ShelfRefCopyWithImpl;
@useResult
$Res call({
@JsonKey(required: true, fromJson: positiveId) int id,@JsonKey(required: true, fromJson: safeInteger) int sortOrder
});




}
/// @nodoc
class _$ShelfRefCopyWithImpl<$Res>
    implements $ShelfRefCopyWith<$Res> {
  _$ShelfRefCopyWithImpl(this._self, this._then);

  final ShelfRef _self;
  final $Res Function(ShelfRef) _then;

/// Create a copy of ShelfRef
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? sortOrder = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ShelfRef].
extension ShelfRefPatterns on ShelfRef {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ShelfBookRef value)?  book,TResult Function( ShelfFolderRef value)?  folder,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ShelfBookRef() when book != null:
return book(_that);case ShelfFolderRef() when folder != null:
return folder(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ShelfBookRef value)  book,required TResult Function( ShelfFolderRef value)  folder,}){
final _that = this;
switch (_that) {
case ShelfBookRef():
return book(_that);case ShelfFolderRef():
return folder(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ShelfBookRef value)?  book,TResult? Function( ShelfFolderRef value)?  folder,}){
final _that = this;
switch (_that) {
case ShelfBookRef() when book != null:
return book(_that);case ShelfFolderRef() when folder != null:
return folder(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder)?  book,TResult Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder)?  folder,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ShelfBookRef() when book != null:
return book(_that.id,_that.sortOrder);case ShelfFolderRef() when folder != null:
return folder(_that.id,_that.sortOrder);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder)  book,required TResult Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder)  folder,}) {final _that = this;
switch (_that) {
case ShelfBookRef():
return book(_that.id,_that.sortOrder);case ShelfFolderRef():
return folder(_that.id,_that.sortOrder);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder)?  book,TResult? Function(@JsonKey(required: true, fromJson: positiveId)  int id, @JsonKey(required: true, fromJson: safeInteger)  int sortOrder)?  folder,}) {final _that = this;
switch (_that) {
case ShelfBookRef() when book != null:
return book(_that.id,_that.sortOrder);case ShelfFolderRef() when folder != null:
return folder(_that.id,_that.sortOrder);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class ShelfBookRef extends ShelfRef {
  const ShelfBookRef({@JsonKey(required: true, fromJson: positiveId) required this.id, @JsonKey(required: true, fromJson: safeInteger) required this.sortOrder,  String? $type}): $type = $type ?? 'book',super._();
  factory ShelfBookRef.fromJson(Map<String, dynamic> json) => _$ShelfBookRefFromJson(json);

@override@JsonKey(required: true, fromJson: positiveId) final  int id;
@override@JsonKey(required: true, fromJson: safeInteger) final  int sortOrder;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ShelfRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShelfBookRefCopyWith<ShelfBookRef> get copyWith => _$ShelfBookRefCopyWithImpl<ShelfBookRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShelfBookRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ShelfBookRef&&(identical(other.id, id) || other.id == id)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sortOrder);
}

@override
String toString() {
    return 'ShelfRef.book(id: $id, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class $ShelfBookRefCopyWith<$Res> implements $ShelfRefCopyWith<$Res> {
  factory $ShelfBookRefCopyWith(ShelfBookRef value, $Res Function(ShelfBookRef) _then) = _$ShelfBookRefCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(required: true, fromJson: positiveId) int id,@JsonKey(required: true, fromJson: safeInteger) int sortOrder
});




}
/// @nodoc
class _$ShelfBookRefCopyWithImpl<$Res>
    implements $ShelfBookRefCopyWith<$Res> {
  _$ShelfBookRefCopyWithImpl(this._self, this._then);

  final ShelfBookRef _self;
  final $Res Function(ShelfBookRef) _then;

/// Create a copy of ShelfRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sortOrder = null,}) {
  return _then(ShelfBookRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
@JsonSerializable()

class ShelfFolderRef extends ShelfRef {
  const ShelfFolderRef({@JsonKey(required: true, fromJson: positiveId) required this.id, @JsonKey(required: true, fromJson: safeInteger) required this.sortOrder,  String? $type}): $type = $type ?? 'folder',super._();
  factory ShelfFolderRef.fromJson(Map<String, dynamic> json) => _$ShelfFolderRefFromJson(json);

@override@JsonKey(required: true, fromJson: positiveId) final  int id;
@override@JsonKey(required: true, fromJson: safeInteger) final  int sortOrder;

@JsonKey(name: 'type')
final String $type;


/// Create a copy of ShelfRef
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ShelfFolderRefCopyWith<ShelfFolderRef> get copyWith => _$ShelfFolderRefCopyWithImpl<ShelfFolderRef>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ShelfFolderRefToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is ShelfFolderRef&&(identical(other.id, id) || other.id == id)&&(identical(other.sortOrder, sortOrder) || other.sortOrder == sortOrder));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,id,sortOrder);
}

@override
String toString() {
    return 'ShelfRef.folder(id: $id, sortOrder: $sortOrder)';
}


}

/// @nodoc
abstract mixin class $ShelfFolderRefCopyWith<$Res> implements $ShelfRefCopyWith<$Res> {
  factory $ShelfFolderRefCopyWith(ShelfFolderRef value, $Res Function(ShelfFolderRef) _then) = _$ShelfFolderRefCopyWithImpl;
@override @useResult
$Res call({
@JsonKey(required: true, fromJson: positiveId) int id,@JsonKey(required: true, fromJson: safeInteger) int sortOrder
});




}
/// @nodoc
class _$ShelfFolderRefCopyWithImpl<$Res>
    implements $ShelfFolderRefCopyWith<$Res> {
  _$ShelfFolderRefCopyWithImpl(this._self, this._then);

  final ShelfFolderRef _self;
  final $Res Function(ShelfFolderRef) _then;

/// Create a copy of ShelfRef
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? sortOrder = null,}) {
  return _then(ShelfFolderRef(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as int,sortOrder: null == sortOrder ? _self.sortOrder : sortOrder // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
