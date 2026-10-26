import 'package:freezed_annotation/freezed_annotation.dart';
part 'frame_sample.freezed.dart';
part 'frame_sample.g.dart';

@freezed
abstract class FrameSample with _$FrameSample {
  const factory FrameSample({
    required int frameNumber,
    required int vsyncUs,
    required int buildStartUs,
    required int buildFinishUs,
    required int rasterStartUs,
    required int rasterFinishUs,
    required int rasterFinishWallUs,
    required int arrivalMonotonicUs,
  }) = _FrameSample;
  factory FrameSample.fromJson(Map<String, Object?> json) =>
      _$FrameSampleFromJson(json);
}
