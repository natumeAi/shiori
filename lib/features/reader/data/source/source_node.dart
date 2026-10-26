import 'package:shiori/features/reader/data/source/source_attribute.dart';

enum SourceNodeKind { element, text, cdata, comment, processingInstruction }

/// Immutable DOM-shaped source identity. Character-data offsets use UTF-16.
final class SourceNode {
  SourceNode({
    required this.index,
    required this.kind,
    required this.childSlot,
    this.namespaceUri,
    this.localName,
    this.id,
    this.parentIndex,
    this.text,
    List<int> children = const [],
    List<SourceAttribute> attributes = const [],
  }) : children = List.unmodifiable(children),
       attributes = List.unmodifiable(attributes);

  final int index;
  final SourceNodeKind kind;
  final String? namespaceUri;
  final String? localName;
  final String? id;
  final int? parentIndex;
  final int childSlot;
  final List<int> children;
  final List<SourceAttribute> attributes;
  final String? text;

  bool get isCharacterData =>
      kind == SourceNodeKind.text || kind == SourceNodeKind.cdata;

  String? attribute(String qualifiedName) {
    for (final attribute in attributes) {
      if (attribute.qualifiedName == qualifiedName) return attribute.value;
    }
    return null;
  }
}
