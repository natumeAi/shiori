import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/cfi/cfi.dart';
import 'package:shiori/features/reader/data/source/source_position.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/resources/archive_reader_resource_source.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/image_cache.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';

import '../../contract_test_values.dart';
import '../style/style_test_support.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('contain fit: portrait, landscape, spread, DPR and intrinsic clamp', () {
    for (final dpr in [1.0, 2.0, 3.0]) {
      for (final size in [(800.0, 1200.0), (1200.0, 800.0), (1600.0, 1200.0)]) {
        final scale = FixedPreparationScale.fit(
          authoredWidth: size.$1,
          authoredHeight: size.$2,
          viewWidth: 400,
          viewHeight: 600,
          devicePixelRatio: dpr,
        );
        final expected =
            (size.$1 == 800
                ? .5
                : size.$1 == 1200
                ? 1 / 3
                : .25) *
            dpr;
        expect(scale.value, closeTo(expected, 1e-12));
        final target = scale.imageTarget(800, 1200);
        expect(target.width, lessThanOrEqualTo(800));
        expect(target.height, lessThanOrEqualTo(1200));
      }
    }
    expect(FixedPreparationScale(3).imageTarget(17, 13), (
      width: 17,
      height: 13,
    ));
    expect(FixedPreparationScale(.25).imageTarget(17, 13), (
      width: 5,
      height: 4,
    ));
    for (final value in [0.0, -1.0, double.nan, double.infinity]) {
      expect(() => FixedPreparationScale(value), throwsArgumentError);
    }
  });

  for (final sizing in [
    ('width:40px;height:30px', const ui.Size(40, 30)),
    ('width:40px;height:auto', const ui.Size(40, 30)),
    ('width:auto;height:30px', const ui.Size(40, 30)),
    ('max-height:30px', const ui.Size(40, 30)),
    ('', const ui.Size(80, 60)),
  ]) {
    test(
      'inline img preserves replaced source and pixels: ${sizing.$1}',
      () async {
        final run = _Run(
          '<p style="margin:0">A<span><img id="photo" src="tile" '
          'style="${sizing.$1}"/></span>B</p>',
          png: await _png(true),
        );
        final result = await run.prepare();
        addTearDown(result.dispose);
        final node = run.sample.byId('photo');
        final paints = result.geometry.paint
            .where((p) => p.nodeIndex == node)
            .toList();
        expect(paints, hasLength(1));
        expect(paints.single.kind, GeometryPaintKind.image);
        expect(
          result.geometry.fragments.where((f) => f.nodeIndex == node),
          isNotEmpty,
        );
        final box = result.scene.boxes.singleWhere((b) => b.nodeIndex == node);
        expect(box.contentBox.size, sizing.$2);
        expect(box.contentBox.left, greaterThan(0));
        final image = await result.scene.picture.toImage(320, 240);
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        final r = box.contentBox;
        expect(
          bytes.getUint8(
            ((r.top + 2).floor() * 320 + (r.left + 2).floor()) * 4 + 3,
          ),
          255,
        );
        image.dispose();
      },
    );
  }

  test(
    'intrinsic alpha lease ends before post-evidence reconciliation',
    () async {
      final run = _Run(
        '<div id="bg" style="width:80px;height:60px;background-image:url(tile.png)"/>',
        png: await _png(false),
        background: true,
        scale: .25,
      );
      final result = await run.prepare();
      expect(run.bytesAtAcquisition, [
        80 * 60 * 4 + 20 * 15 * 4,
        80 * 60 * 4 + 20 * 15 * 4,
      ]);
      expect(run.bytesAtPicture, 20 * 15 * 4);
      expect(run.releasesAtPicture, 1);
      expect(run.cache.totalBytes, 20 * 15 * 4);
      result.dispose();
      run.expectDrained();
    },
  );

  test(
    'an inline image without an admitted resource refuses before publication',
    () async {
      final run = _Run('<p>A<span><img src="missing"/></span>B</p>');
      await expectLater(
        run.prepare(),
        throwsA(
          isA<FixedPreparationFailure>().having(
            (e) => e.capability.constructs.map((c) => c.identifier),
            'resource refusal',
            contains('missing-admitted-image'),
          ),
        ),
      );
      run.expectDrained();
    },
  );

  for (final opaque in [true, false]) {
    for (final background in [true, false]) {
      test(
        'exact ${opaque ? 'opaque' : 'alpha'} evidence, background=$background',
        () async {
          final png = await _png(opaque);
          final body = background
              ? '<div id="bg" style="width:80px;height:60px;background-image:url(tile.png)"></div>'
              : '<div>'
                    '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
                    '<defs><clipPath id="c"><circle cx="40" cy="30" r="28"/></clipPath></defs>'
                    '<image href="tile" width="80" height="60" clip-path="url(#c)"/>'
                    '</svg></div>';
          final whole = _Run(body, png: png, background: background);
          final small = _Run(
            body,
            png: png,
            background: background,
            scale: .25,
          );
          final a = await whole.prepare(), b = await small.prepare();
          expect(b.geometry, a.geometry);
          expect(small.targets, [(80, 60), (20, 15)]);
          expect(b.imageOpacity.values.single, opaque);
          expect(
            small.releases,
            1,
            reason: 'inspection/alpha decode released before publication',
          );
          expect(small.cache.totalBytes, 20 * 15 * 4);
          expect(small.cache.peakBytes, 80 * 60 * 8 + 20 * 15 * 4);
          a.dispose();
          b.dispose();
          b.dispose();
          whole.expectDrained();
          small.expectDrained();
        },
      );
    }
  }

  test(
    'alpha path refuses before image allocation when codec peak is too large',
    () async {
      final run = _Run(
        '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
        '<image href="tile" width="80" height="60"/></svg>',
        png: await _png(false),
        scale: .25,
        maxBytes: 80 * 60 * 8 + 20 * 15 * 4 - 1,
      );
      await expectLater(run.prepare(), throwsA(isA<ImageAdmissionException>()));
      expect(run.targets, [(80, 60)]);
      expect(run.decoded, isEmpty);
      run.expectDrained();
    },
  );

  test(
    'alpha pattern retains exact authored samples through clipped roles',
    () async {
      const body =
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
          '<defs><pattern id="p" width="80" height="60" patternUnits="userSpaceOnUse">'
          '<image href="tile" width="80" height="60"/></pattern>'
          '<clipPath id="c"><circle cx="40" cy="30" r="29"/></clipPath></defs>'
          '<rect width="80" height="60" fill="url(#p)" stroke="red" '
          'stroke-dasharray="4 3" clip-path="url(#c)"/></svg>';
      final png = await _png(false);
      final whole = _Run(body, png: png),
          small = _Run(body, png: png, scale: .25);
      final a = await whole.prepare(), b = await small.prepare();
      expect(b.geometry, a.geometry);
      expect(small.releases, 1);
      a.dispose();
      b.dispose();
      whole.expectDrained();
      small.expectDrained();
    },
  );

  test('filtered image inputs and DAG display stay authored', () async {
    const body =
        '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
        '<defs><filter id="f"><feColorMatrix type="matrix" '
        'values="0 0 0 0 1 0 0 0 0 1 0 0 0 0 1 1 0 0 0 0"/></filter></defs>'
        '<g filter="url(#f)"><image href="tile" width="80" height="60"/></g></svg>';
    final png = await _png(true);
    final whole = _Run(body, png: png),
        small = _Run(body, png: png, scale: .25);
    final a = await whole.prepare(), b = await small.prepare();
    expect(small.plan.authoredImagePaths, contains('tile'));
    expect(small.targets, [(80, 60)]);
    expect(b.geometry, a.geometry);
    expect(small.releases, 0);
    a.dispose();
    b.dispose();
    whole.expectDrained();
    small.expectDrained();
  });

  test(
    'opaque display cannot hide a fine authored alpha hole from evidence',
    () async {
      const body =
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
          '<image href="tile" width="80" height="60"/></svg>';
      final png = await _png(true, fineHole: true);
      final whole = _Run(body, png: png),
          small = _Run(body, png: png, scale: .0125);
      final a = await whole.prepare(), b = await small.prepare();
      expect(small.targets, [(80, 60), (1, 1)]);
      final display = (await small.decoded.last.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      expect(display.getUint8(3), 255);
      expect(b.imageOpacity.values.single, false);
      expect(b.geometry, a.geometry);
      a.dispose();
      b.dispose();
      whole.expectDrained();
      small.expectDrained();
    },
  );

  for (final cancel in [true, false]) {
    test(
      'scaled alpha late ${cancel ? 'cancellation' : 'failure'} releases each image',
      () async {
        final run = _Run(
          '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
          '<image href="tile" width="80" height="60"/></svg>',
          png: await _png(false),
          scale: .25,
          cancel: cancel,
          reconcile: false,
        );
        await expectLater(
          run.prepare(),
          throwsA(
            cancel
                ? isA<PreparationCancelled>()
                : isA<SceneAdmissionException>(),
          ),
        );
        expect(run.releases, 2);
        run.expectDrained();
      },
    );
  }
  final bodies = <String, String>{
    'XHTML opacity/text': '<div style="opacity:.7;background:red;width:80px;height:60px">Ab😀e</div>',
    'placed SVG roles':
        '<div style="position:absolute;left:100.25px;top:12.75px;width:80px;height:60px">'
        '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
        '<path d="M3 4H70V50H3Z" fill="red" stroke="blue" stroke-width="3" opacity=".7"/>'
        '</svg></div>',
    'mask/pattern/dash':
        '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
        '<defs><mask id="m" mask-type="luminance"><circle cx="40" cy="30" r="27" fill="white"/></mask>'
        '<pattern id="p" width="10" height="10" patternUnits="userSpaceOnUse">'
        '<rect width="5" height="10" fill="red"/></pattern></defs>'
        '<rect x="4" y="4" width="70" height="50" fill="url(#p)" stroke="blue" '
        'stroke-dasharray="4 3" mask="url(#m)" opacity=".8"/></svg>',
    'foreignObject':
        '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
        '<foreignObject width="80" height="60"><div xmlns="http://www.w3.org/1999/xhtml" '
        'style="background:red;opacity:.8">Ab</div></foreignObject></svg>',
    'filter remains authored':
        '<svg xmlns="http://www.w3.org/2000/svg" width="80" height="60">'
        '<defs><filter id="f"><feGaussianBlur stdDeviation="1"/></filter></defs>'
        '<rect x="10" y="10" width="50" height="30" fill="red" filter="url(#f)"/></svg>',
  };
  for (final body in bodies.entries) {
    for (final scale in [.25, 1.5]) {
      test('${body.key}: geometry, roles and CFIs at scale $scale', () async {
        final whole = _Run(body.value), small = _Run(body.value, scale: scale);
        final cfis = _cfis(whole.sample), before = _cfis(small.sample);
        final a = await whole.prepare(), b = await small.prepare();
        expect(b.geometry, a.geometry);
        expect(_cfis(small.sample), cfis);
        expect(before, cfis);
        expect(b.geometry.completeness, isA<CompleteGeometry>());
        expect(b.geometry.paint, isNotEmpty);
        for (final paint in b.geometry.paint) {
          expect(paint.alphaFootprint?.pixelSize, 1);
        }
        if (body.key == 'placed SVG roles') {
          expect(
            b.geometry.paint.map((p) => p.role).toSet(),
            containsAll([GeometryPaintRole.fill, GeometryPaintRole.stroke]),
          );
        }
        final original = whole.plan.resources[SceneResource.layerPixels]!;
        final scaled = small.plan.resources[SceneResource.layerPixels]!;
        expect(scaled, scale < 1 ? lessThan(original) : greaterThan(original));
        expect(small.plan.evidencePixels, whole.plan.evidencePixels);
        if (body.key == 'filter remains authored') {
          final svgWhole = whole.plan.svgPlans.single,
              svgSmall = small.plan.svgPlans.single;
          final difference =
              svgWhole.reservation()[SceneResource.layerPixels]! -
              svgSmall.reservation()[SceneResource.layerPixels]!;
          // Only opacity/wrapper buffers shrink. DAG cache/scratch stays charged.
          expect(
            difference,
            (80 * 60 - (80 * scale).ceil() * (60 * scale).ceil()) *
                svgWhole.layerDepth,
          );
        }
        a.dispose();
        b.dispose();
        whole.expectDrained();
        small.expectDrained();
      });
    }
  }
}

