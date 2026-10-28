import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/verified_raster_wrapper.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';

/// XHTML: document viewport > package viewport > verified raster wrapper.
/// SVG roots: explicit absolute size > viewBox size. Embedded SVG declarations
/// are validated, but never become the XHTML page's dimensions.
DimensionResolution resolveAuthoredDimensions({
  required SectionSourceFacts source,
  Map<String, String?> packageRendition = const {},
  VerifiedRasterWrapper? rasterWrapper,
}) {
  DimensionResolution? viewport;
  if (source.rootSvgNodeIndex == null) {
    if (source.viewports.isNotEmpty) {
      for (final raw in source.viewports) {
        final next = _viewport(raw);
        if (next is! ResolvedDimensions) return next;
        if (viewport is ResolvedDimensions && viewport.size != next.size) {
          return MalformedDimensions('Conflicting document viewports');
        }
        viewport = next;
      }
    } else if (packageRendition['viewport'] case final String raw) {
      viewport = _viewport(raw);
      if (viewport is! ResolvedDimensions) return viewport;
    }
  }
  DimensionResolution? root;
  for (final svg in source.svgDimensions) {
    final dimensions = resolveSvgDimensions(svg);
    // A nested percentage viewport needs containing-block layout, not a guess
    // from its viewBox. Do not publish complete dimensions for that profile.
    if (dimensions is! ResolvedDimensions) return dimensions;
    if (svg.nodeIndex == source.rootSvgNodeIndex) root = dimensions;
  }
  if (source.rootSvgNodeIndex != null) {
    return root ?? MalformedDimensions('Missing root SVG dimensions');
  }
  if (viewport != null) return viewport;
  if (rasterWrapper != null) {
    return ResolvedDimensions(
      size: rasterWrapper.size,
      source: DimensionSource.rasterIntrinsic,
      reason: 'Verified raster wrapper intrinsic size',
    );
  }
  return UnsupportedDimensions(
    'No authored viewport or verified raster dimensions',
  );
}

DimensionResolution _viewport(String raw) {
  final values = <String, String>{};
  final pattern = RegExp(r'(?:^|[,;\s])(width|height)\b\s*(?:=\s*([^,;\s]*))?');
  for (final match in pattern.allMatches(raw)) {
    final key = match[1]!;
    final value = match[2];
    if (value == null || value.isEmpty) {
      return MalformedDimensions('Missing viewport $key value');
    }
    if (values.containsKey(key) && values[key] != value) {
      return MalformedDimensions('Conflicting viewport $key');
    }
    values[key] = value;
  }
  if (!values.containsKey('width') || !values.containsKey('height')) {
    return MalformedDimensions('Viewport requires width and height');
  }
  if (values.values.any((v) => v == 'device-width' || v == 'device-height')) {
    return UnsupportedDimensions('Device-relative authored viewport');
  }
  final w = double.tryParse(values['width']!);
  final h = double.tryParse(values['height']!);
  if (!_positive(w) || !_positive(h)) {
    return MalformedDimensions(
      'Viewport dimensions must be positive finite numbers',
    );
  }
  return ResolvedDimensions(
    size: AuthoredPageSize(w!, h!),
    source: DimensionSource.viewportMeta,
    reason: 'Explicit authored viewport',
  );
}

DimensionResolution resolveSvgDimensions(SvgSourceDimensions svg) {
  AuthoredPageSize? box;
  if (svg.viewBox case final String raw) {
    final fields = raw.trim().split(RegExp(r'[\s,]+'));
    final numbers = fields.map(double.tryParse).toList();
    if (numbers.length != 4 ||
        numbers.any((v) => v == null || !v.isFinite) ||
        !_positive(numbers[2]) ||
        !_positive(numbers[3])) {
      return MalformedDimensions(
        'Invalid SVG viewBox at node ${svg.nodeIndex}',
      );
    }
    box = AuthoredPageSize(numbers[2]!, numbers[3]!);
  }
  if (svg.width != null || svg.height != null) {
    if (svg.width == null || svg.height == null) {
      return MalformedDimensions('SVG requires both explicit dimensions');
    }
    final width = _absolute(svg.width!);
    final height = _absolute(svg.height!);
    if (width.failure != null) return width.failure!;
    if (height.failure != null) return height.failure!;
    return ResolvedDimensions(
      size: AuthoredPageSize(width.value!, height.value!),
      source: DimensionSource.svgSize,
      reason: 'Explicit absolute SVG viewport; viewBox origin is separate',
    );
  }
  if (box != null) {
    return ResolvedDimensions(
      size: box,
      source: DimensionSource.svgViewBox,
      reason: 'SVG viewBox extent; origin is separate',
    );
  }
  return UnsupportedDimensions('SVG has no absolute size or viewBox');
}

bool _positive(double? value) => value != null && value.isFinite && value > 0;

({double? value, DimensionResolution? failure}) _absolute(String raw) {
  final match = RegExp(
    r'^([+-]?(?:\d+(?:\.\d*)?|\.\d+)(?:[eE][+-]?\d+)?)\s*([a-zA-Z%]*)$',
  ).firstMatch(raw.trim());
  if (match == null) {
    return (
      value: null,
      failure: MalformedDimensions('Invalid SVG length: $raw'),
    );
  }
  const factors = {
    '': 1.0,
    'px': 1.0,
    'in': 96.0,
    'cm': 96 / 2.54,
    'mm': 96 / 25.4,
    'q': 96 / 101.6,
    'pt': 96 / 72,
    'pc': 16.0,
  };
  final factor = factors[match[2]];
  if (factor == null) {
    return (
      value: null,
      failure: UnsupportedDimensions('Relative or unknown SVG length: $raw'),
    );
  }
  final value = double.parse(match[1]!) * factor;
  if (!_positive(value)) {
    return (
      value: null,
      failure: MalformedDimensions('Nonpositive or nonfinite SVG size'),
    );
  }
  return (value: value, failure: null);
}
