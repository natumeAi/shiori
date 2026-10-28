import 'dart:math' as math;
import 'dart:typed_data';

const d4ComponentAlphaThreshold = 32;

/// D8 expands native text coverage and reference text geometry by one pixel.
const d8TextMaskDilationPixels = 1;

/// D8 reports text raster parity on the device; it is never a host pass.
const textRasterParityStatus = 'device-gated (A5)';

/// D8 text pixels are excluded from the D4 component sub-rule only.
///
/// [pixels] is a viewport-sized mask (1 = text pixel). Masks are built from
/// native glyph coverage plus reference text geometry, both dilated by one
/// pixel, and are applied identically to both images.
final class SpikeTextMask {
  SpikeTextMask._({
    required this.pixels,
    required this.provenance,
    required this.nativeGlyphCoveragePixels,
    required this.referenceGeometryPixels,
    required this.referenceGeometryBoxes,
    required this.maskPixels,
  });
  final Uint8List pixels;
  final Map<String, Object?> provenance;
  final int nativeGlyphCoveragePixels;
  final int referenceGeometryPixels;
  final int referenceGeometryBoxes;
  final int maskPixels;
}

/// Builds the D8 mask at DPR 1.
///
/// Native coverage is an alpha-positive bitmap of the native text paint; it
/// is dilated by [dilationPixels] in all eight directions. Reference geometry
/// arrives as LTRB CSS-pixel boxes and each box is expanded by
/// [dilationPixels] before rasterising. The union is applied to both images.
SpikeTextMask buildD8TextMask({
  required Uint8List? nativeGlyphCoverage,
  required List<List<double>> referenceGeometryLtrb,
  required Map<String, Object?> provenance,
  int width = 320,
  int height = 240,
  int dilationPixels = d8TextMaskDilationPixels,
}) {
  final pixels = width * height;
  if (nativeGlyphCoverage != null && nativeGlyphCoverage.length != pixels) {
    throw StateError('Native text coverage viewport mismatch');
  }
  if (dilationPixels < 0) throw ArgumentError('Negative mask dilation');
  final mask = Uint8List(pixels);
  var nativeCount = 0;
  if (nativeGlyphCoverage != null) {
    for (var i = 0; i < pixels; i++) {
      if (nativeGlyphCoverage[i] == 0) continue;
      nativeCount++;
      final x = i % width, y = i ~/ width;
      for (var dy = -dilationPixels; dy <= dilationPixels; dy++) {
        for (var dx = -dilationPixels; dx <= dilationPixels; dx++) {
          final xx = x + dx, yy = y + dy;
          if (xx < 0 || xx >= width || yy < 0 || yy >= height) continue;
          mask[yy * width + xx] = 1;
        }
      }
    }
  }
  final rawReference = Uint8List(pixels);
  for (final box in referenceGeometryLtrb) {
    if (box.length != 4 ||
        box.any((v) => !v.isFinite) ||
        box[2] < box[0] ||
        box[3] < box[1]) {
      throw ArgumentError('Invalid reference text geometry: $box');
    }
    final left = box[0], top = box[1], right = box[2], bottom = box[3];
    final rawLeft = left.floor(), rawRight = right.ceil() - 1;
    final rawTop = top.floor(), rawBottom = bottom.ceil() - 1;
    for (
      var y = math.max(0, rawTop);
      y <= math.min(height - 1, rawBottom);
      y++
    ) {
      for (
        var x = math.max(0, rawLeft);
        x <= math.min(width - 1, rawRight);
        x++
      ) {
        rawReference[y * width + x] = 1;
      }
    }
    final expandedLeft = math.max(0, (left - dilationPixels).floor());
    final expandedRight = math.min(
      width - 1,
      (right + dilationPixels).ceil() - 1,
    );
    final expandedTop = math.max(0, (top - dilationPixels).floor());
    final expandedBottom = math.min(
      height - 1,
      (bottom + dilationPixels).ceil() - 1,
    );
    for (var y = expandedTop; y <= expandedBottom; y++) {
      for (var x = expandedLeft; x <= expandedRight; x++) {
        mask[y * width + x] = 1;
      }
    }
  }
  var referenceCount = 0, maskCount = 0;
  for (var i = 0; i < pixels; i++) {
    if (rawReference[i] != 0) referenceCount++;
    if (mask[i] != 0) maskCount++;
  }
  return SpikeTextMask._(
    pixels: mask,
    provenance: {
      ...provenance,
      'definition':
          'D8: native glyph coverage plus reference text geometry, each dilated '
          'by $dilationPixels px, applied identically to both images',
      'dilationPixels': dilationPixels,
      'viewport': [width, height],
      'referenceGeometryBoxes': referenceGeometryLtrb.length,
      'componentSubRuleOnly': true,
    },
    nativeGlyphCoveragePixels: nativeCount,
    referenceGeometryPixels: referenceCount,
    referenceGeometryBoxes: referenceGeometryLtrb.length,
    maskPixels: maskCount,
  );
}

