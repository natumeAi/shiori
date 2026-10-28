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
  while (offset >= intervals[first]) {
    offset -= intervals[first];
    first = (first + 1) % intervals.length;
  }
  final metrics = shape.path!.computeMetrics().toList();
  final available = budget.limits[SceneResource.vectorOperations]!;
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
    var index = first, remaining = intervals[index] - offset, position = 0.0;
    while (position < metric.length) {
      final end = math.min(metric.length, position + remaining);
      if (index.isEven && end > position) {
        output.addPath(metric.extractPath(position, end), ui.Offset.zero);
      }
      position = end;
      index = (index + 1) % intervals.length;
      remaining = intervals[index];
    }
  }
  return output;
}
