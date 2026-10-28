part of 'fixed_scene.dart';

/// Fixed scenes draw their own decoration bands when pinned font metrics are
/// available. Otherwise keep the engine decoration as the explicit fallback.
bool _engineDecorationsVisible(ParagraphFonts fonts, TextBlock block) {
  if (!block.runs.any((r) => r.style.underline || r.style.lineThrough)) {
    return true;
  }
  final base = block.baseStyle;
  final resolved = fonts.resolve(
    base.fontFamilies,
    weight: base.fontWeight,
    style: base.fontStyle,
  );
  return !fonts.decorationMetrics.containsKey(resolved.primary);
}

extension _FixedLayout on FixedSceneBuilder {
  FixedBox? _layout(
    int index,
    FixedBox? parent,
    ui.Rect containing,
    ui.Offset flow,
    FixedBox? positioned,
    int depth,
  ) {
    _checkCancellation();
    if (depth > 128 || !_active.add(index)) {
      _reject(index, 'layout-cycle-or-depth', malformed: true);
      return null;
    }
    try {
      final node = document.node(index), style = styles.styleOf(index);
      if (style == null || style.display == StyleDisplay.none) return null;
      if (style.writingMode != StyleWritingMode.horizontalTb ||
          style.direction != StyleDirection.ltr) {
        _reject(index, 'vertical-or-rtl-layout');
      }
      if (node.localName == 'svg' &&
          node.namespaceUri == 'http://www.w3.org/2000/svg') {
        return _layoutSvg(index, parent, flow);
      }
      if (node.namespaceUri != 'http://www.w3.org/1999/xhtml' ||
          atomicElementNames.contains(node.localName)) {
        _reject(index, 'non-xhtml-box');
        return null;
      }
      if (style.display == StyleDisplay.listItem) _reject(index, 'list-marker');
      final box = FixedBox._(index, style, parent);
      _boxes.add(box);
      parent?.children.add(box);
      parent?.contents.add(box);
      final a = style.authored;
      final out =
          a.position == AuthoredPosition.absolute ||
          a.position == AuthoredPosition.fixed;
      final cb = a.position == AuthoredPosition.fixed
          ? ui.Rect.fromLTWH(0, 0, size.width, size.height)
          : out && positioned != null
          ? positioned.borderBox.deflate(0)
          : containing;
      final basis = cb.width;
      double edge(StyleLength l) => l.resolve(basis) ?? 0;
      final ml = edge(style.margin.left),
          mr = edge(style.margin.right),
          mt = edge(style.margin.top);
      final pl = edge(style.padding.left),
          pr = edge(style.padding.right),
          pt = edge(style.padding.top),
          pb = edge(style.padding.bottom);
      double border(String e) =>
          a.borderStyle(e) == 'none' ? 0 : a.borderWidth(e).resolve(basis) ?? 0;
      final bl = border('left'),
          br = border('right'),
          bt = border('top'),
          bb = border('bottom');
      final extraW = pl + pr + bl + br, extraH = pt + pb + bt + bb;
      final left = a.inset('left').resolve(cb.width),
          right = a.inset('right').resolve(cb.width);
      final top = a.inset('top').resolve(cb.height),
          bottom = a.inset('bottom').resolve(cb.height);
      var width = style.width.resolve(cb.width);
      final shrink =
          (out && (left == null || right == null) ||
              style.display == StyleDisplay.inlineBlock) &&
          width == null;
      if (shrink &&
          node.children.any(
            (c) => styles.styleOf(c)?.width.kind == StyleLengthKind.percent,
          )) {
        _reject(index, 'percentage-width-cycle', malformed: true);
      }
      width ??= out && left != null && right != null
          ? cb.width - left - right - ml - mr - extraW
          : cb.width - ml - mr - extraW;
      if (a.boxSizing == AuthoredBoxSizing.borderBox &&
          style.width.kind != StyleLengthKind.auto) {
        width -= extraW;
      }
      double constrain(
        double value,
        StyleLength min,
        StyleLength? max,
        double base,
        double extra,
      ) {
        final adjust = a.boxSizing == AuthoredBoxSizing.borderBox ? extra : 0.0;
        final lower = math.max(0.0, (min.resolve(base) ?? 0) - adjust);
        final upper = max?.resolve(base);
        return math.max(
          lower,
          upper == null ? value : math.min(value, math.max(0, upper - adjust)),
        );
      }

      width = constrain(
        math.max(0, width),
        a.minimum('width'),
        style.maxWidth,
        cb.width,
        extraW,
      );
      var height = style.height.resolve(cb.height);
      if (height != null && a.boxSizing == AuthoredBoxSizing.borderBox) {
        height = math.max(0, height - extraH);
      }
      if (height == null && out && top != null && bottom != null) {
        height = math.max(
          0,
          cb.height - top - bottom - extraH - mt - edge(style.margin.bottom),
        );
      }
      var x = out ? cb.left + (left ?? 0) + ml : flow.dx + ml;
      var y = out ? cb.top + (top ?? 0) + mt : flow.dy + mt;
      if (a.position == AuthoredPosition.relative) {
        x += left ?? -(right ?? 0);
        y += top ?? -(bottom ?? 0);
      }
      box.borderBox = ui.Rect.fromLTWH(
        x,
        y,
        width + extraW,
        (height ?? 0) + extraH,
      );
      box.contentBox = ui.Rect.fromLTWH(
        x + bl + pl,
        y + bt + pt,
        width,
        height ?? 0,
      );
      final content = box.contentBox;
      var cursor = content.top, maxInline = 0.0;
      final inline = <int>[];
      void flush() {
        if (inline.isEmpty) return;
        final acc = InlineAccumulator();
        final inlineBoxes = <FixedBox>[];
        final nodeShifts = <int, double>{};
        void collect(int child, [double inheritedShift = 0]) {
          final n = document.node(child), s = styles.styleOf(child);
          if (s == null || s.display == StyleDisplay.none) return;
          var shift = inheritedShift;
          if (!n.isCharacterData) {
            final parentSize =
                (n.parentIndex == null ? null : styles.styleOf(n.parentIndex!))
                    ?.fontSize ??
                style.fontSize;
            // CSS leaves sub/super displacement to the UA. This horizontal
            // profile follows the reference UA's parent-font-relative rule.
            shift += switch (s.verticalAlign) {
              StyleVerticalAlign.baseline => 0,
              StyleVerticalAlign.sub => parentSize / 5 + 1,
              StyleVerticalAlign.superscript => -(parentSize / 3 + 1),
            };
          }
          nodeShifts[child] = shift;
          if (n.isCharacterData) {
            acc.addText(child, n.text ?? '', s);
            return;
          }
          if (n.localName == 'br') {
            acc.addBreak(child, s);
            return;
          }
          if (s.display == StyleDisplay.inlineBlock) {
            final childBox = _layout(
              child,
              box,
              ui.Rect.fromLTWH(
                content.left,
                content.top,
                width!,
                height ?? cb.height,
              ),
              ui.Offset(content.left, cursor),
              a.position != AuthoredPosition.static || a.transforms.isNotEmpty
                  ? box
                  : positioned,
              depth + 1,
            );
            if (childBox != null) {
              inlineBoxes.add(childBox);
              final margin = childBox.style.margin, r = childBox.borderBox;
              final baseline = childBox.texts.isEmpty
                  ? r.height
                  : childBox.texts.last.origin.dy -
                        r.top +
                        childBox
                            .texts
                            .last
                            .paragraph
                            .paragraph
                            .alphabeticBaseline;
              acc.addPlaceholder(
                child,
                s,
                width: r.width + edge(margin.left) + edge(margin.right),
                height: r.height + edge(margin.top) + edge(margin.bottom),
                baseline: baseline + edge(margin.top),
              );
            }
            return;
          }
          if (s.authored.opacity != 1 || s.authored.transforms.isNotEmpty) {
            _reject(child, 'inline-compositing');
          }
          for (final c in n.children) {
            collect(c, shift);
          }
        }

        for (final child in inline) {
          collect(child);
        }
        inline.clear();
        if (!acc.hasContent) return;
        final indent = style.textIndent.resolve(width!) ?? 0;
        if (indent < 0) _reject(index, 'negative-text-indent');
        final result = acc.finish(style, [
          if (indent > 0) InlinePrefix.placeholder(indent, style),
        ]);
        if (result == null) return;
        final block = TextBlock(
          index: _texts.length,
          gapBefore: 0,
          breakBefore: false,
          leftInset: 0,
          rightInset: 0,
          text: result.text,
          runs: result.runs,
          map: result.map,
          baseStyle: style,
          backgrounds: const [],
          firstNodeIndex: result.firstNodeIndex,
          lastNodeIndex: result.lastNodeIndex,
        );
        try {
          _leases.add(budget.reserve({SceneResource.paragraphs: 1}));
        } on SceneAdmissionException {
          _resourceFailures.add(
            OffendingConstruct(
              kind: CapabilityConstructKind.resource,
              identifier: 'paragraphs',
              nodeIndex: index,
            ),
          );
          return;
        }
        var built = buildParagraph(
          block,
          math.max(1, width!),
          fonts,
          paintBackgrounds: false,
          paintDecorations: _engineDecorationsVisible(fonts, block),
        );
        if (style.whiteSpace == StyleWhiteSpace.nowrap ||
            style.whiteSpace == StyleWhiteSpace.pre) {
          final intrinsic = built.paragraph.maxIntrinsicWidth;
          if (intrinsic > built.layoutWidth) {
            built.dispose();
            built = buildParagraph(
              block,
              intrinsic,
              fonts,
              paintBackgrounds: false,
              paintDecorations: _engineDecorationsVisible(fonts, block),
            );
          }
        }
        if (shrink) {
          final desired = constrain(
            built.paragraph.maxIntrinsicWidth,
            a.minimum('width'),
            style.maxWidth,
            cb.width,
            extraW,
          );
          if (desired != width) {
            width = desired;
            built.dispose();
            built = buildParagraph(
              block,
              math.max(1, width!),
              fonts,
              paintBackgrounds: false,
              paintDecorations: _engineDecorationsVisible(fonts, block),
            );
          }
        }
        final positions = result.runs
            .map((r) => r.style.authored)
            .where((a) => a.position == AuthoredPosition.relative)
            .toList();
        var offset = ui.Offset.zero;
        if (positions.isNotEmpty) {
          if (positions.length == result.runs.length) {
            final relative = positions.first;
            offset = ui.Offset(
              relative.inset('left').resolve(width!) ??
                  -(relative.inset('right').resolve(width!) ?? 0),
              relative.inset('top').resolve(height ?? cb.height) ??
                  -(relative.inset('bottom').resolve(height ?? cb.height) ?? 0),
            );
          } else {
            _reject(index, 'mixed-relative-inline-offsets');
          }
        }
        final origin = ui.Offset(content.left, cursor) + offset;
        final text = FixedText._(box, block, built, origin);
        box.texts.add(text);
        box.contents.add(text);
        _texts.add(text);
        if (nodeShifts.values.any((shift) => shift != 0)) {
          try {
            text._inline = _layoutInline(block, built, nodeShifts);
          } on SceneAdmissionException {
            _resourceFailures.add(
              OffendingConstruct(
                kind: CapabilityConstructKind.resource,
                identifier: 'inline-paragraphs',
                nodeIndex: index,
              ),
            );
          }
        }
        final placeholders = built.paragraph.getBoxesForPlaceholders();
        final placeholderRuns = result.runs
            .where((r) => r.placeholderWidth != null)
            .toList();
        for (final child in inlineBoxes) {
          final entry = block.map.entries.firstWhere(
            (e) =>
                e.nodeIndex == child.nodeIndex && e.kind == MapKind.synthetic,
          );
          final i = placeholderRuns.indexWhere(
            (r) => r.start == entry.paraStart,
          );
          if (i < 0 || i >= placeholders.length) {
            _reject(
              child.nodeIndex,
              'missing-inline-placeholder',
              malformed: true,
            );
            continue;
          }
          final rect = placeholders[i].toRect(),
              margin = child.style.margin,
              delta = text._offsetAt(placeholderRuns[i].start);
          _shift(
            child,
            origin.dx +
                delta.dx +
                rect.left +
                edge(margin.left) -
                child.borderBox.left,
            origin.dy +
                delta.dy +
                rect.top +
                edge(margin.top) -
                child.borderBox.top,
          );
        }
        cursor += text.height;
        maxInline = math.max(maxInline, built.paragraph.maxIntrinsicWidth);
      }

      for (final child in node.children) {
        final n = document.node(child), s = styles.styleOf(child);
        if (s == null || s.display == StyleDisplay.none) continue;
        final childOut =
            s.authored.position == AuthoredPosition.absolute ||
            s.authored.position == AuthoredPosition.fixed;
        if (n.isCharacterData ||
            (s.display == StyleDisplay.inline ||
                    s.display == StyleDisplay.inlineBlock) &&
                !childOut &&
                n.namespaceUri != 'http://www.w3.org/2000/svg') {
          inline.add(child);
          continue;
        }
        flush();
        final childBox = _layout(
          child,
          box,
          ui.Rect.fromLTWH(
            content.left,
            content.top,
            width!,
            height ?? cb.height,
          ),
          ui.Offset(content.left, cursor),
          a.position != AuthoredPosition.static || a.transforms.isNotEmpty
              ? box
              : positioned,
          depth + 1,
        );
        if (childBox != null && !childOut) {
          cursor = childBox.borderBox.bottom + edge(s.margin.bottom);
        }
      }
      flush();
      height ??= math.max(0, cursor - content.top);
      height = constrain(
        height,
        a.minimum('height'),
        style.maxHeight,
        cb.height,
        extraH,
      );
      if (shrink && box.texts.isEmpty && box.children.isEmpty) {
        width = math.min(width!, maxInline);
      }
      if (out && left == null && right != null) {
        x = cb.right - right - width! - extraW - mr;
      }
      if (out && top == null && bottom != null) {
        y = cb.bottom - bottom - height - extraH - edge(style.margin.bottom);
      }
      final dx = x - box.borderBox.left, dy = y - box.borderBox.top;
      if (dx != 0 || dy != 0) _shift(box, dx, dy);
      box.borderBox = ui.Rect.fromLTWH(x, y, width! + extraW, height + extraH);
      box.contentBox = ui.Rect.fromLTWH(
        x + bl + pl,
        y + bt + pt,
        width!,
        height,
      );
      if (![x, y, width!, height, extraW, extraH].every((v) => v.isFinite)) {
        _reject(index, 'nonfinite-box', malformed: true);
      }
      return box;
    } finally {
      _active.remove(index);
    }
  }