/// D4 uses straight RGBA at DPR 1. Exemptions are explicit D3 pixel scopes.
///
/// Under D8, [textMask] removes text pixels from the component sub-rule only.
/// Interior, edge-band, support-bound and sample sub-rules still cover them.
Map<String, Object?> compareSpikePixels(
  Uint8List actual,
  Uint8List expected, {
  Map<int, String> exemptScope = const {},
  int maximumSampleDelta = 0,
  SpikeTextMask? textMask,
}) {
  if (actual.length != 320 * 240 * 4 || actual.length != expected.length) {
    throw StateError('PNG viewport mismatch');
  }
  var changed = 0, interior = 0, missing = 0, extra = 0, maxDelta = 0;
  var outsideEdge = 0, remaining = 0;
  var nativeTextExcluded = 0, referenceTextExcluded = 0;
  final tiles = <String, int>{};
  final examples = <Map<String, Object?>>[];
  final exemptions = <Map<String, Object?>>[];
  final aSupport = Uint8List(320 * 240), bSupport = Uint8List(320 * 240);
  final aTopology = Uint8List(320 * 240), bTopology = Uint8List(320 * 240);
  final textPixels = textMask?.pixels;
  for (var y = 0; y < 240; y++) {
    for (var x = 0; x < 320; x++) {
      final index = y * 320 + x;
      final a = _pixel(actual, index), b = _pixel(expected, index);
      if (!exemptScope.containsKey(index)) {
        aSupport[index] = a[3] > 0 ? 1 : 0;
        bSupport[index] = b[3] > 0 ? 1 : 0;
        final text = textPixels != null && textPixels[index] != 0;
        final aTopologyPixel = a[3] >= d4ComponentAlphaThreshold;
        final bTopologyPixel = b[3] >= d4ComponentAlphaThreshold;
        aTopology[index] = aTopologyPixel && !text ? 1 : 0;
        bTopology[index] = bTopologyPixel && !text ? 1 : 0;
        if (text && aTopologyPixel) nativeTextExcluded++;
        if (text && bTopologyPixel) referenceTextExcluded++;
      }
      final delta = a[3] == 0 && b[3] == 0 ? 0 : _delta(a, b);
      maxDelta = math.max(maxDelta, delta);
      if (delta <= 2) continue;
      changed++;
      final detail = <String, Object?>{
        'x': x,
        'y': y,
        'native': a,
        'reference': b,
        'maximumChannelDelta': delta,
      };
      if (examples.length < 100) examples.add(detail);
      final key = '${x ~/ 16},${y ~/ 16}';
      tiles[key] = (tiles[key] ?? 0) + 1;
      if (b[3] > 16 && a[3] == 0) missing++;
      if (a[3] > 16 && b[3] == 0) extra++;
      if (exemptScope.containsKey(index)) {
        exemptions.add({...detail, 'defect': exemptScope[index]});
        continue;
      }
      remaining++;
      var flat = x > 0 && y > 0 && x < 319 && y < 239;
      var edge = false;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx, yy = y + dy;
          if (xx < 0 || xx >= 320 || yy < 0 || yy >= 240) continue;
          final aa = _pixel(actual, yy * 320 + xx);
          final bb = _pixel(expected, yy * 320 + xx);
          if (_delta(a, aa) > 2 || _delta(b, bb) > 2) flat = false;
          if ((aa[3] > 0 && aa[3] < 255) || (bb[3] > 0 && bb[3] < 255)) {
            edge = true;
          }
        }
      }
      if (flat) interior++;
      if (!edge) outsideEdge++;
    }
  }
  final aBounds = _bounds(aSupport), bBounds = _bounds(bSupport);
  final aComponents = _components(aTopology),
      bComponents = _components(bTopology);
  final pairing = _pairComponents(aComponents, bComponents);
  final d4 = <String, Object?>{
    'interior': {'pass': interior == 0, 'mismatchPixels': interior},
    'edgeNeighbourhood': {
      'pass': outsideEdge == 0,
      'outsidePixels': outsideEdge,
    },
    'supportBounds': {
      'pass': _near(aBounds, bBounds),
      'native': aBounds,
      'reference': bBounds,
    },
    'components': {
      'alphaThresholdInclusive': d4ComponentAlphaThreshold,
      'pass': pairing != null,
      'nativeCount': aComponents.length,
      'referenceCount': bComponents.length,
      'nativeBounds': aComponents,
      'referenceBounds': bComponents,
      'pairs': pairing,
      'textMask': textMask == null
          ? {'applied': false}
          : {
              'applied': true,
              'componentSubRuleOnly': true,
              'excludedTopologyPixelsPerImage': {
                'native': nativeTextExcluded,
                'reference': referenceTextExcluded,
              },
            },
    },
    'samples': {
      'pass': maximumSampleDelta == 0,
      'maximumChannelDelta': maximumSampleDelta,
    },
  };
  final pass = d4.values.every((v) => (v as Map)['pass'] == true);
  return {
    'status': pass ? 'pass' : 'fail',
    'pass': pass,
    'd4': d4,
    'changedPixels': changed,
    'nonExemptChangedPixels': remaining,
    'interiorMismatchPixels': interior,
    'edgeOrGradientMismatchPixels': remaining - interior,
    'missingVisiblePixels': missing,
    'extraVisiblePixels': extra,
    'maximumChannelDelta': maxDelta,
    'mismatchPixelsPer16pxTile': tiles,
    'firstChangedPixels': examples,
    'exemptPixels': exemptions.length,
    'exemptCoordinates': exemptions,
    'exemptCounts': {
      for (final id in ['RD-1', 'RD-2'])
        id: exemptions.where((p) => p['defect'] == id).length,
    },
    'scopePixelCounts': {
      for (final id in ['RD-1', 'RD-2'])
        id: exemptScope.values.where((v) => v == id).length,
    },
    'textMask': textMask == null
        ? {'applied': false}
        : {
            'applied': true,
            'provenance': textMask.provenance,
            'maskPixels': textMask.maskPixels,
            'nativeGlyphCoveragePixels': textMask.nativeGlyphCoveragePixels,
            'referenceGeometryPixels': textMask.referenceGeometryPixels,
            'referenceGeometryBoxes': textMask.referenceGeometryBoxes,
            'dilationPixels': d8TextMaskDilationPixels,
            'excludedPixelsPerImage': {
              'native': nativeTextExcluded,
              'reference': referenceTextExcluded,
            },
            'scope': 'component sub-rule only; interior, edge, support and sample rules unchanged',
          },
    'textRasterParity': textMask == null ? null : textRasterParityStatus,
    'interpretation':
        'D4 outside recorded D3 scopes; raw differences include exemptions.',
  };
}

