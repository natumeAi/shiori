part of 'svg_graphics.dart';

extension _SvgTree on SvgGraphicsPlan {
  _SvgInstance _tree(
    int index,
    Map<String, String> inherited,
    AffineTransform parent,
    ui.Size parentViewport,
    List<int> instances,
    List<GeometryClip> clips,
    double opacity,
    List<GeometryOpacityGroup> groups, {
    Map<String, String> overrides = const {},
  }) {
    final n = document.node(index),
        attrs = {..._attributes(index), ...overrides};
    final paint = {
      ...inherited,
      for (final a in attrs.entries)
        if (_svgPaint.contains(a.key)) a.key: a.value,
    };
    var transform = parent.compose(_svgTransform(attrs['transform'], index));
    var viewport = parentViewport;
    var localClips = clips;
    var localGroups = groups;
    final alpha = _number(attrs['opacity'], index, fallback: 1).clamp(0.0, 1.0);
    if (alpha != 1) {
      localGroups = [
        ...groups,
        GeometryOpacityGroup(
          id: 'svg-group-${instances.join('-')}-$index',
          parentId: groups.lastOrNull?.id,
          opacity: alpha,
        ),
      ];
    }
    if (const {'svg', 'symbol', 'marker'}.contains(n.localName)) {
      final w = _number(
        attrs['width'],
        index,
        fallback: parentViewport.width,
        basis: parentViewport.width,
      );
      final h = _number(
        attrs['height'],
        index,
        fallback: parentViewport.height,
        basis: parentViewport.height,
      );
      if (w < 0 || h < 0) {
        throw _SvgFailure(index, 'svg-viewport-size', malformed: true);
      }
      if (w == 0 || h == 0) attrs['display'] = 'none';
      final x = _number(attrs['x'], index, basis: parentViewport.width);
      final y = _number(attrs['y'], index, basis: parentViewport.height);
      transform = transform.compose(_translate(x, y));
      final viewportTransform = transform;
      if (w > 0 && h > 0) {
        final resolved = FixedSvgViewport.resolve(
          SvgSourceDimensions(
            nodeIndex: index,
            width: '$w',
            height: '$h',
            viewBox: attrs['viewBox'],
            preserveAspectRatio: attrs['preserveAspectRatio'],
          ),
        );
        if (resolved.transform == null) {
          throw _SvgFailure(index, 'svg-viewport', malformed: true);
        }
        transform = transform.compose(resolved.transform!);
      }
      final vb = attrs['viewBox'] == null
          ? null
          : _numbers(attrs['viewBox']!, index);
      viewport = ui.Size(vb == null ? w : vb[2], vb == null ? h : vb[3]);
      // UA overflow is hidden for nested SVG and markers; root defaults hidden
      // when embedded as a replaced viewport. Explicit visible is preserved.
      if (attrs['overflow'] != 'visible') {
        localClips = [
          ...clips,
          GeometryClip(
            id: 'svg-clip-${instances.join('-')}-$index',
            region: _region(ui.Rect.fromLTWH(0, 0, w, h), viewportTransform),
          ),
        ];
      }
    }
    final result = _SvgInstance(
      n,
      Map.unmodifiable(attrs),
      Map.unmodifiable(paint),
      transform,
      viewport,
      List.unmodifiable(instances),
      localClips,
      opacity * alpha,
      localGroups,
    );
    if (attrs['display'] == 'none') return result;
    if (n.localName == 'use') {
      final href = attrs['href'] ?? attrs['xlink:href'];
      if (href == null) {
        throw _SvgFailure(index, 'svg-use-href', malformed: true);
      }
      final target = _reference(index, href);
      final translation = _translate(
        _number(attrs['x'], index, basis: viewport.width),
        _number(attrs['y'], index, basis: viewport.height),
      );
      final targetNode = document.node(target);
      result.children.add(
        _tree(
          target,
          paint,
          transform.compose(translation),
          viewport,
          [...instances, index],
          localClips,
          result.opacity,
          localGroups,
          overrides: {
            if (const {'svg', 'symbol'}.contains(targetNode.localName)) ...{
              if (attrs['width'] != null) 'width': attrs['width']!,
              if (attrs['height'] != null) 'height': attrs['height']!,
            },
          },
        ),
      );
    } else if (const {
      'svg',
      'g',
      'symbol',
      'marker',
      'pattern',
    }.contains(n.localName)) {
      for (final child in n.children) {
        final tag = document.node(child).localName;
        if (tag == null ||
            const {
              'defs',
              'symbol',
              'linearGradient',
              'radialGradient',
              'pattern',
              'marker',
              'title',
              'desc',
            }.contains(tag) ||
            features.isDefinitionTag(tag)) {
          continue;
        }
        result.children.add(
          _tree(
            child,
            paint,
            transform,
            viewport,
            instances,
            localClips,
            result.opacity,
            localGroups,
          ),
        );
      }
    } else if (features.ownsTag(n.localName)) {
      // Feature-owned rendered node. Its feature supplies the picture and any
      // nested text/foreignObject content without shared tree edits.
    }
    return result;
  }
}
