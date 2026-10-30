part of 'svg_graphics.dart';

Map<String, String> _svgTextAttributes(SvgGraphicsPlan plan, int index) {
  final service = plan.host.text;
  if (service is! FixedSvgTextFontService) return plan._attributes(index);
  final presentation = service.presentation;
  if (presentation.problems.isNotEmpty) {
    throw SvgFeatureRefusal(index, presentation.problems.first);
  }
  return {...plan._attributes(index), ...?presentation.values[index]};
}

/// Source-aware, horizontal LTR outlines. No platform text painter is used.
final class SvgTextFeature extends SvgFeature {
  const SvgTextFeature();
  @override
  String get key => 'text';
  @override
  Set<String> get tags => const {'text', 'tspan', 'textPath', 'style'};
  @override
  Set<String> get definitionTags => const {'style'};
  @override
  bool get opaqueChildren => true;
  @override
  Set<String> get attributes => const {
    'dx',
    'dy',
    'rotate',
    'text-anchor',
    'textLength',
    'lengthAdjust',
    'startOffset',
    'font-family',
    'font-size',
    'font-weight',
    'font-style',
    'letter-spacing',
    'word-spacing',
    'font-kerning',
    'writing-mode',
    'direction',
    'unicode-bidi',
    'xml:space',
    'text-decoration',
  };
  @override
  Set<String> get presentationProperties => attributes;
  @override
  String? presentationRefusal(String property, String value) =>
      switch (property) {
        'writing-mode' when value != 'horizontal-tb' => 'svg-text-vertical',
        'direction' when value != 'ltr' => 'svg-text-bidi',
        'unicode-bidi' when value != 'normal' => 'svg-text-bidi',
        'font-kerning' when !const {'auto', 'normal', 'none'}.contains(value) =>
          'svg-text-font-kerning',
        'text-decoration' when value != 'none' => 'svg-text-decoration',
        _ => null,
      };

  @override
  void admit(SvgFeatureAdmission admission) {
    final a = admission;
    // Styles were already resolved by SvgPresentation/the fixed host. They are
    // nonpainting definitions; their character data must not enter geometry.
    if (a.tag == 'style') return;
    if (!tags.contains(a.tag)) {
      for (final e in a.attributes.entries) {
        if (_shapes.contains(a.tag) && attributes.contains(e.key)) {
          a.refuse('svg-css-${e.key}');
        }
        final refusal = presentationRefusal(e.key, e.value);
        if (refusal != null) a.refuse(refusal);
      }
      return;
    }
    if (!a.host.text.available) a.refuse('svg-${a.tag}');
    if (a.tag != 'text') a.refuse('svg-text-orphan');
    final input = _SvgTextInput.read(a.plan, a.index);
    if (input.pathReference case final reference?) {
      a.addReference(
        source: reference.source,
        target: reference.target,
        attribute: 'href',
      );
      a.charge(SceneResource.references, 1);
    }
    // One bounded prepaid envelope, included in the whole-unit SVG vector
    // payload. HB suballocation below cannot exceed it. No second process or
    // unit reservation is made. Oversized fonts/outlines fail before allocation.
    a.charge(SceneResource.vectorBytes, input.envelopeBytes);
    a.charge(SceneResource.vectorOperations, input.operationLimit);
  }

