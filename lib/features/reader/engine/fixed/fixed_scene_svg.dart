part of 'fixed_scene.dart';

extension _FixedSvg on FixedSceneBuilder {
  FixedBox? _layoutSvg(int index, FixedBox? parent, ui.Offset flow) {
    final node = document.node(index), style = styles.styleOf(index)!;
    final facts = extractSectionSourceFacts(document).svgDimensions
        .singleWhere((s) => s.nodeIndex == index);
    final viewport = FixedSvgViewport.resolve(facts);
    if (viewport.dimensions is! ResolvedDimensions) {
      final failure = OffendingConstruct(
        kind: CapabilityConstructKind.dimensions,
        identifier: 'svg-viewport',
        nodeIndex: index,
      );
      (viewport.dimensions is MalformedDimensions
              ? _malformed
              : _dimensionFailures)
          .add(failure);
      return null;
    }
    // General SVG text/vector adoption remains gated on A0b. This admitted
    // primitive route conserves every child or refuses the complete scene.
    final size = (viewport.dimensions as ResolvedDimensions).size;
    final box = FixedBox._(index, style, parent);
    box.borderBox = box.contentBox = ui.Rect.fromLTWH(
      flow.dx,
      flow.dy,
      size.width,
      size.height,
    );
    box.svgContentTransform = _translation(
      flow.dx,
      flow.dy,
    ).compose(viewport.transform!);
    _boxes.add(box);
    parent?.children.add(box);
    parent?.contents.add(box);
    const svgAttributes = {
      'xmlns',
      'width',
      'height',
      'viewBox',
      'preserveAspectRatio',
      'id',
      'data-source',
      'fill',
    };
    if (node.attributes.any((a) => !svgAttributes.contains(a.qualifiedName))) {
      _reject(index, 'svg-viewport-attribute');
    }
    for (final child in node.children) {
      final n = document.node(child);
      if (n.isCharacterData && (n.text ?? '').trim().isEmpty) continue;
      if (n.localName != 'rect' ||
          n.namespaceUri != node.namespaceUri ||
          n.children.isNotEmpty) {
        _reject(child, 'svg-primitive-not-admitted');
        continue;
      }
      const rectAttributes = {
        'id',
        'data-source',
        'x',
        'y',
        'width',
        'height',
        'fill',
      };
      if (n.attributes.any((a) => !rectAttributes.contains(a.qualifiedName))) {
        _reject(child, 'svg-rect-attribute');
      }
      double? number(String key, [String? fallback]) =>
          double.tryParse(n.attribute(key) ?? fallback ?? '');
      final x = number('x', '0'),
          y = number('y', '0'),
          w = number('width'),
          h = number('height');
      if ([x, y, w, h].any((v) => v == null || !v.isFinite) ||
          w! < 0 ||
          h! < 0) {
        _reject(child, 'svg-rect-geometry', malformed: true);
        continue;
      }
      final fill = n.attribute('fill') ?? node.attribute('fill') ?? 'black';
      final declarations = parseInlineStyle('color:$fill', null);
      if (fill != 'none' &&
          (declarations.length != 1 ||
              declarations.single.value is! CssColor)) {
        _reject(child, 'svg-rect-fill');
        continue;
      }
      final color = fill == 'none'
          ? const CssColor(0)
          : declarations.single.value as CssColor;
      final rect = FixedBox._(child, styles.styleOf(child)!, box);
      rect.borderBox = rect.contentBox = ui.Rect.fromLTWH(x!, y!, w, h);
      rect.svgFill = color.isCurrent ? rect.style.color : color.argb;
      box.children.add(rect);
      box.contents.add(rect);
      _boxes.add(rect);
    }
    return box;
  }
}
