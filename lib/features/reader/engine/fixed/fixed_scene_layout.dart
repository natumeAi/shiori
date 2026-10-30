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
  ui.Rect _positioningBlock(
    ComputedStyle style,
    ui.Rect containing,
    FixedBox? positioned,
  ) {
    final position = style.authored.position;
    return position == AuthoredPosition.fixed
        ? ui.Rect.fromLTWH(0, 0, size.width, size.height)
        : position == AuthoredPosition.absolute && positioned != null
        ? positioned.borderBox
        : containing;
  }

  ui.Offset _positionedOrigin(
    ComputedStyle style,
    ui.Rect cb,
    ui.Offset flow,
    ui.Size borderSize, {
    bool trailing = true,
  }) {
    final a = style.authored;
    final out =
        a.position == AuthoredPosition.absolute ||
        a.position == AuthoredPosition.fixed;
    final left = a.inset('left').resolve(cb.width),
        right = a.inset('right').resolve(cb.width),
        top = a.inset('top').resolve(cb.height),
        bottom = a.inset('bottom').resolve(cb.height);
    double margin(StyleLength length) => length.resolve(cb.width) ?? 0;
    var x = (out ? cb.left + (left ?? 0) : flow.dx) + margin(style.margin.left);
    var y = (out ? cb.top + (top ?? 0) : flow.dy) + margin(style.margin.top);
    if (a.position == AuthoredPosition.relative) {
      x += left ?? -(right ?? 0);
      y += top ?? -(bottom ?? 0);
    }
    if (trailing && out && left == null && right != null) {
      x = cb.right - right - borderSize.width - margin(style.margin.right);
    }
    if (trailing && out && top == null && bottom != null) {
      y = cb.bottom - bottom - borderSize.height - margin(style.margin.bottom);
    }
    return ui.Offset(x, y);
  }

  bool _missingInlineContainingBlock(int index) {
    var ancestor = document.node(index).parentIndex;
    while (ancestor != null) {
      // A foreignObject host supplies its own definite containing viewport.
      if (ancestor == _foreignRoot) return false;
      final node = document.node(ancestor), style = styles.styleOf(ancestor);
      if (style != null &&
          (style.authored.position != AuthoredPosition.static ||
              style.authored.transforms.isNotEmpty)) {
        // Relative non-atomic inline elements are flattened into paragraphs.
        // Their CSS containing block requires first/last inline fragment boxes,
        // which are not retained by this layout path. An intervening positioned
        // block/atomic element supplies a real box and ends the search instead.
        return style.authored.position == AuthoredPosition.relative &&
            style.display == StyleDisplay.inline &&
            node.namespaceUri == 'http://www.w3.org/1999/xhtml' &&
            !atomicElementNames.contains(node.localName);
      }
      ancestor = node.parentIndex;
    }
    return false;
  }

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
      final node = document.node(index);
      final foreignRoot = index == _foreignRoot;
      final style = foreignRoot
          ? _foreignRootStyle(
              styles.styleOf(index) ?? const ComputedStyle(),
              size,
            )
          : styles.styleOf(index);
      if (style == null || style.display == StyleDisplay.none) return null;
      if (style.authored.position == AuthoredPosition.absolute &&
          _missingInlineContainingBlock(index)) {
        _reject(index, 'inline-positioned-containing-block');
        return null;
      }
      if (style.writingMode != StyleWritingMode.horizontalTb ||
          style.direction != StyleDirection.ltr) {
        _reject(index, 'vertical-or-rtl-layout');
      }
      if (node.localName == 'svg' &&
          node.namespaceUri == 'http://www.w3.org/2000/svg') {
        return _layoutSvg(index, parent, containing, flow, positioned);
      }
      if (!foreignRoot &&
          (node.namespaceUri != 'http://www.w3.org/1999/xhtml' ||
              atomicElementNames.contains(node.localName) &&
                  node.localName != 'img')) {
        _reject(index, 'non-xhtml-box');
        return null;
      }
      if (style.display == StyleDisplay.listItem) _reject(index, 'list-marker');
      final box = FixedBox._(index, style, parent);
      if (node.localName == 'img') {
        box.imagePath = node.attribute('src');
        if (!backgroundImages.containsKey(box.imagePath)) {
          _reject(index, 'missing-admitted-image');
        }
      }
      _boxes.add(box);
      parent?.children.add(box);
      parent?.contents.add(box);
      final a = style.authored;
      final out =
          a.position == AuthoredPosition.absolute ||
          a.position == AuthoredPosition.fixed;
      final cb = _positioningBlock(style, containing, positioned);
      final basis = cb.width;
      double edge(StyleLength l) => l.resolve(basis) ?? 0;
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
      final cbHeight = parent == null || a.position == AuthoredPosition.fixed
          ? cb.height
          : out && positioned != null
          ? positioned.definiteContentHeight == null
                ? null
                : cb.height
          : parent.definiteContentHeight;
      final used = FixedUsedBoxSize.resolve(style, cb.width, cbHeight);
      var width = used.width;
      final shrink =
          (out && (left == null || right == null) ||
              style.display == StyleDisplay.inlineBlock) &&
          style.width.kind == StyleLengthKind.auto;
      if (shrink &&
          node.children.any(
            (c) => styles.styleOf(c)?.width.kind == StyleLengthKind.percent,
          )) {
        _reject(index, 'percentage-width-cycle', malformed: true);
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
      var height = used.height;
      if (node.localName == 'img') {
        final intrinsic = intrinsicImageSizes[box.imagePath];
        if (intrinsic != null) {
          final ratio = intrinsic.width / intrinsic.height;
          final autoW = style.width.kind == StyleLengthKind.auto;
          final autoH = height == null;
          double imageLimit(String axis, double value) =>
              FixedUsedBoxSize.constrain(
                style,
                axis,
                value,
                axis == 'width' ? cb.width : cbHeight,
                axis == 'width' ? extraW : extraH,
              );
          if (autoW && autoH) {
            final lower = math.max(
              imageLimit('width', 0) / intrinsic.width,
              imageLimit('height', 0) / intrinsic.height,
            );
            final upper = math.min(
              imageLimit('width', double.infinity) / intrinsic.width,
              imageLimit('height', double.infinity) / intrinsic.height,
            );
            final factor = math.max(lower, math.min(1.0, upper));
            width = imageLimit('width', intrinsic.width * factor);
            height = imageLimit('height', intrinsic.height * factor);
          } else if (autoW) {
            height = imageLimit('height', height!);
            width = imageLimit('width', height * ratio);
          } else if (autoH) {
            width = imageLimit('width', width);
            height = imageLimit('height', width / ratio);
          }
        } else {
          _reject(index, 'missing-image-intrinsic-size');
        }
      }
      box.definiteContentHeight = height;
      final origin = _positionedOrigin(
        style,
        cb,
        flow,
        ui.Size.zero,
        trailing: false,
      );
      var x = origin.dx, y = origin.dy;
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
        final relativeOffsets = <int, ui.Offset>{};
        void collect(
          int child, [
          double inheritedShift = 0,
          ui.Offset relativeOffset = ui.Offset.zero,
        ]) {
          final n = document.node(child), s = styles.styleOf(child);
          if (s == null || s.display == StyleDisplay.none) return;
          if (!n.isCharacterData &&
              (s.authored.position == AuthoredPosition.absolute ||
                  s.authored.position == AuthoredPosition.fixed)) {
            // Nested inline descendants still use their containing block;
            // they neither consume nor receive paragraph placeholder space.
            _layout(
              child,
              box,
              ui.Rect.fromLTWH(
                content.left,
                content.top,
                width,
                height ?? cb.height,
              ),
              ui.Offset(content.left, cursor),
              a.position != AuthoredPosition.static || a.transforms.isNotEmpty
                  ? box
                  : positioned,
              depth + 1,
            );
            return;
          }
          var shift = inheritedShift;
          if (!n.isCharacterData) {
            if (s.authored.position == AuthoredPosition.relative) {
              relativeOffset += ui.Offset(
                s.authored.inset('left').resolve(width) ??
                    -(s.authored.inset('right').resolve(width) ?? 0),
                s.authored.inset('top').resolve(height ?? cb.height) ??
                    -(s.authored.inset('bottom').resolve(height ?? cb.height) ??
                        0),
              );
            }
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
          relativeOffsets[child] = relativeOffset;
          if (n.isCharacterData) {
            acc.addText(child, n.text ?? '', s);
            return;
          }
          if (n.localName == 'br') {
            acc.addBreak(child, s);
            return;
          }
          if (s.display == StyleDisplay.inlineBlock ||
              atomicElementNames.contains(n.localName) ||
              n.namespaceUri != 'http://www.w3.org/1999/xhtml') {
            final childBox = _layout(
              child,
              box,
              ui.Rect.fromLTWH(
                content.left,
                content.top,
                width,
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
          if (s.authored.backgroundImage != null ||
              const [
                'top',
                'right',
                'bottom',
                'left',
              ].any((e) => s.authored.borderStyle(e) != 'none') ||
              [
                s.padding.top,
                s.padding.right,
                s.padding.bottom,
                s.padding.left,
              ].any((p) => (p.resolve(width) ?? 0) != 0) ||
              [
                s.margin.top,
                s.margin.right,
                s.margin.bottom,
                s.margin.left,
              ].any((p) => (p.resolve(width) ?? 0) != 0) ||
              const [
                'top-left',
                'top-right',
                'bottom-right',
                'bottom-left',
              ].any((c) => (s.authored.radius(c).resolve(width) ?? 0) != 0)) {
            _reject(child, 'inline-box-decoration');
          }
          for (final c in n.children) {
            collect(c, shift, relativeOffset);
          }
        }

        for (final child in inline) {
          collect(child);
        }
        inline.clear();
        if (!acc.hasContent) return;
        final indent = style.textIndent.resolve(width) ?? 0;
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
          _leases.add(
            budget.reserve({
              SceneResource.paragraphs: 1,
              SceneResource.textCodeUnits: result.map.entries
                  .where(
                    (e) =>
                        e.kind == MapKind.synthetic ||
                        e.kind == MapKind.lineBreak,
                  )
                  .fold(0, (sum, e) => sum + e.paraEnd - e.paraStart),
            }),
          );
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
          math.max(1, width),
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
              math.max(1, width),
              fonts,
              paintBackgrounds: false,
              paintDecorations: _engineDecorationsVisible(fonts, block),
            );
          }
        }
        final origin = ui.Offset(content.left, cursor);
        final text = FixedText._(box, block, built, origin);
        box.texts.add(text);
        box.contents.add(text);
        // Inline backgrounds belong below the replaced children of this run.
        for (final child in inlineBoxes) {
          box.contents.remove(child);
          box.contents.add(child);
        }
        _texts.add(text);
        if (nodeShifts.values.any((shift) => shift != 0) ||
            relativeOffsets.values.any((offset) => offset != ui.Offset.zero)) {
          try {
            text._inline = _layoutInline(
              block,
              built,
              nodeShifts,
              relativeOffsets: relativeOffsets,
            );
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
                !childOut) {
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
            width,
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
      height = FixedUsedBoxSize.constrain(
        style,
        'height',
        height,
        cbHeight,
        extraH,
      );
      if (shrink &&
          node.localName != 'img' &&
          box.texts.isEmpty &&
          box.children.isEmpty) {
        width = math.min(width, maxInline);
      }
      final placed = _positionedOrigin(
        style,
        cb,
        flow,
        ui.Size(width + extraW, height + extraH),
      );
      x = placed.dx;
      y = placed.dy;
      final dx = x - box.borderBox.left, dy = y - box.borderBox.top;
      if (dx != 0 || dy != 0) _shift(box, dx, dy);
      box.borderBox = ui.Rect.fromLTWH(x, y, width + extraW, height + extraH);
      box.contentBox = ui.Rect.fromLTWH(
        x + bl + pl,
        y + bt + pt,
        width,
        height,
      );
      if (![x, y, width, height, extraW, extraH].every((v) => v.isFinite)) {
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
      // A viewport-fixed subtree has already resolved its own coordinates.
      if (child.style.authored.position == AuthoredPosition.fixed) continue;
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