  @override
  Future<void> prepare(SvgFeaturePreparation preparation) async {
    final c = preparation;
    final output = <_SvgPreparedText>[];
    c.state[this] = output;
    for (final node in c.nodes) {
      if (!tags.contains(node.localName)) {
        if (node.attributes.keys.any(attributes.contains)) c.markCovered(node);
        continue;
      }
      final input = _SvgTextInput.read(c.plan, node.nodeIndex);
      if (input.text.isEmpty || node.attributes['display'] == 'none') {
        c.markCovered(node);
        continue;
      }
      // The source-only style flattener does not resolve instance inheritance.
      if (node.instancePath.isNotEmpty) {
        throw SvgFeatureRefusal(node.nodeIndex, 'svg-text-use-profile');
      }
      final lease = await c.host.text.acquire(
        SvgTextFontRequest(
          document: c.plan.document,
          nodeIndex: node.nodeIndex,
          families: input.families.toSet(),
          textCodeUnits: input.text.length,
        ),
      );
      if (lease == null) {
        throw const RequiredFontException('svg-text-font-missing');
      }
      c.onDispose(lease.release);
      c.checkCancellation();
      if (lease is! FixedSvgTextFontLease) {
        throw const RequiredFontException('svg-text-font-admission-token');
      }
      final asset = lease.selectFace(
        input.families,
        input.weight,
        input.italic,
      );
      final resources = hb.HarfBuzzResources(input.prepaidLedger());
      c.onDispose(() {
        if (resources.live.values.any((v) => v != 0) ||
            resources.budget.used.values.any((v) => v != 0)) {
          throw StateError('SVG text module resource leak');
        }
      });
      late final hb.HarfBuzzFont font;
      try {
        font = hb.HarfBuzzFont.open(
          lease.admitted[asset]!,
          bindings: hb.HarfBuzzBindings(),
          resources: resources,
          fontSize: input.fontSize,
          cancellation: c.cancellation,
        );
      } on hb.HarfBuzzException catch (error) {
        c.checkCancellation();
        throw SvgFeatureRefusal(
          node.nodeIndex,
          'svg-text-harfbuzz-${error.failure.name}',
        );
      }
      hb.HarfBuzzRun? run;
      hb.HarfBuzzQuadraticPath? path;
      try {
        run = font.shapeRun(
          input.text,
          cancellation: c.cancellation,
          features: [
            hb.HarfBuzzFeature('kern', input.kerningNone ? 0 : 1),
            if (input.letterSpacing != 0) hb.HarfBuzzFeature('liga', 0),
          ],
        );
        input.validatePaintPositions(run);
        if (input.path case final points?) {
          path = hb.HarfBuzzQuadraticPath(
            start: points[0],
            control: points[1],
            end: points[2],
            resources: resources,
          );
        }
        final placed = run.place(
          positions: input.positions(run.advance),
          x: input.anchor == 'end' ? -input.endAnchorShift(run.advance) : 0,
          anchorMiddle: input.anchor == 'middle',
          textLength: input.textLength,
          lengthAdjust: input.lengthAdjust,
          path: path,
          startOffset: input.startOffset,
          cancellation: c.cancellation,
        );
        c.onDispose(placed.dispose);
        final prepared = _SvgPreparedText(
          node,
          input,
          placed,
          run.layoutClusters,
          run.paintGlyphs.length,
        );
        output.add(prepared);
        for (final span in input.spans) {
          // Retained per-source grids stay inside the prepaid text envelope;
          // serial raster scratch uses the shared SVG subdivision below.
          final pixels =
              c.evidenceExtent.width.toInt() * c.evidenceExtent.height.toInt();
          final retained = resources.budget.reserve({
            SceneResource.vectorBytes:
                pixels + GeometryAlphaFootprint.storageOverhead,
          });
          c.onDispose(retained.release);
          final recorder = ui.PictureRecorder();
          final canvas = ui.Canvas(recorder);
          ui.Rect? bounds;
          for (final fragment in placed.fragments) {
            if (fragment.geometry.range.start < span.start ||
                fragment.geometry.range.end > span.end) {
              continue;
            }
            canvas.drawPath(fragment.path, ui.Paint()..color = input.color);
            final r = fragment.path.getBounds();
            bounds = bounds?.expandToInclude(r) ?? r;
          }
          final picture = recorder.endRecording();
          try {
            final instance = node._instance;
            final measurement =
                _SvgInstance(
                    instance.node,
                    instance.attributes,
                    instance.paint,
                    instance.transform,
                    instance.viewport,
                    instance.instances,
                    instance.clips,
                    instance.opacity,
                    instance.groups,
                  )
                  ..picture = picture
                  ..bounds = bounds ?? ui.Rect.zero;
            prepared.coverage[span.node] = await _coverage(
              measurement,
              c.plan.size,
              c.rasterBudget,
              c.checkCancellation,
              c.evidenceExtent,
            );
            prepared.bounds[span.node] = bounds ?? ui.Rect.zero;
          } finally {
            picture.dispose();
          }
          c.checkCancellation();
        }
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final paint = ui.Paint()..color = input.color;
        ui.Rect? bounds;
        for (final fragment in placed.fragments) {
          canvas.drawPath(fragment.path, paint);
          final r = fragment.path.getBounds();
          bounds = bounds?.expandToInclude(r) ?? r;
        }
        c.setPicture(
          node,
          recorder.endRecording(),
          bounds: bounds ?? ui.Rect.zero,
        );
        c.markCovered(node);
      } on hb.HarfBuzzException catch (error) {
        c.checkCancellation();
        throw SvgFeatureRefusal(
          node.nodeIndex,
          'svg-text-harfbuzz-${error.failure.name}',
        );
      } finally {
        path?.dispose();
        run?.dispose();
        font.dispose();
      }
    }
  }

