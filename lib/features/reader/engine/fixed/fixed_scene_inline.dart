part of 'fixed_scene.dart';

final class _FixedInline {
  _FixedInline(this.height, this.placements, this.paints, this.lineBaselines);
  final double height;
  final List<({ui.TextRange range, ui.Offset offset})> placements;
  final List<({BuiltParagraph paragraph, ui.Offset offset})> paints;

  /// Line base baseline, before per-run sub/sup shifts.
  final List<double> lineBaselines;
  ui.Offset offsetAt(int offset) =>
      placements
          .where((p) => p.range.start <= offset && offset < p.range.end)
          .firstOrNull
          ?.offset ??
      ui.Offset.zero;
  void dispose() {
    for (final p in paints) {
      p.paragraph.dispose();
    }
  }
}

extension _FixedInlineLayout on FixedSceneBuilder {
  _FixedInline _layoutInline(
    TextBlock block,
    BuiltParagraph built,
    Map<int, double> nodeShifts,
  ) {
    // CSS 2.2 10.8: include the block strut, then take the maximum ascent
    // and descent of every inline box after aligning its baseline. Half of
    // the used line-height minus font height goes on either side of the font.
    final fontMetrics =
        <(ComputedStyle, double), ({double ascent, double descent})>{};
    ({double ascent, double descent}) metrics(ComputedStyle s, double scale) =>
        fontMetrics.putIfAbsent((s, scale), () {
          final lease = budget.reserve({
            SceneResource.paragraphs: 1,
            SceneResource.textCodeUnits: 1,
          });
          try {
            final m = measureInlineFont(s, scale, fonts);
            final height =
                s.lineHeight.px ??
                (s.lineHeight.multiplier == null
                    ? m.ascent + m.descent
                    : s.lineHeight.multiplier! * s.fontSize * scale);
            final leading = (height - m.ascent - m.descent) / 2;
            return (ascent: m.ascent + leading, descent: m.descent + leading);
          } finally {
            lease.release();
          }
        });
    double shiftAt(int offset) {
      final entry = block.map.entries
          .where((e) => e.paraStart <= offset && offset < e.paraEnd)
          .firstOrNull;
      return nodeShifts[entry?.nodeIndex] ?? 0;
    }

    final placements = <({ui.TextRange range, ui.Offset offset})>[];
    final groups = <ui.Offset, List<ui.TextRange>>{};
    final lineBaselines = <double>[];
    final strut = metrics(block.baseStyle, 1);
    var top = 0.0;
    for (final line in built.lines) {
      var ascent = strut.ascent, descent = strut.descent;
      final pieces = <({int start, int end, TextStyleRun run, double shift})>[];
      for (final run in block.runs) {
        final start = math.max(run.start, line.start),
            end = math.min(run.end, line.end);
        if (start >= end) continue;
        // A node boundary can carry an ancestor alignment even if the
        // computed text style is shared. Keep those source boundaries intact.
        final cuts = <int>{start, end};
        for (final e in block.map.entries) {
          if (e.paraStart > start && e.paraStart < end) cuts.add(e.paraStart);
        }
        final sorted = cuts.toList()..sort();
        for (var i = 0; i + 1 < sorted.length; i++) {
          final shift = shiftAt(sorted[i]);
          final m = run.placeholderWidth == null
              ? metrics(run.style, run.scale)
              : (
                  ascent: run.placeholderBaseline,
                  descent: run.placeholderHeight - run.placeholderBaseline,
                );
          ascent = math.max(ascent, m.ascent - shift);
          descent = math.max(descent, m.descent + shift);
          pieces.add((
            start: sorted[i],
            end: sorted[i + 1],
            run: run,
            shift: shift,
          ));
        }
      }
      final baseline = top + ascent;
      lineBaselines.add(baseline);
      for (final p in pieces) {
        final offset = ui.Offset(
          p.run.placeholderWidth == null ? -p.run.style.letterSpacing / 2 : 0,
          baseline - line.baseline + p.shift,
        );
        final range = ui.TextRange(start: p.start, end: p.end);
        placements.add((range: range, offset: offset));
        groups.putIfAbsent(offset, () => []).add(range);
      }
      top += ascent + descent;
    }
    final paints = <({BuiltParagraph paragraph, ui.Offset offset})>[];
    try {
      for (final group in groups.entries) {
        _checkCancellation();
        _leases.add(
          budget.reserve({
            SceneResource.paragraphs: 1,
            SceneResource.textCodeUnits: block.text.length,
          }),
        );
        final painted = buildParagraph(
          block,
          built.layoutWidth,
          fonts,
          paintBackgrounds: false,
          paintRanges: group.value,
          paintDecorations: _engineDecorationsVisible(fonts, block),
        );
        // A paint-only change must never alter shaping, wrapping or advances.
        if (painted.lines.length != built.lines.length ||
            List.generate(
              built.lines.length,
              (i) =>
                  painted.lines[i].start != built.lines[i].start ||
                  painted.lines[i].end != built.lines[i].end ||
                  (painted.lines[i].width - built.lines[i].width).abs() > .0001,
            ).any((v) => v)) {
          painted.dispose();
          throw StateError('Inline paint changed paragraph shaping');
        }
        paints.add((paragraph: painted, offset: group.key));
      }
      return _FixedInline(top, placements, paints, lineBaselines);
    } on Object {
      for (final p in paints) {
        p.paragraph.dispose();
      }
      rethrow;
    }
  }
}
