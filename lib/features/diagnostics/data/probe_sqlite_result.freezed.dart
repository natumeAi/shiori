// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'probe_sqlite_result.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ProbeSqliteResult {

 int get schemaVersion; DateTime get checkedAt; String get buildId; String get buildNumber; String get packageVersion; String get packageVersionSource; bool get ranOffRootIsolate; Map<String, bool?> get steps; int get elapsedUs; String? get libraryVersion; String? get sourceId; List<String> get compileOptions; String? get journalMode; int? get synchronous; String? get failure;
/// Create a copy of ProbeSqliteResult
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ProbeSqliteResultCopyWith<ProbeSqliteResult> get copyWith => _$ProbeSqliteResultCopyWithImpl<ProbeSqliteResult>(this as ProbeSqliteResult, _$identity);

  /// Serializes this ProbeSqliteResult to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ProbeSqliteResult;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ProbeSqliteResult&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion)&&(identical(other.checkedAt, _this.checkedAt) || other.checkedAt == _this.checkedAt)&&(identical(other.buildId, _this.buildId) || other.buildId == _this.buildId)&&(identical(other.buildNumber, _this.buildNumber) || other.buildNumber == _this.buildNumber)&&(identical(other.packageVersion, _this.packageVersion) || other.packageVersion == _this.packageVersion)&&(identical(other.packageVersionSource, _this.packageVersionSource) || other.packageVersionSource == _this.packageVersionSource)&&(identical(other.ranOffRootIsolate, _this.ranOffRootIsolate) || other.ranOffRootIsolate == _this.ranOffRootIsolate)&&const DeepCollectionEquality().equals(other.steps, _this.steps)&&(identical(other.elapsedUs, _this.elapsedUs) || other.elapsedUs == _this.elapsedUs)&&(identical(other.libraryVersion, _this.libraryVersion) || other.libraryVersion == _this.libraryVersion)&&(identical(other.sourceId, _this.sourceId) || other.sourceId == _this.sourceId)&&const DeepCollectionEquality().equals(other.compileOptions, _this.compileOptions)&&(identical(other.journalMode, _this.journalMode) || other.journalMode == _this.journalMode)&&(identical(other.synchronous, _this.synchronous) || other.synchronous == _this.synchronous)&&(identical(other.failure, _this.failure) || other.failure == _this.failure));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ProbeSqliteResult;
  return Object.hash(runtimeType,_this.schemaVersion,_this.checkedAt,_this.buildId,_this.buildNumber,_this.packageVersion,_this.packageVersionSource,_this.ranOffRootIsolate,const DeepCollectionEquality().hash(_this.steps),_this.elapsedUs,_this.libraryVersion,_this.sourceId,const DeepCollectionEquality().hash(_this.compileOptions),_this.journalMode,_this.synchronous,_this.failure);
}

@override
String toString() {
  final _this = this as ProbeSqliteResult;
  return 'ProbeSqliteResult(schemaVersion: ${_this.schemaVersion}, checkedAt: ${_this.checkedAt}, buildId: ${_this.buildId}, buildNumber: ${_this.buildNumber}, packageVersion: ${_this.packageVersion}, packageVersionSource: ${_this.packageVersionSource}, ranOffRootIsolate: ${_this.ranOffRootIsolate}, steps: ${_this.steps}, elapsedUs: ${_this.elapsedUs}, libraryVersion: ${_this.libraryVersion}, sourceId: ${_this.sourceId}, compileOptions: ${_this.compileOptions}, journalMode: ${_this.journalMode}, synchronous: ${_this.synchronous}, failure: ${_this.failure})';
}


}

