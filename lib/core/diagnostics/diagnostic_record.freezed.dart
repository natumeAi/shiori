// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint, type=warning, deprecated_member_use, deprecated_member_use_from_same_package
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'diagnostic_record.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DiagnosticRecord {

 int get schemaVersion; String get scenarioId; String get runId; String get buildId; DateTime get startedAt; DateTime get stoppedAt; int get startedMonotonicUs; int get stoppedMonotonicUs; int get finalizedMonotonicUs; String get stopReason; ProbeDeclarations get declarations; Map<String, Object?> get metadata; Map<String, Object?> get clocks; List<FrameSample> get frames; List<MotionSample> get motion; int get frameOverflow; int get motionOverflow; int get reportsDuringDrain; int get omittedOutsideMotion; bool get incompleteTrailingBatch; List<String> get errors; Map<String, Object?> get aggregates; String get physicalPresentation;
/// Create a copy of DiagnosticRecord
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DiagnosticRecordCopyWith<DiagnosticRecord> get copyWith => _$DiagnosticRecordCopyWithImpl<DiagnosticRecord>(this as DiagnosticRecord, _$identity);

  /// Serializes this DiagnosticRecord to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  final _this = this as DiagnosticRecord;
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DiagnosticRecord&&(identical(other.schemaVersion, _this.schemaVersion) || other.schemaVersion == _this.schemaVersion)&&(identical(other.scenarioId, _this.scenarioId) || other.scenarioId == _this.scenarioId)&&(identical(other.runId, _this.runId) || other.runId == _this.runId)&&(identical(other.buildId, _this.buildId) || other.buildId == _this.buildId)&&(identical(other.startedAt, _this.startedAt) || other.startedAt == _this.startedAt)&&(identical(other.stoppedAt, _this.stoppedAt) || other.stoppedAt == _this.stoppedAt)&&(identical(other.startedMonotonicUs, _this.startedMonotonicUs) || other.startedMonotonicUs == _this.startedMonotonicUs)&&(identical(other.stoppedMonotonicUs, _this.stoppedMonotonicUs) || other.stoppedMonotonicUs == _this.stoppedMonotonicUs)&&(identical(other.finalizedMonotonicUs, _this.finalizedMonotonicUs) || other.finalizedMonotonicUs == _this.finalizedMonotonicUs)&&(identical(other.stopReason, _this.stopReason) || other.stopReason == _this.stopReason)&&(identical(other.declarations, _this.declarations) || other.declarations == _this.declarations)&&const DeepCollectionEquality().equals(other.metadata, _this.metadata)&&const DeepCollectionEquality().equals(other.clocks, _this.clocks)&&const DeepCollectionEquality().equals(other.frames, _this.frames)&&const DeepCollectionEquality().equals(other.motion, _this.motion)&&(identical(other.frameOverflow, _this.frameOverflow) || other.frameOverflow == _this.frameOverflow)&&(identical(other.motionOverflow, _this.motionOverflow) || other.motionOverflow == _this.motionOverflow)&&(identical(other.reportsDuringDrain, _this.reportsDuringDrain) || other.reportsDuringDrain == _this.reportsDuringDrain)&&(identical(other.omittedOutsideMotion, _this.omittedOutsideMotion) || other.omittedOutsideMotion == _this.omittedOutsideMotion)&&(identical(other.incompleteTrailingBatch, _this.incompleteTrailingBatch) || other.incompleteTrailingBatch == _this.incompleteTrailingBatch)&&const DeepCollectionEquality().equals(other.errors, _this.errors)&&const DeepCollectionEquality().equals(other.aggregates, _this.aggregates)&&(identical(other.physicalPresentation, _this.physicalPresentation) || other.physicalPresentation == _this.physicalPresentation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
  final _this = this as DiagnosticRecord;
  return Object.hashAll([runtimeType,_this.schemaVersion,_this.scenarioId,_this.runId,_this.buildId,_this.startedAt,_this.stoppedAt,_this.startedMonotonicUs,_this.stoppedMonotonicUs,_this.finalizedMonotonicUs,_this.stopReason,_this.declarations,const DeepCollectionEquality().hash(_this.metadata),const DeepCollectionEquality().hash(_this.clocks),const DeepCollectionEquality().hash(_this.frames),const DeepCollectionEquality().hash(_this.motion),_this.frameOverflow,_this.motionOverflow,_this.reportsDuringDrain,_this.omittedOutsideMotion,_this.incompleteTrailingBatch,const DeepCollectionEquality().hash(_this.errors),const DeepCollectionEquality().hash(_this.aggregates),_this.physicalPresentation]);
}