  void _shift(FixedBox box, double dx, double dy) {
    box.borderBox = box.borderBox.shift(ui.Offset(dx, dy));
    box.contentBox = box.contentBox.shift(ui.Offset(dx, dy));
    if (box.svgContentTransform != null) {
      box.svgContentTransform = _translation(
        dx,
        dy,
      ).compose(box.svgContentTransform!);
      return;
    }
    for (var i = 0; i < box.texts.length; i++) {
      final t = box.texts[i],
          replacement = FixedText._(
            box,
            t.block,
            t.paragraph,
            t.origin + ui.Offset(dx, dy),
          ).._inline = t._inline;
      _texts[_texts.indexOf(t)] = replacement;
      box.texts[i] = replacement;
      box.contents[box.contents.indexOf(t)] = replacement;
    }
    for (final child in box.children) {
      _shift(child, dx, dy);
    }
  }

  void _transforms(
    FixedBox box,
    AffineTransform parent,
    double opacity,
    List<String> clips,
  ) {
    final a = box.style.authored, r = box.borderBox;
    var t = const AffineTransform.identity();
    for (final op in a.transforms) {
      final v = op.arguments;
      double n(int i, [double fallback = 0]) =>
          i < v.length ? (v[i] as num).toDouble() : fallback;
      double l(int i, double base) =>
          i < v.length ? (v[i] as StyleLength).resolve(base) ?? 0 : 0;
      final m = switch (op.name) {
        'matrix' => AffineTransform(n(0), n(1), n(2), n(3), n(4), n(5)),
        'translate' => _translation(l(0, r.width), l(1, r.height)),
        'translatex' => _translation(l(0, r.width), 0),
        'translatey' => _translation(0, l(0, r.height)),
        'scale' => AffineTransform(n(0), 0, 0, n(1, n(0)), 0, 0),
        'scalex' => AffineTransform(n(0), 0, 0, 1, 0, 0),
        'scaley' => AffineTransform(1, 0, 0, n(0), 0, 0),
        'rotate' => AffineTransform(
          math.cos(n(0)),
          math.sin(n(0)),
          -math.sin(n(0)),
          math.cos(n(0)),
          0,
          0,
        ),
        'skewx' => AffineTransform(1, 0, math.tan(n(0)), 1, 0, 0),
        'skewy' => AffineTransform(1, math.tan(n(0)), 0, 1, 0, 0),
        _ => AffineTransform(1, math.tan(n(1)), math.tan(n(0)), 1, 0, 0),
      };
      t = t.compose(m);
    }
    final origin = box.svgFill != null
        ? r.topLeft
        : ui.Offset(
            r.left + (a.transformOrigin[0].resolve(r.width) ?? 0),
            r.top + (a.transformOrigin[1].resolve(r.height) ?? 0),
          );
    box.localTransform = t;
    box.transformOrigin = origin - r.topLeft;
    box.transform = parent
        .compose(_translation(origin.dx, origin.dy))
        .compose(t)
        .compose(_translation(-origin.dx, -origin.dy));
    final inversion = box.transform.inverse();
    box.hasVisibleTransform =
        (box.parent?.hasVisibleTransform ?? true) &&
        inversion is InvertedTransform;
    if (inversion is NonInvertibleTransform &&
        inversion.reason == InversionFailure.numericRange) {
      _reject(box.nodeIndex, 'transform-numeric-range', malformed: true);
    }
    box.effectiveOpacity = opacity * a.opacity;
    box.clipIds = clips;
    var childrenClips = clips;
    if (box.hasVisibleTransform &&
        (a.overflow != AuthoredOverflow.visible ||
            box.svgContentTransform != null)) {
      final id = 'box-${box.nodeIndex}';
      _clips.add(GeometryClip(id: id, region: _region(box, r)));
      childrenClips = [...clips, id];
    }
    for (final child in box.children) {
      _transforms(
        child,
        box.transform.compose(
          box.svgContentTransform ?? const AffineTransform.identity(),
        ),
        box.effectiveOpacity,
        childrenClips,
      );
    }
  }
}
