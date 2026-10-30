part of 'svg_graphics.dart';

int _markerReferenceCount(
  String tag,
  String property,
  Map<String, String> attrs,
  int node,
) {
  var vertices = 0, contours = 1;
  if (tag == 'line') {
    vertices = 2;
  } else if (tag == 'polyline' || tag == 'polygon') {
    vertices = _numbers(attrs['points'] ?? '', node).length ~/ 2;
    if (tag == 'polygon' && vertices > 0) vertices++;
  } else if (tag == 'path') {
    contours = 0;
    for (final segment in pp.SvgPathStringSource(
      attrs['d'] ?? '',
    ).parseSegments()) {
      vertices++;
      // SvgPathSegType is not exported by package:path_parsing; compare by name.
      final command = segment.command.name;
      if (command == 'moveToAbs' || command == 'moveToRel') contours++;
    }
  }
  if (vertices == 0) return 0;
  return property == 'marker-mid'
      ? math.max(0, vertices - 2 * contours)
      : contours;
}

extension _SvgMarkers on SvgGraphicsPlan {
  List<_SvgInstance> _markers(_SvgInstance shape) {
    final result = <_SvgInstance>[];
    final contours = _vertices(shape);
    for (var contourIndex = 0; contourIndex < contours.length; contourIndex++) {
      final contour = contours[contourIndex];
      for (var j = 0; j < contour.length; j++) {
        final key = j == 0
            ? 'marker-start'
            : j == contour.length - 1
            ? 'marker-end'
            : 'marker-mid';
        final raw = shape.paint[key];
        if (raw == null || raw == 'none') continue;
        final index = _reference(shape.node.index, raw), a = _attributes(index);
        if (document.node(index).localName != 'marker') {
          throw _SvgFailure(index, 'svg-marker-reference');
        }
        final vertex = contour[j];
        double angle(ui.Offset v) => math.atan2(v.dy, v.dx);
        final incoming = vertex.$2 == ui.Offset.zero ? vertex.$3 : vertex.$2;
        final outgoing = vertex.$3 == ui.Offset.zero ? vertex.$2 : vertex.$3;
        var orientation = j == 0
            ? angle(outgoing)
            : j == contour.length - 1
            ? angle(incoming)
            : angle(incoming) +
                  math.atan2(
                        math.sin(angle(outgoing) - angle(incoming)),
                        math.cos(angle(outgoing) - angle(incoming)),
                      ) /
                      2;
        final orient = a['orient'] ?? '0';
        if (!const {'auto', 'auto-start-reverse'}.contains(orient)) {
          orientation = _number(orient, index) * math.pi / 180;
        } else if (orient == 'auto-start-reverse' && j == 0) {
          orientation += math.pi;
        }
        final units = a['markerUnits'] ?? 'strokeWidth';
        if (!const {'strokeWidth', 'userSpaceOnUse'}.contains(units)) {
          throw _SvgFailure(index, 'svg-marker-units');
        }
        final scale = units == 'strokeWidth'
            ? _number(
                shape.paint['stroke-width'],
                shape.node.index,
                fallback: 1,
              )
            : 1.0;
        final w = _number(a['markerWidth'], index, fallback: 3),
            h = _number(a['markerHeight'], index, fallback: 3);
        if (w < 0 || h < 0) {
          throw _SvgFailure(index, 'svg-marker-size', malformed: true);
        }
        final viewport = FixedSvgViewport.resolve(
          SvgSourceDimensions(
            nodeIndex: index,
            width: '$w',
            height: '$h',
            viewBox: a['viewBox'],
            preserveAspectRatio: a['preserveAspectRatio'],
          ),
        );
        if (viewport.transform == null) {
          throw _SvgFailure(index, 'svg-marker-viewport');
        }
        final ref = _point(
          viewport.transform!,
          ui.Offset(_number(a['refX'], index), _number(a['refY'], index)),
        );
        final matrix = shape.transform
            .compose(_translate(vertex.$1.dx, vertex.$1.dy))
            .compose(_rotate(orientation))
            .compose(_scale(scale, scale))
            .compose(_translate(-ref.dx, -ref.dy));
        result.add(
          _tree(
            index,
            const {'fill': 'black', 'stroke': 'none'},
            matrix,
            ui.Size(w, h),
            [...shape.instances, shape.node.index, contourIndex, j],
            shape.clips,
            shape.opacity,
            shape.groups,
            overrides: {'width': '$w', 'height': '$h'},
          ),
        );
      }
    }
    return result;
  }
}