List<String> _cfis(StyleSample sample) => [
  for (final node in sample.document.nodes)
    if (node.isCharacterData && node.text!.trim().isNotEmpty)
      for (var offset = 0; offset <= node.text!.length; offset++)
        Cfi.export(
          sample.document,
          SourcePosition(nodeIndex: node.index, offset: offset),
        ),
];

Future<Uint8List> _png(bool opaque, {bool fineHole = false}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 80, 60),
    ui.Paint()
      ..color = opaque
          ? const ui.Color(0xff804020)
          : const ui.Color(0x40804020),
  );
  if (!opaque || fineHole) {
    canvas.drawRect(
      fineHole
          ? const ui.Rect.fromLTWH(11, 9, 1, 1)
          : const ui.Rect.fromLTWH(11, 9, 7, 13),
      ui.Paint()..blendMode = ui.BlendMode.clear,
    );
  }
  final picture = recorder.endRecording(),
      image = await picture.toImage(80, 60);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

final class _Run {
  _Run(
    String body, {
    this.png,
    bool background = false,
    this.scale = 1,
    int maxBytes = 48 * 1024 * 1024,
    this.cancel = false,
    this.reconcile = true,
  }) : cache = ReaderImageCache(maxBytes: maxBytes) {
    sample = StyleSample.html(
      body,
      css: 'html,body{margin:0;width:320px;height:240px}',
      head: '<meta name="viewport" content="width=320,height=240"/>',
      metadata: '<meta property="rendition:layout">pre-paginated</meta>',
      files: {'tile.png': ?png},
    );
    imagePath = background
        ? sample.styled.styleOf(sample.byId('bg'))!.authored.backgroundImage!
        : 'tile';
  }
  late final StyleSample sample;
  late final String imagePath;
  final Uint8List? png;
  final double scale;
  final bool cancel, reconcile;
  final ReaderImageCache cache;
  final budget = SceneResourceBudget();
  final targets = <(int, int)>[], decoded = <ui.Image>[];
  final bytesAtAcquisition = <int>[];
  int releases = 0, sourceReleases = 0;
  int? bytesAtPicture, releasesAtPicture;
  ImageReservation? credit;
  late FixedPreparationPlan plan;
  Future<FixedImageLease> acquire(
    PublicationCancellation token,
    int w,
    int h,
  ) async {
    targets.add((w, h));
    final lease = (await cache.lease(
      'tile',
      png!,
      targetWidth: w,
      targetHeight: h,
      reservation: credit,
    ))!;
    decoded.add(lease.image);
    bytesAtAcquisition.add(cache.totalBytes);
    if (cancel && w < 80) token.cancel();
    return FixedImageLease(lease.image, () {
      releases++;
      lease.release(discard: true);
    });
  }

