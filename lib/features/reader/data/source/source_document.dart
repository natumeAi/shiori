import 'package:shiori/features/reader/data/source/source_node.dart';

enum SourceParserMode { xhtml, html }

/// A projected source document, with stable depth-first node indices.
final class SourceDocument {
  SourceDocument({
    required List<SourceNode> nodes,
    required this.documentElementIndex,
    required this.parserMode,
    this.bodyIndex,
    this.parserErrorClass,
    this.originalMediaType,
    this.htmlFallback = false,
  }) : nodes = List.unmodifiable(nodes);

  final List<SourceNode> nodes;
  final int documentElementIndex;
  final int? bodyIndex;
  final SourceParserMode parserMode;
  final String? parserErrorClass;

  /// Manifest media type before any XHTML-to-HTML fallback.
  final String? originalMediaType;

  /// True when an XHTML resource was reparsed as HTML.
  final bool htmlFallback;

  /// Oracle vocabulary: `xhtml`, `html` or `html-fallback`.
  String get parserUsed => htmlFallback
      ? 'html-fallback'
      : parserMode == SourceParserMode.html
      ? 'html'
      : 'xhtml';

  SourceNode node(int index) => nodes[index];

  String? attribute(int nodeIndex, String qualifiedName) =>
      nodes[nodeIndex].attribute(qualifiedName);

  SourceNode? getElementById(String id) {
    if (id.isEmpty) return null;
    for (final node in nodes) {
      if (node.kind == SourceNodeKind.element && node.id == id) return node;
    }
    return null;
  }

  List<Map<String, Object?>> toProjectionJson() => nodes
      .map(
        (node) => <String, Object?>{
          'index': node.index,
          'kind': switch (node.kind) {
            SourceNodeKind.processingInstruction => 'pi',
            _ => node.kind.name,
          },
          'namespaceURI': node.namespaceUri,
          'localName': node.localName,
          'id': node.id,
          'parent': node.parentIndex,
          'slot': node.childSlot,
          'text': node.text,
        },
      )
      .toList(growable: false);
}
