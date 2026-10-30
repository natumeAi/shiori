part of 'svg_graphics.dart';

double _number(String? raw, int node, {double fallback = 0, double basis = 1}) {
  if (raw == null) return fallback;
  final units = RegExp(
    r'^([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)(%|px|pt|pc|in|cm|mm|q)?$',
  ).firstMatch(raw.trim());
  if (units == null) throw _SvgFailure(node, 'svg-length');
  final value =
      double.parse(units[1]!) *
      switch (units[2]) {
        '%' => basis / 100,
        'pt' => 96 / 72,
        'pc' => 16,
        'in' => 96,
        'cm' => 96 / 2.54,
        'mm' => 96 / 25.4,
        'q' => 96 / 101.6,
        _ => 1,
      };
  if (!value.isFinite) {
    throw _SvgFailure(node, 'svg-numeric-range', malformed: true);
  }
  return value;
}

List<double> _numbers(String raw, int node) {
  final pattern = RegExp(r'[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?');
  if (raw.replaceAll(pattern, '').replaceAll(RegExp(r'[\s,]'), '').isNotEmpty) {
    throw _SvgFailure(node, 'svg-number-list', malformed: true);
  }
  return [for (final m in pattern.allMatches(raw)) _number(m[0], node)];
}

AffineTransform _translate(double x, double y) =>
    AffineTransform(1, 0, 0, 1, x, y);
AffineTransform _scale(double x, double y) => AffineTransform(x, 0, 0, y, 0, 0);
AffineTransform _rotate(double radians) => AffineTransform(
  math.cos(radians),
  math.sin(radians),
  -math.sin(radians),
  math.cos(radians),
  0,
  0,
);

double _transformNumber(String raw, int node) {
  final match = RegExp(r'^([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)$')
      .firstMatch(raw.trim());
  if (match == null) throw _SvgFailure(node, 'svg-transform');
  return double.parse(match[1]!);
}

double _transformLength(String raw, int node) {
  // CSS Transforms lengths are absolute here. Percentages need a reference box
  // that this module does not resolve, so they must refuse rather than guess.
  if (raw.trim().endsWith('%')) {
    throw _SvgFailure(node, 'svg-transform-percent');
  }
  return _number(raw, node);
}

double _transformAngle(String raw, int node) {
  final match = RegExp(
    r'^([+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?)(deg|rad|grad|turn)?$',
  ).firstMatch(raw.trim());
  if (match == null) throw _SvgFailure(node, 'svg-transform');
  final value = double.parse(match[1]!);
  final radians = switch (match[2]) {
    'rad' => value,
    'grad' => value * math.pi / 200,
    'turn' => value * math.pi * 2,
    // Unitless angles keep SVG attribute compatibility; CSS requires a unit.
    _ => value * math.pi / 180,
  };
  if (!radians.isFinite) {
    throw _SvgFailure(node, 'svg-numeric-range', malformed: true);
  }
  return radians;
}

List<String> _transformArguments(String raw, int node) {
  final pattern = RegExp(
    r'[+-]?(?:\d+\.?\d*|\.\d+)(?:[eE][+-]?\d+)?(?:deg|rad|grad|turn|px|pt|pc|in|cm|mm|q|%)?',
  );
  final arguments = [for (final match in pattern.allMatches(raw)) match[0]!];
  if (arguments.isEmpty ||
      raw.replaceAll(pattern, '').replaceAll(RegExp(r'[\s,]'), '').isNotEmpty) {
    throw _SvgFailure(node, 'svg-transform');
  }
  return arguments;
}

AffineTransform _svgTransform(String? raw, int node) {
  if (raw == null || raw == 'none' || raw.trim().isEmpty) {
    return const AffineTransform.identity();
  }
  var result = const AffineTransform.identity(), offset = 0;
  final pattern = RegExp(r'([a-zA-Z]+)\s*\(([^)]*)\)');
  for (final match in pattern.allMatches(raw)) {
    if (raw
        .substring(offset, match.start)
        .replaceAll(RegExp(r'[\s,]'), '')
        .isNotEmpty) {
      throw _SvgFailure(node, 'svg-transform');
    }
    final arguments = _transformArguments(match[2]!, node);
    double length(int i) => _transformLength(arguments[i], node);
    double angle(int i) => _transformAngle(arguments[i], node);
    double number(int i) => _transformNumber(arguments[i], node);
    final matrix = switch ((match[1], arguments.length)) {
      ('matrix', 6) => AffineTransform(
        number(0),
        number(1),
        number(2),
        number(3),
        length(4),
        length(5),
      ),
      ('translate', 1) => _translate(length(0), 0),
      ('translate', 2) => _translate(length(0), length(1)),
      ('translateX', 1) => _translate(length(0), 0),
      ('translateY', 1) => _translate(0, length(0)),
      ('scale', 1) => _scale(number(0), number(0)),
      ('scale', 2) => _scale(number(0), number(1)),
      ('scaleX', 1) => _scale(number(0), 1),
      ('scaleY', 1) => _scale(1, number(0)),
      ('rotate', 1) => _rotate(angle(0)),
      ('rotate', 3) => _translate(
        length(1),
        length(2),
      ).compose(_rotate(angle(0))).compose(_translate(-length(1), -length(2))),
      ('skewX', 1) => AffineTransform(1, 0, math.tan(angle(0)), 1, 0, 0),
      ('skewY', 1) => AffineTransform(1, math.tan(angle(0)), 0, 1, 0, 0),
      ('skew', 1) => AffineTransform(1, 0, math.tan(angle(0)), 1, 0, 0),
      ('skew', 2) => AffineTransform(
        1,
        math.tan(angle(1)),
        math.tan(angle(0)),
        1,
        0,
        0,
      ),
      _ => throw _SvgFailure(node, 'svg-transform'),
    };
    result = result.compose(matrix);
    offset = match.end;
  }
  if (raw.substring(offset).trim().isNotEmpty) {
    throw _SvgFailure(node, 'svg-transform');
  }
  return result;
}

