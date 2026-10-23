// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'reader_feasibility_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$ReaderFeasibilityRecord {

 String get kind; int get schemaVersion; String get bookSha256; String? get fixtureId; String get scenarioId; int get repeatIndex; int get repeatCount; String get input; DiagnosticRecord get engine; List<Map<String, Object?>> get readerEvents; List<Map<String, Object?>> get layoutCosts; List<Map<String, Object?>> get resources; Map<String, Object?> get presentation; Map<String, Object?> get aggregates; Map<String, int> get overflow; Map<String, Object?> get omissions;
/// Create a copy of ReaderFeasibilityRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ReaderFeasibilityRecordCopyWith<ReaderFeasibilityRecord> get copyWith => _$ReaderFeasibilityRecordCopyWithImpl<ReaderFeasibilityRecord>(this as ReaderFeasibilityRecord, _$identity);

  /// Serializes this ReaderFeasibilityRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as ReaderFeasibilityRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ReaderFeasibilityRecord&&(identical(other.kind, _this.kind) || other.kind == _this.kind)&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion)&&(identical(other.bookSha256, _this.bookSha256) || other.bookSha256 == _this.bookSha256)&&(identical(other.fixtureId, _this.fixtureId) || other.fixtureId == _this.fixtureId)&&(identical(other.scenarioId, _this.scenarioId) || other.scenarioId == _this.scenarioId)&&(identical(other.repeatIndex, _this.repeatIndex) || other.repeatIndex == _this.repeatIndex)&&(identical(other.repeatCount, _this.repeatCount) || other.repeatCount == _this.repeatCount)&&(identical(other.input, _this.input) || other.input == _this.input)&&(identical(other.engine, _this.engine) || other.engine == _this.engine)&&const DeepCollectionEquality().equals(other.readerEvents, _this.readerEvents)&&const DeepCollectionEquality().equals(other.layoutCosts, _this.layoutCosts)&&const DeepCollectionEquality().equals(other.resources, _this.resources)&&const DeepCollectionEquality().equals(other.presentation, _this.presentation)&&const DeepCollectionEquality().equals(other.aggregates, _this.aggregates)&&const DeepCollectionEquality().equals(other.overflow, _this.overflow)&&const DeepCollectionEquality().equals(other.omissions, _this.omissions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as ReaderFeasibilityRecord;
  return Object.hash(runtimeType,_this.kind,_this.schemaVersion,_this.bookSha256,_this.fixtureId,_this.scenarioId,_this.repeatIndex,_this.repeatCount,_this.input,_this.engine,const DeepCollectionEquality().hash(_this.readerEvents),const DeepCollectionEquality().hash(_this.layoutCosts),const DeepCollectionEquality().hash(_this.resources),const DeepCollectionEquality().hash(_this.presentation),const DeepCollectionEquality().hash(_this.aggregates),const DeepCollectionEquality().hash(_this.overflow),const DeepCollectionEquality().hash(_this.omissions));
}

@override
String toString() {
  final _this = this as ReaderFeasibilityRecord;
  return 'ReaderFeasibilityRecord(kind: ${_this.kind}, schemaVersion: ${_this.schemaVersion}, bookSha256: ${_this.bookSha256}, fixtureId: ${_this.fixtureId}, scenarioId: ${_this.scenarioId}, repeatIndex: ${_this.repeatIndex}, repeatCount: ${_this.repeatCount}, input: ${_this.input}, engine: ${_this.engine}, readerEvents: ${_this.readerEvents}, layoutCosts: ${_this.layoutCosts}, resources: ${_this.resources}, presentation: ${_this.presentation}, aggregates: ${_this.aggregates}, overflow: ${_this.overflow}, omissions: ${_this.omissions})';
}


}

