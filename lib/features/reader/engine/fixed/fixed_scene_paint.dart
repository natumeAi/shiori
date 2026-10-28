part of 'fixed_scene.dart';

extension _FixedPaint on FixedSceneBuilder {
  GeometryRegion _region(FixedBox box, ui.Rect rect) => GeometryRegion(
    left: rect.left,
    top: rect.top,
    width: rect.width,
    height: rect.height,
    transform: box.transform,
    radii: [
      for (final corner in [
        'top-left',
        'top-right',
        'bottom-right',
        'bottom-left',
      ])
        math.max(0, box.style.authored.radius(corner).resolve(rect.width) ?? 0),
    ],
  );
  ui.RRect _round(GeometryRegion r) => ui.RRect.fromRectAndCorners(
    ui.Rect.fromLTWH(r.left, r.top, r.width, r.height),
    topLeft: ui.Radius.circular(r.radii[0]),
    topRight: ui.Radius.circular(r.radii[1]),
    bottomRight: ui.Radius.circular(r.radii[2]),
    bottomLeft: ui.Radius.circular(r.radii[3]),
  );
  void _withBox(
    ui.Canvas canvas,
    FixedBox box,
    void Function() draw, {
    bool content = false,
  }) {
    canvas.save();
    final ids = [
      ...box.clipIds,
      if (content && box.style.authored.overflow != AuthoredOverflow.visible)
        'box-${box.nodeIndex}',
    ];
    for (final id in ids) {
      final clip = _clips.firstWhere((c) => c.id == id),
          t = clip.region.transform;
      final inverse = t.inverse();
      if (inverse is! InvertedTransform) continue;
      canvas.transform(_matrix(t));
      canvas.clipRRect(_round(clip.region));
      canvas.transform(_matrix(inverse.transform));
    }
    canvas.transform(_matrix(box.transform));
    draw();
    canvas.restore();
  }

  void _paintContext(ui.Canvas canvas, FixedBox root) {
    if (!root.hasVisibleTransform) return;
    final id = 'context-${root.nodeIndex}';
    _groups.add(
      GeometryOpacityGroup(
        id: id,
        parentId: _paintGroups.lastOrNull,
        opacity: root.style.authored.opacity,
      ),
    );
    _paintGroups.add(id);
    canvas.save();
    if (root.style.authored.opacity < 1) {
      canvas.saveLayer(
        null,
        ui.Paint()
          ..color = ui.Color.fromRGBO(
            255,
            255,
            255,
            root.style.authored.opacity,
          ),
      );
    }
    _background(canvas, root);
    final entries = <FixedBox>[];
    void collect(FixedBox box) {
      for (final child in box.children) {
        if (child.context) {
          entries.add(child);
        } else {
          if (child.style.authored.position != AuthoredPosition.static) {
            entries.add(child);
          }
          collect(child);
        }
      }
    }

    collect(root);
    entries.sort((a, b) {
      final c = (a.style.authored.zIndex ?? 0).compareTo(
        b.style.authored.zIndex ?? 0,
      );
      return c != 0 ? c : a.nodeIndex.compareTo(b.nodeIndex);
    });
    for (final box in entries.where(
      (b) => (b.style.authored.zIndex ?? 0) < 0,
    )) {
      _paintContext(canvas, box);
    }
    void flow(FixedBox box, {bool background = true}) {
      if (background) _background(canvas, box);
      for (final entry in box.contents) {
        if (entry is FixedText) {
          _text(canvas, entry);
        }
        if (entry is FixedBox && !entries.contains(entry)) flow(entry);
      }
    }

    flow(root, background: false);
    for (final box in entries.where(
      (b) => (b.style.authored.zIndex ?? 0) >= 0,
    )) {
      if (box.context) {
        _paintContext(canvas, box);
      } else {
        flow(box);
      }
    }
    if (root.style.authored.opacity < 1) canvas.restore();
    canvas.restore();
    _paintGroups.removeLast();
  }

