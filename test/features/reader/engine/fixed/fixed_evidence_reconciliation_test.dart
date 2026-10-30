import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';

import '../../contract_test_values.dart';
import '../style/style_test_support.dart';

const _vector = SceneResource.vectorBytes;
const _overhead = GeometryAlphaFootprint.storageOverhead;

final class _Resources implements ReaderResourceSource {
  _Resources(this.font);
  final Uint8List font;
  @override
  Uint8List? bytes(String path) => font;
  @override
  bool contains(String path) => true;
  @override
  int size(String path) => font.length;
  @override
  void dispose() {}
}

/// Independent oracle: every footprint reachable from the geometry, once by
/// identity, with the bytes it reports for itself.
({int count, int bytes}) _stored(Iterable<SourceGeometry> geometries) {
  final seen = HashSet<GeometryAlphaFootprint>.identity();
  var bytes = 0;
  void add(GeometryAlphaFootprint f) {
    if (seen.add(f)) bytes += f.storageBytes;
  }

  for (final geometry in geometries) {
    for (final paint in geometry.paint) {
      final footprint = paint.alphaFootprint;
      if (footprint == null) continue;
      add(footprint);
      for (final mask in footprint.masks) {
        add(mask.coverage);
      }
    }
  }
  return (count: seen.length, bytes: bytes);
}

/// One fixed preparation against a shared unit ledger with samples of that
/// ledger and of the scene's local sub-ledger taken between its awaits.
final class _Run {
  _Run(this.font, this.body);
  final Uint8List font;
  final String body;
  late FixedPreparationPlan plan;
  late SceneResourceBudget shared, local;
  late SceneResourceLease lease;
  late FixedSceneAdmission admission;
  late int vectorBefore;
  final sharedSamples = <int>[], localSamples = <int>[];
  var released = false;
  int? sharedAtPicture, localAtPicture;

  FixedSourceLease _source() {
    final sample = StyleSample.html(
      body,
      css:
          '@font-face{font-family:Fixture;src:url(font.ttf)}'
          'body{margin:0;font:20px Fixture}',
      head: '<meta name="viewport" content="width=320,height=240"/>',
      files: {'font.ttf': font},
      metadata: '<meta property="rendition:layout">pre-paginated</meta>',
    );
    addTearDown(sample.book.archive.close);
    return FixedSourceLease(
      page: contractPage(),
      document: sample.document,
      styles: sample.styled,
      rendition: sectionRendition(sample.book, 0),
      resources: _Resources(Uint8List.fromList(font)),
      retainedSourceBytes: 1024,
      releaseSource: () {},
    );
  }

  Future<PreparedFixedScene> prepare({
    bool reconcilePicture = true,
    PublicationCancellation? cancellation,
    void Function()? onFirstSample,
  }) async {
    final registry = FontRegistry(processBudget: ProcessFontBudget());
    var preparer = FixedSectionPreparer(
      fonts: registry,
      drainFonts: () async {},
    );
    final source = _source();
    plan = preparer.plan(source);
    expect(plan.capability.isComplete, true, reason: plan.capability.reason);
    shared = SceneResourceBudget();
    // The scene's sub-ledger is limited by what the unit reserved; it records
    // the footprint bytes as they are allocated.
    local = SceneResourceBudget(
      limits: {
        for (final r in SceneResource.values)
          r: (plan.resources[r] ?? 0) > 0 ? plan.resources[r]! : 1,
      },
      sourceDepthLimit: plan.sourceDepth,
      referenceDepthLimit: plan.referenceDepth < 1 ? 1 : plan.referenceDepth,
      layerDepthLimit: plan.layerDepth,
    );
    preparer = FixedSectionPreparer(
      fonts: registry,
      drainFonts: () async {},
      sceneBudget: local,
    );
    lease = shared.reserveUnit(
      sourcePages: 1,
      resources: plan.resources,
      sourceDepth: plan.sourceDepth,
      referenceDepth: plan.referenceDepth,
      layerDepth: plan.layerDepth,
    );
    addTearDown(() {
      if (!lease.isReleased) lease.release();
    });
    vectorBefore = shared.used[_vector]!;
    admission = FixedSceneAdmission(
      plan: plan,
      sceneLease: lease,
      pictureBytes: plan.pictureBytes,
      decodedImageBytes: plan.decodedImageBytes,
      reconcilePictureBytes: (_) {
        // The last allocation-bearing moment: every footprint exists, the
        // shared ledger has not moved yet.
        sharedAtPicture = shared.used[_vector];
        localAtPicture = local.used[_vector];
        return reconcilePicture;
      },
      releaseReservations: () {
        released = true;
        lease.release();
      },
    );
    final operation = preparer.prepare(
      plan,
      admission,
      cancellation: cancellation,
    );
    var sampling = true;
    final timer = Timer.periodic(const Duration(microseconds: 50), (_) {
      if (!sampling) return;
      sharedSamples.add(shared.used[_vector] ?? 0);
      localSamples.add(local.used[_vector] ?? 0);
      if (sharedSamples.length == 1) onFirstSample?.call();
    });
    try {
      final result = await operation.result;
      sampling = false;
      return result;
    } finally {
      sampling = false;
      timer.cancel();
      await operation.drained;
    }
  }