Float64List _matrix(AffineTransform t) => Float64List.fromList([
  t.a,
  t.b,
  0,
  0,
  t.c,
  t.d,
  0,
  0,
  0,
  0,
  1,
  0,
  t.e,
  t.f,
  0,
  1,
]);
ui.Offset _point(AffineTransform t, ui.Offset p) =>
    ui.Offset(t.a * p.dx + t.c * p.dy + t.e, t.b * p.dx + t.d * p.dy + t.f);
ui.Rect _bounds(AffineTransform t, ui.Rect r) {
  final points = [
    r.topLeft,
    r.topRight,
    r.bottomRight,
    r.bottomLeft,
  ].map((p) => _point(t, p)).toList();
  return ui.Rect.fromLTRB(
    points.map((p) => p.dx).reduce(math.min),
    points.map((p) => p.dy).reduce(math.min),
    points.map((p) => p.dx).reduce(math.max),
    points.map((p) => p.dy).reduce(math.max),
  );
}

GeometryRegion _region(ui.Rect r, AffineTransform t) => GeometryRegion(
  left: r.left,
  top: r.top,
  width: r.width,
  height: r.height,
  transform: t,
);

const _inheritedSvgProperties = {..._svgPaint, 'stop-color', 'stop-opacity'};

extension _SvgMarkup on SvgGraphicsPlan {
  /// Inherited presentation that a definition loses when it is copied out of
  /// its original ancestor chain into the detached leaf markup.
  Map<String, String> _inherited(
    int index, [
    Set<String> properties = _svgPaint,
  ]) {
    final chain = <int>[];
    var parent = document.node(index).parentIndex;
    while (parent != null) {
      final node = document.node(parent);
      if (node.namespaceUri == 'http://www.w3.org/2000/svg') chain.add(parent);
      parent = node.parentIndex;
    }
    final result = <String, String>{};
    for (final ancestor in chain.reversed) {
      final attributes = _attributes(ancestor);
      for (final key in properties) {
        final value = attributes[key];
        if (value != null) result[key] = value;
      }
    }
    return result;
  }

  XmlElement _xml(int index, void Function(int) include) {
    final n = document.node(index),
        attrs = {
          ..._inherited(index, _inheritedSvgProperties),
          ..._attributes(index),
        };
    // The installed compiler resolves currentColor only from the root theme,
    // ignoring a stop's inherited color. Resolve it in the detached markup.
    final color = attrs['color'];
    if (color != null && attrs['stop-color']?.toLowerCase() == 'currentcolor') {
      attrs['stop-color'] = color;
    }
    for (final a in attrs.entries) {
      if (a.key == 'href' ||
          a.key == 'xlink:href' ||
          a.value.startsWith('url(')) {
        include(_reference(index, a.value));
      }
    }
    return XmlElement(
      XmlName.parts(n.localName!),
      [
        for (final a in attrs.entries)
          if (!const {
            'class',
            'data-source',
            'filter',
            'display',
          }.contains(a.key))
            XmlAttribute(XmlName.parts(a.key), a.value),
      ],
      [
        for (final child in n.children)
          if (document.node(child).localName != null) _xml(child, include),
      ],
    );
  }

  String _leafMarkup(
    _SvgInstance instance, {
    Map<String, String> overrides = const {},
  }) {
    final attrs = {...instance.attributes, ...instance.paint, ...overrides};
    for (final key in [
      'transform',
      'opacity',
      'overflow',
      'marker-start',
      'marker-mid',
      'marker-end',
      'href',
      'xlink:href',
      'class',
      'data-source',
      'filter',
      'display',
    ]) {
      attrs.remove(key);
    }
    final leaf = XmlElement(XmlName.parts(instance.node.localName!), [
      for (final a in attrs.entries)
        XmlAttribute(XmlName.parts(a.key), a.value),
    ]);
    final defs = <XmlElement>[];
    final included = <int>{};
    void include(int index) {
      if (!included.add(index)) return;
      final n = document.node(index);
      if (!const {
        'linearGradient',
        'radialGradient',
        'pattern',
      }.contains(n.localName)) {
        return;
      }
      defs.add(_xml(index, include));
    }

    for (final key in ['fill', 'stroke']) {
      final value = attrs[key];
      if (value != null && value.startsWith('url(')) {
        include(_reference(instance.node.index, value));
      }
    }
    return '<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" '
        'width="${instance.viewport.width}" height="${instance.viewport.height}" '
        'overflow="visible"><defs>${defs.join()}</defs>$leaf</svg>';
  }
}