  @override
  void geometry(SvgFeatureGeometryContext context) {
    final c = context;
    for (final text in (c.state[this] as List<_SvgPreparedText>?) ?? const []) {
      text.addGeometry(c);
    }
  }
}

final class _SvgTextInput {
  _SvgTextInput(this.plan, this.root);
  final SvgGraphicsPlan plan;
  final int root;
  final spans = <({int node, int start, int end})>[];
  final characterStyles = <Map<String, String>>[];
  final authoredPositions = <hb.HarfBuzzPosition>[];
  String text = '', anchor = 'start';
  List<String> families = [];
  double fontSize = 16, letterSpacing = 0, wordSpacing = 0;
  double? textLength;
  bool kerningNone = false;
  int weight = 400;
  bool italic = false;
  ui.Color color = const ui.Color(0xff000000);
  List<ui.Offset>? path;
  ({int source, int target})? pathReference;
  hb.HarfBuzzLengthAdjust lengthAdjust = hb.HarfBuzzLengthAdjust.spacing;
  hb.HarfBuzzStartOffset startOffset = const hb.HarfBuzzStartOffset.absolute(0);
  // These exact caps are prepaid once as vector payload by admit. The inner
  // ledger is only a suballocator of that envelope, never a shared admission.
  int get sourceLimit => 1024 * 1024 + text.length * 4096;
  int get vectorLimit => 1024 * 1024;
  int get operationLimit => 12000;
  int get envelopeBytes => sourceLimit + vectorLimit;
  SceneResourceBudget prepaidLedger() => SceneResourceBudget(
    limits: {
      for (final r in SceneResource.values)
        r: switch (r) {
          SceneResource.sourceBytes => sourceLimit,
          SceneResource.sourceNodes => text.length * 32 + 32,
          SceneResource.paragraphs => 1,
          SceneResource.textCodeUnits => math.max(1, text.length),
          SceneResource.vectorBytes => vectorLimit,
          SceneResource.vectorOperations => operationLimit,
          _ => 1,
        },
    },
  );