@override
String toString() {
  final _this = this as DiagnosticRecord;
  return 'DiagnosticRecord(schemaVersion: ${_this.schemaVersion}, scenarioId: ${_this.scenarioId}, runId: ${_this.runId}, buildId: ${_this.buildId}, startedAt: ${_this.startedAt}, stoppedAt: ${_this.stoppedAt}, startedMonotonicUs: ${_this.startedMonotonicUs}, stoppedMonotonicUs: ${_this.stoppedMonotonicUs}, finalizedMonotonicUs: ${_this.finalizedMonotonicUs}, stopReason: ${_this.stopReason}, declarations: ${_this.declarations}, metadata: ${_this.metadata}, clocks: ${_this.clocks}, frames: ${_this.frames}, motion: ${_this.motion}, frameOverflow: ${_this.frameOverflow}, motionOverflow: ${_this.motionOverflow}, reportsDuringDrain: ${_this.reportsDuringDrain}, omittedOutsideMotion: ${_this.omittedOutsideMotion}, incompleteTrailingBatch: ${_this.incompleteTrailingBatch}, errors: ${_this.errors}, aggregates: ${_this.aggregates}, physicalPresentation: ${_this.physicalPresentation})';
}


}

/// @nodoc
abstract mixin class $DiagnosticRecordCopyWith<$Res>  {
  factory $DiagnosticRecordCopyWith(DiagnosticRecord value, $Res Function(DiagnosticRecord) _then) = _$DiagnosticRecordCopyWithImpl;
@useResult
$Res call({
 int schemaVersion, String scenarioId, String runId, String buildId, DateTime startedAt, DateTime stoppedAt, int startedMonotonicUs, int stoppedMonotonicUs, int finalizedMonotonicUs, String stopReason, ProbeDeclarations declarations, Map<String, Object?> metadata, Map<String, Object?> clocks, List<FrameSample> frames, List<MotionSample> motion, int frameOverflow, int motionOverflow, int reportsDuringDrain, int omittedOutsideMotion, bool incompleteTrailingBatch, List<String> errors, Map<String, Object?> aggregates, String physicalPresentation
});


$ProbeDeclarationsCopyWith<$Res> get declarations;

}
/// @nodoc
class _$DiagnosticRecordCopyWithImpl<$Res>
    implements $DiagnosticRecordCopyWith<$Res> {
  _$DiagnosticRecordCopyWithImpl(this._self, this._then);

  final DiagnosticRecord _self;
  final $Res Function(DiagnosticRecord) _then;

/// Create a copy of DiagnosticRecord
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? schemaVersion = null,Object? scenarioId = null,Object? runId = null,Object? buildId = null,Object? startedAt = null,Object? stoppedAt = null,Object? startedMonotonicUs = null,Object? stoppedMonotonicUs = null,Object? finalizedMonotonicUs = null,Object? stopReason = null,Object? declarations = null,Object? metadata = null,Object? clocks = null,Object? frames = null,Object? motion = null,Object? frameOverflow = null,Object? motionOverflow = null,Object? reportsDuringDrain = null,Object? omittedOutsideMotion = null,Object? incompleteTrailingBatch = null,Object? errors = null,Object? aggregates = null,Object? physicalPresentation = null,}) {
  return _then(DiagnosticRecord(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,scenarioId: null == scenarioId ? _self.scenarioId : scenarioId // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,buildId: null == buildId ? _self.buildId : buildId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,stoppedAt: null == stoppedAt ? _self.stoppedAt : stoppedAt // ignore: cast_nullable_to_non_nullable
as DateTime,startedMonotonicUs: null == startedMonotonicUs ? _self.startedMonotonicUs : startedMonotonicUs // ignore: cast_nullable_to_non_nullable
as int,stoppedMonotonicUs: null == stoppedMonotonicUs ? _self.stoppedMonotonicUs : stoppedMonotonicUs // ignore: cast_nullable_to_non_nullable
as int,finalizedMonotonicUs: null == finalizedMonotonicUs ? _self.finalizedMonotonicUs : finalizedMonotonicUs // ignore: cast_nullable_to_non_nullable
as int,stopReason: null == stopReason ? _self.stopReason : stopReason // ignore: cast_nullable_to_non_nullable
as String,declarations: null == declarations ? _self.declarations : declarations // ignore: cast_nullable_to_non_nullable
as ProbeDeclarations,metadata: null == metadata ? _self.metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,clocks: null == clocks ? _self.clocks : clocks // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,frames: null == frames ? _self.frames : frames // ignore: cast_nullable_to_non_nullable
as List<FrameSample>,motion: null == motion ? _self.motion : motion // ignore: cast_nullable_to_non_nullable
as List<MotionSample>,frameOverflow: null == frameOverflow ? _self.frameOverflow : frameOverflow // ignore: cast_nullable_to_non_nullable
as int,motionOverflow: null == motionOverflow ? _self.motionOverflow : motionOverflow // ignore: cast_nullable_to_non_nullable
as int,reportsDuringDrain: null == reportsDuringDrain ? _self.reportsDuringDrain : reportsDuringDrain // ignore: cast_nullable_to_non_nullable
as int,omittedOutsideMotion: null == omittedOutsideMotion ? _self.omittedOutsideMotion : omittedOutsideMotion // ignore: cast_nullable_to_non_nullable
as int,incompleteTrailingBatch: null == incompleteTrailingBatch ? _self.incompleteTrailingBatch : incompleteTrailingBatch // ignore: cast_nullable_to_non_nullable
as bool,errors: null == errors ? _self.errors : errors // ignore: cast_nullable_to_non_nullable
as List<String>,aggregates: null == aggregates ? _self.aggregates : aggregates // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,physicalPresentation: null == physicalPresentation ? _self.physicalPresentation : physicalPresentation // ignore: cast_nullable_to_non_nullable
as String,
  ));
}
/// Create a copy of DiagnosticRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProbeDeclarationsCopyWith<$Res> get declarations {
  
  return $ProbeDeclarationsCopyWith<$Res>(_self.declarations, (value) {
    return _then(_self.copyWith(declarations: value));
  });
}
}


