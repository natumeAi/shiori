import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/geometry/cluster_geometry.dart';
import 'package:shiori/features/reader/data/geometry/paint_geometry.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/support/section_capability.dart';

import '../../../contract_test_values.dart';

SvgGraphicsPlan _plan(String children) {
  final document = const SourceParser().parse(
    '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="100">$children</svg>',
    mediaType: 'image/svg+xml',
  );
  return SvgGraphicsPlan.inspect(
    document: document,
    rootIndex: document.documentElementIndex,
    page: contractPage(),
    size: AuthoredPageSize(100, 100),
  );
}

Future<Uint8List> _pixels(SvgGraphicsScene scene) async {
  final image = await scene.picture!.toImage(100, 100);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer
        .asUint8List();
  } finally {
    image.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('role footprint payload is prepaid before native preparation', () async {
    final plan = _plan(
      '<rect x="20" y="20" width="60" height="50" fill="red" stroke="blue"/>',
    );
    final request = plan.reservation();
    expect(
      request[SceneResource.vectorBytes]! -
          plan.resources[SceneResource.vectorBytes]! -
          2 * 1024 * 1024,
      2 * (100 * 100 + GeometryAlphaFootprint.storageOverhead),
    );
    final budget = SceneResourceBudget(
      limits: {
        ...SceneResourceBudget.provisionalLimits,
        SceneResource.vectorBytes: request[SceneResource.vectorBytes]! - 1,
      },
    );
    final refused = await plan.prepare(budget: budget);
    expect(refused.capability, isA<ResourceSectionCapability>());
    expect(refused.picture, isNull);
    expect(refused.geometry.paint, isEmpty);
    refused.dispose();
    expect(budget.used.values.every((v) => v == 0), true);
    final admitted = SceneResourceBudget(
      limits: {
        ...SceneResourceBudget.provisionalLimits,
        SceneResource.vectorBytes: request[SceneResource.vectorBytes]!,
      },
    );
    final scene = await plan.prepare(budget: admitted);
    try {
      expect(scene.capability.isComplete, true);
      expect(scene.geometry.paint, hasLength(2));
      expect(
        scene.geometry.paint.fold<int>(
          0,
          (n, p) => n + p.alphaFootprint!.storageBytes,
        ),
        lessThanOrEqualTo(
          2 * (100 * 100 + GeometryAlphaFootprint.storageOverhead),
        ),
      );
      expect(
        admitted.used[SceneResource.vectorBytes],
        request[SceneResource.vectorBytes],
      );
    } finally {
      scene.dispose();
    }
    expect(admitted.used.values.every((v) => v == 0), true);
  });
  test('unsupported paint-order remains a typed refusal', () {
    expect(
      _plan(
        '<rect width="40" height="40" fill="red" stroke="blue" paint-order="stroke fill"/>',
      ).capability,
      isA<UnsupportedSectionCapability>(),
    );
  });
  const shapes = {
    'rect': '<rect x="20" y="20" width="60" height="50"',
    'circle': '<circle cx="50" cy="50" r="30"',
    'path': '<path d="M20 20H80L50 80Z"',
  };
  for (final effect in ['clip-path="url(#clip)"', 'mask="url(#mask)"']) {
    test('$effect preserves role evidence after feature composition', () async {
      final budget = SceneResourceBudget();
      final scene = await _plan(
        '<defs><clipPath id="clip"><rect width="50" height="100"/></clipPath>'
        '<mask id="mask" maskUnits="userSpaceOnUse" x="0" y="0" width="100" height="100">'
        '<rect width="50" height="100" fill="white"/></mask></defs>'
        '<rect x="20" y="20" width="60" height="50" fill="red" stroke="blue" stroke-width="8" $effect/>',
      ).prepare(budget: budget);
      try {
        expect(scene.capability.isComplete, true);
        expect(scene.geometry.paint.map((p) => p.role), [
          GeometryPaintRole.fill,
          GeometryPaintRole.stroke,
        ]);
        for (final p in scene.geometry.paint) {
          expect(p.alphaFootprint, isNotNull);
          if (effect.startsWith('mask')) expect(p.masks, hasLength(1));
        }
      } finally {
        scene.dispose();
      }
      expect(budget.used.values.every((v) => v == 0), true);
    });
  }
  test('pattern fill and dashed gradient stroke retain their own alpha', () async {
    const definitions =
        '<defs><pattern id="p" width="8" height="8" patternUnits="userSpaceOnUse">'
        '<rect width="4" height="8" fill="red"/></pattern>'
        '<linearGradient id="g"><stop stop-color="blue"/><stop offset="1" stop-color="green"/></linearGradient></defs>';
    String source(String fill, String stroke) =>
        '$definitions<rect x="20" y="20" width="60" height="50" '
        'fill="$fill" stroke="$stroke" stroke-width="8" stroke-dasharray="10 14" stroke-linecap="round"/>';
    final budget = SceneResourceBudget();
    final scene = await _plan(source('url(#p)', 'url(#g)'))
        .prepare(budget: budget);
    try {
      expect(scene.capability.isComplete, true);
      for (final p in scene.geometry.paint) {
        final fill = p.role == GeometryPaintRole.fill;
        final controlBudget = SceneResourceBudget();
        final control = await _plan(
          source(fill ? 'url(#p)' : 'none', fill ? 'none' : 'url(#g)'),
        ).prepare(budget: controlBudget);
        try {
          expect(control.capability.isComplete, true);
          final expected = await _pixels(control);
          for (var y = 0; y < 100; y++) {
            for (var x = 0; x < 100; x++) {
              expect(
                p.alphaFootprint!.alphaAt(GeometryPoint(x + .5, y + .5)),
                expected[(y * 100 + x) * 4 + 3],
              );
            }
          }
        } finally {
          control.dispose();
        }
        expect(controlBudget.used.values.every((v) => v == 0), true);
      }
    } finally {
      scene.dispose();
    }
    expect(budget.used.values.every((v) => v == 0), true);
  });
  for (final shape in shapes.entries) {
    for (final cap in ['butt', 'round', 'square']) {
      for (final join in ['miter', 'round', 'bevel']) {
        test(
          '${shape.key} role alpha matches native $cap/$join dashed paint',
          () async {
            String source(String fill, String stroke) =>
                '${shape.value} fill="$fill" stroke="$stroke" '
                'fill-opacity=".6" stroke-opacity=".7" stroke-width="9" '
                'stroke-linecap="$cap" stroke-linejoin="$join" '
                'stroke-dasharray="10 14" stroke-dashoffset="3" '
                'transform="translate(3 2) rotate(7 50 50)"/>';
            final budget = SceneResourceBudget();
            final scene = await _plan(source('red', 'blue'))
                .prepare(budget: budget);
            try {
              expect(scene.capability.isComplete, true);
              expect(scene.geometry.paint.map((p) => p.role), [
                GeometryPaintRole.fill,
                GeometryPaintRole.stroke,
              ]);
              expect(scene.geometry.fragments, hasLength(2));
              final both = await _pixels(scene);
              for (final paint in scene.geometry.paint) {
                final fill = paint.role == GeometryPaintRole.fill;
                final controlBudget = SceneResourceBudget();
                final control = await _plan(
                  source(fill ? 'red' : 'none', fill ? 'none' : 'blue'),
                ).prepare(budget: controlBudget);
                try {
                  expect(control.capability.isComplete, true);
                  final expected = await _pixels(control);
                  var covered = 0, absent = 0, overlap = 0;
                  for (var y = 0; y < 100; y++) {
                    for (var x = 0; x < 100; x++) {
                      final point = GeometryPoint(x + .5, y + .5);
                      final index = (y * 100 + x) * 4 + 3;
                      final alpha = paint.alphaFootprint!.alphaAt(point);
                      expect(
                        alpha,
                        expected[index],
                        reason: '$x,$y ${paint.role}',
                      );
                      if (alpha! > 0) covered++;
                      if (alpha == 0 && both[index] > 0) absent++;
                      if (scene.geometry.paint.every(
                        (p) => p.alphaFootprint!.alphaAt(point)! > 0,
                      )) {
                        overlap++;
                      }
                    }
                  }
                  expect(covered, greaterThan(0));
                  expect(absent, greaterThan(0));
                  expect(overlap, greaterThan(0));
                } finally {
                  control.dispose();
                }
                expect(controlBudget.used.values.every((v) => v == 0), true);
              }
            } finally {
              scene.dispose();
            }
            expect(budget.used.values.every((v) => v == 0), true);
          },
        );
      }
    }
  }
}
