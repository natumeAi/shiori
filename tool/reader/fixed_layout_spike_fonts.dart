import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';

/// Same-table source wrappers are loaded through the actual native font API.
/// A completed registration future is not accepted as proof of usable glyphs:
/// compare shaped width to both pinned SFNT and an absent-family control.
Future<List<Map<String, Object?>>> runSpikeFonts(
  Map<String, Object?> oracle,
) async {
  final manifest = jsonDecode(
    File('test/fixtures/reader/fixed_layout/fonts.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final faces = (manifest['faces'] as List<Object?>)
      .cast<Map<String, Object?>>();
  final references = (oracle['fontProbes'] as List<Object?>)
      .cast<Map<String, Object?>>();
  final result = <Map<String, Object?>>[];
  final control = _shape('FixedLayoutSpikeAbsentControl');
  double? sfntWidth;
  for (final face in faces) {
    final bytes = File(face['path'] as String).readAsBytesSync();
    if (bytes.length != face['bytes'] ||
        sha256.convert(bytes).toString() != face['sha256']) {
      throw StateError('Font wrapper provenance mismatch');
    }
    final format = face['format'] as String;
    final family = format == 'sfnt'
        ? 'FixedLayoutSpikeRoboto'
        : 'FixedLayoutSpike$format';
    var completed = format == 'sfnt';
    try {
      if (!completed) {
        await ui.loadFontFromList(bytes, fontFamily: family);
        completed = true;
      }
    } catch (_) {
      completed = false;
    }
    final shaped = _shape(family);
    final width = shaped['width'] as double;
    if (format == 'sfnt') sfntWidth = width;
    final reference = references.singleWhere((f) => f['format'] == format);
    final delta = (width - (reference['width'] as num)).abs();
    result.add({
      ...face,
      'registrationFutureCompleted': completed,
      'native': shaped,
      'absentFamilyControl': control,
      'differentFromAbsentControl': width != control['width'],
      'sameSfntShapedWidth': (width - sfntWidth!).abs() <= .01,
      'browserLoaded': reference['loaded'],
      'browserWidth': reference['width'],
      'widthDeltaCssPx': delta,
      'fidelityGate': completed && width != control['width'] && delta <= .5,
      'scope': 'Host native API and same-table wrapper shaping only; no iPhone font admission proof.',
    });
  }
  return result;
}

Map<String, Object?> _shape(String family) {
  const text = 'Ab fi e\u0301 Z';
  final builder =
      ui.ParagraphBuilder(
          ui.ParagraphStyle(
            fontFamily: family,
            fontSize: 20,
            textDirection: ui.TextDirection.ltr,
          ),
        )
        ..pushStyle(ui.TextStyle(fontFamily: family, fontSize: 20))
        ..addText(text);
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: 10000));
  try {
    return {
      'text': text,
      'utf16Length': text.length,
      'width': paragraph.longestLine,
      'baseline': paragraph.alphabeticBaseline,
      'clusters': [
        for (var i = 0; i < text.length; i++)
          {
            'utf16': i,
            'range': paragraph.getGlyphInfoAt(i) == null
                ? null
                : [
                    paragraph
                        .getGlyphInfoAt(i)!
                        .graphemeClusterCodeUnitRange
                        .start,
                    paragraph
                        .getGlyphInfoAt(i)!
                        .graphemeClusterCodeUnitRange
                        .end,
                  ],
            'boxes': [
              for (final box in paragraph.getBoxesForRange(i, i + 1))
                [box.left, box.top, box.right - box.left, box.bottom - box.top],
            ],
          },
      ],
    };
  } finally {
    paragraph.dispose();
  }
}