/// Adds pattern-matching-related methods to [DiagnosticRecord].
extension DiagnosticRecordPatterns on DiagnosticRecord {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DiagnosticRecord value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DiagnosticRecord() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DiagnosticRecord value)  $default,){
final _that = this;
switch (_that) {
case _DiagnosticRecord():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DiagnosticRecord value)?  $default,){
final _that = this;
switch (_that) {
case _DiagnosticRecord() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int schemaVersion,  String scenarioId,  String runId,  String buildId,  DateTime startedAt,  DateTime stoppedAt,  int startedMonotonicUs,  int stoppedMonotonicUs,  int finalizedMonotonicUs,  String stopReason,  ProbeDeclarations declarations,  Map<String, Object?> metadata,  Map<String, Object?> clocks,  List<FrameSample> frames,  List<MotionSample> motion,  int frameOverflow,  int motionOverflow,  int reportsDuringDrain,  int omittedOutsideMotion,  bool incompleteTrailingBatch,  List<String> errors,  Map<String, Object?> aggregates,  String physicalPresentation)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DiagnosticRecord() when $default != null:
return $default(_that.schemaVersion,_that.scenarioId,_that.runId,_that.buildId,_that.startedAt,_that.stoppedAt,_that.startedMonotonicUs,_that.stoppedMonotonicUs,_that.finalizedMonotonicUs,_that.stopReason,_that.declarations,_that.metadata,_that.clocks,_that.frames,_that.motion,_that.frameOverflow,_that.motionOverflow,_that.reportsDuringDrain,_that.omittedOutsideMotion,_that.incompleteTrailingBatch,_that.errors,_that.aggregates,_that.physicalPresentation);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int schemaVersion,  String scenarioId,  String runId,  String buildId,  DateTime startedAt,  DateTime stoppedAt,  int startedMonotonicUs,  int stoppedMonotonicUs,  int finalizedMonotonicUs,  String stopReason,  ProbeDeclarations declarations,  Map<String, Object?> metadata,  Map<String, Object?> clocks,  List<FrameSample> frames,  List<MotionSample> motion,  int frameOverflow,  int motionOverflow,  int reportsDuringDrain,  int omittedOutsideMotion,  bool incompleteTrailingBatch,  List<String> errors,  Map<String, Object?> aggregates,  String physicalPresentation)  $default,) {final _that = this;
switch (_that) {
case _DiagnosticRecord():
return $default(_that.schemaVersion,_that.scenarioId,_that.runId,_that.buildId,_that.startedAt,_that.stoppedAt,_that.startedMonotonicUs,_that.stoppedMonotonicUs,_that.finalizedMonotonicUs,_that.stopReason,_that.declarations,_that.metadata,_that.clocks,_that.frames,_that.motion,_that.frameOverflow,_that.motionOverflow,_that.reportsDuringDrain,_that.omittedOutsideMotion,_that.incompleteTrailingBatch,_that.errors,_that.aggregates,_that.physicalPresentation);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int schemaVersion,  String scenarioId,  String runId,  String buildId,  DateTime startedAt,  DateTime stoppedAt,  int startedMonotonicUs,  int stoppedMonotonicUs,  int finalizedMonotonicUs,  String stopReason,  ProbeDeclarations declarations,  Map<String, Object?> metadata,  Map<String, Object?> clocks,  List<FrameSample> frames,  List<MotionSample> motion,  int frameOverflow,  int motionOverflow,  int reportsDuringDrain,  int omittedOutsideMotion,  bool incompleteTrailingBatch,  List<String> errors,  Map<String, Object?> aggregates,  String physicalPresentation)?  $default,) {final _that = this;
switch (_that) {
case _DiagnosticRecord() when $default != null:
return $default(_that.schemaVersion,_that.scenarioId,_that.runId,_that.buildId,_that.startedAt,_that.stoppedAt,_that.startedMonotonicUs,_that.stoppedMonotonicUs,_that.finalizedMonotonicUs,_that.stopReason,_that.declarations,_that.metadata,_that.clocks,_that.frames,_that.motion,_that.frameOverflow,_that.motionOverflow,_that.reportsDuringDrain,_that.omittedOutsideMotion,_that.incompleteTrailingBatch,_that.errors,_that.aggregates,_that.physicalPresentation);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DiagnosticRecord implements DiagnosticRecord {
  const _DiagnosticRecord({this.schemaVersion = 1, this.scenarioId = 'synthetic_transform', required this.runId, required this.buildId, required this.startedAt, required this.stoppedAt, required this.startedMonotonicUs, required this.stoppedMonotonicUs, required this.finalizedMonotonicUs, required this.stopReason, required this.declarations, required  Map<String, Object?> metadata, required  Map<String, Object?> clocks, required  List<FrameSample> frames, required  List<MotionSample> motion, required this.frameOverflow, required this.motionOverflow, required this.reportsDuringDrain, required this.omittedOutsideMotion, required this.incompleteTrailingBatch, required  List<String> errors, required  Map<String, Object?> aggregates, this.physicalPresentation = 'unverified'}): _metadata = metadata,_clocks = clocks,_frames = frames,_motion = motion,_errors = errors,_aggregates = aggregates;
  factory _DiagnosticRecord.fromJson(Map<String, dynamic> json) => _$DiagnosticRecordFromJson(json);

@override@JsonKey() final  int schemaVersion;
@override@JsonKey() final  String scenarioId;
@override final  String runId;
@override final  String buildId;
@override final  DateTime startedAt;
@override final  DateTime stoppedAt;
@override final  int startedMonotonicUs;
@override final  int stoppedMonotonicUs;
@override final  int finalizedMonotonicUs;
@override final  String stopReason;
@override final  ProbeDeclarations declarations;
 final  Map<String, Object?> _metadata;
@override Map<String, Object?> get metadata {
  if (_metadata is EqualUnmodifiableMapView) return _metadata;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_metadata);
}

 final  Map<String, Object?> _clocks;
@override Map<String, Object?> get clocks {
  if (_clocks is EqualUnmodifiableMapView) return _clocks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_clocks);
}

 final  List<FrameSample> _frames;
@override List<FrameSample> get frames {
  if (_frames is EqualUnmodifiableListView) return _frames;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_frames);
}

 final  List<MotionSample> _motion;
