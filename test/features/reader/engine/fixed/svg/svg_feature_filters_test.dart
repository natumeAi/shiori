import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/affine_transform.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/geometry/source_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/pagination/preparation.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import '../../../../../../tool/reader/fixed_layout_scene_input.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final corpus = jsonDecode(
    File('test/fixtures/reader/fixed_layout/corpus.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final fixture = (corpus['cases'] as List).cast<Map<String, Object?>>().first;
  final input = SceneHarnessInput(
    fixture,
    corpus,
    File((corpus['font'] as Map)['path'] as String).readAsBytesSync(),
  );
  tearDownAll(input.book.archive.close);

  SvgGraphicsPlan plan(
    String primitives, {
    String filterAttributes =
        'filterUnits="userSpaceOnUse" x="0" y="0" width="100" height="100" '
        'color-interpolation-filters="sRGB"',
    String shape =
        '<rect x="10" y="10" width="20" height="20" fill="red" '
        'filter="url(#f)"/>',
    int width = 100,
    int height = 100,
    String rootAttributes = '',
  }) {
    final document = const SourceParser().parse(
      '<svg xmlns="http://www.w3.org/2000/svg" width="$width" height="$height" $rootAttributes>'
      '<defs><filter id="f" $filterAttributes>$primitives</filter></defs>'
      '$shape</svg>',
      mediaType: 'image/svg+xml',
    );
    return SvgGraphicsPlan.inspect(
      document: document,
      rootIndex: document.documentElementIndex,
      page: input.page,
      size: AuthoredPageSize(width.toDouble(), height.toDouble()),
    );
  }

  Future<Uint8List> render(
    SvgGraphicsPlan p, {
    int width = 100,
    int height = 100,
  }) async {
    final budget = SceneResourceBudget();
    final scene = await p.prepare(budget: budget);
    try {
      expect(scene.picture, isNotNull, reason: '${scene.capability}');
      final image = await scene.picture!.toImage(width, height);
      try {
        final bytes = (await image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        ))!.buffer.asUint8List();
        expect(scene.geometry.completeness, isA<CompleteGeometry>());
        final paint = scene.geometry.paint.single;
        expect(paint.exactCoverage, true);
        expect(paint.effectiveOpacity, 1);
        expect(paint.groupIds, isEmpty); // Opacity is already in native alpha.
        final alpha = paint.alphaFootprint!;
        expect(alpha.pixelSize, 1);
        for (var y = 0; y < height; y++) {
          for (var x = 0; x < width; x++) {
            expect(
              alpha.alphaAt(GeometryPoint(x + .5, y + .5)),
              bytes[(y * width + x) * 4 + 3],
              reason: 'output alpha at $x,$y',
            );
          }
        }
        return bytes;
      } finally {
        image.dispose();
      }
    } finally {
      scene.dispose();
      expect(budget.used.values.every((v) => v == 0), true);
    }
  }

  List<int> rgba(Uint8List bytes, int x, int y) {
    final offset = (y * 100 + x) * 4;
    return bytes.sublist(offset, offset + 4);
  }

  test('filtered flood retains inherited hidden SVG viewport clips', () async {
    final p = plan(
      '<feFlood flood-color="red"/>',
      filterAttributes:
          'filterUnits="userSpaceOnUse" x="0" y="0" '
          'width="40" height="40" color-interpolation-filters="sRGB"',
      shape:
          '<svg x="20" y="25" width="30" height="30" overflow="hidden">'
          '<g filter="url(#f)"><rect width="10" height="10"/></g></svg>',
    );
    final bytes = await render(p);
    expect(rgba(bytes, 30, 35)[3], 255);
    for (final (x, y) in [(19, 35), (50, 35), (30, 24), (30, 55)]) {
      expect(rgba(bytes, x, y)[3], 0, reason: 'outside nested viewport $x,$y');
    }
  });

  SvgGraphicsPlan fractionalViewportPlan(
    String primitives, {
    bool filtered = true,
    String content =
        '<rect x="-20" y="-20" width="80" height="80" fill="red"/>',
  }) => plan(
    primitives,
    filterAttributes:
        'filterUnits="userSpaceOnUse" x="-5" y="-5" '
        'width="40" height="40" color-interpolation-filters="sRGB"',
    shape:
        '<svg x="20.5" y="25.25" width="30" height="30" overflow="hidden">'
        '<g ${filtered ? 'filter="url(#f)"' : ''}>$content</g></svg>',
  );

  for (final (name, primitive) in [
    ('identity', '<feOffset dx="0" dy="0"/>'),
    ('flood', '<feFlood flood-color="red"/>'),
    ('blur', '<feGaussianBlur stdDeviation="1"/>'),
  ]) {
    test('$name applies fractional inherited viewport clips once', () async {
      final control = await render(fractionalViewportPlan('', filtered: false));
      final filtered = await render(fractionalViewportPlan(primitive));
      // The oversized source/flood is solid throughout the viewport even after
      // blur. Native output and its evidence must retain the control's AA.
      expect(rgba(control, 30, 25)[3], 191);
      expect(rgba(control, 20, 25)[3], 96);
      expect(filtered, orderedEquals(control), reason: '$name whole RGBA grid');
      for (final (x, y) in [(19, 35), (51, 35), (30, 24), (30, 56)]) {
        expect(rgba(filtered, x, y)[3], 0, reason: 'exterior $x,$y');
      }
    });
  }

  for (final nested in [false, true]) {
    test('identity clips a filtered leaf once (nested=$nested)', () async {
      const leaf =
          '<rect x="-20" y="-20" width="80" height="80" '
          'fill="red" filter="url(#f)"/>';
      final control = await render(fractionalViewportPlan('', filtered: false));
      final filtered = await render(
        fractionalViewportPlan(
          '<feOffset dx="0" dy="0"/>',
          filtered: false,
          content: nested ? '<g filter="url(#f)">$leaf</g>' : leaf,
        ),
      );
      expect(filtered, orderedEquals(control));
    });
  }

  for (final (name, content) in [
    (
      'descendant viewport',
      '<svg x="7.25" y="9.5" width="10.5" height="8.25" overflow="hidden">'
          '<rect x="-20" y="-20" width="80" height="80" fill="red"/></svg>',
    ),
    (
      'descendant clip path',
      '<defs><clipPath id="local"><rect x="7.25" y="9.5" '
          'width="10.5" height="8.25"/></clipPath></defs>'
          '<rect x="-20" y="-20" width="80" height="80" fill="red" '
          'clip-path="url(#local)"/>',
    ),
    (
      'nested filter descendant viewport',
      '<g filter="url(#f)"><svg x="7.25" y="9.5" width="10.5" '
          'height="8.25" overflow="hidden"><rect x="-20" y="-20" '
          'width="80" height="80" fill="red"/></svg></g>',
    ),
  ]) {
    test('identity preserves $name in SourceGraphic', () async {
      // Remove all filters for an independently painted control.
      final control = await render(
        fractionalViewportPlan(
          '',
          filtered: false,
          content: content.replaceAll('filter="url(#f)"', ''),
        ),
      );
      final filtered = await render(
        fractionalViewportPlan('<feOffset dx="0" dy="0"/>', content: content),
      );
      expect(rgba(filtered, 30, 37)[3], 255);
      expect(rgba(filtered, 25, 37)[3], 0);
      expect(rgba(filtered, 30, 45)[3], 0);
      expect(filtered, orderedEquals(control), reason: '$name whole RGBA grid');
    });
  }

  test('transparent output cannot prove source coverage', () async {
    for (final primitive in [
      '<feFlood flood-opacity="0"/>',
      '<feComposite in="SourceGraphic" in2="SourceGraphic" operator="out"/>',
      '<feColorMatrix values="1 0 0 0 0 0 1 0 0 0 0 0 1 0 0 0 0 0 0 0"/>',
    ]) {
      for (final shape in [
        '<rect x="10" y="10" width="20" height="20" filter="url(#f)"/>',
        '<g filter="url(#f)"><rect x="10" y="10" width="20" height="20"/></g>',
      ]) {
        final p = plan(primitive, shape: shape);
        expect(rgba(await render(p), 20, 20)[3], 0);
        final scene = await p.prepare(budget: SceneResourceBudget());
        try {
          expect(scene.geometry.completeness, isA<CompleteGeometry>());
          final alpha = scene.geometry.paint.single.alphaFootprint!;
          expect(alpha.uniformAlpha, 0);
          expect(alpha.storageBytes, 128);
          expect(alpha.alpha.every((value) => value == 0), true);
        } finally {
          scene.dispose();
        }
      }
    }
  });

  test(
    'post-paint removes source evidence appended by later geometry hooks',
    () async {
      final p = plan('<feFlood flood-opacity="0"/>');
      final budget = SceneResourceBudget();
      final scene = await p.prepare(
        budget: budget,
        features: SvgFeatureRegistry([
          const SvgFilterFeature(),
          const _LateSourceFeature(),
        ]),
      );
      try {
        expect(scene.geometry.completeness, isA<CompleteGeometry>());
        expect(scene.geometry.paint, hasLength(1));
        expect(scene.geometry.paint.single.alphaFootprint!.uniformAlpha, 0);
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );

  test(
    'cached DAG images release after late failure and cancellation',
    () async {
      for (final cancel in [false, true]) {
        final p = plan('<feFlood result="f"/><feBlend in="f" in2="f"/>');
        final budget = SceneResourceBudget();
        final token = PublicationCancellation();
        final created = <ui.Image>[], disposed = <ui.Image>[];
        final previousCreate = ui.Image.onCreate;
        final previousDispose = ui.Image.onDispose;
        ui.Image.onCreate = (image) {
          previousCreate?.call(image);
          created.add(image);
        };
        ui.Image.onDispose = (image) {
          previousDispose?.call(image);
          disposed.add(image);
        };
        try {
          final future = p.prepare(
            budget: budget,
            cancellation: token,
            features: SvgFeatureRegistry([
              _AfterFilterFeature(cancel ? token : null),
              const SvgFilterFeature(),
            ]),
          );
          if (cancel) {
            await expectLater(future, throwsA(isA<PreparationCancelled>()));
          } else {
            final scene = await future;
            expect(scene.picture, isNull);
            expect(scene.capability, isA<UnsupportedSectionCapability>());
            scene.dispose();
          }
          // Bounded evidence rasterization (2026-10-30) adds one whole
          // authored coverage image before exact tile readback.
          expect(created, hasLength(6));
          expect(disposed, hasLength(created.length));
          for (final image in created) {
            expect(
              disposed.where((other) => identical(image, other)),
              hasLength(1),
            );
          }
          expect(budget.used.values.every((v) => v == 0), true);
        } finally {
          ui.Image.onCreate = previousCreate;
          ui.Image.onDispose = previousDispose;
        }
      }
    },
  );

  test(
    'transformed raster allocation is bounded before graph capture',
    () async {
      final p = plan(
        '<feFlood/>',
        shape:
            '<rect x="10" y="10" width="20" height="20" transform="scale(2)" '
            'filter="url(#f)"/>',
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      try {
        expect(scene.picture, isNull);
        expect(scene.capability, isA<UnsupportedSectionCapability>());
        expect(
          scene.capability.constructs.single.identifier,
          'svg-filter-region',
        );
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );

  test('repeated blend and merge inputs execute once per DAG result', () async {
    const count = 24;
    final primitives = StringBuffer(
      '<feFlood flood-color="blue" result="r0"/>',
    );
    for (var i = 1; i < count; i++) {
      final previous = 'r${i - 1}';
      primitives.write(
        i.isEven
            ? '<feMerge result="r$i"><feMergeNode in="$previous"/>'
                  '<feMergeNode in="$previous"/></feMerge>'
            : '<feBlend in="$previous" in2="$previous" result="r$i"/>',
      );
    }
    final created = <ui.Image>[], disposed = <ui.Image>[];
    final previousCreate = ui.Image.onCreate;
    final previousDispose = ui.Image.onDispose;
    ui.Image.onCreate = (image) {
      previousCreate?.call(image);
      created.add(image);
    };
    ui.Image.onDispose = (image) {
      previousDispose?.call(image);
      disposed.add(image);
    };
    try {
      expect(rgba(await render(plan(primitives.toString())), 50, 50), [
        0,
        0,
        255,
        255,
      ]);
      // Source coverage raster/tile, two sources, N results, isolated output
      // raster/tile and test raster. Repeated edges never rerun a primitive.
      expect(created.length, count + 7);
      expect(disposed, hasLength(created.length));
      for (final image in created) {
        expect(
          disposed.where((other) => identical(image, other)),
          hasLength(1),
        );
      }
    } finally {
      ui.Image.onCreate = previousCreate;
      ui.Image.onDispose = previousDispose;
    }
    final excessive = plan(
      '<feMerge>${List.filled(257, '<feMergeNode in="SourceGraphic"/>').join()}</feMerge>',
    );
    expect(excessive.capability, isA<UnsupportedSectionCapability>());
    final excessiveGraph = plan(
      List.generate(
        2,
        (i) =>
            '<feMerge result="m$i">${List.filled(129, '<feMergeNode in="SourceGraphic"/>').join()}</feMerge>',
      ).join(),
    );
    expect(excessiveGraph.capability, isA<UnsupportedSectionCapability>());
  });

  test('element and group opacity apply after filter output', () async {
    for (final shape in [
      '<rect x="10" y="10" width="20" height="20" opacity=".25" filter="url(#f)"/>',
      '<g opacity=".25" filter="url(#f)"><rect x="10" y="10" width="20" height="20"/></g>',
      '<g opacity=".5"><rect x="10" y="10" width="20" height="20" '
          'opacity=".5" filter="url(#f)"/></g>',
    ]) {
      final bytes = await render(
        plan('<feFlood flood-color="blue"/>', shape: shape),
      );
      expect(rgba(bytes, 20, 20)[3], 64);
      expect(rgba(bytes, 50, 50)[3], 64);
    }
  });

  test('nested filters publish only the final outer output', () async {
    final p = plan(
      '<feOffset dx="10" result="m"/>'
      '<feBlend in="m" in2="m"/>',
      shape:
          '<g opacity=".5" filter="url(#f)"><g opacity=".5" filter="url(#f)">'
          '<rect x="10" y="10" width="20" height="20"/></g></g>',
    );
    final bytes = await render(p);
    expect(rgba(bytes, 35, 20)[3], greaterThan(0));
    expect(rgba(bytes, 15, 20)[3], 0);
  });

  test(
    'own clip and mask wrap filtered output before captured opacity',
    () async {
      for (final effect in ['clip-path="url(#c)"', 'mask="url(#m)"']) {
        final bytes = await render(
          plan(
            '<feFlood flood-color="blue"/>',
            shape:
                '<defs><clipPath id="c"><rect x="40" y="40" width="20" height="20"/>'
                '</clipPath><mask id="m" mask-type="alpha" maskUnits="userSpaceOnUse" '
                'x="0" y="0" width="100" height="100"><rect x="40" y="40" '
                'width="20" height="20"/></mask></defs>'
                '<g $effect opacity=".25" filter="url(#f)"><rect x="10" y="10" '
                'width="20" height="20"/></g>',
          ),
        );
        expect(rgba(bytes, 45, 45)[3], 64);
        expect(rgba(bytes, 20, 20)[3], 0);
      }
    },
  );

  test('rotated blur output keeps exact native antialiasing', () async {
    await render(
      plan(
        '<feGaussianBlur stdDeviation="2"/>',
        shape:
            '<rect x="10" y="10" width="20" height="20" '
            'transform="translate(25 -5) rotate(17)" opacity=".25" filter="url(#f)"/>',
      ),
    );
  });

  test(
    'flood subregion is uniform and negative output retains unit placement',
    () async {
      final p = plan(
        '<feFlood x="-10" y="-5" width="40" height="35"/>',
        // Negative output is visible only when the root allows overflow.
        rootAttributes: 'overflow="visible"',
        filterAttributes:
            'filterUnits="userSpaceOnUse" x="-10" y="-5" '
            'width="100" height="100" color-interpolation-filters="sRGB"',
      );
      final budget = SceneResourceBudget();
      final scene = await p.prepare(budget: budget);
      try {
        expect(scene.geometry.completeness, isA<CompleteGeometry>());
        final alpha = scene.geometry.paint.single.alphaFootprint!;
        expect(alpha.uniformAlpha, 255);
        expect(alpha.storageBytes, 128);
        expect(alpha.width, 40);
        expect(alpha.height, 35);
        expect(alpha.alphaAt(GeometryPoint(-9.5, -4.5)), 255);
        expect(alpha.alphaAt(GeometryPoint(30.5, 10.5)), 0);
        final placed = alpha.placed(AffineTransform(1, 0, 0, 1, 120, 80));
        expect(placed.alphaAt(GeometryPoint(110.5, 75.5)), 255);
        expect(identical(placed.alpha, alpha.alpha), true);
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    },
  );

  test('uncaptured ancestor clip keeps filtered geometry incomplete', () async {
    final p = plan(
      '<feFlood/>',
      shape:
          '<defs><clipPath id="c"><rect width="25" height="25"/></clipPath></defs>'
          '<g clip-path="url(#c)"><rect width="20" height="20" '
          'filter="url(#f)"/></g>',
    );
    final budget = SceneResourceBudget();
    final scene = await p.prepare(budget: budget);
    try {
      expect(scene.geometry.completeness, isA<IncompleteGeometry>());
      expect(
        (scene.geometry.completeness as IncompleteGeometry).issues.any(
          (issue) => issue.reason.contains('uncaptured ancestor clip/mask'),
        ),
        true,
      );
      expect(scene.geometry.paint, isEmpty);
    } finally {
      scene.dispose();
    }
    expect(budget.used.values.every((v) => v == 0), true);
  });

  test(
    'fractional output preserves every sample across evidence tile seams',
    () async {
      await render(
        plan(
          '<feFlood flood-opacity=".25"/>',
          width: 600,
          filterAttributes:
              'filterUnits="userSpaceOnUse" x="0" y="0" '
              'width="600" height="100" color-interpolation-filters="sRGB"',
          shape:
              '<rect x="10" y="10" width="20" height="20" '
              'transform="translate(.25 .5)" filter="url(#f)"/>',
        ),
        width: 600,
      );
    },
  );

  test(
    'filter caches and serial evidence share the admitted raster peak',
    () async {
      final p = plan('<feFlood result="f"/><feBlend in="f" in2="f"/>');
      final budget = SceneResourceBudget();
      final observer = _PostFilterFeature();
      SceneResourceBudget? rasterBudget;
      final sizes = <(ui.Image, int)>[];
      var livePixels = 0, peakPixels = 0;
      final previousCreate = ui.Image.onCreate;
      final previousDispose = ui.Image.onDispose;
      ui.Image.onCreate = (image) {
        previousCreate?.call(image);
        final pixels = image.width * image.height;
        sizes.add((image, pixels));
        livePixels += pixels;
        if (livePixels > peakPixels) peakPixels = livePixels;
        expect(
          rasterBudget!.used[SceneResource.layerPixels],
          greaterThanOrEqualTo(livePixels),
        );
      };
      ui.Image.onDispose = (image) {
        previousDispose?.call(image);
        livePixels -= sizes.singleWhere((s) => identical(s.$1, image)).$2;
      };
      observer.onPrepare = (context) => rasterBudget = context.rasterBudget;
      try {
        final scene = await p.prepare(
          budget: budget,
          features: SvgFeatureRegistry([observer, const SvgFilterFeature()]),
        );
        expect(scene.geometry.completeness, isA<CompleteGeometry>());
        expect(peakPixels, 60000); // Four DAG caches + output raster + tile.
        expect(rasterBudget!.peaks[SceneResource.layerPixels], 100000);
        expect(
          rasterBudget!.peaks[SceneResource.layerPixels],
          lessThanOrEqualTo(p.reservation()[SceneResource.layerPixels]!),
        );
        scene.dispose();
        scene.dispose();
        expect(livePixels, 0);
        expect(rasterBudget!.used.values.every((v) => v == 0), true);
        expect(budget.used.values.every((v) => v == 0), true);
      } finally {
        ui.Image.onCreate = previousCreate;
        ui.Image.onDispose = previousDispose;
      }
    },
  );

  test('output readback cancellation and post-evidence failure drain owners', () async {
    for (final cancelReadback in [true, false]) {
      final p = plan('<feFlood result="f"/><feBlend in="f" in2="f"/>');
      final budget = SceneResourceBudget(), token = PublicationCancellation();
      final observer = _PostFilterFeature(failAfterEvidence: !cancelReadback);
      SceneResourceBudget? rasterBudget;
      observer.onPrepare = (context) => rasterBudget = context.rasterBudget;
      final created = <ui.Image>[], disposed = <ui.Image>[];
      final previousCreate = ui.Image.onCreate;
      final previousDispose = ui.Image.onDispose;
      ui.Image.onCreate = (image) {
        previousCreate?.call(image);
        created.add(image);
        // Source coverage raster/tile + four DAG caches precede output raster.
        if (cancelReadback && created.length == 7) token.cancel();
      };
      ui.Image.onDispose = (image) {
        previousDispose?.call(image);
        disposed.add(image);
      };
      try {
        final future = p.prepare(
          budget: budget,
          cancellation: token,
          features: SvgFeatureRegistry([const SvgFilterFeature(), observer]),
        );
        if (cancelReadback) {
          await expectLater(future, throwsA(isA<PreparationCancelled>()));
        } else {
          final scene = await future;
          expect(observer.sawEvidence, true);
          expect(scene.picture, isNull);
          expect(scene.capability, isA<UnsupportedSectionCapability>());
          scene.dispose();
        }
        expect(created, hasLength(cancelReadback ? 7 : 8));
        expect(disposed, hasLength(created.length));
        for (final image in created) {
          expect(
            disposed.where((other) => identical(image, other)),
            hasLength(1),
          );
        }
        expect(rasterBudget!.used.values.every((v) => v == 0), true);
        expect(budget.used.values.every((v) => v == 0), true);
      } finally {
        ui.Image.onCreate = previousCreate;
        ui.Image.onDispose = previousDispose;
      }
    }
  });

  test(
    'bbox primitive subregion uses object bounds and filter clipping',
    () async {
      for (final units in [
        'filterUnits="userSpaceOnUse" x="0" y="0" width="100" height="100"',
        'filterUnits="objectBoundingBox" x="-50%" y="-50%" width="200%" height="200%"',
      ]) {
        final bytes = await render(
          plan(
            '<feFlood flood-color="blue" x=".5" y="25%" width="100%" height=".5"/>',
            filterAttributes:
                '$units primitiveUnits="objectBoundingBox" '
                'color-interpolation-filters="sRGB"',
          ),
        );
        expect(rgba(bytes, 25, 20), [0, 0, 255, 255]);
        expect(rgba(bytes, 15, 20)[3], 0);
        expect(rgba(bytes, 25, 27)[3], 0);
        expect(rgba(bytes, 45, 20)[3], 0);
      }
      final clipped = await render(
        plan(
          '<feFlood flood-color="blue" x="0" y="0" width="2" height="2"/>',
          filterAttributes:
              'filterUnits="userSpaceOnUse" x="15" y="15" width="10" '
              'height="10" primitiveUnits="objectBoundingBox" color-interpolation-filters="sRGB"',
        ),
      );
      expect(rgba(clipped, 20, 20)[3], 255);
      expect(rgba(clipped, 12, 20)[3], 0);
      expect(rgba(clipped, 27, 20)[3], 0);
    },
  );

  test('each supported primitive renders its documented effect', () async {
    final blur = await render(
      plan('<feGaussianBlur in="SourceGraphic" stdDeviation="3"/>'),
    );
    expect(rgba(blur, 20, 20), [255, 0, 0, 255]);
    expect(rgba(blur, 31, 20)[3], greaterThan(0));

    final offset = await render(
      plan('<feOffset in="SourceGraphic" dx="40" dy="0"/>'),
    );
    expect(rgba(offset, 55, 20), [255, 0, 0, 255]);
    expect(rgba(offset, 20, 20)[3], 0);

    final green = await render(
      plan(
        '<feColorMatrix in="SourceGraphic" type="matrix" '
        'values="0 0 0 0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 1 0"/>',
      ),
    );
    expect(rgba(green, 20, 20), [0, 255, 0, 255]);

    final flood = await render(
      plan('<feFlood flood-color="#0000ff" flood-opacity=".5"/>'),
    );
    expect(rgba(flood, 50, 50).sublist(0, 3), [0, 0, 255]);
    expect(rgba(flood, 50, 50)[3], inInclusiveRange(126, 128));

    final composite = await render(
      plan(
        '<feFlood flood-color="blue" flood-opacity="1" result="flood"/>'
        '<feComposite in="SourceGraphic" in2="flood" operator="in"/>',
      ),
    );
    expect(rgba(composite, 20, 20), [255, 0, 0, 255]);
    expect(rgba(composite, 50, 50)[3], 0);

    final blend = await render(
      plan(
        '<feFlood flood-color="blue" flood-opacity="1" result="flood"/>'
        '<feBlend in="SourceGraphic" in2="flood" mode="multiply"/>',
      ),
    );
    expect(rgba(blend, 20, 20), [0, 0, 0, 255]);
    expect(rgba(blend, 50, 50), [0, 0, 255, 255]);

    final merge = await render(
      plan(
        '<feFlood flood-color="blue" flood-opacity="1" result="flood"/>'
        '<feMerge><feMergeNode in="flood"/>'
        '<feMergeNode in="SourceGraphic"/></feMerge>',
      ),
    );
    expect(rgba(merge, 50, 50), [0, 0, 255, 255]);
    expect(rgba(merge, 20, 20), [255, 0, 0, 255]);
  });

  test('filter and primitive units, subregions and graph references', () async {
    final bounded = await render(
      plan(
        '<feFlood flood-color="blue" flood-opacity="1"/>',
        filterAttributes:
            'filterUnits="userSpaceOnUse" x="0" y="0" width="50" height="50" '
            'color-interpolation-filters="sRGB"',
      ),
    );
    expect(rgba(bounded, 25, 25), [0, 0, 255, 255]);
    expect(rgba(bounded, 75, 75)[3], 0);

    final objectBox = await render(
      plan(
        '<feFlood flood-color="blue" flood-opacity="1"/>',
        filterAttributes: 'filterUnits="objectBoundingBox" color-interpolation-filters="sRGB"',
      ),
    );
    expect(rgba(objectBox, 9, 9), [0, 0, 255, 255]);
    expect(rgba(objectBox, 40, 40)[3], 0);

    final primitiveBox = await render(
      plan(
        '<feOffset in="SourceGraphic" dx="1" dy="0"/>',
        filterAttributes:
            'filterUnits="userSpaceOnUse" x="0" y="0" width="100" height="100" '
            'primitiveUnits="objectBoundingBox" color-interpolation-filters="sRGB"',
      ),
    );
    expect(rgba(primitiveBox, 45, 20), [255, 0, 0, 255]);
    expect(rgba(primitiveBox, 20, 20)[3], 0);

    final subregion = await render(
      plan(
        '<feFlood flood-color="blue" flood-opacity="1" '
        'x="0" y="0" width="50" height="50"/>',
      ),
    );
    expect(rgba(subregion, 25, 25), [0, 0, 255, 255]);
    expect(rgba(subregion, 75, 75)[3], 0);

    final references = await render(
      plan(
        '<feFlood flood-color="blue" flood-opacity="1" result="base"/>'
        '<feComposite in="SourceAlpha" in2="base" operator="in"/>',
      ),
    );
    expect(rgba(references, 20, 20), [0, 0, 0, 255]);
    expect(rgba(references, 50, 50)[3], 0);
  });

  test('linearRGB performs blending in linear light', () async {
    Future<List<int>> sample(String interpolation) async {
      final bytes = await render(
        plan(
          '<feFlood flood-color="#808080" flood-opacity="1" result="g"/>'
          '<feBlend in="g" in2="g" mode="screen"/>',
          filterAttributes:
              'filterUnits="userSpaceOnUse" x="0" y="0" width="100" height="100" '
              'color-interpolation-filters="$interpolation"',
        ),
      );
      return rgba(bytes, 50, 50);
    }

    final srgb = await sample('sRGB');
    final linear = await sample('linearRGB');
    expect(srgb[0], inInclusiveRange(188, 194));
    expect(linear[0], inInclusiveRange(163, 172));
    expect(linear[0], lessThan(srgb[0] - 10));
  });

  test('bounds and profile refusals are typed before allocation', () async {
    final unsupported = plan('<feTurbulence baseFrequency=".05"/>');
    expect(unsupported.capability, isA<UnsupportedSectionCapability>());
    expect(
      (unsupported.capability as UnsupportedSectionCapability)
          .constructs
          .single
          .identifier,
      'svg-feTurbulence',
    );

    final background = plan(
      '<feComposite in="BackgroundImage" in2="SourceGraphic" operator="in"/>',
    );
    expect(background.capability, isA<UnsupportedSectionCapability>());
    expect(
      (background.capability as UnsupportedSectionCapability)
          .constructs
          .single
          .identifier,
      'svg-filter-reference',
    );

    final unresolved = plan(
      '<feFlood flood-color="blue"/>',
      shape:
          '<rect x="10" y="10" width="20" height="20" fill="red" '
          'filter="url(#missing)"/>',
    );
    expect(unresolved.capability, isA<UnsupportedSectionCapability>());
    expect(
      (unresolved.capability as UnsupportedSectionCapability)
          .constructs
          .single
          .identifier,
      'svg-filter',
    );

    final oversized = plan(
      '<feFlood flood-color="blue"/>',
      filterAttributes:
          'filterUnits="userSpaceOnUse" x="0" y="0" width="1000" height="1000" '
          'color-interpolation-filters="sRGB"',
    );
    expect(oversized.capability, isA<CompleteSectionCapability>());
    final budget = SceneResourceBudget();
    final scene = await oversized.prepare(budget: budget);
    try {
      expect(scene.capability, isA<UnsupportedSectionCapability>());
      expect(scene.picture, isNull);
      expect(scene.geometry.fragments, isEmpty);
    } finally {
      scene.dispose();
      expect(budget.used.values.every((v) => v == 0), true);
    }
  });

  test(
    'admitted layers fit exactly, including repeated source instances',
    () async {
      final p = plan(
        '<feMerge><feMergeNode in="SourceGraphic"/>'
        '<feMergeNode in="SourceAlpha"/></feMerge>',
        shape:
            '<defs><rect id="r" x="10" y="10" width="20" height="20" '
            'filter="url(#f)"/></defs><use href="#r"/><use href="#r" x="40"/>',
      );
      for (final (preReserved, alreadyDebited) in [
        (false, false),
        (true, false),
        (true, true),
      ]) {
        final request = p.reservation();
        final budget = SceneResourceBudget(
          limits: {
            ...SceneResourceBudget.provisionalLimits,
            SceneResource.layerPixels: request[SceneResource.layerPixels]!,
            SceneResource.layerBytes: request[SceneResource.layerBytes]!,
          },
        );
        final outer = alreadyDebited
            ? budget.reserve({
                SceneResource.layerPixels: request[SceneResource.layerPixels]!,
                SceneResource.layerBytes: request[SceneResource.layerBytes]!,
              })
            : null;
        final scene = await p.prepare(budget: budget, preReserved: preReserved);
        try {
          expect(scene.capability, isA<CompleteSectionCapability>());
          expect(scene.picture, isNotNull);
          expect(scene.geometry.completeness, isA<CompleteGeometry>());
          expect(scene.geometry.paint, hasLength(2));
          final outputs = scene.geometry.paint;
          expect(
            outputs[0].alphaFootprint!.alphaAt(GeometryPoint(20, 20)),
            255,
          );
          expect(
            outputs[1].alphaFootprint!.alphaAt(GeometryPoint(60, 20)),
            255,
          );
          expect(
            budget.used[SceneResource.layerPixels],
            request[SceneResource.layerPixels],
          );
        } finally {
          scene.dispose();
          scene.dispose();
          if (alreadyDebited) {
            expect(
              budget.used[SceneResource.layerPixels],
              request[SceneResource.layerPixels],
            );
          }
          outer?.release();
        }
        expect(budget.used.values.every((v) => v == 0), true);
      }
    },
  );

  test('layer over-budget refuses before creating any picture', () async {
    final p = plan('<feGaussianBlur stdDeviation="2"/>');
    for (final preReserved in [false, true]) {
      for (final resource in [
        SceneResource.layerPixels,
        SceneResource.layerBytes,
        SceneResource.vectorBytes,
      ]) {
        final budget = SceneResourceBudget(
          limits: {
            ...SceneResourceBudget.provisionalLimits,
            resource: p.reservation()[resource]! - 1,
          },
        );
        final pictures = <ui.Picture>[];
        final previous = ui.Picture.onCreate;
        ui.Picture.onCreate = (picture) {
          previous?.call(picture);
          pictures.add(picture);
        };
        try {
          final scene = await p.prepare(
            budget: budget,
            preReserved: preReserved,
          );
          expect(scene.capability, isA<ResourceSectionCapability>());
          expect(
            (scene.capability as ResourceSectionCapability)
                .constructs
                .single
                .identifier,
            'svg-${resource.name}',
          );
          expect(scene.picture, isNull);
          scene.dispose();
          expect(pictures, isEmpty);
          expect(budget.used.values.every((v) => v == 0), true);
        } finally {
          ui.Picture.onCreate = previous;
        }
      }
    }
  });

  test('leases release exactly once on success, failure and cancellation', () async {
    final success = plan('<feGaussianBlur stdDeviation="2"/>');
    final budget = SceneResourceBudget();
    final scene = await success.prepare(budget: budget);
    expect(scene.picture, isNotNull);
    expect(budget.used.values.any((v) => v != 0), true);
    scene.dispose();
    scene.dispose();
    expect(budget.used.values.every((v) => v == 0), true);

    final failure = plan(
      '<feFlood flood-color="blue"/>',
      filterAttributes:
          'filterUnits="userSpaceOnUse" x="0" y="0" width="1000" height="1000" '
          'color-interpolation-filters="sRGB"',
    );
    final failureBudget = SceneResourceBudget();
    final failed = await failure.prepare(budget: failureBudget);
    expect(failed.picture, isNull);
    failed.dispose();
    failed.dispose();
    expect(failureBudget.used.values.every((v) => v == 0), true);

    final canceled = plan('<feGaussianBlur stdDeviation="2"/>');
    final cancelBudget = SceneResourceBudget(),
        token = PublicationCancellation();
    token.cancel();
    await expectLater(
      canceled.prepare(budget: cancelBudget, cancellation: token),
      throwsA(isA<PreparationCancelled>()),
    );
    expect(cancelBudget.used.values.every((v) => v == 0), true);
  });
}

final class _LateSourceFeature extends SvgFeature {
  const _LateSourceFeature();
  @override
  String get key => 'late-source-test';
  @override
  void geometry(SvgFeatureGeometryContext context) {
    final node = context.nodes.singleWhere(
      (n) => n.attributes['filter'] != null,
    );
    // The input rectangle is opaque, but the actual filter output is empty.
    context.geometry.addPaint(
      GeometryPaint(
        nodeIndex: node.nodeIndex,
        paintOrdinal: node.paintOrdinal,
        region: GeometryRegion(
          left: 10,
          top: 10,
          width: 20,
          height: 20,
          transform: const AffineTransform.identity(),
        ),
        kind: GeometryPaintKind.solid,
        effectiveOpacity: 1,
        exactCoverage: true,
      ),
    );
  }
}

final class _PostFilterFeature extends SvgFeature {
  _PostFilterFeature({this.failAfterEvidence = false});
  final bool failAfterEvidence;
  void Function(SvgFeaturePreparation)? onPrepare;
  bool sawEvidence = false;
  @override
  String get key => 'post-filter-test';
  @override
  Set<String> get attributes => const {'filter'};
  @override
  Future<void> prepare(SvgFeaturePreparation context) async =>
      onPrepare?.call(context);
  @override
  void geometry(SvgFeatureGeometryContext context) {
    for (final node in context.nodes) {
      context.markCovered(node);
    }
  }

  @override
  Future<void> postPaint(SvgFeaturePostPaintContext post) async {
    sawEvidence = post.geometry.geometry.paints.any(
      (p) => p.alphaFootprint != null,
    );
    if (failAfterEvidence) {
      throw const SvgFeatureRefusal(0, 'test-after-filter-evidence');
    }
  }
}

final class _AfterFilterFeature extends SvgFeature {
  const _AfterFilterFeature(this.token);
  final PublicationCancellation? token;
  @override
  String get key => 'after-filter';
  @override
  Set<String> get attributes => const {'filter'};
  @override
  void geometry(SvgFeatureGeometryContext context) {
    for (final node in context.nodes) {
      context.markCovered(node);
    }
  }

  @override
  void paint(SvgFeaturePaint context) {
    context.paintDefault();
    if (token != null) {
      token!.cancel();
    } else {
      throw SvgFeatureRefusal(context.node.nodeIndex, 'test-after-filter');
    }
  }
}