List<int> _pixel(Uint8List bytes, int index) =>
    bytes.sublist(index * 4, index * 4 + 4);
int _delta(List<int> a, List<int> b) =>
    List.generate(4, (i) => (a[i] - b[i]).abs()).reduce(math.max);

List<int>? _bounds(Uint8List support) {
  int? left, top, right, bottom;
  for (var i = 0; i < support.length; i++) {
    if (support[i] == 0) continue;
    final x = i % 320, y = i ~/ 320;
    left = math.min(left ?? x, x);
    top = math.min(top ?? y, y);
    right = math.max(right ?? x + 1, x + 1);
    bottom = math.max(bottom ?? y + 1, y + 1);
  }
  return left == null ? null : [left, top!, right!, bottom!];
}

bool _near(List<int>? a, List<int>? b) => a == null || b == null
    ? a == null && b == null
    : List.generate(4, (i) => (a[i] - b[i]).abs()).every((d) => d <= 1);

List<List<int>> _components(Uint8List support) {
  final visited = Uint8List(support.length);
  final result = <List<int>>[];
  for (var start = 0; start < support.length; start++) {
    if (support[start] == 0 || visited[start] != 0) continue;
    final queue = <int>[start];
    visited[start] = 1;
    var left = start % 320, right = left + 1;
    var top = start ~/ 320, bottom = top + 1;
    for (var head = 0; head < queue.length; head++) {
      final index = queue[head], x = index % 320, y = index ~/ 320;
      left = math.min(left, x);
      right = math.max(right, x + 1);
      top = math.min(top, y);
      bottom = math.max(bottom, y + 1);
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          final xx = x + dx, yy = y + dy;
          if (xx < 0 || xx >= 320 || yy < 0 || yy >= 240) continue;
          final neighbour = yy * 320 + xx;
          if (support[neighbour] == 0 || visited[neighbour] != 0) continue;
          visited[neighbour] = 1;
          queue.add(neighbour);
        }
      }
    }
    result.add([left, top, right, bottom]);
  }
  return result;
}

// Bipartite matching avoids a greedy pairing hiding an unmatched component.
List<List<int>>? _pairComponents(List<List<int>> a, List<List<int>> b) {
  if (a.length != b.length) return null;
  final owner = List<int>.filled(b.length, -1);
  bool match(int i, Set<int> seen) {
    for (var j = 0; j < b.length; j++) {
      if (!_near(a[i], b[j]) || !seen.add(j)) continue;
      if (owner[j] == -1 || match(owner[j], seen)) {
        owner[j] = i;
        return true;
      }
    }
    return false;
  }

  for (var i = 0; i < a.length; i++) {
    if (!match(i, <int>{})) return null;
  }
  return [
    for (var j = 0; j < owner.length; j++) [owner[j], j],
  ];
}
