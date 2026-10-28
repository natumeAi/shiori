import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_preparation_plan.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_admission.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_section_preparer.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';
import 'package:shiori/features/reader/engine/layout/font_mapping.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_factory.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/support/layout_flags.dart';

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
      throwsArgumentError,
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
}
