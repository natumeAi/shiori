import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/engine/layout/layout_model.dart';
import 'package:shiori/features/reader/engine/layout/paragraph_map.dart';
import 'package:shiori/features/reader/engine/layout/svg_support.dart';
import 'package:shiori/features/reader/engine/pagination/page_plan.dart';
import 'package:shiori/features/reader/engine/pagination/prepared_section.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';

const _geometryTolerance = 0.5;

/// Result of [checkConservation]. Messages carry node, block and page
/// indices and counts only, never book text.
final class ConservationReport {
  const ConservationReport({
    required this.failures,
    required this.pages,
    required this.lines,
    required this.sourceCharacters,
    required this.images,
    required this.surfacedUnsupported,
  });

  final List<String> failures;
  final int pages;
  final int lines;

  /// Non-whitespace source code units compared.
  final int sourceCharacters;

  /// Image/SVG boxes placed exactly once.
  final int images;

  /// Eligible `img`/`svg` elements listed as unsupported instead.
  final int surfacedUnsupported;

  bool get ok => failures.isEmpty;
}

bool _isCssSpace(int unit) =>
    unit == 0x20 ||
    unit == 0x09 ||
    unit == 0x0a ||
    unit == 0x0c ||
    unit == 0x0d;

bool _isSpace(int unit) =>
    (unit >= 0x09 && unit <= 0x0d) ||
    unit == 0x20 ||
    unit == 0xa0 ||
    unit == 0x1680 ||
    (unit >= 0x2000 && unit <= 0x200a) ||
    unit == 0x2028 ||
    unit == 0x2029 ||
    unit == 0x202f ||
    unit == 0x205f ||
    unit == 0x3000 ||
    unit == 0xfeff ||
    unit == 0x200b;

/// Eligible source text and image elements, by an independent walk of the
/// source document and styles: the oracle the pages are compared with.
({List<int> units, List<int> elements}) _expected(
  SourceDocument document,
  StyledDocument styled,
) {
  final units = <int>[];
  final elements = <int>[];
  final root = document.bodyIndex ?? document.documentElementIndex;
  void walk(int index) {
    final node = document.node(index);
    switch (node.kind) {
      case SourceNodeKind.text || SourceNodeKind.cdata:
        final style = styled.styleOf(index);
        if (style == null || style.display == StyleDisplay.none) return;
        final text = node.text ?? '';
        for (var i = 0; i < text.length; i++) {
          final unit = text.codeUnitAt(i);
          if (!_isSpace(unit)) units.add(unit);
        }
      case SourceNodeKind.element:
        final name = (node.localName ?? '').toLowerCase();
        if (nonRenderedElementNames.contains(name) &&
            node.namespaceUri != svgNamespace) {
          return;
        }
        final style = styled.styleOf(index);
        if (style == null || style.display == StyleDisplay.none) return;
        if (name == 'svg' || name == 'img') {
          elements.add(index);
          return;
        }
        if (atomicElementNames.contains(name)) {
          elements.add(index);
          return;
        }
        for (final child in node.children) {
          walk(child);
        }
      case SourceNodeKind.comment || SourceNodeKind.processingInstruction:
        break;
    }
  }

  walk(root);
  return (units: units, elements: elements);
}

