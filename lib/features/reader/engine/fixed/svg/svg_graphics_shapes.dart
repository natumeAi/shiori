part of 'svg_graphics.dart';

const _shapes = {
  'rect',
  'circle',
  'ellipse',
  'line',
  'polyline',
  'polygon',
  'path',
};

ui.Path _nativePath(vc.Path source) {
  final path = ui.Path()
    ..fillType = ui.PathFillType.values[source.fillType.index];
  for (final command in source.commands) {
    switch (command) {
      case vc.MoveToCommand():
        path.moveTo(command.x, command.y);
      case vc.LineToCommand():
        path.lineTo(command.x, command.y);
      case vc.CubicToCommand():
        path.cubicTo(
          command.x1,
          command.y1,
          command.x2,
          command.y2,
          command.x3,
          command.y3,
        );
      case vc.CloseCommand():
        path.close();
    }
  }
  return path;
}

ui.Path _shape(_SvgInstance i) {
  final a = i.attributes, n = i.node.index;
  double x(String key, [double fallback = 0]) =>
      _number(a[key], n, fallback: fallback, basis: i.viewport.width);
  double y(String key, [double fallback = 0]) =>
      _number(a[key], n, fallback: fallback, basis: i.viewport.height);
  double positive(double value) {
    if (value < 0) throw _SvgFailure(n, 'svg-negative-extent', malformed: true);
    return value;
  }

  final path = ui.Path()
    ..fillType = i.paint['fill-rule'] == 'evenodd'
        ? ui.PathFillType.evenOdd
        : ui.PathFillType.nonZero;
  switch (i.node.localName) {
    case 'rect' || 'image':
      final r = ui.Rect.fromLTWH(
        x('x'),
        y('y'),
        positive(x('width')),
        positive(y('height')),
      );
      final rx = positive(x('rx', a['ry'] == null ? 0 : x('ry')));
      final ry = positive(y('ry', a['rx'] == null ? 0 : y('rx')));
      path.addRRect(
        ui.RRect.fromRectAndRadius(r, ui.Radius.elliptical(rx, ry)),
      );
    case 'circle':
      final basis =
          math.sqrt(
            i.viewport.width * i.viewport.width +
                i.viewport.height * i.viewport.height,
          ) /
          math.sqrt2;
      final r = positive(_number(a['r'], n, basis: basis));
      path.addOval(
        ui.Rect.fromCircle(center: ui.Offset(x('cx'), y('cy')), radius: r),
      );
    case 'ellipse':
      final rx = positive(x('rx')), ry = positive(y('ry'));
      path.addOval(
        ui.Rect.fromCenter(
          center: ui.Offset(x('cx'), y('cy')),
          width: rx * 2,
          height: ry * 2,
        ),
      );
    case 'line':
      path.moveTo(x('x1'), y('y1'));
      path.lineTo(x('x2'), y('y2'));
    case 'polyline' || 'polygon':
      final values = _numbers(a['points'] ?? '', n);
      if (values.length.isOdd) {
        throw _SvgFailure(n, 'svg-points', malformed: true);
      }
      for (var j = 0; j < values.length; j += 2) {
        if (j == 0) {
          path.moveTo(values[j], values[j + 1]);
        } else {
          path.lineTo(values[j], values[j + 1]);
        }
      }
      if (i.node.localName == 'polygon') path.close();
    case 'path':
      final compiled = vc.parseSvgPathData(a['d'] ?? '');
      path.addPath(_nativePath(compiled), ui.Offset.zero);
  }
  return path;
}

/// SVG marker positions use authored vertices and incoming/outgoing tangents,
/// never evenly spaced PathMetrics samples. Full grammar is normalized by the
/// installed path parser (including relative, smooth, quadratic and arc verbs).
List<List<(ui.Offset, ui.Offset, ui.Offset)>> _vertices(_SvgInstance i) {
  final a = i.attributes, n = i.node.index;
  String data;
  if (i.node.localName == 'path') {
    data = a['d'] ?? '';
  } else if (i.node.localName == 'line') {
    data = 'M${a['x1'] ?? 0} ${a['y1'] ?? 0}L${a['x2'] ?? 0} ${a['y2'] ?? 0}';
  } else if (const {'polyline', 'polygon'}.contains(i.node.localName)) {
    final v = _numbers(a['points'] ?? '', n);
    data = [
      for (var j = 0; j + 1 < v.length; j += 2)
        '${j == 0 ? 'M' : 'L'}${v[j]} ${v[j + 1]}',
      if (i.node.localName == 'polygon') 'z',
    ].join();
  } else {
    return [];
  }
  final contours = <List<(ui.Offset, ui.Offset, ui.Offset)>>[];
  var current = <(ui.Offset, ui.Offset, ui.Offset)>[];
  var position = ui.Offset.zero;
  void segment(ui.Offset end, ui.Offset outgoing, ui.Offset incoming) {
    if (current.isEmpty) return;
    final last = current.removeLast();
    current.add((
      last.$1,
      last.$2,
      outgoing == ui.Offset.zero ? end - position : outgoing,
    ));
    current.add((
      end,
      incoming == ui.Offset.zero ? end - position : incoming,
      ui.Offset.zero,
    ));
    position = end;
  }

  final normalizer = pp.SvgPathNormalizer();
  for (final source in pp.SvgPathStringSource(data).parseSegments()) {
    final builder = vc.PathBuilder();
    normalizer.emitSegment(source, builder);
    final commands = builder.toPath().commands.toList();
    // One authored arc may normalize to several cubic pieces. Only its final
    // endpoint is a marker vertex; tangents use the first and last pieces.
    if (commands.length > 1 && commands.every((c) => c is vc.CubicToCommand)) {
      final first = commands.first as vc.CubicToCommand,
          last = commands.last as vc.CubicToCommand;
      segment(
        ui.Offset(last.x3, last.y3),
        ui.Offset(first.x1, first.y1) - position,
        ui.Offset(last.x3 - last.x2, last.y3 - last.y2),
      );
      continue;
    }
    for (final c in commands) {
      switch (c) {
        case vc.MoveToCommand():
          current = [];
          contours.add(current);
          position = ui.Offset(c.x, c.y);
          current.add((position, ui.Offset.zero, ui.Offset.zero));
        case vc.LineToCommand():
          segment(ui.Offset(c.x, c.y), ui.Offset.zero, ui.Offset.zero);
        case vc.CubicToCommand():
          final end = ui.Offset(c.x3, c.y3),
              p1 = ui.Offset(c.x1, c.y1),
              p2 = ui.Offset(c.x2, c.y2);
          segment(
            end,
            p1 - position == ui.Offset.zero ? p2 - position : p1 - position,
            end - p2 == ui.Offset.zero ? end - p1 : end - p2,
          );
        case vc.CloseCommand():
          if (current.isNotEmpty) {
            segment(current.first.$1, ui.Offset.zero, ui.Offset.zero);
            final first = current.first, last = current.last;
            current[0] = (first.$1, last.$2, first.$3);
            current[current.length - 1] = (last.$1, last.$2, first.$3);
          }
      }
    }
  }
  return contours;
}