@override List<MotionSample> get motion {
  if (_motion is EqualUnmodifiableListView) return _motion;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_motion);
}

@override final  int frameOverflow;
@override final  int motionOverflow;
@override final  int reportsDuringDrain;
@override final  int omittedOutsideMotion;
@override final  bool incompleteTrailingBatch;
 final  List<String> _errors;
@override List<String> get errors {
  if (_errors is EqualUnmodifiableListView) return _errors;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_errors);
}

 final  Map<String, Object?> _aggregates;
@override Map<String, Object?> get aggregates {
  if (_aggregates is EqualUnmodifiableMapView) return _aggregates;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_aggregates);
}

@override@JsonKey() final  String physicalPresentation;

/// Create a copy of DiagnosticRecord
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DiagnosticRecordCopyWith<_DiagnosticRecord> get copyWith => __$DiagnosticRecordCopyWithImpl<_DiagnosticRecord>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DiagnosticRecordToJson(this, );
}

@override
bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is _DiagnosticRecord&&(identical(other.schemaVersion, schemaVersion) || other.schemaVersion == schemaVersion)&&(identical(other.scenarioId, scenarioId) || other.scenarioId == scenarioId)&&(identical(other.runId, runId) || other.runId == runId)&&(identical(other.buildId, buildId) || other.buildId == buildId)&&(identical(other.startedAt, startedAt) || other.startedAt == startedAt)&&(identical(other.stoppedAt, stoppedAt) || other.stoppedAt == stoppedAt)&&(identical(other.startedMonotonicUs, startedMonotonicUs) || other.startedMonotonicUs == startedMonotonicUs)&&(identical(other.stoppedMonotonicUs, stoppedMonotonicUs) || other.stoppedMonotonicUs == stoppedMonotonicUs)&&(identical(other.finalizedMonotonicUs, finalizedMonotonicUs) || other.finalizedMonotonicUs == finalizedMonotonicUs)&&(identical(other.stopReason, stopReason) || other.stopReason == stopReason)&&(identical(other.declarations, declarations) || other.declarations == declarations)&&const DeepCollectionEquality().equals(other.metadata, _metadata)&&const DeepCollectionEquality().equals(other.clocks, _clocks)&&const DeepCollectionEquality().equals(other.frames, _frames)&&const DeepCollectionEquality().equals(other.motion, _motion)&&(identical(other.frameOverflow, frameOverflow) || other.frameOverflow == frameOverflow)&&(identical(other.motionOverflow, motionOverflow) || other.motionOverflow == motionOverflow)&&(identical(other.reportsDuringDrain, reportsDuringDrain) || other.reportsDuringDrain == reportsDuringDrain)&&(identical(other.omittedOutsideMotion, omittedOutsideMotion) || other.omittedOutsideMotion == omittedOutsideMotion)&&(identical(other.incompleteTrailingBatch, incompleteTrailingBatch) || other.incompleteTrailingBatch == incompleteTrailingBatch)&&const DeepCollectionEquality().equals(other.errors, _errors)&&const DeepCollectionEquality().equals(other.aggregates, _aggregates)&&(identical(other.physicalPresentation, physicalPresentation) || other.physicalPresentation == physicalPresentation));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode {
    return Object.hashAll([runtimeType,schemaVersion,scenarioId,runId,buildId,startedAt,stoppedAt,startedMonotonicUs,stoppedMonotonicUs,finalizedMonotonicUs,stopReason,declarations,const DeepCollectionEquality().hash(_metadata),const DeepCollectionEquality().hash(_clocks),const DeepCollectionEquality().hash(_frames),const DeepCollectionEquality().hash(_motion),frameOverflow,motionOverflow,reportsDuringDrain,omittedOutsideMotion,incompleteTrailingBatch,const DeepCollectionEquality().hash(_errors),const DeepCollectionEquality().hash(_aggregates),physicalPresentation]);
}