/// The conservation check (design §5.6) for one prepared section:
///
/// * the source text shown by the pages, in page order, equals the eligible
///   source text (whitespace is compared through the documented mapping:
///   collapsible whitespace is ignored on both sides, and its handling is
///   covered by the paragraph-map integrity check);
/// * every paragraph's map reproduces its text from the source;
/// * every block's lines are placed once, in order, with no gap;
/// * each image/SVG appears exactly once, or is listed as unsupported;
/// * no line box or image crosses the content rectangle.
ConservationReport checkConservation(
  PreparedSection section,
  StyledDocument styled,
) {
  final failures = <String>[];
  void fail(String message) {
    if (failures.length < 40) failures.add(message);
  }

  final document = section.document;
  final width = section.box.width;
  final height = section.box.height;

  // 1. Paragraph map integrity.
  for (final laid in section.blocks) {
    final block = laid.block;
    if (block is! TextBlock) continue;
    var cursor = 0;
    final coverage = <int, int>{};
    for (final entry in block.map.entries) {
      if (entry.paraStart != cursor) {
        fail('block ${block.index}: map gap at $cursor');
        break;
      }
      cursor = entry.paraEnd;
      if (entry.hasSource) {
        final source = document.node(entry.nodeIndex).text ?? '';
        if (entry.sourceEnd > source.length) {
          fail('block ${block.index}: map beyond node ${entry.nodeIndex}');
          continue;
        }
        final sourceText = source.substring(entry.sourceStart, entry.sourceEnd);
        switch (entry.kind) {
          case MapKind.exact:
            if (block.text.substring(entry.paraStart, entry.paraEnd) !=
                sourceText) {
              fail('block ${block.index}: exact entry differs from source');
            }
          case MapKind.collapsed:
            if (block.text.substring(entry.paraStart, entry.paraEnd) != ' ' ||
                !sourceText.codeUnits.every(_isCssSpace)) {
              fail('block ${block.index}: bad collapsed entry');
            }
          case MapKind.removed:
            if (entry.paraEnd != entry.paraStart ||
                !sourceText.codeUnits.every(_isCssSpace)) {
              fail('block ${block.index}: bad removed entry');
            }
          case MapKind.synthetic || MapKind.lineBreak:
            break;
        }
        // Source coverage of one node must be contiguous from zero.
        final covered = coverage[entry.nodeIndex] ?? 0;
        if (entry.sourceStart != covered) {
          fail('block ${block.index}: node ${entry.nodeIndex} coverage gap');
        }
        coverage[entry.nodeIndex] = entry.sourceEnd;
      }
    }
    if (cursor != block.text.length) {
      fail('block ${block.index}: map ends at $cursor of ${block.text.length}');
    }
    for (final entry in coverage.entries) {
      final length = document.node(entry.key).text?.length ?? 0;
      if (entry.value != length) {
        fail('block ${block.index}: node ${entry.key} not fully covered');
      }
    }
  }

  // 2. Lines placed once, in order.
  final nextLine = <int, int>{};
  var lineCount = 0;
  final shownUnits = <int>[];
  final shownImages = <int, int>{};
  for (final page in section.pages) {
    double previousBottom = -1;
    for (final fragment in page.fragments) {
      if (fragment.top < previousBottom - _geometryTolerance) {
        fail('page ${page.index}: fragment overlaps the previous one');
      }
      previousBottom = fragment.top + fragment.height;
      if (previousBottom > height + _geometryTolerance) {
        fail('page ${page.index}: fragment crosses the bottom edge');
      }
      final laid = section.blocks[fragment.blockIndex];
      switch (fragment) {
        case TextFragment():
          final built = laid.paragraph!;
          final expectedLine = nextLine[fragment.blockIndex] ?? 0;
          if (fragment.firstLine != expectedLine) {
            fail(
              'block ${fragment.blockIndex}: lines resume at '
              '${fragment.firstLine}, expected $expectedLine',
            );
          }
          nextLine[fragment.blockIndex] = fragment.endLine;
          lineCount += fragment.endLine - fragment.firstLine;
          for (var line = fragment.firstLine; line < fragment.endLine; line++) {
            final info = built.lines[line];
            // The engine offsets a justified line by half a letter spacing.
            final side =
                _geometryTolerance +
                (laid.block as TextBlock).baseStyle.letterSpacing;
            if (info.left < -side ||
                info.left + info.width > laid.width + side) {
              fail(
                'block ${fragment.blockIndex} line $line: crosses side edge '
                '(left ${info.left}, width ${info.width}, box ${laid.width})',
              );
            }
          }
          final block = laid.block as TextBlock;
          final first = built.lines[fragment.firstLine].start;
          final last = built.lines[fragment.endLine - 1].end;
          for (final span in block.map.sourceSpans(first, last)) {
            final text = document.node(span.nodeIndex).text ?? '';
            for (var i = span.start; i < span.end; i++) {
              final unit = text.codeUnitAt(i);
              if (!_isSpace(unit)) shownUnits.add(unit);
            }
          }
        case BoxFragment():
          if (fragment.left < -_geometryTolerance ||
              fragment.left + fragment.width > width + _geometryTolerance) {
            fail('block ${fragment.blockIndex}: box crosses a side edge');
          }
          final block = laid.block;
          if (block is ImageBlock) {
            shownImages.update(
              block.anchorNodeIndex,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          } else if (block is UnsupportedBlock) {
            shownImages.update(
              block.nodeIndex,
              (count) => count + 1,
              ifAbsent: () => 1,
            );
          }
      }
    }
  }
  for (final laid in section.blocks) {
    final built = laid.paragraph;
    if (built == null) continue;
    final placed = nextLine[laid.index] ?? 0;
    if (placed != built.lines.length) {
      fail(
        'block ${laid.index}: $placed of ${built.lines.length} lines placed',
      );
    }
  }

  // 3. Text equals the eligible source text, in order.
  final expected = _expected(document, styled);
  if (shownUnits.length != expected.units.length) {
    fail(
      'text: ${shownUnits.length} code units shown, '
      '${expected.units.length} expected',
    );
  } else {
    for (var i = 0; i < shownUnits.length; i++) {
      if (shownUnits[i] != expected.units[i]) {
        fail('text: first difference at code unit $i');
        break;
      }
    }
  }

  // 4. Images exactly once or surfaced.
  final unsupportedNodes = {
    for (final item in section.unsupported) item.nodeIndex,
  };
  var surfaced = 0;
  var placedImages = 0;
  for (final element in expected.elements) {
    final count = shownImages[element] ?? 0;
    final markerOnly = section.blocks.any(
      (laid) =>
          laid.block is UnsupportedBlock &&
          (laid.block as UnsupportedBlock).nodeIndex == element,
    );
    if (count != 1) {
      fail('element $element: placed $count times');
    } else if (markerOnly) {
      surfaced++;
      if (!unsupportedNodes.contains(element)) {
        fail('element $element: marker without an unsupported entry');
      }
    } else {
      placedImages++;
    }
  }
  for (final entry in shownImages.entries) {
    if (!expected.elements.contains(entry.key)) {
      // Markers for tables/math etc. are not image elements.
      final isMarker = section.blocks.any(
        (laid) =>
            laid.block is UnsupportedBlock &&
            (laid.block as UnsupportedBlock).nodeIndex == entry.key,
      );
      if (!isMarker) fail('element ${entry.key}: placed but not eligible');
    }
  }

  return ConservationReport(
    failures: failures,
    pages: section.pages.length,
    lines: lineCount,
    sourceCharacters: expected.units.length,
    images: placedImages,
    surfacedUnsupported: surfaced,
  );
}