  static _SvgTextInput read(SvgGraphicsPlan plan, int root) {
    final result = _SvgTextInput(plan, root);
    final service = plan.host.text;
    final inherited = <String, String>{
      if (service is FixedSvgTextFontService) ...service.inheritedStyle(root),
    };
    final ancestors = <int>[];
    var parent = plan.document.node(root).parentIndex;
    while (parent != null) {
      ancestors.add(parent);
      parent = plan.document.node(parent).parentIndex;
    }
    for (final index in ancestors.reversed) {
      final attrs = _svgTextAttributes(plan, index);
      result.validateEffects(index, attrs);
      for (final e in attrs.entries) {
        if (const SvgTextFeature().presentationProperties.contains(e.key) ||
            _svgPaint.contains(e.key)) {
          inherited[e.key] = e.value;
        }
      }
    }
    final base = {...inherited, ..._svgTextAttributes(plan, root)};
    final starts = <int, int>{};
    final chains = <List<int>>[];
    final text = StringBuffer();
    void walk(int index, Map<String, String> parent, List<int> chain) {
      final n = plan.document.node(index);
      if (n.isCharacterData) {
        final value = n.text ?? '';
        if (value.isEmpty) return;
        if (value.runes.any(
          (r) =>
              r < 32 ||
              (r >= 0x590 && r <= 0x8ff) ||
              (r >= 0x10800 && r <= 0x10fff) ||
              (r >= 0x1e800 && r <= 0x1eeff) ||
              (r >= 0x200b && r <= 0x206f) ||
              (r >= 0xd800 && r <= 0xdfff) ||
              (r >= 0xfb1d && r <= 0xfefc),
        )) {
          throw SvgFeatureRefusal(root, 'svg-text-unsupported-run');
        }
        final start = text.length;
        text.write(value);
        result.spans.add((node: index, start: start, end: text.length));
        for (var i = 0; i < value.length; i++) {
          chains.add(chain);
          result.characterStyles.add(parent);
        }
        return;
      }
      if (n.namespaceUri != 'http://www.w3.org/2000/svg' ||
          !const {'text', 'tspan', 'textPath'}.contains(n.localName) ||
          index != root && n.localName == 'text') {
        throw SvgFeatureRefusal(index, 'svg-text-child');
      }
      final own = _svgTextAttributes(plan, index), style = {...parent, ...own};
      starts[index] = text.length;
      for (final e in own.entries) {
        if (!const {
              'xmlns',
              'xmlns:xlink',
              'id',
              'class',
              'data-source',
              'x',
              'y',
              'transform',
              'opacity',
              'visibility',
              'display',
              'overflow',
              'filter',
              'clip-path',
              'mask',
              'href',
              'xlink:href',
            }.contains(e.key) &&
            !_svgPaint.contains(e.key) &&
            !const SvgTextFeature().attributes.contains(e.key)) {
          throw SvgFeatureRefusal(index, 'svg-text-attribute-${e.key}');
        }
        final refusal = const SvgTextFeature().presentationRefusal(
          e.key,
          e.value,
        );
        if (refusal != null) throw SvgFeatureRefusal(index, refusal);
      }
      _validateSvgValues(index, own);
      result.validateEffects(index, own);
      if (own['xml:space'] != null &&
          !const {'default', 'preserve'}.contains(own['xml:space'])) {
        throw SvgFeatureRefusal(index, 'svg-text-whitespace-profile');
      }
      if ((n.localName != 'textPath' &&
              own.keys.any(
                const {'href', 'xlink:href', 'startOffset'}.contains,
              )) ||
          own.keys.any(
            const {
              'width',
              'height',
              'viewBox',
              'preserveAspectRatio',
              'marker-start',
              'marker-mid',
              'marker-end',
            }.contains,
          )) {
        throw SvgFeatureRefusal(index, 'svg-text-attribute-profile');
      }
      if (index != root &&
          own.keys.any(
            const {
              'transform',
              'opacity',
              'display',
              'visibility',
              'filter',
              'clip-path',
              'mask',
              'text-anchor',
            }.contains,
          )) {
        throw SvgFeatureRefusal(index, 'svg-text-child-paint');
      }
      if ((style['stroke'] ?? 'none') != 'none' ||
          (style['fill'] ?? '').startsWith('url(')) {
        throw SvgFeatureRefusal(index, 'svg-text-paint');
      }
      for (final key in ['x', 'y', 'dx', 'dy', 'rotate']) {
        if (own[key] != null && _numbers(own[key]!, index).isEmpty) {
          throw SvgFeatureRefusal(index, 'svg-text-position');
        }
      }
      if (own['textLength'] != null &&
          (own['textLength']!.contains('%') ||
              _number(own['textLength'], index) <= 0)) {
        throw SvgFeatureRefusal(index, 'svg-text-length');
      }
      if (own['lengthAdjust'] != null &&
          !const {
            'spacing',
            'spacingAndGlyphs',
          }.contains(own['lengthAdjust'])) {
        throw SvgFeatureRefusal(index, 'svg-text-length-adjust');
      }
      for (final child in n.children) {
        walk(child, style, [...chain, index]);
      }
    }

    walk(root, inherited, []);
    result.text = text.toString();
    if (result.text.length > 65536) {
      throw SvgFeatureRefusal(root, 'svg-text-limit');
    }
    for (var i = 0; i < chains.length; i++) {
      final values = <String, double>{};
      for (final index in chains[i]) {
        final attrs = _svgTextAttributes(plan, index),
            local = i - starts[index]!;
        for (final key in ['x', 'y', 'dx', 'dy', 'rotate']) {
          if (attrs[key] == null) continue;
          final list = _numbers(attrs[key]!, index);
          if (local < list.length || key == 'rotate') {
            values[key] = list[math.min(local, list.length - 1)];
          }
        }
      }
      result.authoredPositions.add(
        hb.HarfBuzzPosition(
          x: values['x'],
          y: values['y'],
          dx: values['dx'] ?? 0,
          dy: values['dy'] ?? 0,
          rotationDegrees: values['rotate'] ?? 0,
        ),
      );
    }
    result.resolveStyle(base);
    result.resolveScope(chains);
    if (base['xml:space'] != 'preserve' &&
        (result.text.startsWith(' ') ||
            result.text.endsWith(' ') ||
            result.text.contains('  '))) {
      throw SvgFeatureRefusal(root, 'svg-text-whitespace-profile');
    }
    if (result.anchor != 'start' &&
        (result.textLength != null ||
            result.authoredPositions
                .skip(1)
                .any((p) => p.x != null || p.y != null))) {
      throw SvgFeatureRefusal(root, 'svg-text-anchor-chunks');
    }
    return result;
  }