/// @nodoc
abstract mixin class $ProbeSqliteResultCopyWith<$Res>  {
  factory $ProbeSqliteResultCopyWith(ProbeSqliteResult value, $Res Function(ProbeSqliteResult) _then) = _$ProbeSqliteResultCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, DateTime checkedAt, String buildId, String buildNumber, String packageVersion, String packageVersionSource, bool ranOffRootIsolate, Map<String, bool?> steps, int elapsedUs, String? libraryVersion, String? sourceId, List<String> compileOptions, String? journalMode, int? synchronous, String? failure
});




}
/// @nodoc
class _$ProbeSqliteResultCopyWithImpl<$Res>
    implements $ProbeSqliteResultCopyWith<$Res> {
  _$ProbeSqliteResultCopyWithImpl(this._self, this._then);

  final ProbeSqliteResult _self;
  final $Res Function(ProbeSqliteResult) _then;

/// Create a copy of ProbeSqliteResult
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? checkedAt = null,Object? buildId = null,Object? buildNumber = null,Object? packageVersion = null,Object? packageVersionSource = null,Object? ranOffRootIsolate = null,Object? steps = null,Object? elapsedUs = null,Object? libraryVersion = freezed,Object? sourceId = freezed,Object? compileOptions = null,Object? journalMode = freezed,Object? synchronous = freezed,Object? failure = freezed,}) {
  return _then(ProbeSqliteResult(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,checkedAt: null == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime,buildId: null == buildId ? _self.buildId : buildId // ignore: cast_nullable_to_non_nullable
as String,buildNumber: null == buildNumber ? _self.buildNumber : buildNumber // ignore: cast_nullable_to_non_nullable
as String,packageVersion: null == packageVersion ? _self.packageVersion : packageVersion // ignore: cast_nullable_to_non_nullable
as String,packageVersionSource: null == packageVersionSource ? _self.packageVersionSource : packageVersionSource // ignore: cast_nullable_to_non_nullable
as String,ranOffRootIsolate: null == ranOffRootIsolate ? _self.ranOffRootIsolate : ranOffRootIsolate // ignore: cast_nullable_to_non_nullable
as bool,steps: null == steps ? _self.steps : steps // ignore: cast_nullable_to_non_nullable
as Map<String, bool?>,elapsedUs: null == elapsedUs ? _self.elapsedUs : elapsedUs // ignore: cast_nullable_to_non_nullable
as int,libraryVersion: freezed == libraryVersion ? _self.libraryVersion : libraryVersion // ignore: cast_nullable_to_non_nullable
as String?,sourceId: freezed == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String?,compileOptions: null == compileOptions ? _self.compileOptions : compileOptions // ignore: cast_nullable_to_non_nullable
as List<String>,journalMode: freezed == journalMode ? _self.journalMode : journalMode // ignore: cast_nullable_to_non_nullable
as String?,synchronous: freezed == synchronous ? _self.synchronous : synchronous // ignore: cast_nullable_to_non_nullable
as int?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ProbeSqliteResult].
extension ProbeSqliteResultPatterns on ProbeSqliteResult {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ProbeSqliteResult value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ProbeSqliteResult() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ProbeSqliteResult value)  $default,){
final _that = this;
switch (_that) {
case _ProbeSqliteResult():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ProbeSqliteResult value)?  $default,){
final _that = this;
switch (_that) {
case _ProbeSqliteResult() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  DateTime checkedAt,  String buildId,  String buildNumber,  String packageVersion,  String packageVersionSource,  bool ranOffRootIsolate,  Map<String, bool?> steps,  int elapsedUs,  String? libraryVersion,  String? sourceId,  List<String> compileOptions,  String? journalMode,  int? synchronous,  String? failure)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ProbeSqliteResult() when $default != null:
return $default(_that.schemaVersion,_that.checkedAt,_that.buildId,_that.buildNumber,_that.packageVersion,_that.packageVersionSource,_that.ranOffRootIsolate,_that.steps,_that.elapsedUs,_that.libraryVersion,_that.sourceId,_that.compileOptions,_that.journalMode,_that.synchronous,_that.failure);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  DateTime checkedAt,  String buildId,  String buildNumber,  String packageVersion,  String packageVersionSource,  bool ranOffRootIsolate,  Map<String, bool?> steps,  int elapsedUs,  String? libraryVersion,  String? sourceId,  List<String> compileOptions,  String? journalMode,  int? synchronous,  String? failure)  $default,) {final _that = this;
switch (_that) {
case _ProbeSqliteResult():
return $default(_that.schemaVersion,_that.checkedAt,_that.buildId,_that.buildNumber,_that.packageVersion,_that.packageVersionSource,_that.ranOffRootIsolate,_that.steps,_that.elapsedUs,_that.libraryVersion,_that.sourceId,_that.compileOptions,_that.journalMode,_that.synchronous,_that.failure);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  DateTime checkedAt,  String buildId,  String buildNumber,  String packageVersion,  String packageVersionSource,  bool ranOffRootIsolate,  Map<String, bool?> steps,  int elapsedUs,  String? libraryVersion,  String? sourceId,  List<String> compileOptions,  String? journalMode,  int? synchronous,  String? failure)?  $default,) {final _that = this;
switch (_that) {
case _ProbeSqliteResult() when $default != null:
return $default(_that.schemaVersion,_that.checkedAt,_that.buildId,_that.buildNumber,_that.packageVersion,_that.packageVersionSource,_that.ranOffRootIsolate,_that.steps,_that.elapsedUs,_that.libraryVersion,_that.sourceId,_that.compileOptions,_that.journalMode,_that.synchronous,_that.failure);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ProbeSqliteResult extends ProbeSqliteResult {
  const _ProbeSqliteResult({this.schemaVersion = 1, required this.checkedAt, required this.buildId, required this.buildNumber, required this.packageVersion, this.packageVersionSource = 'resolved_pubspec_lock_snapshot', required this.ranOffRootIsolate, required  Map<String, bool?> steps, required this.elapsedUs, this.libraryVersion, this.sourceId,  List<String> compileOptions = const [], this.journalMode, this.synchronous, this.failure}): _steps = steps,_compileOptions = compileOptions,super._();
  factory _ProbeSqliteResult.fromJson(Map<String, dynamic> json) => _$ProbeSqliteResultFromJson(json);

@override@JsonKey() final  int schemaVersion;
@override final  DateTime checkedAt;
@override final  String buildId;
@override final  String buildNumber;
@override final  String packageVersion;
@override@JsonKey() final  String packageVersionSource;
@override final  bool ranOffRootIsolate;
 final  Map<String, bool?> _steps;
@override Map<String, bool?> get steps {
  if (_steps is EqualUnmodifiableMapView) return _steps;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_steps);
}

@override final  int elapsedUs;
@override final  String? libraryVersion;
@override final  String? sourceId;
 final  List<String> _compileOptions;
@override@JsonKey() List<String> get compileOptions {
  if (_compileOptions is EqualUnmodifiableListView) return _compileOptions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_compileOptions);
}

@override final  String? journalMode;
@override final  int? synchronous;
@override final  String? failure;

/// Create a copy of ProbeSqliteResult
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ProbeSqliteResultCopyWith<_ProbeSqliteResult> get copyWith => __$ProbeSqliteResultCopyWithImpl<_ProbeSqliteResult>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ProbeSqliteResultToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ProbeSqliteResult&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.checkedAt, checkedAt) || other.checkedAt == checkedAt)&&(identical(other.buildId, buildId) || other.buildId == buildId)&&(identical(other.buildNumber, buildNumber) || other.buildNumber == buildNumber)&&(identical(other.packageVersion, packageVersion) || other.packageVersion == packageVersion)&&(identical(other.packageVersionSource, packageVersionSource) || other.packageVersionSource == packageVersionSource)&&(identical(other.ranOffRootIsolate, ranOffRootIsolate) || other.ranOffRootIsolate == ranOffRootIsolate)&&const DeepCollectionEquality().equals(other.steps, _steps)&&(identical(other.elapsedUs, elapsedUs) || other.elapsedUs == elapsedUs)&&(identical(other.libraryVersion, libraryVersion) || other.libraryVersion == libraryVersion)&&(identical(other.sourceId, sourceId) || other.sourceId == sourceId)&&const DeepCollectionEquality().equals(other.compileOptions, _compileOptions)&&(identical(other.journalMode, journalMode) || other.journalMode == journalMode)&&(identical(other.synchronous, synchronous) || other.synchronous == synchronous)&&(identical(other.failure, failure) || other.failure == failure));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,schemaVersion,checkedAt,buildId,buildNumber,packageVersion,packageVersionSource,ranOffRootIsolate,const DeepCollectionEquality().hash(_steps),elapsedUs,libraryVersion,sourceId,const DeepCollectionEquality().hash(_compileOptions),journalMode,synchronous,failure);
}

