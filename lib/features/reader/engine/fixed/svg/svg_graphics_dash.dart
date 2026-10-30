part of 'svg_graphics.dart';

ui.Path _dashPath(
  _SvgInstance shape,
  SceneResourceBudget budget,
  List<SceneResourceLease> leases,
) {
  final value = shape.paint['stroke-dasharray'];
  if (value == null || value == 'none') return shape.path!;
  final basis =
      math.sqrt(
        shape.viewport.width * shape.viewport.width +
            shape.viewport.height * shape.viewport.height,
      ) /
      math.sqrt2;
  var intervals = [
    for (final part
        in value.split(RegExp(r'[\s,]+')).where((s) => s.isNotEmpty))
      _number(part, shape.node.index, basis: basis),
  ];
  if (intervals.isEmpty || intervals.every((v) => v == 0)) return shape.path!;
  if (intervals.length.isOdd) intervals = [...intervals, ...intervals];
  final total = intervals.reduce((a, b) => a + b);
  var offset =
      _number(
        shape.paint['stroke-dashoffset'],
        shape.node.index,
        basis: basis,
      ) %
      total;
  var first = 0;
  // A zero-length painted interval at offset 0 is a real cap, not a boundary
  // to consume. Positive boundaries still advance to the next interval.
  while (offset > intervals[first] ||
      (offset == intervals[first] && intervals[first] > 0)) {
    offset -= intervals[first];
    first = (first + 1) % intervals.length;
  }
  final metrics = shape.path!.computeMetrics().toList();
  final available = budget.limits[SceneResource.vectorOperations]!;
  final cap = shape.paint['stroke-linecap'];
  final capWidth = _number(
    shape.paint['stroke-width'],
    shape.node.index,
    fallback: 1,
  );
  final paintCaps = (cap == 'round' || cap == 'square') && capWidth > 0;
  var commands = 0;
  for (final metric in metrics) {
    final repeats = metric.length / total;
    if (!repeats.isFinite || repeats > available ~/ intervals.length) {
      throw const SceneAdmissionException(
        SceneAdmissionFailure.complexityExceeded,
        resource: SceneResource.vectorOperations,
      );
    }
    commands += repeats.ceil() * intervals.length + intervals.length;
  }
  leases.add(
    budget.reserve({
      SceneResource.vectorOperations: commands,
      SceneResource.vectorBytes: commands * 96,
    }),
  );
  final output = ui.Path();
  for (final metric in metrics) {
    if (metric.length == 0) continue;
    var index = first, remaining = intervals[index] - offset, position = 0.0;
    while (position < metric.length ||
        (position == metric.length && remaining == 0)) {
      final end = math.min(metric.length, position + remaining);
      if (index.isEven) {
        if (end > position) {
          output.addPath(metric.extractPath(position, end), ui.Offset.zero);
        } else if (remaining == 0 && paintCaps) {
          _dashCap(output, metric, position, capWidth);
        }
      }
      position = end;
      index = (index + 1) % intervals.length;
      remaining = intervals[index];
    }
  }
  return output;
}

/// A zero-length painted dash still contributes its cap shape (SVG 2 stroke
/// shape). A sub-pixel segment along the path tangent lets the stroke paint's
/// round/square cap emit the dot with the authored orientation.
void _dashCap(
  ui.Path output,
  ui.PathMetric metric,
  double position,
  double strokeWidth,
) {
  final tangent = metric.getTangentForOffset(position);
  if (tangent == null) return;
  final vector = tangent.vector;
  final length = vector.distance;
  final direction = length == 0 ? const ui.Offset(1, 0) : vector / length;
  final extent = strokeWidth * 1e-3;
  final start = tangent.position - direction * (extent / 2);
  final end = tangent.position + direction * (extent / 2);
  output
    ..moveTo(start.dx, start.dy)
    ..lineTo(end.dx, end.dy);
}
