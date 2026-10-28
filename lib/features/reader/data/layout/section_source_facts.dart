import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';

/// Extract dimensions from the existing projected tree without style/layout.
SectionSourceFacts extractSectionSourceFacts(SourceDocument document) {
  final viewports = <String>[];
  final sourceViewports = <String>[];
  final svg = <SvgSourceDimensions>[];
  for (final node in document.nodes) {
    if (node.kind != SourceNodeKind.element) continue;
    if (node.localName == 'meta') {
      final name = node.attribute('name') ?? node.attribute('property');
      final value = node.attribute('content');
      if (value != null) {
        if (name == 'viewport' || name == 'rendition:viewport') {
          viewports.add(value);
        }
        if (name == 'source-viewport' || name == 'rendition:source-viewport') {
          sourceViewports.add(value);
        }
      }
    }
    if (node.localName == 'svg' &&
        node.namespaceUri == 'http://www.w3.org/2000/svg') {
      svg.add(
        SvgSourceDimensions(
          nodeIndex: node.index,
          width: node.attribute('width'),
          height: node.attribute('height'),
          viewBox: node.attribute('viewBox'),
          preserveAspectRatio: node.attribute('preserveAspectRatio'),
        ),
      );
    }
  }
  final root = document.node(document.documentElementIndex);
  return SectionSourceFacts(
    viewports: viewports,
    sourceViewports: sourceViewports,
    svgDimensions: svg,
    rootSvgNodeIndex:
        root.localName == 'svg' &&
            root.namespaceUri == 'http://www.w3.org/2000/svg'
        ? root.index
        : null,
  );
}