  Future<PreparedFixedScene> prepare() async {
    final preparer = FixedSectionPreparer(
      fonts: FontRegistry(processBudget: ProcessFontBudget()),
      drainFonts: () async {},
    );
    final source = FixedSourceLease(
      page: contractPage(),
      document: sample.document,
      styles: sample.styled,
      rendition: sectionRendition(sample.book, 0),
      resources: ArchiveReaderResourceSource(sample.book.archive),
      retainedSourceBytes: 1024,
      images: {
        if (png != null)
          imagePath: FixedImageRequest(
            width: 80,
            height: 60,
            acquire: (t) => acquire(t, 80, 60),
            acquireAt: acquire,
          ),
      },
      releaseSource: () {
        sourceReleases++;
        sample.book.archive.close();
      },
    );
    plan = preparer.plan(source, scale: FixedPreparationScale(scale));
    expect(
      plan.capability.isComplete,
      true,
      reason:
          '${plan.capability.reason}: ${plan.capability.constructs.map((c) => c.identifier)}',
    );
    final sceneLease = budget.reserveUnit(
      sourcePages: 1,
      resources: plan.resources,
      sourceDepth: plan.sourceDepth,
      referenceDepth: plan.referenceDepth,
      layerDepth: plan.layerDepth,
    );
    try {
      credit = cache.reserveOutput(plan.decodedImageBytes);
    } catch (_) {
      sceneLease.release();
      source.dispose();
      rethrow;
    }
    final operation = preparer.prepare(
      plan,
      FixedSceneAdmission(
        plan: plan,
        sceneLease: sceneLease,
        pictureBytes: plan.pictureBytes,
        decodedImageBytes: plan.decodedImageBytes,
        reconcilePictureBytes: (_) {
          bytesAtPicture = cache.totalBytes;
          releasesAtPicture = releases;
          return reconcile;
        },
        releaseReservations: () {
          credit?.release();
          sceneLease.release();
        },
      ),
    );
    try {
      return await operation.result;
    } finally {
      await operation.drained;
    }
  }

  void expectDrained() {
    expect(cache.totalBytes, 0);
    expect(cache.pendingBytes, 0);
    expect(budget.used.values.every((v) => v == 0), true);
    expect(sourceReleases, 1);
    expect(releases, decoded.length);
    expect(decoded.every((i) => i.debugDisposed), true);
  }
}