/// @nodoc
abstract mixin class $ReaderFeasibilityRecordCopyWith<$Res>  {
  factory $ReaderFeasibilityRecordCopyWith(ReaderFeasibilityRecord value, $Res Function(ReaderFeasibilityRecord) _then) = _$ReaderFeasibilityRecordCopyWithImpl;
@useResult
$Res call({
 String kind, int schemaVersion, String bookSha256, String? fixtureId, String scenarioId, int repeatIndex, int repeatCount, String input, DiagnosticRecord engine, List<Map<String, Object?>> readerEvents, List<Map<String, Object?>> layoutCosts, List<Map<String, Object?>> resources, Map<String, Object?> presentation, Map<String, Object?> aggregates, Map<String, int> overflow, Map<String, Object?> omissions
});


$DiagnosticRecordCopyWith<$Res> get engine;

}
/// @nodoc
class _$ReaderFeasibilityRecordCopyWithImpl<$Res>
    implements $ReaderFeasibilityRecordCopyWith<$Res> {
  _$ReaderFeasibilityRecordCopyWithImpl(this._self, this._then);

  final ReaderFeasibilityRecord _self;
  final $Res Function(ReaderFeasibilityRecord) _then;

/// Create a copy of ReaderFeasibilityRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? kind = null,Object? schemaVersion = null,Object? bookSha256 = null,Object? fixtureId = freezed,Object? scenarioId = null,Object? repeatIndex = null,Object? repeatCount = null,Object? input = null,Object? engine = null,Object? readerEvents = null,Object? layoutCosts = null,Object? resources = null,Object? presentation = null,Object? aggregates = null,Object? overflow = null,Object? omissions = null,}) {
  return _then(ReaderFeasibilityRecord(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,bookSha256: null == bookSha256 ? _self.bookSha256 : bookSha256 // ignore: cast_nullable_to_non_nullable
as String,fixtureId: freezed == fixtureId ? _self.fixtureId : fixtureId // ignore: cast_nullable_to_non_nullable
as String?,scenarioId: null == scenarioId ? _self.scenarioId : scenarioId // ignore: cast_nullable_to_non_nullable
as String,repeatIndex: null == repeatIndex ? _self.repeatIndex : repeatIndex // ignore: cast_nullable_to_non_nullable
as int,repeatCount: null == repeatCount ? _self.repeatCount : repeatCount // ignore: cast_nullable_to_non_nullable
as int,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as String,engine: null == engine ? _self.engine : engine // ignore: cast_nullable_to_non_nullable
as DiagnosticRecord,readerEvents: null == readerEvents ? _self.readerEvents : readerEvents // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>,layoutCosts: null == layoutCosts ? _self.layoutCosts : layoutCosts // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>,resources: null == resources ? _self.resources : resources // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>,presentation: null == presentation ? _self.presentation : presentation // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,aggregates: null == aggregates ? _self.aggregates : aggregates // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,overflow: null == overflow ? _self.overflow : overflow // ignore: cast_nullable_to_non_nullable
as Map<String, int>,omissions: null == omissions ? _self.omissions : omissions // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}
/// Create a copy of ReaderFeasibilityRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DiagnosticRecordCopyWith<$Res> get engine {
  
  return $DiagnosticRecordCopyWith<$Res>(_self.engine, (value) {
    return _then(_self.copyWith(engine: value));
  });
}
}


/// Adds pattern-matching-related methods to [ReaderFeasibilityRecord].
extension ReaderFeasibilityRecordPatterns on ReaderFeasibilityRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ReaderFeasibilityRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ReaderFeasibilityRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ReaderFeasibilityRecord value)  $default,){
final _that = this;
switch (_that) {
case _ReaderFeasibilityRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ReaderFeasibilityRecord value)?  $default,){
final _that = this;
switch (_that) {
case _ReaderFeasibilityRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String kind,  int schemaVersion,  String bookSha256,  String? fixtureId,  String scenarioId,  int repeatIndex,  int repeatCount,  String input,  DiagnosticRecord engine,  List<Map<String, Object?>> readerEvents,  List<Map<String, Object?>> layoutCosts,  List<Map<String, Object?>> resources,  Map<String, Object?> presentation,  Map<String, Object?> aggregates,  Map<String, int> overflow,  Map<String, Object?> omissions)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ReaderFeasibilityRecord() when $default != null:
return $default(_that.kind,_that.schemaVersion,_that.bookSha256,_that.fixtureId,_that.scenarioId,_that.repeatIndex,_that.repeatCount,_that.input,_that.engine,_that.readerEvents,_that.layoutCosts,_that.resources,_that.presentation,_that.aggregates,_that.overflow,_that.omissions);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String kind,  int schemaVersion,  String bookSha256,  String? fixtureId,  String scenarioId,  int repeatIndex,  int repeatCount,  String input,  DiagnosticRecord engine,  List<Map<String, Object?>> readerEvents,  List<Map<String, Object?>> layoutCosts,  List<Map<String, Object?>> resources,  Map<String, Object?> presentation,  Map<String, Object?> aggregates,  Map<String, int> overflow,  Map<String, Object?> omissions)  $default,) {final _that = this;
switch (_that) {
case _ReaderFeasibilityRecord():
return $default(_that.kind,_that.schemaVersion,_that.bookSha256,_that.fixtureId,_that.scenarioId,_that.repeatIndex,_that.repeatCount,_that.input,_that.engine,_that.readerEvents,_that.layoutCosts,_that.resources,_that.presentation,_that.aggregates,_that.overflow,_that.omissions);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String kind,  int schemaVersion,  String bookSha256,  String? fixtureId,  String scenarioId,  int repeatIndex,  int repeatCount,  String input,  DiagnosticRecord engine,  List<Map<String, Object?>> readerEvents,  List<Map<String, Object?>> layoutCosts,  List<Map<String, Object?>> resources,  Map<String, Object?> presentation,  Map<String, Object?> aggregates,  Map<String, int> overflow,  Map<String, Object?> omissions)?  $default,) {final _that = this;
switch (_that) {
case _ReaderFeasibilityRecord() when $default != null:
return $default(_that.kind,_that.schemaVersion,_that.bookSha256,_that.fixtureId,_that.scenarioId,_that.repeatIndex,_that.repeatCount,_that.input,_that.engine,_that.readerEvents,_that.layoutCosts,_that.resources,_that.presentation,_that.aggregates,_that.overflow,_that.omissions);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ReaderFeasibilityRecord implements ReaderFeasibilityRecord {
  const _ReaderFeasibilityRecord({this.kind = 'reader_feasibility', this.schemaVersion = 1, required this.bookSha256, required this.fixtureId, required this.scenarioId, required this.repeatIndex, required this.repeatCount, required this.input, required this.engine, required  List<Map<String, Object?>> readerEvents, required  List<Map<String, Object?>> layoutCosts, required  List<Map<String, Object?>> resources, required  Map<String, Object?> presentation, required  Map<String, Object?> aggregates, required  Map<String, int> overflow, required  Map<String, Object?> omissions}): _readerEvents = readerEvents,_layoutCosts = layoutCosts,_resources = resources,_presentation = presentation,_aggregates = aggregates,_overflow = overflow,_omissions = omissions;
  factory _ReaderFeasibilityRecord.fromJson(Map<String, dynamic> json) => _$ReaderFeasibilityRecordFromJson(json);

@override@JsonKey() final  String kind;
@override@JsonKey() final  int schemaVersion;
@override final  String bookSha256;
@override final  String? fixtureId;
@override final  String scenarioId;
@override final  int repeatIndex;
@override final  int repeatCount;
@override final  String input;
@override final  DiagnosticRecord engine;
 final  List<Map<String, Object?>> _readerEvents;
@override List<Map<String, Object?>> get readerEvents {
  if (_readerEvents is EqualUnmodifiableListView) return _readerEvents;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_readerEvents);
}

 final  List<Map<String, Object?>> _layoutCosts;
@override List<Map<String, Object?>> get layoutCosts {
  if (_layoutCosts is EqualUnmodifiableListView) return _layoutCosts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_layoutCosts);
}

 final  List<Map<String, Object?>> _resources;
@override List<Map<String, Object?>> get resources {
  if (_resources is EqualUnmodifiableListView) return _resources;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_resources);
}

 final  Map<String, Object?> _presentation;