  void resolveStyle(Map<String, String> base) {
    for (final e in base.entries) {
      final refusal = const SvgTextFeature().presentationRefusal(
        e.key,
        e.value,
      );
      if (refusal != null) throw SvgFeatureRefusal(root, refusal);
    }
    families = (base['font-family'] ?? '')
        .split(',')
        .map(
          (s) =>
              s.trim().replaceAll(RegExp(r'''^["']|["']$'''), '').toLowerCase(),
        )
        .where((s) => s.isNotEmpty)
        .toList();
    if (base['font-size']?.contains('%') ?? false) {
      throw SvgFeatureRefusal(root, 'svg-text-font-size-profile');
    }
    fontSize = _number(base['font-size'], root, fallback: 16);
    if (fontSize <= 0 || families.isEmpty) {
      throw SvgFeatureRefusal(root, 'svg-text-font');
    }
    final rawWeight = base['font-weight'] ?? '400';
    weight = switch (rawWeight) {
      'normal' => 400,
      'bold' => 700,
      _ => int.tryParse(rawWeight) ?? 0,
    };
    final style = base['font-style'] ?? 'normal';
    if (weight < 1 ||
        weight > 1000 ||
        !const {'normal', 'italic'}.contains(style)) {
      throw SvgFeatureRefusal(root, 'svg-text-font-descriptor');
    }
    italic = style == 'italic';
    anchor = base['text-anchor'] ?? 'start';
    if (!const {'start', 'middle', 'end'}.contains(anchor)) {
      throw SvgFeatureRefusal(root, 'svg-text-anchor');
    }
    double spacing(String key) =>
        base[key] == 'normal' ? 0 : _number(base[key], root);
    letterSpacing = spacing('letter-spacing');
    wordSpacing = spacing('word-spacing');
    kerningNone = base['font-kerning'] == 'none';
    for (final style in characterStyles) {
      for (final key in [
        'font-family',
        'font-size',
        'font-weight',
        'font-style',
        'letter-spacing',
        'word-spacing',
        'font-kerning',
        'fill',
        'fill-opacity',
      ]) {
        if (style[key] != base[key]) {
          throw SvgFeatureRefusal(root, 'svg-text-mixed-$key');
        }
      }
    }
    final raw = (base['fill'] ?? 'black').toLowerCase();
    final hex = RegExp(r'^#([0-9a-f]{6})$').firstMatch(raw);
    final rgb = switch (raw) {
      'black' => 0,
      'white' => 0xffffff,
      'red' => 0xff0000,
      'blue' => 0x0000ff,
      'green' => 0x008000,
      'none' => 0,
      _ => hex == null ? null : int.parse(hex[1]!, radix: 16),
    };
    if (rgb == null) throw SvgFeatureRefusal(root, 'svg-text-fill');
    final alpha = raw == 'none'
        ? 0
        : (_number(base['fill-opacity'], root, fallback: 1).clamp(0, 1) * 255)
              .round();
    color = ui.Color((alpha << 24) | rgb);
  }

