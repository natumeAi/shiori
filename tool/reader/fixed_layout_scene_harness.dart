import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import 'fixed_layout_scene_input.dart';
import 'fixed_layout_scene_metrics.dart';
import 'fixed_layout_spike_defects.dart';
import 'fixed_layout_spike_pixels.dart';

/// Native authored scene experiment; test execution is separate from fidelity.
final class FixedLayoutSceneHarness {
  static const rows = {
    'cascade',
    'box',
    'paint',
    'stacking',
    'text',
    'dimensions',
    'metadata',
  };
  static const output = 'build/fixed-layout-native';
  late SpikeReferenceDefects _defects;
  Future<Map<String, Object?>> run() async {
    final corpusBytes = File('test/fixtures/reader/fixed_layout/corpus.json')
        .readAsBytesSync();
    final oracleBytes = File('test/fixtures/reader/fixed_layout/oracle.json')
        .readAsBytesSync();
    final corpus = jsonDecode(utf8.decode(corpusBytes)) as Map<String, Object?>,
        oracle = jsonDecode(utf8.decode(oracleBytes)) as Map<String, Object?>;
    if (oracle['corpusSHA256'] != sha256.convert(corpusBytes).toString()) {
      throw StateError('Oracle corpus mismatch');
    }
    _defects = SpikeReferenceDefects(oracle);
    await _defects.load();
    final fontInfo = corpus['font'] as Map<String, Object?>,
        font = File(fontInfo['path'] as String).readAsBytesSync();
    if (sha256.convert(font).toString() != fontInfo['sha256']) {
      throw StateError('Font provenance mismatch');
    }
    await ui.loadFontFromList(font, fontFamily: 'AuthoredSceneFixture');
    final decorationMetrics = FontDecorationMetrics.tryParseSfnt(font);
    final resources = corpus['resources'] as Map<String, Object?>;
    final tile = await vg.loadPicture(
      SvgStringLoader(resources['/tile.svg'] as String),
      null,
    );
    final image = await tile.picture.toImage(320, 240);
    tile.picture.dispose();
    final references = {
      for (final raw in oracle['cases'] as List)
        (raw as Map<String, Object?>)['id']: raw,
    };
    final cases = <Map<String, Object?>>[],
        fallbackCases = <Map<String, Object?>>[];
    Directory(output).createSync(recursive: true);
    try {
      for (final raw in corpus['cases'] as List) {
        final fixture = raw as Map<String, Object?>;
        final fallback = fixture.containsKey('fallbackCharacters');
        if (!rows.contains(fixture['row']) && !fallback) continue;
        final input = SceneHarnessInput(fixture, corpus, font);
        final styles = const CssStyleResolver().resolve(
          input.book,
          0,
          input.document,
          const ReaderSettings(),
          authoredViewport: AuthoredPageSize(320, 240),
        );
        final source = FixedSourceLease(
          page: input.page,
          document: input.document,
          styles: styles,
          rendition: sectionRendition(input.book, 0),
          resources: ArchiveReaderResourceSource(input.book.archive),
          retainedSourceBytes: utf8.encode(fixture['source'] as String).length,
          releaseSource: () {},
        );
        final plan = FixedPreparationPlan.inspect(
          source,
          scale: const FixedPreparationScale.authored(),
        );
        if (fixture['row'] == 'metadata' || !plan.capability.isComplete) {
          final metadata = fixture['row'] == 'metadata';
          final wanted = fixture['expectedCapability'];
          final matches = switch (wanted) {
            'malformed' => plan.capability is MalformedSectionCapability,
            'unsupported' => plan.capability is UnsupportedSectionCapability,
            _ => plan.capability.isComplete,
          };
          final identity =
              input.page.stableId == fixture['id'] &&
              input.page.sectionIndex == 0 &&
              input.page.spineIndex == 0 &&
              input.page.content.sha256 == fixture['sha256'];
          cases.add({
            'id': fixture['id'],
            'row': fixture['row'],
            'required': fixture['variant'] != 'unsupported',
            'capability': {
              'kind': plan.capability.runtimeType.toString(),
              'complete': plan.capability.isComplete,
            },
            'identityPass': identity,
            'typedCapabilityPass': matches,
            'unsupportedVerdict': matches,
            'geometry': {
              'pass': matches,
              'maximumCssPxDelta': null,
              'unverified': [],
              'scope': metadata
                  ? 'capability-and-identity-only'
                  : 'invalid-dimensions-no-guessed-scene',
            },
            'pixels': {'status': 'not-applicable', 'pass': matches},
            'referenceDefects': _defects.unmeasured(
              'No raster gate for typed capability/identity',
            ),
            'fidelityGate': matches && identity,
            'reasons': [
              if (!matches) 'Typed capability mismatch',
              if (!identity) 'Source identity mismatch',
            ],
          });
          source.dispose();
          input.book.archive.close();
          continue;
        }
        final scene = await FixedSceneBuilder(
          preparationScale: const FixedPreparationScale.authored(),
          document: input.document,
          styles: styles,
          page: input.page,
          size: (plan.dimensions as ResolvedDimensions).size,
          fonts: ParagraphFonts(
            embedded: {'fixture': 'AuthoredSceneFixture'},
            decorationMetrics: decorationMetrics == null
                ? const {}
                : {'AuthoredSceneFixture': decorationMetrics},
          ),
          backgroundImages: {'tile.svg': image},
          svgPlans: {for (final svg in plan.svgPlans) svg.rootIndex: svg},
        ).build();
        try {
          if (fallback) {
            fallbackCases.add(
              await _fallback(
                fixture,
                references[fixture['id']]!,
                input,
                scene,
              ),
            );
          } else {
            cases.add(
              await _measure(fixture, references[fixture['id']]!, input, scene),
            );
          }
        } finally {
          scene.dispose();
          source.dispose();
          input.book.archive.close();
        }
      }
    } finally {
      image.dispose();
    }
    final verdicts = [
      for (final row in rows)
        (() {
          final required = cases
              .where((c) => c['row'] == row && c['required'] == true)
              .toList();
          final failures = required
              .where((c) => c['fidelityGate'] != true)
              .map((c) => c['id'])
              .toList();
          final maxima = required
              .map(
                (c) =>
                    (c['geometry']
                        as Map<String, Object?>)['maximumCssPxDelta'],
              )
              .whereType<num>();
          final measuredGate = failures.isEmpty;
          final textRow = row == 'text';
          return <String, Object?>{
            'row': row,
            'verdict': !measuredGate
                ? 'fail'
                : textRow
                ? textRasterParityStatus
                : 'pass',
            'hostGate': measuredGate,
            'textRasterParity':
                required.any((c) => c['textRasterParity'] != null)
                ? textRasterParityStatus
                : null,
            'failedCases': failures,
            'maximumGatedCssPxDelta': maxima.isEmpty
                ? null
                : maxima.reduce(math.max),
            'reasons': required
                .where((c) => c['fidelityGate'] != true)
                .map((c) => {'id': c['id'], 'reasons': c['reasons']})
                .toList(),
          };
        })(),
    ];
    final report = <String, Object?>{
      'schemaVersion': 1,
      'evidence': 'host-native-authored-xhtml-no-device-claim',
      'corpusSHA256': sha256.convert(corpusBytes).toString(),
      'oracleSHA256': sha256.convert(oracleBytes).toString(),
      'geometryToleranceCssPx': .5,
      'd4ComponentAlphaThresholdInclusive': d4ComponentAlphaThreshold,
      'd10ChangedPixelMinimumDelta': d10ChangedPixelMinimumDelta,
      'referenceDefectsSHA256': _defects.registrySHA256,
      'paintControlsSHA256': _defects.controlsSHA256,
      'font': fontInfo,
      'cases': cases,
      'fallbackCases': fallbackCases,
      'rowVerdicts': verdicts,
      'rowHostGate': verdicts.every((v) => v['hostGate'] == true),
      'rowFidelityGate': verdicts.every((v) => v['verdict'] == 'pass'),
      'textRasterParity': textRasterParityStatus,
      'fidelityGate':
          verdicts.every((v) => v['verdict'] == 'pass') &&
          fallbackCases.every((c) => c['fidelityGate'] == true),
      'hostFidelityGate':
          verdicts.every((v) => v['hostGate'] == true) &&
          fallbackCases.every((c) => c['hostConservationPass'] == true),
    };
    File('$output/scene-report.json')
        .writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
    return report;
  }