@override Map<String, Object?> get presentation {
  if (_presentation is EqualUnmodifiableMapView) return _presentation;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_presentation);
}

 final  Map<String, Object?> _aggregates;
@override Map<String, Object?> get aggregates {
  if (_aggregates is EqualUnmodifiableMapView) return _aggregates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_aggregates);
}

 final  Map<String, int> _overflow;
@override Map<String, int> get overflow {
  if (_overflow is EqualUnmodifiableMapView) return _overflow;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_overflow);
}

 final  Map<String, Object?> _omissions;
@override Map<String, Object?> get omissions {
  if (_omissions is EqualUnmodifiableMapView) return _omissions;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_omissions);
}


/// Create a copy of ReaderFeasibilityRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ReaderFeasibilityRecordCopyWith<_ReaderFeasibilityRecord> get copyWith => __$ReaderFeasibilityRecordCopyWithImpl<_ReaderFeasibilityRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ReaderFeasibilityRecordToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _ReaderFeasibilityRecord&&(identical(other.kind, kind) || other.kind == kind)&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.bookSha256, bookSha256) || other.bookSha256 == bookSha256)&&(identical(other.fixtureId, fixtureId) || other.fixtureId == fixtureId)&&(identical(other.scenarioId, scenarioId) || other.scenarioId == scenarioId)&&(identical(other.repeatIndex, repeatIndex) || other.repeatIndex == repeatIndex)&&(identical(other.repeatCount, repeatCount) || other.repeatCount == repeatCount)&&(identical(other.input, input) || other.input == input)&&(identical(other.engine, engine) || other.engine == engine)&&const DeepCollectionEquality().equals(other.readerEvents, _readerEvents)&&const DeepCollectionEquality().equals(other.layoutCosts, _layoutCosts)&&const DeepCollectionEquality().equals(other.resources, _resources)&&const DeepCollectionEquality().equals(other.presentation, _presentation)&&const DeepCollectionEquality().equals(other.aggregates, _aggregates)&&const DeepCollectionEquality().equals(other.overflow, _overflow)&&const DeepCollectionEquality().equals(other.omissions, _omissions));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hash(runtimeType,kind,schemaVersion,bookSha256,fixtureId,scenarioId,repeatIndex,repeatCount,input,engine,const DeepCollectionEquality().hash(_readerEvents),const DeepCollectionEquality().hash(_layoutCosts),const DeepCollectionEquality().hash(_resources),const DeepCollectionEquality().hash(_presentation),const DeepCollectionEquality().hash(_aggregates),const DeepCollectionEquality().hash(_overflow),const DeepCollectionEquality().hash(_omissions));
}

