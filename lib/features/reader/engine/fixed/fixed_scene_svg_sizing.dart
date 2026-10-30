import 'package:shiori/features/reader/data/epub/epub_url.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/section_source_facts.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_scene_sizing.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/fixed_svg_viewport.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/css_selector.dart';
import 'package:shiori/features/reader/engine/style/css_stylesheet.dart';

/// XHTML containing blocks for admission, with no native allocation.
Map<int, FixedSvgViewport> fixedInlineSvgViewports(
  FixedSourceLease source,
  AuthoredPageSize page,
) {
  final document = source.document, styles = source.styles;
  final initial = FixedUsedBoxSize(page.width, page.height);
  final boxes = <int, FixedUsedBoxSize>{};
  final positioned = <int, FixedUsedBoxSize>{};
  final failures = <int>{};
  FixedUsedBoxSize box(int index) {
    if (boxes[index] case final cached?) return cached;
    final node = document.node(index), s = styles.styleOf(index);
    if (s == null) return initial;
    final parent = node.parentIndex;
    final parentBox = parent == null ? initial : box(parent);
    final inheritedPositioned = parent == null
        ? initial
        : positioned[parent] ?? initial;
    final out =
        s.authored.position == AuthoredPosition.absolute ||
        s.authored.position == AuthoredPosition.fixed;
    final cb = s.authored.position == AuthoredPosition.fixed
        ? initial
        : out
        ? inheritedPositioned
        : parentBox;
    // Intrinsic/shrink-to-fit inline widths need text measurement. Refuse
    // this dependency before allocation rather than invent a containing size.
    if ((s.display == StyleDisplay.inlineBlock || out) &&
        s.width.kind == StyleLengthKind.auto &&
        (!out ||
            s.authored.inset('left').kind == StyleLengthKind.auto ||
            s.authored.inset('right').kind == StyleLengthKind.auto)) {
      failures.add(index);
    }
    if (parent != null && failures.contains(parent)) failures.add(index);
    final used = s.display == StyleDisplay.inline && parent != null
        ? parentBox
        : FixedUsedBoxSize.resolve(s, cb.width, cb.height);
    boxes[index] = used;
    double padding(StyleLength l) => l.resolve(cb.width) ?? 0;
    positioned[index] =
        s.authored.position != AuthoredPosition.static ||
            s.authored.transforms.isNotEmpty
        ? FixedUsedBoxSize(
            used.width + padding(s.padding.left) + padding(s.padding.right),
            used.height == null
                ? null
                : used.height! +
                      padding(s.padding.top) +
                      padding(s.padding.bottom),
          )
        : inheritedPositioned;
    return used;
  }

  // Computed auto alone cannot distinguish an explicit CSS override from the
  // initial value. Reuse the stylesheet parser/selector engine for presence;
  // the winning value still comes exclusively from the computed style.
  final sheet = CssSheetBuilder(
    reader: source.resources.text,
    viewportWidth: page.width,
    viewportHeight: page.height,
  );
  for (final node in document.nodes) {
    if (!sheet.matchesMediaAttribute(node.attribute('media'))) continue;
    if (node.localName == 'style') {
      final text = node.children.map((i) => document.node(i).text ?? '').join();
      sheet.addStylesheet(text, source.page.stableId);
    } else if (node.localName == 'link' &&
        (node.attribute('rel') ?? '')
            .split(RegExp(r'\s+'))
            .contains('stylesheet') &&
        !(node.attribute('rel') ?? '').contains('alternate')) {
      final href = node.attribute('href');
      if (href == null || isExternalUrl(href)) continue;
      final path = resolveUrl(href, source.page.stableId);
      final text = source.resources.text(path);
      if (text != null) sheet.addStylesheet(text, path);
    }
  }
  final tree = StyleTree(document);
  final result = <int, FixedSvgViewport>{};
  for (final svg in extractSectionSourceFacts(document).svgDimensions) {
    if (svg.nodeIndex == document.documentElementIndex) {
      result[svg.nodeIndex] = FixedSvgViewport.resolve(svg);
      continue;
    }
    // SVG descendants have their own SVG user-space containing viewport; the
    // SVG graphics plan handles them, rather than this XHTML sizing pass.
    var parent = document.node(svg.nodeIndex).parentIndex;
    var nested = false;
    while (parent != null) {
      final n = document.node(parent);
      if (n.namespaceUri == 'http://www.w3.org/2000/svg') nested = true;
      parent = n.parentIndex;
    }
    if (nested) continue;
    parent = document.node(svg.nodeIndex).parentIndex;
    final parentBox = parent == null ? initial : box(parent);
    final s = styles.styleOf(svg.nodeIndex)!;
    final cb = s.authored.position == AuthoredPosition.fixed
        ? initial
        : s.authored.position == AuthoredPosition.absolute
        ? positioned[parent] ?? initial
        : parentBox;
    if (parent != null && failures.contains(parent)) {
      // Keep the failure typed; no partial or guessed SVG plan is admitted.
      result[svg.nodeIndex] = FixedSvgViewport.unsupportedContainingBlock();
      continue;
    }
    final declared = <String>{
      for (final rule in sheet.rules)
        if (rule.selector.matches(tree, svg.nodeIndex))
          for (final declaration in rule.declarations) declaration.property,
      for (final declaration in parseInlineStyle(
        document.node(svg.nodeIndex).attribute('style') ?? '',
        null,
      ))
        declaration.property,
    };
    result[svg.nodeIndex] = FixedSvgViewport.resolveInline(
      svg,
      style: s,
      containingWidth: cb.width,
      containingHeight: cb.height,
      cssWidth: declared.contains('width'),
      cssHeight: declared.contains('height'),
    );
  }
  return result;
}