  void _background(ui.Canvas canvas, FixedBox box) {
    if (!box.hasVisibleTransform) return;
    box.paintOrdinal = _ordinal++;
    if (box.style.authored.visibility != AuthoredVisibility.visible) return;
    if (box.svgFill case final int color) {
      _withBox(
        canvas,
        box,
        () =>
            canvas.drawRect(box.borderBox, ui.Paint()..color = ui.Color(color)),
      );
      _paint.add(
        GeometryPaint(
          nodeIndex: box.nodeIndex,
          paintOrdinal: box.paintOrdinal,
          region: _region(box, box.borderBox),
          kind: GeometryPaintKind.solid,
          effectiveOpacity: box.effectiveOpacity,
          exactCoverage: true,
          argb: color,
          clipIds: box.clipIds,
          groupIds: _paintGroups,
        ),
      );
      return;
    }
    final target = canvas,
        recorder = ui.PictureRecorder(),
        firstPaint = _paint.length;
    canvas = ui.Canvas(recorder);
    final s = box.style,
        a = s.authored,
        r = box.borderBox,
        region = _region(box, r);
    _withBox(canvas, box, () {
      final color = s.backgroundColor;
      if (color != null) {
        canvas.drawRRect(_round(region), ui.Paint()..color = ui.Color(color));
        _paint.add(
          GeometryPaint(
            nodeIndex: box.nodeIndex,
            paintOrdinal: _ordinal++,
            region: region,
            kind: GeometryPaintKind.solid,
            effectiveOpacity: box.effectiveOpacity,
            exactCoverage: true,
            argb: color,
            clipIds: box.clipIds,
          ),
        );
      }
      final imagePath = a.backgroundImage;
      if (imagePath != null) {
        final image = backgroundImages[imagePath];
        if (image == null) {
          _reject(box.nodeIndex, 'background-resource-missing');
        } else {
          canvas.save();
          canvas.clipRRect(_round(region));
          final origin = ui.Rect.fromLTRB(
            r.left + (a.borderWidth('left').resolve(r.width) ?? 0),
            r.top + (a.borderWidth('top').resolve(r.width) ?? 0),
            r.right - (a.borderWidth('right').resolve(r.width) ?? 0),
            r.bottom - (a.borderWidth('bottom').resolve(r.width) ?? 0),
          );
          var w = image.width.toDouble(), h = image.height.toDouble();
          final bs = a.backgroundSize;
          if (bs is String) {
            final scale = bs == 'cover'
                ? math.max(origin.width / w, origin.height / h)
                : math.min(origin.width / w, origin.height / h);
            w *= scale;
            h *= scale;
          } else {
            final lengths = bs as List<StyleLength>,
                rw = lengths[0].resolve(origin.width),
                rh = lengths[1].resolve(origin.height);
            if (rw != null) {
              w = rw;
              h = rh ?? w * image.height / image.width;
            } else if (rh != null) {
              h = rh;
              w = h * image.width / image.height;
            }
          }
          if (w > 0 && h > 0 && w.isFinite && h.isFinite) {
            final pos = a.backgroundPosition;
            double p(StyleLength l, double space) => l.resolve(space) ?? 0;
            final x = origin.left + p(pos[0], origin.width - w),
                y = origin.top + p(pos[1], origin.height - h);
            final rx = const {
                  BackgroundRepeat.repeat,
                  BackgroundRepeat.repeatX,
                }.contains(a.backgroundRepeat),
                ry = const {
                  BackgroundRepeat.repeat,
                  BackgroundRepeat.repeatY,
                }.contains(a.backgroundRepeat);
            final firstX = rx ? x - ((x - r.left) / w).ceil() * w : x,
                firstY = ry ? y - ((y - r.top) / h).ceil() * h : y;
            final countX = rx ? ((r.right - firstX) / w).ceil() : 1,
                countY = ry ? ((r.bottom - firstY) / h).ceil() : 1;
            if (countX * countY > 16384) {
              _reject(box.nodeIndex, 'background-repeat-limit');
            } else {
              for (var iy = 0; iy < countY; iy++) {
                for (var ix = 0; ix < countX; ix++) {
                  canvas.drawImageRect(
                    image,
                    ui.Rect.fromLTWH(
                      0,
                      0,
                      image.width.toDouble(),
                      image.height.toDouble(),
                    ),
                    ui.Rect.fromLTWH(firstX + ix * w, firstY + iy * h, w, h),
                    ui.Paint()..filterQuality = ui.FilterQuality.none,
                  );
                }
              }
            }
          }
          canvas.restore();
          _paint.add(
            GeometryPaint(
              nodeIndex: box.nodeIndex,
              paintOrdinal: _ordinal++,
              region: region,
              kind: GeometryPaintKind.image,
              effectiveOpacity: box.effectiveOpacity,
              exactCoverage: false,
              clipIds: box.clipIds,
            ),
          );
        }
      }
      final widths = [
        for (final edge in ['top', 'right', 'bottom', 'left'])
          a.borderStyle(edge) == 'solid'
              ? a.borderWidth(edge).resolve(r.width) ?? 0
              : 0.0,
      ];
      if (widths.any((w) => w > 0)) {
        final inner = ui.Rect.fromLTRB(
          r.left + widths[3],
          r.top + widths[0],
          r.right - widths[1],
          r.bottom - widths[2],
        );
        final outerRound = _round(region),
            innerRound = outerRound.deflate(widths.reduce(math.min));
        final ring = ui.Path()
          ..fillType = ui.PathFillType.evenOdd
          ..addRRect(outerRound)
          ..addRRect(innerRound);
        canvas.save();
        canvas.clipPath(ring);
        final polygons = [
          [r.topLeft, r.topRight, inner.topRight, inner.topLeft],
          [r.topRight, r.bottomRight, inner.bottomRight, inner.topRight],
          [r.bottomRight, r.bottomLeft, inner.bottomLeft, inner.bottomRight],
          [r.bottomLeft, r.topLeft, inner.topLeft, inner.bottomLeft],
        ];
        for (var i = 0; i < 4; i++) {
          if (widths[i] == 0) continue;
          final points = polygons[i],
              path = ui.Path()..addPolygon(points, true),
              color = a.borderColor(
                ['top', 'right', 'bottom', 'left'][i],
                s.color,
              );
          canvas.drawPath(path, ui.Paint()..color = ui.Color(color));
        }
        canvas.restore();
        _paint.add(
          GeometryPaint(
            nodeIndex: box.nodeIndex,
            paintOrdinal: _ordinal++,
            region: region,
            innerRegion: _region(box, inner),
            kind: GeometryPaintKind.border,
            effectiveOpacity: box.effectiveOpacity,
            exactCoverage: widths.toSet().length == 1,
            argb: a.borderColor('top', s.color),
            clipIds: box.clipIds,
          ),
        );
      }
    });
    final picture = recorder.endRecording();
    target.drawPicture(picture);
    if (_paint.length > firstPaint) {
      final first = _paint[firstPaint];
      _paint.removeRange(firstPaint, _paint.length);
      _paint.add(
        GeometryPaint(
          nodeIndex: box.nodeIndex,
          paintOrdinal: first.paintOrdinal,
          region: region,
          kind: GeometryPaintKind.decoration,
          effectiveOpacity: box.effectiveOpacity,
          exactCoverage: false,
          clipIds: box.clipIds,
          groupIds: _paintGroups,
        ),
      );
      _coveragePictures.add((_paint.length - 1, picture));
    } else {
      picture.dispose();
    }
  }