@override
String toString() {
    return 'DiagnosticRecord(schemaVersion: $schemaVersion, scenarioId: $scenarioId, runId: $runId, buildId: $buildId, startedAt: $startedAt, stoppedAt: $stoppedAt, startedMonotonicUs: $startedMonotonicUs, stoppedMonotonicUs: $stoppedMonotonicUs, finalizedMonotonicUs: $finalizedMonotonicUs, stopReason: $stopReason, declarations: $declarations, metadata: $metadata, clocks: $clocks, frames: $frames, motion: $motion, frameOverflow: $frameOverflow, motionOverflow: $motionOverflow, reportsDuringDrain: $reportsDuringDrain, omittedOutsideMotion: $omittedOutsideMotion, incompleteTrailingBatch: $incompleteTrailingBatch, errors: $errors, aggregates: $aggregates, physicalPresentation: $physicalPresentation)';
}


}

/// @nodoc
abstract mixin class _$DiagnosticRecordCopyWith<$Res> implements $DiagnosticRecordCopyWith<$Res> {
  factory _$DiagnosticRecordCopyWith(_DiagnosticRecord value, $Res Function(_DiagnosticRecord) _then) = __$DiagnosticRecordCopyWithImpl;
@override @useResult
$Res call({
 int schemaVersion, String scenarioId, String runId, String buildId, DateTime startedAt, DateTime stoppedAt, int startedMonotonicUs, int stoppedMonotonicUs, int finalizedMonotonicUs, String stopReason, ProbeDeclarations declarations, Map<String, Object?> metadata, Map<String, Object?> clocks, List<FrameSample> frames, List<MotionSample> motion, int frameOverflow, int motionOverflow, int reportsDuringDrain, int omittedOutsideMotion, bool incompleteTrailingBatch, List<String> errors, Map<String, Object?> aggregates, String physicalPresentation
});


@override $ProbeDeclarationsCopyWith<$Res> get declarations;

}
/// @nodoc
class __$DiagnosticRecordCopyWithImpl<$Res>
    implements _$DiagnosticRecordCopyWith<$Res> {
  __$DiagnosticRecordCopyWithImpl(this._self, this._then);

  final _DiagnosticRecord _self;
  final $Res Function(_DiagnosticRecord) _then;

/// Create a copy of DiagnosticRecord
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? schemaVersion = null,Object? scenarioId = null,Object? runId = null,Object? buildId = null,Object? startedAt = null,Object? stoppedAt = null,Object? startedMonotonicUs = null,Object? stoppedMonotonicUs = null,Object? finalizedMonotonicUs = null,Object? stopReason = null,Object? declarations = null,Object? metadata = null,Object? clocks = null,Object? frames = null,Object? motion = null,Object? frameOverflow = null,Object? motionOverflow = null,Object? reportsDuringDrain = null,Object? omittedOutsideMotion = null,Object? incompleteTrailingBatch = null,Object? errors = null,Object? aggregates = null,Object? physicalPresentation = null,}) {
  return _then(_DiagnosticRecord(
schemaVersion: null == schemaVersion ? _self.schemaVersion : schemaVersion // ignore: cast_nullable_to_non_nullable
as int,scenarioId: null == scenarioId ? _self.scenarioId : scenarioId // ignore: cast_nullable_to_non_nullable
as String,runId: null == runId ? _self.runId : runId // ignore: cast_nullable_to_non_nullable
as String,buildId: null == buildId ? _self.buildId : buildId // ignore: cast_nullable_to_non_nullable
as String,startedAt: null == startedAt ? _self.startedAt : startedAt // ignore: cast_nullable_to_non_nullable
as DateTime,stoppedAt: null == stoppedAt ? _self.stoppedAt : stoppedAt // ignore: cast_nullable_to_non_nullable
as DateTime,startedMonotonicUs: null == startedMonotonicUs ? _self.startedMonotonicUs : startedMonotonicUs // ignore: cast_nullable_to_non_nullable
as int,stoppedMonotonicUs: null == stoppedMonotonicUs ? _self.stoppedMonotonicUs : stoppedMonotonicUs // ignore: cast_nullable_to_non_nullable
as int,finalizedMonotonicUs: null == finalizedMonotonicUs ? _self.finalizedMonotonicUs : finalizedMonotonicUs // ignore: cast_nullable_to_non_nullable
as int,stopReason: null == stopReason ? _self.stopReason : stopReason // ignore: cast_nullable_to_non_nullable
as String,declarations: null == declarations ? _self.declarations : declarations // ignore: cast_nullable_to_non_nullable
as ProbeDeclarations,metadata: null == metadata ? _self._metadata : metadata // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,clocks: null == clocks ? _self._clocks : clocks // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,frames: null == frames ? _self._frames : frames // ignore: cast_nullable_to_non_nullable
as List<FrameSample>,motion: null == motion ? _self._motion : motion // ignore: cast_nullable_to_non_nullable
as List<MotionSample>,frameOverflow: null == frameOverflow ? _self.frameOverflow : frameOverflow // ignore: cast_nullable_to_non_nullable
as int,motionOverflow: null == motionOverflow ? _self.motionOverflow : motionOverflow // ignore: cast_nullable_to_non_nullable
as int,reportsDuringDrain: null == reportsDuringDrain ? _self.reportsDuringDrain : reportsDuringDrain // ignore: cast_nullable_to_non_nullable
as int,omittedOutsideMotion: null == omittedOutsideMotion ? _self.omittedOutsideMotion : omittedOutsideMotion // ignore: cast_nullable_to_non_nullable
as int,incompleteTrailingBatch: null == incompleteTrailingBatch ? _self.incompleteTrailingBatch : incompleteTrailingBatch // ignore: cast_nullable_to_non_nullable
as bool,errors: null == errors ? _self._errors : errors // ignore: cast_nullable_to_non_nullable
as List<String>,aggregates: null == aggregates ? _self._aggregates : aggregates // ignore: cast_nullable_to_non_nullable
as Map<String, Object?>,physicalPresentation: null == physicalPresentation ? _self.physicalPresentation : physicalPresentation // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

/// Create a copy of DiagnosticRecord
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$ProbeDeclarationsCopyWith<$Res> get declarations {
  
  return $ProbeDeclarationsCopyWith<$Res>(_self.declarations, (value) {
    return _then(_self.copyWith(declarations: value));
  });
}
}

// dart format on
