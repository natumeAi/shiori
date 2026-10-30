import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';
import 'package:shiori/features/reader/engine/layout/font_mapping.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import '../../contract_test_values.dart';
import '../style/style_test_support.dart';

final class _Resources implements ReaderResourceSource {
  _Resources(this.font);
  final Uint8List font;
  int disposals = 0, reads = 0;
  @override
  Uint8List? bytes(String path) {
    reads++;
    return font;
  }

  @override
  bool contains(String path) => true;
  @override
  int size(String path) => font.length;
  @override
  void dispose() {
    disposals++;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final font = File('tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf')
      .readAsBytesSync();
  late _Resources resources;
  var releases = 0, reservations = 0;
  FixedSourceLease source({
    String viewport = 'width=320,height=240',
    String css = '',
    String body = '<div>Ab</div>',
    Map<String, FixedImageRequest> images = const {},
  }) {
    final sample = StyleSample.html(
      body,
      css:
          '@font-face{font-family:Fixture;src:url(font.ttf)}'
          'body{margin:0;font:20px Fixture}$css',
      head: '<meta name="viewport" content="$viewport"/>',
      files: {'font.ttf': font},
      metadata: '<meta property="rendition:layout">pre-paginated</meta>',
    );
    resources = _Resources(Uint8List.fromList(font));
    addTearDown(sample.book.archive.close);
    return FixedSourceLease(
      page: contractPage(),
      document: sample.document,
      styles: sample.styled,
      rendition: sectionRendition(sample.book, 0),
      resources: resources,
      retainedSourceBytes: 1024,
      images: images,
      releaseSource: () {
        releases++;
      },
    );
  }

  FixedSceneAdmission reserve(
    FixedPreparationPlan plan,
    SceneResourceBudget budget, {
    bool reconcile = true,
  }) {
    final lease = budget.reserveUnit(
      sourcePages: 1,
      resources: plan.resources,
      sourceDepth: plan.sourceDepth,
      layerDepth: plan.layerDepth,
    );
    reservations++;
    return FixedSceneAdmission(
      plan: plan,
      sceneLease: lease,
      pictureBytes: plan.pictureBytes,
      decodedImageBytes: plan.decodedImageBytes,
      reconcilePictureBytes: (_) => reconcile,
      releaseReservations: () {
        lease.release();
        reservations--;
      },
    );
  }

  SceneResourceBudget planBudget(FixedPreparationPlan plan) =>
      SceneResourceBudget(
        limits: {
          for (final r in SceneResource.values)
            r: (plan.resources[r] ?? 0) > 0 ? plan.resources[r]! : 1,
        },
        sourceDepthLimit: plan.sourceDepth,
        referenceDepthLimit: plan.referenceDepth < 1 ? 1 : plan.referenceDepth,
        layerDepthLimit: plan.layerDepth,
      );

  setUp(() {
    releases = 0;
    reservations = 0;
  });
  test('plan precedes all font/native work; result retains and releases ownership once', () async {
    final registry = FontRegistry(processBudget: ProcessFontBudget());
    final preparer = FixedSectionPreparer(
      fonts: registry,
      drainFonts: () async {},
    );
    final input = source();
    final plan = preparer.plan(input), budget = SceneResourceBudget();
    expect(resources.reads, 0);
    expect(registry.processBudget.faces, 0);
    expect(plan.resources[SceneResource.paragraphs], greaterThan(0));
    final operation = preparer.prepare(plan, reserve(plan, budget));
    final result = await operation.result;
    await operation.drained;
    expect(result.geometry.completeness, isA<CompleteGeometry>());
    expect(result.plan.source.page, contractPage());
    expect(result.scene.picture.approximateBytesUsed, greaterThan(0));
    final placement = AffineTransform(2, 0, 0, 2, 320, 9);
    final placed = result.geometryForUnit(
      placement,
      registryPrefix: 'right-source',
      paintOrdinalOffset: 100,
    );
    expect(placed.completeness, isA<CompleteGeometry>());
    expect(
      placed.fragments.first.sourceToUnit,
      placement.compose(result.geometry.fragments.first.sourceToUnit),
    );
    expect(placed.clips.every((c) => c.id.startsWith('right-source:')), true);
    final originalAlpha = result.geometry.paint
        .firstWhere((p) => p.alphaFootprint != null)
        .alphaFootprint!;
    final placedAlpha = placed.paint
        .firstWhere((p) => p.alphaFootprint != null)
        .alphaFootprint!;
    expect(identical(originalAlpha.alpha, placedAlpha.alpha), true);
    expect(placedAlpha.transform, placement);
    expect(
      () => result.geometryForUnit(
        AffineTransform(0, 0, 0, 0, 0, 0),
        registryPrefix: 'singular',
      ),
      throwsStateError,
    );
    expect(releases, 0);
    expect(reservations, 1);
    result.dispose();
    result.dispose();
    expect(releases, 1);
    expect(resources.disposals, 1);
    expect(reservations, 0);
    expect(budget.used.values.every((v) => v == 0), true);
  });
  test(
    'logical font cancel preserves owners until physical registration drains',
    () async {
      final native = Completer<void>(), entered = Completer<void>();
      final registry = FontRegistry(
        processBudget: ProcessFontBudget(),
        register: (_, _) {
          entered.complete();
          return native.future;
        },
      );
      final preparer = FixedSectionPreparer(
        fonts: registry,
        drainFonts: () => native.future,
      );
      final plan = preparer.plan(source()), budget = SceneResourceBudget();
      final operation = preparer.prepare(plan, reserve(plan, budget));
      final rejected = expectLater(
        operation.result,
        throwsA(isA<PreparationCancelled>()),
      );
      await entered.future;
      operation.cancel();
      await rejected;
      expect(releases, 0);
      expect(reservations, 1);
      expect(registry.processBudget.pendingFaces, 1);
      native.complete();
      await operation.drained;
      expect(releases, 1);
      expect(reservations, 0);
      expect(registry.processBudget.registeredFaces, 1);
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
  test(
    'required missing font fails without successful fallback and drains',
    () async {
      final preparer = FixedSectionPreparer(
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        drainFonts: () async {},
      );
      final input = source();
      resources.font.fillRange(0, 4, 0);
      final plan = preparer.plan(input), budget = SceneResourceBudget();
      final operation = preparer.prepare(plan, reserve(plan, budget));
      await expectLater(
        operation.result,
        throwsA(isA<RequiredFontException>()),
      );
      await operation.drained;
      expect(releases, 1);
      expect(reservations, 0);
    },
  );
  test(
    'picture reconciliation failure destroys the scene before releasing',
    () async {
      final preparer = FixedSectionPreparer(
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        drainFonts: () async {},
      );
      final plan = preparer.plan(source()), budget = SceneResourceBudget();
      final operation = preparer.prepare(
        plan,
        reserve(plan, budget, reconcile: false),
      );
      await expectLater(
        operation.result,
        throwsA(isA<SceneAdmissionException>()),
      );
      await operation.drained;
      expect(releases, 1);
      expect(reservations, 0);
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
  test(
    'late decoded image after cancel is destroyed before owner release',
    () async {
      final pending = Completer<FixedImageLease>(), entered = Completer<void>();
      var imageReleases = 0;
      final preparer = FixedSectionPreparer(
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        drainFonts: () async {},
      );
      final input = source(
        images: {
          'tile': FixedImageRequest(
            width: 2,
            height: 2,
            acquire: (_) {
              entered.complete();
              return pending.future;
            },
          ),
        },
      );
      final plan = preparer.plan(input), budget = SceneResourceBudget();
      expect(plan.decodedImageBytes, 16);
      final operation = preparer.prepare(plan, reserve(plan, budget));
      final rejected = expectLater(
        operation.result,
        throwsA(isA<PreparationCancelled>()),
      );
      await entered.future;
      operation.cancel();
      await rejected;
      expect(reservations, 1);
      expect(releases, 0);
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder);
      final picture = recorder.endRecording();
      final image = await picture.toImage(2, 2);
      picture.dispose();
      pending.complete(
        FixedImageLease(image, () {
          expect(reservations, 1);
          image.dispose();
          imageReleases++;
        }),
      );
      await operation.drained;
      expect(imageReleases, 1);
      expect(reservations, 0);
      expect(releases, 1);
    },
  );
  test('motion guard and preallocation refusal perform no font read', () {
    final preparer = FixedSectionPreparer(
      fonts: FontRegistry(processBudget: ProcessFontBudget()),
      drainFonts: () async {},
    );
    final input = source();
    expect(
      () => ReaderWorkGuard.callback(() => preparer.plan(input)),
      throwsAssertionError,
    );
    final plan = preparer.plan(input);
    final limits = {
      ...SceneResourceBudget.provisionalLimits,
      SceneResource.sourceNodes: 1,
    };
    expect(
      () => reserve(plan, SceneResourceBudget(limits: limits)),
      throwsA(isA<SceneAdmissionException>()),
    );
    expect(resources.reads, 0);
    expect(reservations, 0);
    input.dispose();
  });
  test(
    'painted runs request family, weight and style from the supplied selector',
    () async {
      final requests = <ParagraphFontRequest>[];
      final registry = FontRegistry(processBudget: ProcessFontBudget());
      final preparer = FixedSectionPreparer(
        fonts: registry,
        drainFonts: () async {},
        selectFace: (request) {
          requests.add(request);
          return resolveFontFamilies(
            request.families,
            embedded: {'fixture': registry.records.single.alias},
          );
        },
      );
      final plan = preparer.plan(
        source(body: '<div>Ab<strong>bold</strong><em>italic</em></div>'),
      );
      final operation = preparer.prepare(
        plan,
        reserve(plan, SceneResourceBudget()),
      );
      final result = await operation.result;
      await operation.drained;
      expect(
        requests.any(
          (r) =>
              r.families.contains('Fixture') &&
              r.weight == 400 &&
              r.style == StyleFontStyle.normal,
        ),
        true,
      );
      expect(requests.any((r) => r.weight == 700), true);
      expect(requests.any((r) => r.style == StyleFontStyle.italic), true);
      result.dispose();
    },
  );
  test(
    'multiple faces in one family cannot silently use its final alias',
    () async {
      final preparer = FixedSectionPreparer(
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        drainFonts: () async {},
      );
      final plan = preparer.plan(
        source(
          css:
              '@font-face{font-family:Fixture;'
              'src:url(font.ttf);font-weight:700;font-style:italic}',
        ),
      );
      expect(plan.source.styles.fontFaces.map((f) => f.weight), [400, 700]);
      final operation = preparer.prepare(
        plan,
        reserve(plan, SceneResourceBudget()),
      );
      await expectLater(
        operation.result,
        throwsA(isA<FixedPreparationFailure>()),
      );
      await operation.drained;
      expect(resources.reads, 0);
      expect(releases, 1);
      expect(reservations, 0);
    },
  );
  test(
    'two constituents retain the same spread reservation until last disposal',
    () async {
      final preparer = FixedSectionPreparer(
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        drainFonts: () async {},
      );
      final left = preparer.plan(source()), right = preparer.plan(source());
      final budget = SceneResourceBudget();
      final shared = budget.reserveUnit(
        sourcePages: 2,
        resources: {
          for (final r in left.resources.keys)
            r: left.resources[r]! + right.resources[r]!,
        },
        sourceDepth: left.sourceDepth,
        layerDepth: left.layerDepth,
      );
      var refs = 2, releasesOfSharedOwner = 0;
      FixedSceneAdmission ticket(FixedPreparationPlan plan) =>
          FixedSceneAdmission(
            plan: plan,
            sceneLease: shared,
            pictureBytes: plan.pictureBytes,
            decodedImageBytes: 0,
            reconcilePictureBytes: (_) => true,
            releaseReservations: () {
              if (--refs == 0) {
                shared.release();
                releasesOfSharedOwner++;
              }
            },
          );
      expect(
        left.pictureBytes * SceneResourceBudget.maxSourcePages,
        16 * 1024 * 1024,
      );
      final a = preparer.prepare(left, ticket(left)),
          b = preparer.prepare(right, ticket(right));
      final scenes = await Future.wait([a.result, b.result]);
      await Future.wait([a.drained, b.drained]);
      scenes.first.dispose();
      scenes.first.dispose();
      expect(shared.isReleased, false);
      expect(budget.used[SceneResource.sourcePages], 2);
      scenes.last.dispose();
      expect(shared.isReleased, true);
      expect(releasesOfSharedOwner, 1);
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
  test(
    'inline SVG prepares through the fixed section route with source geometry',
    () async {
      final preparer = FixedSectionPreparer(
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        drainFonts: () async {},
      );
      final input = source(
        body: '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100"><rect id="r" x="5" y="5" width="20" height="20" fill="red"/></svg>',
      );
      final plan = preparer.plan(input), budget = SceneResourceBudget();
      expect(plan.capability.isComplete, true);
      expect(plan.svgPlans, hasLength(1));
      expect(plan.resources[SceneResource.vectorBytes], greaterThan(0));
      final operation = preparer.prepare(plan, reserve(plan, budget));
      final result = await operation.result;
      await operation.drained;
      try {
        expect(result.scene.svgScenes, hasLength(1));
        expect(result.geometry.completeness, isA<CompleteGeometry>());
        final rect = input.document.nodes.singleWhere((n) => n.id == 'r');
        expect(
          result.geometry.fragments.where((f) => f.nodeIndex == rect.index),
          hasLength(1),
        );
        final image = await result.scene.picture.toImage(320, 240);
        try {
          final bytes = (await image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!.buffer.asUint8List();
          final offset = (10 * 320 + 10) * 4;
          expect(bytes.sublist(offset, offset + 4), [255, 0, 0, 255]);
        } finally {
          image.dispose();
        }
      } finally {
        result.dispose();
        result.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );
  for (final transform in ['none', 'matrix(1.2,.2,-.3,.9,0,0)']) {
    test('placed inline SVG uses the enclosing authored raster: $transform', () async {
      final preparer = FixedSectionPreparer(
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        drainFonts: () async {},
      );
      final input = source(
        css:
            '#host{position:absolute;left:100.25px;top:12.75px;'
            'width:80px;height:80px;transform:$transform;transform-origin:0 0}',
        body:
            '<div id="host"><svg xmlns="http://www.w3.org/2000/svg" '
            'width="80" height="80"><path id="placed" d="M0 0H80V80H0Z" '
            'fill="red"/></svg></div>',
      );
      final plan = preparer.plan(input), budget = SceneResourceBudget();
      expect(plan.capability.isComplete, true);
      final svgPlan = plan.svgPlans.single;
      expect(svgPlan.size.width, 80);
      expect(svgPlan.size.height, 80);
      expect(svgPlan.evidenceSize!.width, 320);
      expect(svgPlan.evidenceSize!.height, 240);
      expect(
        svgPlan.evidencePixels,
        AuthoredEvidenceRaster.scratchPixels(320, 240),
      );
      expect(plan.evidencePixels, svgPlan.evidencePixels);
      final operation = preparer.prepare(plan, reserve(plan, budget));
      final result = await operation.result;
      await operation.drained;
      try {
        final svg = result.scene.svgScenes.single;
        expect(svg.capability.isComplete, true);
        expect(result.geometry.completeness, isA<CompleteGeometry>());
        final node = input.document.nodes.singleWhere((n) => n.id == 'placed');
        final footprint = result.geometry.paint
            .singleWhere((p) => p.nodeIndex == node.index)
            .alphaFootprint!;
        final image = await svg.picture!.toImage(320, 240);
        try {
          final rgba = (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
          var painted = 0;
          for (var y = 0; y < 240; y++) {
            for (var x = 0; x < 320; x++) {
              final alpha = rgba[(y * 320 + x) * 4 + 3];
              expect(
                footprint.alphaAt(GeometryPoint(x + .5, y + .5)),
                alpha,
                reason: '$transform native alpha at $x,$y',
              );
              if (alpha > 0) painted++;
            }
          }
          expect(painted, greaterThan(0));
        } finally {
          image.dispose();
        }
      } finally {
        result.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    });
  }
  test(
    'inline SVG resources are charged once in the whole-unit plan',
    () async {
      final preparer = FixedSectionPreparer(
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        drainFonts: () async {},
      );
      final input = source(
        body: '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100" viewBox="0 0 100 100"><rect x="5" y="5" width="20" height="20" fill="red"/></svg>',
      );
      final plan = preparer.plan(input);
      final sceneBudget = planBudget(plan);
      final prepared = FixedSectionPreparer(
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        drainFonts: () async {},
        sceneBudget: sceneBudget,
      );
      final operation = prepared.prepare(
        plan,
        reserve(plan, SceneResourceBudget()),
      );
      final result = await operation.result;
      await operation.drained;
      expect(
        plan.resources[SceneResource.sourceNodes],
        input.document.nodes.length,
      );
      expect(
        sceneBudget.peaks[SceneResource.sourceNodes],
        input.document.nodes.length,
      );
      result.dispose();
      result.dispose();
      expect(sceneBudget.used.values.every((v) => v == 0), true);
    },
  );
  test('SVG image uses the admitted image lease once', () async {
    var acquires = 0, releasesOfImage = 0;
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawRect(
      const ui.Rect.fromLTWH(0, 0, 2, 2),
      ui.Paint()..color = const ui.Color(0xffff0000),
    );
    final picture = recorder.endRecording();
    final image = await picture.toImage(2, 2);
    picture.dispose();
    final input = source(
      body: '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><image href="/tile.svg" x="0" y="0" width="20" height="20"/></svg>',
      images: {
        '/tile.svg': FixedImageRequest(
          width: 2,
          height: 2,
          acquire: (_) async {
            acquires++;
            return FixedImageLease(image, () {
              releasesOfImage++;
              image.dispose();
            });
          },
        ),
      },
    );
    final preparer = FixedSectionPreparer(
      fonts: FontRegistry(processBudget: ProcessFontBudget()),
      drainFonts: () async {},
    );
    final plan = preparer.plan(input);
    expect(plan.decodedImageBytes, 16);
    final operation = preparer.prepare(
      plan,
      reserve(plan, SceneResourceBudget()),
    );
    final result = await operation.result;
    await operation.drained;
    expect(acquires, 1);
    expect(result.imageOpacity, {'/tile.svg': true});
    final native = await result.scene.picture.toImage(320, 240);
    try {
      final bytes = (await native.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      ))!.buffer.asUint8List();
      final offset = (10 * 320 + 10) * 4;
      expect(bytes.sublist(offset, offset + 4), [255, 0, 0, 255]);
    } finally {
      native.dispose();
      result.dispose();
      result.dispose();
    }
    expect(releasesOfImage, 1);
  });
  test(
    'unsupported SVG refuses before font/native work with no partial scene',
    () async {
      final preparer = FixedSectionPreparer(
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        drainFonts: () async {},
      );
      final input = source(
        body: '<svg xmlns="http://www.w3.org/2000/svg" width="20" height="20"><text x="0" y="10" writing-mode="vertical-rl">x</text></svg>',
      );
      final plan = preparer.plan(input);
      expect(plan.capability, isA<UnsupportedSectionCapability>());
      expect(plan.svgPlans, hasLength(1));
      expect(
        (plan.capability as UnsupportedSectionCapability).constructs.map(
          (c) => c.identifier,
        ),
        contains('svg-text-vertical'),
      );
      final operation = preparer.prepare(
        plan,
        reserve(plan, SceneResourceBudget()),
      );
      await expectLater(
        operation.result,
        throwsA(isA<FixedPreparationFailure>()),
      );
      await operation.drained;
      expect(resources.reads, 0);
      expect(releases, 1);
      expect(reservations, 0);
    },
  );
  test(
    'failed and canceled SVG preparations release the local ledger once',
    () async {
      final failedInput = source(
        body: '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect x="5" y="5" width="20" height="20" fill="red"/></svg>',
      );
      final preparer = FixedSectionPreparer(
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        drainFonts: () async {},
      );
      final plan = preparer.plan(failedInput), failedBudget = planBudget(plan);
      final failedPreparer = FixedSectionPreparer(
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        drainFonts: () async {},
        sceneBudget: failedBudget,
      );
      final failed = failedPreparer.prepare(
        plan,
        reserve(plan, SceneResourceBudget(), reconcile: false),
      );
      await expectLater(failed.result, throwsA(isA<SceneAdmissionException>()));
      await failed.drained;
      expect(failedBudget.used.values.every((v) => v == 0), true);
      expect(releases, 1);
      expect(reservations, 0);

      final canceledInput = source(
        body: '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100"><rect x="5" y="5" width="20" height="20" fill="red"/></svg>',
      );
      final canceledPlan = preparer.plan(canceledInput);
      final canceledBudget = planBudget(canceledPlan);
      final canceledPreparer = FixedSectionPreparer(
        fonts: FontRegistry(processBudget: ProcessFontBudget()),
        drainFonts: () async {},
        sceneBudget: canceledBudget,
      );
      final canceled = canceledPreparer.prepare(
        canceledPlan,
        reserve(canceledPlan, SceneResourceBudget()),
      );
      canceled.cancel();
      await expectLater(canceled.result, throwsA(isA<PreparationCancelled>()));
      await canceled.drained;
      expect(canceledBudget.used.values.every((v) => v == 0), true);
      expect(releases, 2);
      expect(reservations, 0);
    },
  );
}