  void validateEffects(int index, Map<String, String> attributes) {
    // These wrappers currently annotate the generic leaf before source text
    // fragments exist. Per-source effect footprints need a separate handoff.
    if (const [
      'clip-path',
      'mask',
      'filter',
    ].any((key) => attributes[key] != null && attributes[key] != 'none')) {
      throw SvgFeatureRefusal(index, 'svg-text-effect-profile');
    }
  }

  void resolveScope(List<List<int>> chains) {
    final elements = chains.expand((e) => e).toSet();
    final paths = elements.where(
      (i) => plan.document.node(i).localName == 'textPath',
    );
    int scope = root;
    if (paths.isNotEmpty) {
      if (paths.length != 1 || chains.any((c) => !c.contains(paths.single))) {
        throw SvgFeatureRefusal(root, 'svg-text-path-scope');
      }
      scope = paths.single;
      final attrs = plan._attributes(scope);
      final href = attrs['href'] ?? attrs['xlink:href'];
      if (href == null) throw SvgFeatureRefusal(scope, 'svg-text-path-href');
      final target = plan._reference(scope, href), p = plan._attributes(target);
      pathReference = (source: scope, target: target);
      var ancestor = plan.document.node(target).parentIndex;
      while (ancestor != null &&
          plan.document.node(ancestor).localName != 'svg') {
        if (plan._attributes(ancestor)['transform'] != null) {
          throw SvgFeatureRefusal(scope, 'svg-text-path-profile');
        }
        ancestor = plan.document.node(ancestor).parentIndex;
      }
      final d = p['d'] ?? '';
      if (plan.document.node(target).localName != 'path' ||
          p['transform'] != null ||
          p['pathLength'] != null ||
          !RegExp(r'^\s*M\s*[-+\d.\s,eE]+Q\s*[-+\d.\s,eE]+\s*$').hasMatch(d)) {
        throw SvgFeatureRefusal(scope, 'svg-text-path-profile');
      }
      final values = _numbers(d.replaceAll(RegExp('[MQ]'), ' '), scope);
      if (values.length != 6) {
        throw SvgFeatureRefusal(scope, 'svg-text-path-profile');
      }
      path = [
        for (var i = 0; i < 6; i += 2) ui.Offset(values[i], values[i + 1]),
      ];
      final raw = attrs['startOffset'] ?? '0';
      startOffset = raw.endsWith('%')
          ? hb.HarfBuzzStartOffset.percent(
              _number(raw.substring(0, raw.length - 1), scope),
            )
          : hb.HarfBuzzStartOffset.absolute(_number(raw, scope));
      if (anchor != 'start' ||
          authoredPositions.any(
            (p) =>
                p.x != null ||
                p.y != null ||
                p.dx != 0 ||
                p.dy != 0 ||
                p.rotationDegrees != 0,
          ) ||
          letterSpacing != 0 ||
          wordSpacing != 0) {
        throw SvgFeatureRefusal(root, 'svg-text-path-position');
      }
    }
    for (final element in elements) {
      if (element == root || element == scope) continue;
      if (plan._attributes(element)['textLength'] != null) {
        if (chains.any((c) => !c.contains(element)) || scope != root) {
          throw SvgFeatureRefusal(element, 'svg-text-length-scope');
        }
        scope = element;
      }
    }
    final attrs = plan._attributes(scope);
    // textPath establishes its own length scope. Parent textLength is not
    // inherited into it (the pinned WebKit parent-length diagnostic).
    if (attrs['textLength'] != null) {
      textLength = _number(attrs['textLength'], scope);
    }
    lengthAdjust = attrs['lengthAdjust'] == 'spacingAndGlyphs'
        ? hb.HarfBuzzLengthAdjust.spacingAndGlyphs
        : hb.HarfBuzzLengthAdjust.spacing;
  }

