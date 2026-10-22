import 'package:freezed_annotation/freezed_annotation.dart';
part 'motion_sample.freezed.dart';
part 'motion_sample.g.dart';

@freezed
abstract class MotionSample with _$MotionSample {
  const factory MotionSample({
    required int frameNumber,
    required int schedulerUs,
    required int rawSchedulerUs,
    required int monotonicUs,
    required double progress,
  }) = _MotionSample;
  factory MotionSample.fromJson(Map<String, Object?> json) =>
      _$MotionSampleFromJson(json);
}