  Future<Map<String, Object?>> _fallback(
    Map<String, Object?> fixture,
    Map<String, Object?> reference,
    SceneHarnessInput input,
    FixedScene scene,
  ) async {
    final id = fixture['id'] as String;
    final runs = (fixture['textRuns'] as List).cast<Map<String, Object?>>();
    // The dedicated fixture contains just the glyph, with no decoration or
    // background. Nonzero alpha therefore proves actual fallback glyph paint.
    if (runs.length != 1 || runs.single['text'] != '\u{1f600}') {
      throw StateError('Fallback paint control must contain only its glyph');
    }
    final mapped = scene.geometry.fragments
        .where(
          (f) =>
              f.textRange?.start == 0 &&
              f.textRange?.end == 2 &&
              input.document.node(f.nodeIndex).text == runs.single['text'],
        )
        .toList();
    final codec = await ui.instantiateImageCodec(
      base64Decode(reference['pngBase64'] as String),
    );
    final expected = (await codec.getNextFrame()).image;
    codec.dispose();
    final native = await scene.picture.toImage(320, 240);
    try {
      Future<int> alphaPixels(ui.Image image) async {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!.buffer.asUint8List();
        return [
          for (var i = 3; i < bytes.length; i += 4)
            if (bytes[i] > 0) i,
        ].length;
      }

      final nativeAlpha = await alphaPixels(native),
          referenceAlpha = await alphaPixels(expected);
      final conservation = measureSceneTextConservation(input, scene);
      final sourceMapped =
          mapped.length == 1 &&
          mapped.single.clusters.length == 1 &&
          mapped.single.clusters.single.range.start == 0 &&
          mapped.single.clusters.single.range.end == 2 &&
          sceneCfiRoundTrips(input, scene) &&
          conservation['pass'] == true;
      final projected = (reference['projectedTexts'] as List)
          .cast<Map<String, Object?>>();
      final referenceMapped =
          projected.length == 1 &&
          projected.single['text'] == runs.single['text'] &&
          (projected.single['cfis'] as List).length == 3;
      final png = (await native.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      File('$output/$id.png').writeAsBytesSync(png);
      return {
        'id': id,
        'fallbackCharacters': fixture['fallbackCharacters'],
        'nativePaintedAlphaPixels': nativeAlpha,
        'referencePaintedAlphaPixels': referenceAlpha,
        'sourceMapped': sourceMapped,
        'referenceSourceMapped': referenceMapped,
        'textConservation': conservation,
        'textRasterParity': textRasterParityStatus,
        'hostConservationPass':
            nativeAlpha > 0 &&
            referenceAlpha > 0 &&
            sourceMapped &&
            referenceMapped,
        'geometry': {'status': 'device-gated (A5)', 'pass': false},
        'pixels': {'status': 'device-gated (A5)', 'pass': false},
        'referenceDefects': _defects.unmeasured(
          'Platform fallback raster is device-gated',
        ),
        'fidelityGate': false,
      };
    } finally {
      native.dispose();
      expected.dispose();
    }
  }

  Future<Map<String, Object?>> _measure(
    Map<String, Object?> fixture,
    Map<String, Object?> reference,
    SceneHarnessInput input,
    FixedScene scene,
  ) async {
    final id = fixture['id'] as String,
        required = fixture['variant'] != 'unsupported';
    final capability = {
      'kind': scene.capability.runtimeType.toString(),
      'complete': scene.capability.isComplete,
      'reason': scene.capability.reason,
      'constructs': [
        for (final c in scene.capability.constructs)
          {
            'kind': c.kind.name,
            'identifier': c.identifier,
            'nodeIndex': c.nodeIndex,
          },
      ],
    };
    final native = await scene.picture.toImage(320, 240);
    ui.Image? expected;
    try {
      final rgba = (await native.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!.buffer.asUint8List();
      final png = (await native.toByteData(format: ui.ImageByteFormat.png))!
          .buffer
          .asUint8List();
      File('$output/$id.png').writeAsBytesSync(png);
      final textConservation = measureSceneTextConservation(input, scene);
      final textMask = textConservation['applicable'] == true
          ? buildD8TextMask(
              nativeGlyphCoverage: collectSceneTextCoverage(scene),
              referenceGeometryLtrb: referenceSceneTextBoxes(reference),
              provenance: {
                'native': 'native text-only alpha footprints retained by FixedScene geometry',
                'reference':
                    'oracle texts[].clusters[].boxes (viewport CSS px)',
              },
            )
          : null;
      final samples = <Map<String, Object?>>[],
          geometry = measureSceneGeometry(input, scene, reference);
      var maximumSampleDelta = 0;
      for (final raw in reference['samples'] as List) {
        final sample = raw as Map<String, Object?>,
            xy = [sample['x'] as int, sample['y'] as int];
        final actual = rgba.sublist(
              (xy[1] * 320 + xy[0]) * 4,
              (xy[1] * 320 + xy[0]) * 4 + 4,
            ),
            wanted = (sample['rgba'] as List).cast<int>();
        final delta = List.generate(
          4,
          (i) => (actual[i] - wanted[i]).abs(),
        ).reduce(math.max);
        maximumSampleDelta = math.max(maximumSampleDelta, delta);
        samples.add({
          'point': xy,
          'native': actual,
          'reference': wanted,
          'maximumChannelDelta': delta,
        });
      }
      Map<String, Object?> pixels = {'status': 'unverified', 'pass': false};
      var decisions = _defects.unmeasured('Own reference PNG unavailable');
      if (reference['pngBase64'] != null) {
        final codec = await ui.instantiateImageCodec(
          base64Decode(reference['pngBase64'] as String),
        );
        try {
          expected = (await codec.getNextFrame()).image;
        } finally {
          codec.dispose();
        }
        final expectedRgba = (await expected.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!.buffer.asUint8List();
        final scope = _defects.scope(fixture, reference, rgba, expectedRgba);
        decisions = scope.$2;
        pixels = compareSpikePixels(
          rgba,
          expectedRgba,
          exemptScope: scope.$1,
          maximumSampleDelta: maximumSampleDelta,
          textMask: textMask,
        );
      }
      final complete = scene.geometry.completeness is CompleteGeometry;
      final cfi = sceneCfiRoundTrips(input, scene);
      final reasons = [
        if (!scene.capability.isComplete) scene.capability.reason,
        if (!cfi) 'Source CFI round-trip failed',
        if (geometry['pass'] != true) 'Geometry channel failed or unverified',
        if (pixels['pass'] != true) 'D4 pixel gate failed or unverified',
        if (maximumSampleDelta != 0) 'Exact sample mismatch',
        if (!complete) 'Source visibility geometry incomplete',
        if (textConservation['pass'] != true)
          'Text cluster/grapheme conservation failed',
      ];
      return {
        'id': id,
        'row': fixture['row'],
        'required': required,
        'capability': capability,
        'unsupportedVerdict': required ? null : !scene.capability.isComplete,
        'geometry': geometry,
        'samples': samples,
        'maximumSampleChannelDelta': maximumSampleDelta,
        'pixels': pixels,
        'textConservation': textConservation,
        'textRasterParity': textConservation['applicable'] == true
            ? textRasterParityStatus
            : null,
        'referenceDefects': decisions,
        'referencePaintStability': reference['paintStability'],
        'sourceGeometryComplete': complete,
        'geometryIssues': scene.geometry.completeness is IncompleteGeometry
            ? (scene.geometry.completeness as IncompleteGeometry).issues
                  .map((i) => {'kind': i.kind.name, 'reason': i.reason})
                  .toList()
            : [],
        'sourceFragments': exportSceneFragments(scene),
        'fidelityGate': required && reasons.isEmpty,
        'reasons': reasons,
        'nativePNG_SHA256': sha256.convert(png).toString(),
      };
    } finally {
      native.dispose();
      expected?.dispose();
    }
  }
}