  void validatePaintPositions(hb.HarfBuzzRun run) {
    // Placement consumes the first UTF-16 slot of each paint cluster. Refuse
    // changes in a continuation instead of silently losing authored positions.
    for (final range in run.paintClusters) {
      final first = authoredPositions[range.start];
      for (var i = range.start + 1; i < range.end; i++) {
        final p = authoredPositions[i];
        if (p.x != null ||
            p.y != null ||
            p.dx != 0 ||
            p.dy != 0 ||
            p.rotationDegrees != first.rotationDegrees ||
            letterSpacing != 0) {
          throw SvgFeatureRefusal(root, 'svg-text-cluster-position');
        }
      }
    }
  }

  double endAnchorShift(double advance) =>
      (textLength ?? advance) +
      authoredPositions.skip(1).fold<double>(0, (sum, p) => sum + p.dx) +
      letterSpacing * math.max(0, text.length - 1) +
      wordSpacing *
          ' '.allMatches(text.substring(math.min(1, text.length))).length;

  List<hb.HarfBuzzPosition> positions(double advance) => [
    for (var i = 0; i < authoredPositions.length; i++)
      hb.HarfBuzzPosition(
        x: authoredPositions[i].x == null
            ? null
            : authoredPositions[i].x! -
                  (anchor == 'end' ? endAnchorShift(advance) : 0),
        y: authoredPositions[i].y,
        dx:
            authoredPositions[i].dx +
            (i > 0 ? letterSpacing : 0) +
            (text.codeUnitAt(i) == 32 ? wordSpacing : 0),
        dy: authoredPositions[i].dy,
        rotationDegrees: authoredPositions[i].rotationDegrees,
      ),
  ];
}

final class _SvgPreparedText {
  _SvgPreparedText(
    this.node,
    this.input,
    this.placed,
    this.layoutClusters,
    this.glyphCount,
  );
  final SvgFeatureNode node;
  final _SvgTextInput input;
  final hb.HarfBuzzPlacedRun placed;
  final List<Utf16Range> layoutClusters;
  final int glyphCount;
  final coverage = <int, GeometryAlphaFootprint>{};
  final bounds = <int, ui.Rect>{};

