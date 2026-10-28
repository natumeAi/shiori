import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/engine/text/harfbuzz/harfbuzz.dart';

import '../../../../../../tool/reader/fixed_layout_spike_defects.dart';
import '../../../../../../tool/reader/fixed_layout_spike_pixels.dart';

double definitionB(
  List<(HarfBuzzRun, HarfBuzzPlacedRun)> runs,
  Map<String, Object?> reference,
) {
  var maximum = 0.0;
  for (final ref
      in (reference['svgTexts'] as List).cast<Map<String, Object?>>()) {
    final (run, placed) = runs.singleWhere((r) => r.$1.text == ref['text']);
    final chars = (ref['characters'] as List).cast<Map<String, Object?>>();
    final declared = ((ref['fixtureRun'] ?? ref) as Map)['clusterMap'] as List;
    expect([
      for (final r in run.layoutClusters) [r.start, r.end],
    ], declared);
    expect(placed.fragments.expand((f) => f.glyphIndices).toSet(), {
      for (final glyph in run.paintGlyphs) glyph.index,
    });
    expect(
      placed.fragments.fold<int>(
        0,
        (s, f) => s + f.geometry.range.end - f.geometry.range.start,
      ),
      run.text.length,
    );
    maximum = math.max(
      maximum,
      (placed.advance - (ref['computedTextLength'] as num)).abs(),
    );
    for (final fragment in placed.fragments) {
      final g = fragment.geometry, range = fragment.geometry.range;
      expect(g.provenance, ClusterProvenance.shaped);
      expect(g.granularity, ClusterGranularity.shapingCluster);
      final first = chars[range.start];
      final start = (first['start'] as List).cast<num>();
      maximum = math.max(
        maximum,
        math.sqrt(
          math.pow(start[0] - g.baselineStart.x, 2) +
              math.pow(start[1] - g.baselineStart.y, 2),
        ),
      );
      if (range.end - range.start == 1) {
        final end = (first['end'] as List).cast<num>();
        final advance = math.sqrt(
          math.pow(end[0] - start[0], 2) + math.pow(end[1] - start[1], 2),
        );
        final delta =
            (g.rotationRadians - (first['rotation'] as num) * math.pi / 180)
                .abs();
        maximum = math.max(maximum, delta * advance);
      }
    }
  }
  return maximum;
}

Future<Map<String, Object?>> rasterD4(
  List<(HarfBuzzRun, HarfBuzzPlacedRun)> runs,
  Map<String, Object?> fixture,
  Map<String, Object?> reference,
  SpikeReferenceDefects defects,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  final nested = fixture['variant'] == 'nested';
  canvas.clipRect(const ui.Rect.fromLTWH(0, 0, 320, 240));
  if (fixture['captureBodyMargin'] case final List margin) {
    canvas.translate(
      (margin[0] as num).toDouble(),
      (margin[1] as num).toDouble(),
    );
  }
  if (nested) {
    canvas.translate(7, 9);
    canvas.clipRect(const ui.Rect.fromLTWH(0, 0, 300, 220));
    canvas.saveLayer(
      const ui.Rect.fromLTWH(0, 0, 300, 220),
      ui.Paint()..color = const ui.Color(0xccffffff),
    );
  }
  final paint = ui.Paint()..color = const ui.Color(0xff000000);
  for (final (_, placed) in runs) {
    for (final fragment in placed.fragments) {
      canvas.drawPath(fragment.path, paint);
    }
  }
  if (nested) canvas.restore();
  final picture = recorder.endRecording();
  try {
    final image = await picture.toImage(320, 240);
    try {
      final actual = (await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(
        base64Decode(reference['pngBase64'] as String),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final expected = (await frame.image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!.buffer.asUint8List();
          var maximumSampleDelta = 0;
          for (final sample in (reference['samples'] as List).cast<Map>()) {
            final index =
                ((sample['y'] as int) * 320 + (sample['x'] as int)) * 4;
            final rgba = sample['rgba'] as List;
            for (var i = 0; i < 4; i++) {
              maximumSampleDelta = math.max(
                maximumSampleDelta,
                (actual[index + i] - (rgba[i] as int)).abs(),
              );
            }
          }
          final scope = defects.scope(fixture, reference, actual, expected);
          return compareSpikePixels(
            actual,
            expected,
            exemptScope: scope.$1,
            maximumSampleDelta: maximumSampleDelta,
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      image.dispose();
    }
  } finally {
    picture.dispose();
  }
}