@override
String toString() {
    return 'ProbeSqliteResult(schemaVersion: $schemaVersion, checkedAt: $checkedAt, buildId: $buildId, buildNumber: $buildNumber, packageVersion: $packageVersion, packageVersionSource: $packageVersionSource, ranOffRootIsolate: $ranOffRootIsolate, steps: $steps, elapsedUs: $elapsedUs, libraryVersion: $libraryVersion, sourceId: $sourceId, compileOptions: $compileOptions, journalMode: $journalMode, synchronous: $synchronous, failure: $failure)';
}


}

/// @nodoc
abstract mixin class _$ProbeSqliteResultCopyWith<$Res> implements $ProbeSqliteResultCopyWith<$Res> {
  factory _$ProbeSqliteResultCopyWith(_ProbeSqliteResult value, $Res Function(_ProbeSqliteResult) _then) = __$ProbeSqliteResultCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, DateTime checkedAt, String buildId, String buildNumber, String packageVersion, String packageVersionSource, bool ranOffRootIsolate, Map<String, bool?> steps, int elapsedUs, String? libraryVersion, String? sourceId, List<String> compileOptions, String? journalMode, int? synchronous, String? failure
});




}
/// @nodoc
class __$ProbeSqliteResultCopyWithImpl<$Res>
    implements _$ProbeSqliteResultCopyWith<$Res> {
  __$ProbeSqliteResultCopyWithImpl(this._self, this._then);

  final _ProbeSqliteResult _self;
  final $Res Function(_ProbeSqliteResult) _then;

/// Create a copy of ProbeSqliteResult
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? checkedAt = null,Object? buildId = null,Object? buildNumber = null,Object? packageVersion = null,Object? packageVersionSource = null,Object? ranOffRootIsolate = null,Object? steps = null,Object? elapsedUs = null,Object? libraryVersion = freezed,Object? sourceId = freezed,Object? compileOptions = null,Object? journalMode = freezed,Object? synchronous = freezed,Object? failure = freezed,}) {
  return _then(_ProbeSqliteResult(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,checkedAt: null == checkedAt ? _self.checkedAt : checkedAt // ignore: cast_nullable_to_non_nullable
as DateTime,buildId: null == buildId ? _self.buildId : buildId // ignore: cast_nullable_to_non_nullable
as String,buildNumber: null == buildNumber ? _self.buildNumber : buildNumber // ignore: cast_nullable_to_non_nullable
as String,packageVersion: null == packageVersion ? _self.packageVersion : packageVersion // ignore: cast_nullable_to_non_nullable
as String,packageVersionSource: null == packageVersionSource ? _self.packageVersionSource : packageVersionSource // ignore: cast_nullable_to_non_nullable
as String,ranOffRootIsolate: null == ranOffRootIsolate ? _self.ranOffRootIsolate : ranOffRootIsolate // ignore: cast_nullable_to_non_nullable
as bool,steps: null == steps ? _self._steps : steps // ignore: cast_nullable_to_non_nullable
as Map<String, bool?>,elapsedUs: null == elapsedUs ? _self.elapsedUs : elapsedUs // ignore: cast_nullable_to_non_nullable
as int,libraryVersion: freezed == libraryVersion ? _self.libraryVersion : libraryVersion // ignore: cast_nullable_to_non_nullable
as String?,sourceId: freezed == sourceId ? _self.sourceId : sourceId // ignore: cast_nullable_to_non_nullable
as String?,compileOptions: null == compileOptions ? _self._compileOptions : compileOptions // ignore: cast_nullable_to_non_nullable
as List<String>,journalMode: freezed == journalMode ? _self.journalMode : journalMode // ignore: cast_nullable_to_non_nullable
as String?,synchronous: freezed == synchronous ? _self.synchronous : synchronous // ignore: cast_nullable_to_non_nullable
as int?,failure: freezed == failure ? _self.failure : failure // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