  FontDecorationMetrics? _fixedDecorationMetrics(TextBlock block) {
    final base = block.baseStyle;
    if (!block.runs.any((r) => r.style.underline || r.style.lineThrough)) {
      return null;
    }
    final resolved = fonts.resolve(
      base.fontFamilies,
      weight: base.fontWeight,
      style: base.fontStyle,
    );
    return fonts.decorationMetrics[resolved.primary];
  }

  /// One WebKit-compatible band per line. Sub/sup shifts and the indent
  /// placeholder never move or extend the band; SFNT metrics and device-pixel
  /// snapping decide its vertical position and thickness.
  void _paintFixedDecorations(
    ui.Canvas canvas,
    FixedText text,
    FontDecorationMetrics metrics,
  ) {
    final block = text.block, base = block.baseStyle;
    final fontSize = base.fontSize;
    final inline = text._inline;
    final xOffset = inline == null ? 0.0 : -base.letterSpacing / 2;
    final paint = ui.Paint()..color = ui.Color(base.color);
    for (var i = 0; i < text.paragraph.lines.length; i++) {
      final line = text.paragraph.lines[i];
      var underline = false, lineThrough = false;
      int? start, end;
      for (final run in block.runs) {
        if (run.placeholderWidth != null) continue;
        final runStart = math.max(run.start, line.start);
        final runEnd = math.min(run.end, line.end);
        if (runStart >= runEnd) continue;
        if (run.style.underline) underline = true;
        if (run.style.lineThrough) lineThrough = true;
        if (!run.style.underline && !run.style.lineThrough) continue;
        start = start == null ? runStart : math.min(start, runStart);
        end = end == null ? runEnd : math.max(end, runEnd);
      }
      if ((!underline && !lineThrough) || start == null || end == null) {
        continue;
      }
      final boxes = text.paragraph.paragraph.getBoxesForRange(start, end);
      if (boxes.isEmpty) continue;
      var left = boxes.first.left, right = boxes.first.right;
      for (final box in boxes.skip(1)) {
        left = math.min(left, box.left);
        right = math.max(right, box.right);
      }
      final leftPx = (left + xOffset).floorToDouble() + text.origin.dx;
      final rightPx = (right + xOffset).floorToDouble() + text.origin.dx;
      if (rightPx <= leftPx) continue;
      // WebKit leaves the letter-spacing gap before a space unpainted; the
      // space's own box remains underlined. Reproduce that cutout from the
      // paragraph's space box and the run's letter-spacing.
      final cuts = <(double, double)>[];
      for (var offset = start; offset < end; offset++) {
        if (!_isDecorationSpace(block.text.codeUnitAt(offset))) continue;
        final boxes = text.paragraph.paragraph.getBoxesForRange(
          offset,
          offset + 1,
        );
        if (boxes.isEmpty) continue;
        var spacing = base.letterSpacing;
        for (final run in block.runs) {
          if (run.start <= offset && offset < run.end) {
            spacing = run.style.letterSpacing * run.scale;
            break;
          }
        }
        final cutLeft = boxes.first.left.floorToDouble() + text.origin.dx;
        final cutRight =
            (boxes.first.left + spacing).ceilToDouble() + text.origin.dx;
        if (cutRight > cutLeft) cuts.add((cutLeft, cutRight));
      }
      // A subscript crosses the underline; WebKit's skip-ink gap removes the
      // band around that run. Resume one letter-spacing before the next run.
      for (var r = 0; r < block.runs.length; r++) {
        final run = block.runs[r];
        if (run.placeholderWidth != null ||
            run.style.verticalAlign != StyleVerticalAlign.sub ||
            (!run.style.underline && !run.style.lineThrough)) {
          continue;
        }
        final runStart = math.max(run.start, line.start);
        final runEnd = math.min(run.end, line.end);
        if (runStart >= runEnd) continue;
        final runBoxes = text.paragraph.paragraph.getBoxesForRange(
          runStart,
          runEnd,
        );
        if (runBoxes.isEmpty) continue;
        final spacing = run.style.letterSpacing * run.scale;
        final cutLeft =
            (runBoxes.first.left - spacing).ceilToDouble() + text.origin.dx;
        var resumeLeft = runBoxes.last.right;
        if (r + 1 < block.runs.length) {
          final next = block.runs[r + 1];
          final nextBoxes = text.paragraph.paragraph.getBoxesForRange(
            math.max(next.start, line.start),
            math.min(next.end, line.end),
          );
          if (nextBoxes.isNotEmpty) resumeLeft = nextBoxes.first.left;
        }
        final cutRight =
            (resumeLeft - spacing).floorToDouble() + text.origin.dx;
        if (cutRight > cutLeft) cuts.add((cutLeft, cutRight));
      }
      cuts.sort((a, b) => a.$1.compareTo(b.$1));
      final baseline =
          (inline == null
              ? line.baseline
              : inline.lineBaselines.elementAtOrNull(i) ?? line.baseline) +
          text.origin.dy;
      void band(double top, double thickness) {
        var cursor = leftPx;
        for (final cut in cuts) {
          final cutLeft = math.max(leftPx, cut.$1);
          final cutRight = math.min(rightPx, cut.$2);
          if (cutRight <= cutLeft) continue;
          if (cutLeft > cursor) {
            _fixedDecorationBand(
              canvas,
              cursor,
              cutLeft,
              top,
              thickness,
              paint,
            );
          }
          cursor = math.max(cursor, cutRight);
        }
        if (rightPx > cursor) {
          _fixedDecorationBand(canvas, cursor, rightPx, top, thickness, paint);
        }
      }

      if (underline) {
        band(
          baseline + metrics.underlineOffsetPx(fontSize),
          metrics.underlineThicknessPx(fontSize),
        );
      }
      if (lineThrough && metrics.strikeoutThickness > 0) {
        final thickness = metrics.strikeoutThicknessPx(fontSize);
        band(
          baseline + metrics.strikeoutOffsetPx(fontSize) - thickness / 2,
          thickness,
        );
      }
    }
  }