  void addGeometry(SvgFeatureGeometryContext c) {
    var cursor = 0;
    for (final range in layoutClusters) {
      if (range.start != cursor ||
          range.end <= range.start ||
          range.end > input.text.length ||
          !placed.fragments.any((f) => f.layoutRange == range)) {
        throw SvgFeatureRefusal(
          node.nodeIndex,
          'svg-text-cluster-conservation',
        );
      }
      cursor = range.end;
    }
    if (cursor != input.text.length) {
      throw SvgFeatureRefusal(node.nodeIndex, 'svg-text-cluster-conservation');
    }
    final ids = node.clips.map((e) => e.id).toList();
    final opacity =
        const {'hidden', 'collapse'}.contains(node.paint['visibility'])
        ? 0.0
        : node.opacity;
    var count = 0;
    for (final span in input.spans) {
      final clusters = <ClusterGeometry>[];
      for (final layout in layoutClusters) {
        final members = placed.fragments
            .where((f) => f.layoutRange == layout)
            .toList();
        final first = members.first.geometry;
        final width = members.fold<double>(
          0,
          (sum, f) =>
              sum +
              f.placementAdvance *
                  (f.geometry.range.end - f.geometry.range.start),
        );
        final bounds = members
            .map((f) => f.path.getBounds())
            .reduce((a, b) => a.expandToInclude(b));
        final g = ClusterGeometry(
          range: layout,
          granularity: ClusterGranularity.shapingCluster,
          provenance: ClusterProvenance.shaped,
          quad: [
            for (final p in [
              bounds.topLeft,
              bounds.topRight,
              bounds.bottomRight,
              bounds.bottomLeft,
            ])
              GeometryPoint(p.dx, p.dy),
          ],
          baselineStart: first.baselineStart,
          baselineEnd: GeometryPoint(
            first.baselineStart.x + width * math.cos(first.rotationRadians),
            first.baselineStart.y + width * math.sin(first.rotationRadians),
          ),
          rotationRadians: first.rotationRadians,
        );
        if (g.range.end <= span.start || g.range.start >= span.end) continue;
        if (g.range.start < span.start || g.range.end > span.end) {
          throw SvgFeatureRefusal(
            node.nodeIndex,
            'svg-text-cross-node-cluster',
          );
        }
        count += g.range.end - g.range.start;
        clusters.add(
          ClusterGeometry(
            range: Utf16Range(
              g.range.start - span.start,
              g.range.end - span.start,
            ),
            granularity: g.granularity,
            provenance: g.provenance,
            quad: g.quad,
            baselineStart: g.baselineStart,
            baselineEnd: g.baselineEnd,
            rotationRadians: g.rotationRadians,
          ),
        );
      }
      c.geometry.addFragment(
        SourceFragment(
          page: c.plan.page,
          nodeIndex: span.node,
          kind: SourceFragmentKind.svgText,
          textRange: Utf16Range(0, span.end - span.start),
          clusters: clusters,
          elementAnchor: null,
          sourceToUnit: node.transform,
          clipIds: ids,
          maskIds: const [],
          paintOrdinal: node.paintOrdinal,
          effectiveOpacity: opacity,
        ),
      );
      c.geometry.addPaint(
        GeometryPaint(
          nodeIndex: span.node,
          paintOrdinal: node.paintOrdinal,
          region: _region(bounds[span.node]!, node.transform),
          kind: GeometryPaintKind.text,
          effectiveOpacity: opacity,
          exactCoverage: true,
          alphaFootprint: coverage[span.node],
          clipIds: ids,
          groupIds: node.groups.map((g) => g.id).toList(),
          textRanges: [Utf16Range(0, span.end - span.start)],
        ),
      );
    }
    if (count != input.text.length ||
        layoutClusters.first.start != 0 ||
        layoutClusters.last.end != input.text.length ||
        placed.fragments.expand((f) => f.glyphIndices).toSet().length !=
            glyphCount ||
        placed.fragments.expand((f) => f.glyphIndices).length !=
            placed.fragments.expand((f) => f.glyphIndices).toSet().length) {
      throw SvgFeatureRefusal(node.nodeIndex, 'svg-text-cluster-conservation');
    }
    // Replace the leaf's generic image evidence with exact per-source text
    // coverage at the same module ordinal. Painting still happens only once.
    c._paint.removeWhere(
      (p) =>
          p.nodeIndex == node.nodeIndex && p.paintOrdinal == node.paintOrdinal,
    );
  }
}
