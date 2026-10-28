import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:xml/xml.dart';
import 'package:shiori/features/reader/engine/text/harfbuzz/harfbuzz.dart';

Map<String, Object?> readFixtureJson(String name) => jsonDecode(
  File('test/fixtures/reader/fixed_layout/$name.json').readAsStringSync(),
) as Map<String, Object?>;

List<(Map<String, Object?>, Map<String, Object?>)> requiredCases(
  Map<String, Object?> corpus,
  Map<String, Object?> oracle,
) {
  return [
    for (final c in (corpus['cases'] as List).cast<Map<String, Object?>>())
      if (c['row'] == 'svg-text' && c['expectedCapability'] != 'unsupported')
        (
          c,
          (oracle['cases'] as List).cast<Map<String, Object?>>().singleWhere(
            (r) => r['id'] == c['id'],
          ),
        ),
    for (final p
        in (oracle['svgTextProbes'] as List).cast<Map<String, Object?>>())
      (
        {
          'id': 'svg-text-path-${p['adjustment']}',
          'source': p['source'],
          'captureHostMediaType': 'application/xhtml+xml',
          'captureBodyMargin': [8, 8],
        },
        {
          'svgTexts': [p],
          'pngBase64': p['pngBase64'],
          'paintStability': p['paintStability'],
          'samples': <Object?>[],
        },
      ),
  ];
}

/// Test-only source adapter. Reads authored attributes, never reference metrics.
List<(HarfBuzzRun, HarfBuzzPlacedRun)> prepareFixture(
  String source,
  HarfBuzzFont font,
  HarfBuzzResources resources,
) {
  final document = XmlDocument.parse(source);
  final output = <(HarfBuzzRun, HarfBuzzPlacedRun)>[];
  try {
    for (final element in document.descendants.whereType<XmlElement>().where(
      (e) => e.name.local == 'text',
    )) {
      final nodes = element.descendants.whereType<XmlText>().toList();
      final text = nodes.map((n) => n.value).join();
      final firstIndices = <XmlElement, int>{};
      var global = 0;
      for (final node in nodes) {
        for (final ancestor in node.ancestors.whereType<XmlElement>()) {
          firstIndices.putIfAbsent(ancestor, () => global);
          if (ancestor == element) break;
        }
        global += node.value.length;
      }
      final positions = <HarfBuzzPosition>[];
      global = 0;
      for (final node in nodes) {
        final ancestors = node.ancestors
            .whereType<XmlElement>()
            .takeWhile((e) => e != element)
            .toList();
        for (var local = 0; local < node.value.length; local++) {
          final values = <String, double>{};
          for (final a in [element, ...ancestors.reversed]) {
            final index = global + local - firstIndices[a]!;
            for (final key in ['x', 'y', 'dx', 'dy', 'rotate']) {
              final raw = a.getAttribute(key);
              if (raw == null) continue;
              final numbers = raw
                  .split(RegExp(r'[\s,]+'))
                  .map(double.parse)
                  .toList();
              if (index < numbers.length || key == 'rotate') {
                values[key] =
                    numbers[index < numbers.length
                        ? index
                        : numbers.length - 1];
              }
            }
          }
          positions.add(
            HarfBuzzPosition(
              x: values['x'],
              y: values['y'],
              dx: values['dx'] ?? 0,
              dy: values['dy'] ?? 0,
              rotationDegrees: values['rotate'] ?? 0,
            ),
          );
        }
        global += node.value.length;
      }
      final pathNode = element.descendantElements
          .where((e) => e.name.local == 'textPath')
          .firstOrNull;
      final run = font.shapeRun(text);
      HarfBuzzQuadraticPath? path;
      HarfBuzzPlacedRun? placed;
      try {
        if (pathNode != null) {
          final id = pathNode.getAttribute('href')!.substring(1);
          final d = document.descendants
              .whereType<XmlElement>()
              .singleWhere((e) => e.getAttribute('id') == id)
              .getAttribute('d')!;
          final p = RegExp(r'[-+]?(?:\d*\.)?\d+')
              .allMatches(d)
              .map((m) => double.parse(m[0]!))
              .toList();
          if (!d.startsWith('M') || !d.contains('Q') || p.length != 6) {
            throw StateError('Fixture outside the quadratic profile');
          }
          path = HarfBuzzQuadraticPath(
            start: ui.Offset(p[0], p[1]),
            control: ui.Offset(p[2], p[3]),
            end: ui.Offset(p[4], p[5]),
            resources: resources,
          );
        }
        final raw = pathNode?.getAttribute('startOffset') ?? '0';
        // A nested textPath has its own length scope in this reference profile.
        placed = run.place(
          positions: positions,
          anchorMiddle: element.getAttribute('text-anchor') == 'middle',
          textLength: double.tryParse(
            pathNode?.getAttribute('textLength') ?? '',
          ),
          lengthAdjust:
              pathNode?.getAttribute('lengthAdjust') == 'spacingAndGlyphs'
              ? HarfBuzzLengthAdjust.spacingAndGlyphs
              : HarfBuzzLengthAdjust.spacing,
          path: path,
          startOffset: raw.endsWith('%')
              ? HarfBuzzStartOffset.percent(
                  double.parse(raw.substring(0, raw.length - 1)),
                )
              : HarfBuzzStartOffset.absolute(double.parse(raw)),
        );
        output.add((run, placed));
      } catch (_) {
        placed?.dispose();
        run.dispose();
        rethrow;
      } finally {
        path?.dispose();
      }
    }
    return output;
  } catch (_) {
    for (final (run, placed) in output.reversed) {
      placed.dispose();
      run.dispose();
    }
    rethrow;
  }
}