  bool _isDecorationSpace(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0a ||
      codeUnit == 0x0d;

  void _fixedDecorationBand(
    ui.Canvas canvas,
    double left,
    double right,
    double top,
    double thickness,
    ui.Paint paint,
  ) {
    if (!top.isFinite || !thickness.isFinite || thickness <= 0) return;
    // WebKit's observed rule: the band covers the font-metric rect's whole
    // device rows. Keep its outward row count and land its top on the nearest
    // row so sub-pixel baseline differences cannot move it one row.
    final rows = math.max(1, (top + thickness).ceil() - top.floor()).toDouble();
    final snappedTop = top.roundToDouble();
    canvas.drawRect(
      ui.Rect.fromLTWH(left, snappedTop, right - left, rows),
      paint,
    );
  }

  void _text(ui.Canvas canvas, FixedText text) {
    if (!text.owner.hasVisibleTransform) return;
    text.paintOrdinal = _ordinal++;
    final recorder = ui.PictureRecorder(), coverage = ui.Canvas(recorder);
    _withBox(coverage, text.owner, () {
      final metrics = _fixedDecorationMetrics(text.block);
      if (metrics != null) _paintFixedDecorations(coverage, text, metrics);
      final inline = text._inline;
      if (inline == null) {
        coverage.drawParagraph(text.paragraph.paragraph, text.origin);
      } else {
        for (final p in inline.paints) {
          coverage.drawParagraph(p.paragraph.paragraph, text.origin + p.offset);
        }
      }
    }, content: true);
    final picture = recorder.endRecording();
    canvas.drawPicture(picture);
    _paint.add(
      GeometryPaint(
        nodeIndex: text.owner.nodeIndex,
        paintOrdinal: text.paintOrdinal,
        region: _region(
          text.owner,
          ui.Rect.fromLTWH(
            text.origin.dx,
            text.origin.dy,
            text.paragraph.layoutWidth,
            text.height,
          ),
        ),
        kind: GeometryPaintKind.text,
        effectiveOpacity: text.owner.effectiveOpacity,
        exactCoverage: false,
        clipIds: text.owner.clipIds,
        groupIds: _paintGroups,
      ),
    );
    _coveragePictures.add((_paint.length - 1, picture));
  }
}
