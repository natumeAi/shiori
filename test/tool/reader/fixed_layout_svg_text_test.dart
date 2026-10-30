import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/source_fragment.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/style/css_style_resolver.dart';
import 'package:shiori/features/reader/engine/style/reader_settings.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';

import '../../../tool/reader/fixed_layout_scene_input.dart';
import '../../../tool/reader/fixed_layout_svg_text_harness.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'text gate rejects translated scaled and rotated source mappings',
    () async {
      const folder = 'test/fixtures/reader/fixed_layout';
      final corpus = jsonDecode(
        File('$folder/corpus.json').readAsStringSync(),
      ) as Map<String, Object?>;
      final fixture = (corpus['cases'] as List)
          .cast<Map<String, Object?>>()
          .singleWhere((c) => c['id'] == 'svg-text-positive');
      final oracle =
          jsonDecode(File('$folder/oracle.json').readAsStringSync()) as Map;
      final reference = (oracle['cases'] as List)
          .cast<Map<String, Object?>>()
          .singleWhere((c) => c['id'] == fixture['id']);
      final input = SceneHarnessInput(
        fixture,
        corpus,
        File((corpus['font'] as Map)['path'] as String).readAsBytesSync(),
      );
      final fonts = FontRegistry(processBudget: ProcessFontBudget());
      final source = FixedSourceLease(
        page: input.page,
        document: input.document,
        styles: const CssStyleResolver().resolve(
          input.book,
          0,
          input.document,
          const ReaderSettings(),
          authoredViewport: AuthoredPageSize(320, 240),
        ),
        rendition: sectionRendition(input.book, 0),
        resources: ArchiveReaderResourceSource(input.book.archive),
        retainedSourceBytes: utf8.encode(fixture['source'] as String).length,
        releaseSource: () {},
      );
      final preparer = FixedSectionPreparer(
        fonts: fonts,
        drainFonts: fonts.drainFonts,
      );
      final plan = preparer.plan(source), budget = SceneResourceBudget();
      final lease = budget.reserveUnit(
        sourcePages: 1,
        resources: plan.resources,
        sourceDepth: plan.sourceDepth,
        referenceDepth: plan.referenceDepth,
        layerDepth: plan.layerDepth,
      );
      final operation = preparer.prepare(
        plan,
        FixedSceneAdmission(
          plan: plan,
          sceneLease: lease,
          pictureBytes: plan.pictureBytes,
          decodedImageBytes: plan.decodedImageBytes,
          reconcilePictureBytes: (_) => true,
          releaseReservations: lease.release,
        ),
      );
      PreparedFixedScene? scene;
      try {
        scene = await operation.result;
        final original = measureSvgTextGeometry(scene, reference);
        expect(original['pass'], true);
        expect(original['comparisons'], 12);
        final falsifications = <String, Map<String, Object?>>{};
        for (final (name, displacement) in [
          ('translated', AffineTransform(1, 0, 0, 1, 100, 0)),
          ('scaled', AffineTransform(2, 0, 0, 2, 0, 0)),
          ('rotated', AffineTransform(0, 1, -1, 0, 0, 0)),
        ]) {
          final geometry = scene.geometry;
          final displaced = SourceGeometry(
            version: geometry.version,
            completeness: geometry.completeness,
            clips: geometry.clips,
            paint: geometry.paint,
            opacityGroups: geometry.opacityGroups,
            fragments: [
              for (final f in geometry.fragments)
                SourceFragment(
                  page: f.page,
                  nodeIndex: f.nodeIndex,
                  kind: f.kind,
                  textRange: f.textRange,
                  clusters: f.clusters,
                  elementAnchor: f.elementAnchor,
                  sourceToUnit: displacement.compose(f.sourceToUnit),
                  clipIds: f.clipIds,
                  maskIds: f.maskIds,
                  paintOrdinal: f.paintOrdinal,
                  effectiveOpacity: f.effectiveOpacity,
                  elementQuad: f.elementQuad,
                ),
            ],
          );
          final measured = measureSvgTextSourceGeometry(
            displaced,
            input.document,
            reference,
          );
          expect(measured['clusterConservation'], true, reason: name);
          expect(measured['comparisons'], 12, reason: name);
          falsifications[name] = measured;
        }
        expect(
          falsifications.values.every(
            (m) => (m['maximumCssPx'] as num) > .5 && m['pass'] == false,
          ),
          true,
          reason: jsonEncode(falsifications),
        );
        final missingScreen = Map<String, Object?>.of(reference)
          ..remove('elements');
        final missing = measureSvgTextSourceGeometry(
          scene.geometry,
          input.document,
          missingScreen,
        );
        expect(missing['clusterConservation'], true);
        expect(missing['screenEvidence'], false);
        expect(missing['pass'], false);
      } finally {
        await operation.drained;
        scene?.dispose();
        source.dispose();
        input.book.archive.close();
        expect(budget.used.values.every((v) => v == 0), true);
      }
    },
  );
  test(
    'SVG text production row separates host evidence from A5 raster parity',
    () async {
      final report = await FixedLayoutSvgTextHarness().run();
      // ignore: avoid_print
      print(
        jsonEncode({
          'hostGate': report['hostGate'],
          'verdict': report['verdict'],
          'cases': [
            for (final c in (report['cases'] as List).cast<Map>())
              {
                'id': c['id'],
                'hostGate': c['hostGate'],
                'geometry': c['geometry'],
                'constructs': c['constructs'],
                'error': c['error'],
              },
          ],
        }),
      );
      expect(report['geometryToleranceCssPx'], .5);
      expect(report['textRasterParity'], 'device-gated (A5)');
      final cases = (report['cases'] as List).cast<Map>();
      expect(cases, hasLength(10));
      for (final c in cases) {
        expect(c['resourcesReleased'], true, reason: '${c['id']}');
        expect(c['hostGate'], true, reason: '${c['id']}: $c');
      }
      expect(report['hostGate'], true);
      expect(report['verdict'], 'device-gated (A5)');
    },
  );
}