@override
String toString() {
    return 'ReaderFeasibilityRecord(kind: $kind, schemaVersion: $schemaVersion, bookSha256: $bookSha256, fixtureId: $fixtureId, scenarioId: $scenarioId, repeatIndex: $repeatIndex, repeatCount: $repeatCount, input: $input, engine: $engine, readerEvents: $readerEvents, layoutCosts: $layoutCosts, resources: $resources, presentation: $presentation, aggregates: $aggregates, overflow: $overflow, omissions: $omissions)';
}


}

/// @nodoc
abstract mixin class _$ReaderFeasibilityRecordCopyWith<$Res> implements $ReaderFeasibilityRecordCopyWith<$Res> {
  factory _$ReaderFeasibilityRecordCopyWith(_ReaderFeasibilityRecord value, $Res Function(_ReaderFeasibilityRecord) _then) = __$ReaderFeasibilityRecordCopyWithImpl;
@override @useResult
$Res call({
 String kind, int schemaVersion, String bookSha256, String? fixtureId, String scenarioId, int repeatIndex, int repeatCount, String input, DiagnosticRecord engine, List<Map<String, Object?>> readerEvents, List<Map<String, Object?>> layoutCosts, List<Map<String, Object?>> resources, Map<String, Object?> presentation, Map<String, Object?> aggregates, Map<String, int> overflow, Map<String, Object?> omissions
});


@override $DiagnosticRecordCopyWith<$Res> get engine;

}
/// @nodoc
class __$ReaderFeasibilityRecordCopyWithImpl<$Res>
    implements _$ReaderFeasibilityRecordCopyWith<$Res> {
  __$ReaderFeasibilityRecordCopyWithImpl(this._self, this._then);

  final _ReaderFeasibilityRecord _self;
  final $Res Function(_ReaderFeasibilityRecord) _then;

/// Create a copy of ReaderFeasibilityRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? kind = null,Object? schemaVersion = null,Object? bookSha256 = null,Object? fixtureId = freezed,Object? scenarioId = null,Object? repeatIndex = null,Object? repeatCount = null,Object? input = null,Object? engine = null,Object? readerEvents = null,Object? layoutCosts = null,Object? resources = null,Object? presentation = null,Object? aggregates = null,Object? overflow = null,Object? omissions = null,}) {
  return _then(_ReaderFeasibilityRecord(
kind: null == kind ? _self.kind : kind // ignore: cast_nullable_to_non_nullable
as String,schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,bookSha256: null == bookSha256 ? _self.bookSha256 : bookSha256 // ignore: cast_nullable_to_non_nullable
as String,fixtureId: freezed == fixtureId ? _self.fixtureId : fixtureId // ignore: cast_nullable_to_non_nullable
as String?,scenarioId: null == scenarioId ? _self.scenarioId : scenarioId // ignore: cast_nullable_to_non_nullable
as String,repeatIndex: null == repeatIndex ? _self.repeatIndex : repeatIndex // ignore: cast_nullable_to_non_nullable
as int,repeatCount: null == repeatCount ? _self.repeatCount : repeatCount // ignore: cast_nullable_to_non_nullable
as int,input: null == input ? _self.input : input // ignore: cast_nullable_to_non_nullable
as String,engine: null == engine ? _self.engine : engine // ignore: cast_nullable_to_non_nullable
as DiagnosticRecord,readerEvents: null == readerEvents ? _self._readerEvents : readerEvents // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>,layoutCosts: null == layoutCosts ? _self._layoutCosts : layoutCosts // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>,resources: null == resources ? _self._resources : resources // ignore: cast_nullable_to_non_nullable
as List<Map<String, Object?>>,presentation: null == presentation ? _self._presentation : presentation // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,aggregates: null == aggregates ? _self._aggregates : aggregates // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,overflow: null == overflow ? _self._overflow : overflow // ignore: cast_nullable_to_non_nullable
as Map<String, int>,omissions: null == omissions ? _self._omissions : omissions // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,
  ));
}

/// Create a copy of ReaderFeasibilityRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DiagnosticRecordCopyWith<$Res> get engine {
  
  return $DiagnosticRecordCopyWith<$Res>(_self.engine, (value) {
    return _then(_self.copyWith(engine: value));
  });
}
}

// dart format on