  /// The reservation never leaves the safe upper bound while work runs, and
  /// always covers the footprint bytes the scene sub-ledger holds live.
  void expectNeverBelowLive() {
    expect(
      sharedSamples.every((s) => s == vectorBefore),
      true,
      reason: 'charge held at the planned bound until publication',
    );
    for (var i = 0; i < sharedSamples.length; i++) {
      expect(sharedSamples[i], greaterThanOrEqualTo(localSamples[i]));
    }
    expect(sharedAtPicture, vectorBefore);
    expect(sharedAtPicture, greaterThanOrEqualTo(localAtPicture!));
  }
}

GeometryPaint _paint(int ordinal, GeometryAlphaFootprint? footprint) =>
    GeometryPaint(
      nodeIndex: 0,
      paintOrdinal: ordinal,
      region: GeometryRegion(
        left: 0,
        top: 0,
        width: 4,
        height: 4,
        transform: const AffineTransform.identity(),
      ),
      kind: GeometryPaintKind.solid,
      effectiveOpacity: 1,
      exactCoverage: true,
      alphaFootprint: footprint,
    );

GeometryAlphaFootprint _uniform([List<GeometryMask> masks = const []]) =>
    GeometryAlphaFootprint.uniform(
      width: 3,
      height: 3,
      pixelSize: 1,
      origin: GeometryPoint(0, 0),
      alpha: 255,
      masks: masks,
    );

GeometryAlphaFootprint _grid(int width, int height) => GeometryAlphaFootprint(
  width: width,
  height: height,
  pixelSize: 1,
  origin: GeometryPoint(0, 0),
  alpha: [for (var i = 0; i < width * height; i++) i % 2 == 0 ? 255 : 7],
);

GeometryMask _mask(String id, GeometryAlphaFootprint coverage) => GeometryMask(
  id: id,
  sourceNode: 1,
  units: GeometryMaskUnits.userSpaceOnUse,
  contentUnits: GeometryMaskUnits.userSpaceOnUse,
  kind: GeometryMaskKind.alpha,
  region: GeometryRegion(
    left: 0,
    top: 0,
    width: 4,
    height: 4,
    transform: const AffineTransform.identity(),
  ),
  coverage: coverage,
);

