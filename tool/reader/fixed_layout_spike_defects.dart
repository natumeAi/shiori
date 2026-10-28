import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:xml/xml.dart';

/// D3 only: scope comes from independent controls, never mismatch clustering.
final class SpikeReferenceDefects {
  SpikeReferenceDefects(this.oracle);
  final Map<String, Object?> oracle;
  late Map<String, Object?> registry;
  late List<Map<String, Object?>> controls;
  final rasters = <String, Uint8List>{};
  bool staticControlPass = false;
  late String registrySHA256, controlsSHA256;

  Future<void> load() async {
    final policy = File(
      'test/fixtures/reader/fixed_layout/reference-defects.json',
    ).readAsBytesSync();
    final bytes = File('test/fixtures/reader/fixed_layout/paint-controls.json')
        .readAsBytesSync();
    registrySHA256 = sha256.convert(policy).toString();
    controlsSHA256 = sha256.convert(bytes).toString();
    registry = jsonDecode(utf8.decode(policy)) as Map<String, Object?>;
    controls = ((jsonDecode(utf8.decode(bytes)) as Map)['measurements'] as List)
        .cast<Map<String, Object?>>();
    for (final c in controls.where(
      (c) =>
          c['engine'] == oracle['engine'] &&
          c['engineVersion'] == oracle['engineVersion'],
    )) {
      final codec = await ui.instantiateImageCodec(
        base64Decode(c['pngBase64'] as String),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          rasters[_key(c)] = (await frame.image.toByteData(
            format: ui.ImageByteFormat.rawStraightRgba,
          ))!.buffer.asUint8List();
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    }
  }

  Map<String, Object?> control(String id, String mediaType) =>
      controls.firstWhere(
        (c) =>
            c['engine'] == oracle['engine'] &&
            c['engineVersion'] == oracle['engineVersion'] &&
            c['id'] == id &&
            c['mediaType'] == mediaType,
      );

  List<Map<String, Object?>> unmeasured(String reason) => [
    for (final rule in (registry['exceptions'] as List).cast<Map>())
      {
        'id': rule['id'],
        'eligible': false,
        'evidence': {'reason': reason},
        'scopeRule': rule['scopeRule'],
        'expandedGlyphBoxesLTRB': <Object?>[],
      },
  ];

  (Map<int, String>, List<Map<String, Object?>>) scope(
    Map<String, Object?> fixture,
    Map<String, Object?> reference,
    Uint8List native,
    Uint8List expected,
  ) {
    final scope = <int, String>{};
    final decisions = <Map<String, Object?>>[];
    final source = fixture['source'] as String;
    final tree = XmlDocument.parse(source);
    final elements = tree.descendants.whereType<XmlElement>();
    final xhtmlHost =
        fixture['captureHostMediaType'] == 'application/xhtml+xml' ||
        (fixture['captureHostMediaType'] == null &&
            tree.rootElement.namespaceUri == 'http://www.w3.org/1999/xhtml');
    final hasSvg = elements.any(
      (e) =>
          e.name.local == 'svg' &&
          e.namespaceUri == 'http://www.w3.org/2000/svg',
    );
    for (final rule
        in (registry['exceptions'] as List).cast<Map<String, Object?>>()) {
      final engineMatches =
          rule['engine'] == oracle['engine'] &&
          rule['engineVersion'] == oracle['engineVersion'];
      final id = rule['id'] as String;
      var eligible = false;
      final evidence = <String, Object?>{'engineMatches': engineMatches};
      final boxes = <List<int>>[];
      if (id == 'RD-1') {
        final control = rasters['application/xhtml+xml/emptySVG'];
        final recorded = (reference['paintStability'] as Map?)?['topLeft'];
        evidence.addAll({
          'xhtmlHost': xhtmlHost,
          'containsSvg': hasSvg,
          'ownReferenceTopLeft': expected.sublist(0, 4),
          'nativeTopLeft': native.sublist(0, 4),
          'controlTopLeft': control?.sublist(0, 4),
          'recordedTopLeft': recorded,
          'controlsSHA256': controlsSHA256,
        });
        eligible =
            engineMatches &&
            xhtmlHost &&
            hasSvg &&
            control != null &&
            _same(expected.sublist(0, 4), [0, 0, 0, 38]) &&
            _same(control.sublist(0, 4), [0, 0, 0, 38]) &&
            _same(native.sublist(0, 4), [0, 0, 0, 0]);
        if (eligible) scope[0] = id;
      } else if (id == 'RD-2') {
        final candidates = elements
            .where(
              (e) =>
                  e.name.local == 'span' &&
                  e.innerText.trim() == 'Z' &&
                  e.ancestors.whereType<XmlElement>().any(
                    (a) =>
                        a.name.local == 'foreignObject' &&
                        a.namespaceUri == 'http://www.w3.org/2000/svg',
                  ) &&
                  RegExp(r'position\s*:\s*relative\s*;')
                      .hasMatch(e.getAttribute('style') ?? '') &&
                  RegExp(r'top\s*:\s*3px\s*(;|$)')
                      .hasMatch(e.getAttribute('style') ?? ''),
            )
            .toList();
        evidence.addAll({
          'matchingRelativeZSpans': candidates.length,
          'staticControlPass': staticControlPass,
        });
        if (!engineMatches || candidates.length != 1) {
          decisions.add({
            'id': id,
            'eligible': false,
            'evidence': evidence,
            'scopeRule': rule['scopeRule'],
            'expandedGlyphBoxesLTRB': boxes,
          });
          continue;
        }
        final staticRaster = rasters['text/html/foreignStatic']!;
        final relativeRaster = rasters['text/html/foreignRelative']!;
        final staticBox = _spanInk(staticRaster, without: relativeRaster);
        final relativeBox = _spanInk(relativeRaster, without: staticRaster);
        final xhtmlBox = _spanInk(
          rasters['application/xhtml+xml/foreignRelative']!,
          without: rasters['application/xhtml+xml/foreignStatic']!,
        );
        if (staticBox.length != 4 ||
            relativeBox.length != 4 ||
            xhtmlBox.length != 4) {
          decisions.add({
            'id': id,
            'eligible': false,
            'evidence': evidence,
            'scopeRule': rule['scopeRule'],
            'expandedGlyphBoxesLTRB': boxes,
          });
          continue;
        }
        // Derive translation from the source, never a case id or variant.
        // The independently captured pair still has to match both glyph boxes.
        final translated = candidates.single.ancestors
            .whereType<XmlElement>()
            .map((e) => e.getAttribute('style') ?? '')
            .where((s) => RegExp(r'transform\s*:').hasMatch(s));
        var supportedPlacement = true;
        var dx = 0, dy = 0;
        for (final style in translated) {
          final match = RegExp(
            r'transform\s*:\s*translate\(\s*(-?\d+)px\s*,\s*(-?\d+)px\s*\)\s*(;|$)',
          ).firstMatch(style);
          if (match == null) {
            supportedPlacement = false;
          } else {
            dx += int.parse(match[1]!);
            dy += int.parse(match[2]!);
          }
        }
        final painted = _spanInk(
          expected,
          without: staticRaster,
          dx: dx,
          dy: dy,
        );
        final referenceBox = [
          for (var i = 0; i < 4; i++) relativeBox[i] + (i.isEven ? dx : dy),
        ];
        final nativeBox = [
          for (var i = 0; i < 4; i++) staticBox[i] + (i.isEven ? dx : dy + 3),
        ];
        // Prove the native glyph remains at the CSS position before excusing
        // either raster region. A native-only displacement cannot use RD-2.
        final nativeSupport = _redBoundsIn(native, [
          nativeBox[0] - 1,
          nativeBox[1] - 1,
          nativeBox[2] + 1,
          nativeBox[3] + 1,
        ]);
        eligible =
            supportedPlacement &&
            staticControlPass &&
            !_same(staticBox, relativeBox) &&
            _same(relativeBox, xhtmlBox) &&
            _same(painted, referenceBox) &&
            _same(nativeSupport, nativeBox);
        evidence.addAll({
          'sourceTranslation': [dx, dy],
          'supportedPlacement': supportedPlacement,
          'staticGlyphBox': staticBox,
          'relativeGlyphBox': relativeBox,
          'xhtmlRelativeGlyphBox': xhtmlBox,
          'ownReferenceGlyphBox': painted,
          'nativeGlyphBox': nativeSupport,
        });
        if (eligible) {
          for (final box in [nativeBox, referenceBox]) {
            final expanded = [box[0] - 1, box[1] - 1, box[2] + 1, box[3] + 1];
            boxes.add(expanded);
            for (var y = expanded[1]; y < expanded[3]; y++) {
              for (var x = expanded[0]; x < expanded[2]; x++) {
                if (x >= 0 && x < 320 && y >= 0 && y < 240) {
                  scope[y * 320 + x] = id;
                }
              }
            }
          }
        }
      }
      decisions.add({
        'id': id,
        'eligible': eligible,
        'evidence': evidence,
        'scopeRule': rule['scopeRule'],
        'controlIds': rule['controlIds'],
        'expandedGlyphBoxesLTRB': boxes,
        'handoff': rule['handoff'],
      });
    }
    return (scope, decisions);
  }

  String _key(Map<String, Object?> c) => '${c['mediaType']}/${c['id']}';
}

List<int> _redBoundsIn(Uint8List rgba, List<int> crop) {
  int? left, top, right, bottom;
  for (var y = math.max(0, crop[1]); y < math.min(240, crop[3]); y++) {
    for (var x = math.max(0, crop[0]); x < math.min(320, crop[2]); x++) {
      final i = (y * 320 + x) * 4;
      if (rgba[i] == 0 ||
          rgba[i + 1] != 0 ||
          rgba[i + 2] != 0 ||
          rgba[i + 3] == 0) {
        continue;
      }
      left = math.min(left ?? x, x);
      top = math.min(top ?? y, y);
      right = math.max(right ?? x + 1, x + 1);
      bottom = math.max(bottom ?? y + 1, y + 1);
    }
  }
  return left == null ? [] : [left, top!, right!, bottom!];
}

bool _same(List a, List b) =>
    a.length == b.length &&
    List.generate(a.length, (i) => a[i] == b[i]).every((v) => v);

// Red support introduced by the independently captured relative/static pair
// isolates the displaced Z. No native mismatch is used to define its scope.
List<int> _spanInk(
  Uint8List rgba, {
  required Uint8List without,
  int dx = 0,
  int dy = 0,
}) {
  bool red(Uint8List bytes, int x, int y) {
    if (x < 0 || x >= 320 || y < 0 || y >= 240) return false;
    final i = (y * 320 + x) * 4;
    return bytes[i] > 0 &&
        bytes[i + 1] == 0 &&
        bytes[i + 2] == 0 &&
        bytes[i + 3] > 0;
  }

  int? left, top, right, bottom;
  for (var y = 0; y < 240; y++) {
    for (var x = 0; x < 320; x++) {
      if (!red(rgba, x, y) || red(without, x - dx, y - dy)) continue;
      left = math.min(left ?? x, x);
      top = math.min(top ?? y, y);
      right = math.max(right ?? x + 1, x + 1);
      bottom = math.max(bottom ?? y + 1, y + 1);
    }
  }
  if (left == null) return [];
  return [left, top!, right!, bottom!];
}
