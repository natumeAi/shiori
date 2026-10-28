part of 'svg_graphics.dart';

void _validateSvgValues(int index, Map<String, String> attrs) {
  const enums = <String, Set<String>>{
    'fill-rule': {'nonzero', 'evenodd'},
    'stroke-linecap': {'butt', 'round', 'square'},
    'stroke-linejoin': {'miter', 'round', 'bevel'},
    'visibility': {'visible', 'hidden', 'collapse'},
    'display': {'inline', 'none', 'block'},
    'overflow': {'visible', 'hidden', 'clip', 'scroll', 'auto'},
    'gradientUnits': {'objectBoundingBox', 'userSpaceOnUse'},
    'patternUnits': {'objectBoundingBox', 'userSpaceOnUse'},
    'patternContentUnits': {'objectBoundingBox', 'userSpaceOnUse'},
    'markerUnits': {'strokeWidth', 'userSpaceOnUse'},
    'spreadMethod': {'pad', 'repeat', 'reflect'},
  };
  for (final entry in enums.entries) {
    if (attrs[entry.key] != null && !entry.value.contains(attrs[entry.key])) {
      throw _SvgFailure(index, 'svg-value-${entry.key}');
    }
  }
  for (final key in [
    'opacity',
    'fill-opacity',
    'stroke-opacity',
    'stop-opacity',
  ]) {
    if (attrs[key] != null) _number(attrs[key], index, basis: 1);
  }
  for (final key in ['transform', 'gradientTransform', 'patternTransform']) {
    if (attrs[key] != null) _svgTransform(attrs[key], index);
  }
  final dash = attrs['stroke-dasharray'];
  if (dash != null && dash != 'none') {
    for (final part
        in dash.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty)) {
      if (_number(part, index) < 0) {
        throw _SvgFailure(index, 'svg-negative-dash', malformed: true);
      }
    }
  }
  if (attrs['stroke-width'] != null &&
      _number(attrs['stroke-width'], index) < 0) {
    throw _SvgFailure(index, 'svg-negative-stroke-width', malformed: true);
  }
  if (attrs['stroke-miterlimit'] != null &&
      _number(attrs['stroke-miterlimit'], index) < 1) {
    throw _SvgFailure(index, 'svg-miterlimit', malformed: true);
  }
  if (attrs['fr'] != null && _number(attrs['fr'], index) != 0) {
    // The installed compiler has no two-circle radial-gradient SVG API.
    throw _SvgFailure(index, 'svg-radial-focal-radius');
  }
}