SourceGeometry _geometry(List<GeometryPaint> paint) => SourceGeometry(
  version: 1,
  fragments: const [],
  completeness: IncompleteGeometry([
    GeometryIssue(GeometryGapKind.paint, 'synthetic'),
  ]),
  paint: paint,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = File('tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf')
      .readAsBytesSync();

  group('measurement', () {
    test('uniform footprints cost their 128 byte record only', () {
      final geometry = _geometry([
        for (var i = 0; i < 4; i++) _paint(i, _uniform()),
        _paint(9, null),
      ]);
      final measured = RetainedEvidence.measure([geometry], placed: geometry);
      expect(measured.footprints, 4);
      expect(measured.storageBytes, 4 * _overhead);
      expect(measured.wrappers, 4);
      expect(measured.chargedBytes, 8 * _overhead);
    });

    test('a trimmed grid costs its real size and nothing for the page', () {
      final geometry = _geometry([
        _paint(0, _grid(7, 5)),
        _paint(1, _grid(2, 2)),
      ]);
      final measured = RetainedEvidence.measure([geometry], placed: geometry);
      expect(measured.storageBytes, _overhead + 35 + _overhead + 4);
      expect(
        measured.storageBytes,
        (_grid(7, 5).storageBytes + _grid(2, 2).storageBytes),
      );
    });

    test('shared footprints and mask coverage count once; applications place per paint', () {
      final shared = _uniform();
      final coverage = _grid(5, 5);
      final mask = _mask('m', coverage);
      final masked = _uniform([mask]);
      final geometry = _geometry([
        _paint(0, shared),
        _paint(1, shared),
        _paint(2, masked),
        _paint(3, _uniform([mask])),
      ]);
      // Four paints reference three distinct paint footprints plus one shared
      // coverage grid.
      final measured = RetainedEvidence.measure([geometry], placed: geometry);
      expect(measured.footprints, 4);
      expect(
        measured.storageBytes,
        shared.storageBytes +
            masked.storageBytes +
            geometry.paint[3].alphaFootprint!.storageBytes +
            coverage.storageBytes,
      );
      // Placement re-wraps each paint footprint and each mask application.
      expect(measured.wrappers, 1 + 1 + 2 + 2);
      final svgOnly = RetainedEvidence.measure([
        geometry,
        geometry,
      ], placed: _geometry([_paint(0, shared)]));
      expect(svgOnly.storageBytes, measured.storageBytes);
      expect(svgOnly.wrappers, 1);
    });
  });

  group('reconciliation', () {
    test(
      'foreignObject counts original, exported and unit-placement owners',
      () async {
        final run = _Run(
          font,
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
          '<foreignObject width="80" height="60">'
          '<div xmlns="http://www.w3.org/1999/xhtml" style="width:20px;height:10px;background:red"/>'
          '</foreignObject></svg>',
        );
        final result = await run.prepare();
        addTearDown(result.dispose);
        expect(result.geometry.paint, hasLength(1));
        expect(result.retainedEvidence.footprints, 2);
        expect(result.retainedEvidence.storageBytes, 256);
        expect(result.retainedEvidence.chargedBytes, 384);
        final released = run.plan.retainedEvidenceBytes - 384;
        expect(run.shared.used[_vector], run.vectorBefore - released);
      },
    );

    final bodies = <String, String>{
      'uniform XHTML decoration':
          '<div style="width:100px;height:50px;background:#336699"></div>',
      'trimmed XHTML text grid': '<div>Ab</div>',
      'XHTML opacity and text': '<div style="opacity:.7;background:red;width:80px;height:60px">Ab</div>',
      'SVG fill and stroke roles':
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
          '<path d="M3 4H70V50H3Z" fill="red" stroke="blue" stroke-width="3" opacity=".7"/>'
          '</svg>',
      'SVG clip':
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
          '<defs><clipPath id="c"><circle cx="40" cy="30" r="28"/></clipPath></defs>'
          '<rect width="80" height="60" fill="red" clip-path="url(#c)"/></svg>',
      'SVG mask and pattern':
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
          '<defs><mask id="m" mask-type="luminance"><circle cx="40" cy="30" r="27" fill="white"/></mask>'
          '<pattern id="p" width="10" height="10" patternUnits="userSpaceOnUse">'
          '<rect width="5" height="10" fill="red"/></pattern></defs>'
          '<rect x="4" y="4" width="70" height="50" fill="url(#p)" stroke="blue" '
          'stroke-dasharray="4 3" mask="url(#m)" opacity=".8"/></svg>',
      'SVG filtered output':
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
          '<defs><filter id="f"><feGaussianBlur stdDeviation="1"/></filter></defs>'
          '<rect x="10" y="10" width="50" height="30" fill="red" filter="url(#f)"/></svg>',
      'SVG text':
          '<svg xmlns="http://www.w3.org/2000/svg" width="120" height="60">'
          '<text x="4" y="30" font-size="20">Ab</text></svg>',
      'foreignObject':
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
          '<foreignObject width="80" height="60"><div xmlns="http://www.w3.org/1999/xhtml" '
          'style="background:red;opacity:.8">Ab</div></foreignObject></svg>',
    };
    for (final entry in bodies.entries) {
      test(
        '${entry.key}: charge equals the stored bytes; ledger exact',
        () async {
          final run = _Run(font, entry.value);
          final scene = await run.prepare();
          final evidence = scene.retainedEvidence;
          final oracle = _stored([
            scene.scene.geometry,
            for (final svg in scene.scene.svgScenes) svg.geometry,
            ...scene.scene.retainedHostGeometries,
          ]);
          expect(evidence.footprints, oracle.count);
          expect(evidence.footprints, greaterThan(0));
          expect(evidence.storageBytes, oracle.bytes);
          // Every footprint is either a uniform record or a trimmed grid whose
          // size is what it stores; none is the page-sized safe bound.
          for (final geometry in [
            scene.scene.geometry,
            ...scene.scene.svgScenes.map((s) => s.geometry),
          ]) {
            for (final paint in geometry.paint) {
              final f = paint.alphaFootprint;
              if (f == null) continue;
              expect(
                f.storageBytes,
                _overhead + (f.uniformAlpha == null ? f.alpha.length : 0),
              );
            }
          }
          final placedWrappers = scene.scene.geometry.paint.fold<int>(
            0,
            (n, p) =>
                n +
                (p.alphaFootprint == null
                    ? 0
                    : 1 + p.alphaFootprint!.masks.length),
          );
          expect(evidence.wrappers, placedWrappers);
          expect(
            evidence.chargedBytes,
            oracle.bytes + placedWrappers * _overhead,
          );
          // The plan's bound was the safe predecode figure; exactly the excess
          // left the shared ledger, nothing else changed.
          expect(
            run.plan.retainedEvidenceBytes,
            lessThanOrEqualTo(run.vectorBefore),
          );
          expect(
            evidence.chargedBytes,
            lessThan(run.plan.retainedEvidenceBytes),
          );
          final released =
              run.plan.retainedEvidenceBytes - evidence.chargedBytes;
          expect(scene.evidenceReleased, released);
          expect(run.shared.used[_vector], run.vectorBefore - released);
          expect(run.lease.charge[_vector], run.vectorBefore - released);
          // Still covers everything the scene holds as footprints.
          expect(
            run.shared.used[_vector],
            greaterThanOrEqualTo(evidence.chargedBytes),
          );
          expect(
            run.vectorBefore - released - evidence.chargedBytes,
            run.vectorBefore - run.plan.retainedEvidenceBytes,
            reason: 'only the evidence share of the reservation changed',
          );
          run.expectNeverBelowLive();
          // At the last allocating moment the sub-ledger held at least the
          // footprints, and the shared charge was still the full bound.
          expect(
            run.localAtPicture,
            greaterThanOrEqualTo(
              _stored([
                scene.scene.geometry,
                for (final svg in scene.scene.svgScenes) svg.geometry,
              ]).bytes,
            ),
          );
          // Every other class of the unit reservation is untouched.
          for (final r in SceneResource.values) {
            if (r == _vector ||
                r == SceneResource.readingUnits ||
                r == SceneResource.sourcePages) {
              continue;
            }
            expect(
              run.lease.charge[r] ?? 0,
              run.plan.resources[r] ?? 0,
              reason: r.name,
            );
          }
          scene.dispose();
          scene.dispose();
          expect(run.released, true);
          expect(run.shared.used.values.every((v) => v == 0), true);
          expect(run.lease.isReleased, true);
        },
      );
    }

    test(
      'uniform page: 128 bytes per footprint, trimmed text: its grid',
      () async {
        final uniform = _Run(
          font,
          '<div style="width:100px;height:50px;background:#336699"></div>',
        );
        final a = await uniform.prepare();
        final uniformFootprints = [
          for (final p in a.scene.geometry.paint)
            if (p.alphaFootprint != null) p.alphaFootprint!,
        ];
        expect(uniformFootprints, isNotEmpty);
        expect(uniformFootprints.every((f) => f.uniformAlpha != null), true);
        expect(a.retainedEvidence.storageBytes, uniformFootprints.length * 128);
        a.dispose();
        final text = _Run(font, '<div>Ab</div>');
        final b = await text.prepare();
        final grids = [
          for (final p in b.scene.geometry.paint)
            if (p.alphaFootprint?.uniformAlpha == null &&
                p.alphaFootprint != null)
              p.alphaFootprint!,
        ];
        expect(grids, isNotEmpty);
        for (final grid in grids) {
          expect(grid.alpha.length, lessThan(320 * 240));
          expect(grid.alpha.length, grid.width * grid.height);
        }
        b.dispose();
      },
    );

    test('per-role footprints are stored separately and all charged', () async {
      final run = _Run(
        font,
        '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
        '<path d="M3 4H70V50H3Z" fill="red" stroke="blue" stroke-width="3"/>'
        '</svg>',
      );
      final scene = await run.prepare();
      final roles = scene.scene.geometry.paint
          .where((p) => p.alphaFootprint != null)
          .map((p) => p.role)
          .toSet();
      expect(
        roles,
        containsAll([GeometryPaintRole.fill, GeometryPaintRole.stroke]),
      );
      final footprints = scene.scene.geometry.paint
          .where((p) => p.alphaFootprint != null)
          .map((p) => p.alphaFootprint!)
          .toList();
      expect(
        scene.retainedEvidence.storageBytes,
        footprints.fold<int>(0, (n, f) => n + f.storageBytes),
      );
      scene.dispose();
    });

    test('a masked paint charges its mask coverage as well', () async {
      final run = _Run(
        font,
        '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
        '<defs><mask id="m" mask-type="alpha"><rect width="40" height="60" fill="white"/></mask></defs>'
        '<rect width="80" height="60" fill="red" mask="url(#m)"/></svg>',
      );
      final scene = await run.prepare();
      final withMasks = scene.scene.geometry.paint
          .where((p) => (p.alphaFootprint?.masks ?? const []).isNotEmpty)
          .toList();
      expect(withMasks, isNotEmpty);
      final coverage = withMasks.first.alphaFootprint!.masks.first.coverage;
      expect(
        scene.retainedEvidence.storageBytes,
        greaterThanOrEqualTo(
          withMasks.first.alphaFootprint!.storageBytes + coverage.storageBytes,
        ),
      );
      expect(
        scene.retainedEvidence.wrappers,
        greaterThan(scene.retainedEvidence.footprints - 1),
      );
      scene.dispose();
    });

    test('the filter output payload is part of the evidence bound', () async {
      String svg(String attribute) =>
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
          '<defs><filter id="f"><feGaussianBlur stdDeviation="1"/></filter></defs>'
          '<rect x="10" y="10" width="50" height="30" fill="red" $attribute/></svg>';
      final plain = _Run(font, svg(''));
      final filtered = _Run(font, svg('filter="url(#f)"'));
      final a = await plain.prepare(), b = await filtered.prepare();
      // One filter use admits its retained output (overhead + 2 x viewport).
      expect(
        filtered.plan.retainedEvidenceBytes - plain.plan.retainedEvidenceBytes,
        _overhead + 2 * 80 * 60,
      );
      expect(
        b.retainedEvidence.chargedBytes,
        lessThan(filtered.plan.retainedEvidenceBytes),
      );
      a.dispose();
      b.dispose();
    });

    test('a second reconciliation or placement is a defect', () async {
      final run = _Run(font, '<div>Ab</div>');
      final scene = await run.prepare();
      final charge = run.lease.charge[_vector];
      expect(
        () => run.admission.reconcileEvidence(scene.retainedEvidence),
        throwsStateError,
      );
      expect(run.lease.charge[_vector], charge);
      scene.geometryForUnit(
        const AffineTransform.identity(),
        registryPrefix: 'a',
      );
      expect(
        () => scene.geometryForUnit(
          const AffineTransform.identity(),
          registryPrefix: 'b',
        ),
        throwsStateError,
      );
      scene.dispose();
      expect(run.shared.used.values.every((v) => v == 0), true);
      expect(
        () => run.admission.reconcileEvidence(scene.retainedEvidence),
        throwsStateError,
      );
    });

    test('stored bytes at or above the bound release nothing', () {
      // A plan whose bound is smaller than a synthetic scene's footprints.
      final small = _Run(
        font,
        '<div style="width:10px;height:10px;background:red"></div>',
      );
      final registry = FontRegistry(processBudget: ProcessFontBudget());
      final preparer = FixedSectionPreparer(
        fonts: registry,
        drainFonts: () async {},
      );
      final plan = preparer.plan(small._source());
      final budget = SceneResourceBudget();
      final lease = budget.reserveUnit(
        sourcePages: 1,
        resources: plan.resources,
        sourceDepth: plan.sourceDepth,
        referenceDepth: plan.referenceDepth,
        layerDepth: plan.layerDepth,
      );
      final admission = FixedSceneAdmission(
        plan: plan,
        sceneLease: lease,
        pictureBytes: plan.pictureBytes,
        decodedImageBytes: plan.decodedImageBytes,
        reconcilePictureBytes: (_) => true,
        releaseReservations: lease.release,
      );
      admission.consume(plan);
      final before = budget.used[_vector];
      final huge = _geometry([
        for (var i = 0; i < plan.retainedEvidenceBytes ~/ 64 + 1; i++)
          _paint(i, _uniform()),
      ]);
      final measured = RetainedEvidence.measure([huge], placed: huge);
      expect(measured.chargedBytes, greaterThan(plan.retainedEvidenceBytes));
      expect(admission.reconcileEvidence(measured), 0);
      expect(budget.used[_vector], before);
      expect(lease.charge[_vector], before);
      expect(admission.evidenceReleased, 0);
      admission.dispose();
      expect(budget.used.values.every((v) => v == 0), true);
    });

    test('a shared spread lease shrinks per page and releases once', () {
      final registry = FontRegistry(processBudget: ProcessFontBudget());
      final preparer = FixedSectionPreparer(
        fonts: registry,
        drainFonts: () async {},
      );
      final run = _Run(
        font,
        '<div style="width:10px;height:10px;background:red"></div>',
      );
      final plans = [
        preparer.plan(run._source()),
        preparer.plan(run._source()),
      ];
      final budget = SceneResourceBudget();
      final total = <SceneResource, int>{};
      for (final p in plans) {
        for (final e in p.resources.entries) {
          total.update(e.key, (n) => n + e.value, ifAbsent: () => e.value);
        }
      }
      final lease = budget.reserveUnit(sourcePages: 2, resources: total);
      var parts = 2;
      final admissions = [
        for (final p in plans)
          FixedSceneAdmission(
            plan: p,
            sceneLease: lease,
            pictureBytes: p.pictureBytes,
            decodedImageBytes: p.decodedImageBytes,
            reconcilePictureBytes: (_) => true,
            releaseReservations: () {
              if (--parts == 0) lease.release();
            },
          ),
      ];
      final start = budget.used[_vector]!;
      var expected = start;
      for (var i = 0; i < 2; i++) {
        admissions[i].consume(plans[i]);
        final geometry = _geometry([_paint(0, _uniform())]);
        final measured = RetainedEvidence.measure([geometry], placed: geometry);
        final released = admissions[i].reconcileEvidence(measured);
        expect(
          released,
          plans[i].retainedEvidenceBytes - measured.chargedBytes,
        );
        expected -= released;
        expect(budget.used[_vector], expected);
      }
      admissions[0].dispose();
      expect(budget.used[_vector], expected);
      admissions[1].dispose();
      expect(budget.used.values.every((v) => v == 0), true);
    });

    test(
      'failure before publication keeps the full charge until one release',
      () async {
        final run = _Run(font, '<div>Ab</div>');
        await expectLater(
          run.prepare(reconcilePicture: false),
          throwsA(isA<SceneAdmissionException>()),
        );
        expect(run.admission.evidence, isNull);
        expect(run.admission.evidenceReleased, 0);
        expect(run.sharedSamples.every((s) => s == run.vectorBefore), true);
        expect(run.released, true);
        expect(run.lease.isReleased, true);
        expect(run.shared.used.values.every((v) => v == 0), true);
        expect(run.shared.peaks[_vector], run.vectorBefore);
      },
    );

    test('cancellation keeps the full charge until one release', () async {
      final cancellation = PublicationCancellation();
      final run = _Run(font, '<div>Ab</div>');
      await expectLater(
        run.prepare(
          cancellation: cancellation,
          onFirstSample: cancellation.cancel,
        ),
        throwsA(isA<PreparationCancelled>()),
      );
      expect(run.admission.evidence, isNull);
      expect(run.admission.evidenceReleased, 0);
      expect(run.sharedSamples.every((s) => s == run.vectorBefore), true);
      expect(run.shared.used.values.every((v) => v == 0), true);
    });

    test('a canceled token before reconciliation never shrinks', () async {
      final cancellation = PublicationCancellation()..cancel();
      final run = _Run(font, '<div>Ab</div>');
      await expectLater(
        run.prepare(cancellation: cancellation),
        throwsA(isA<PreparationCancelled>()),
      );
      expect(run.admission.evidence, isNull);
      expect(run.shared.used.values.every((v) => v == 0), true);
    });
  });
}
