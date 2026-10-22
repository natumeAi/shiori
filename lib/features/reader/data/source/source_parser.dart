import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/source/content_protection.dart';
import 'package:shiori/features/reader/data/source/dom_node.dart';
import 'package:shiori/features/reader/data/source/dom_serializer.dart';
import 'package:shiori/features/reader/data/source/html_adapter.dart';
import 'package:shiori/features/reader/data/source/source_attribute.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';
import 'package:shiori/features/reader/data/source/xml_parser.dart';

const xhtmlMediaType = 'application/xhtml+xml';
const htmlMediaType = 'text/html';
const svgMediaType = 'image/svg+xml';

/// Result of [SourceParser.parseTree].
final class ParsedSection {
  const ParsedSection({
    required this.tree,
    required this.effectiveType,
    required this.htmlFallback,
    required this.errorClass,
  });

  final DomNode tree;
  final String effectiveType;
  final bool htmlFallback;
  final String? errorClass;
}

/// Hook applied to the first parse tree, before serialization, like the
/// reference loader's resource rewriting. [effectiveType] is the media type
/// after any XHTML-to-HTML fallback.
typedef SectionTransform = void Function(
  DomNode document,
  String effectiveType,
);

/// Browser-compatible parse selection and the reference inert projection:
/// parse (XML, falling back to HTML as the reference does), loader rewrite,
/// serialize, `protectBookDocument`, serialize and a final reparse.
final class SourceParser {
  const SourceParser();

  /// The reference's first parse: XML for XHTML/SVG, falling back to HTML when
  /// the XML is malformed or its root has no namespace; HTML for `text/html`.
  static ParsedSection parseTree(String source, String mediaType) {
    var tree = DomNode(DomKind.document);
    var htmlFallback = false;
    String? errorClass;
    if (mediaType == htmlMediaType) {
      tree = parseHtmlDocument(source);
    } else {
      try {
        tree = parseXmlDocument(source);
        if (mediaType == xhtmlMediaType &&
            tree.documentElement?.namespaceUri == null) {
          htmlFallback = true;
          errorClass = 'missing_namespace';
        }
      } on XmlSyntaxException catch (error) {
        if (mediaType != xhtmlMediaType) throw ParseException(error);
        htmlFallback = true;
        errorClass = 'xml_parsererror';
      }
      if (htmlFallback) tree = parseHtmlDocument(source);
    }
    return ParsedSection(
      tree: tree,
      effectiveType: htmlFallback ? htmlMediaType : mediaType,
      htmlFallback: htmlFallback,
      errorClass: errorClass,
    );
  }

  SourceDocument parse(
    String source, {
    String mediaType = xhtmlMediaType,
    SectionTransform? transform,
    bool protect = true,
  }) {
    final parsed = parseTree(source, mediaType);
    var tree = parsed.tree;
    final htmlFallback = parsed.htmlFallback;
    final errorClass = parsed.errorClass;
    final effectiveType = parsed.effectiveType;
    transform?.call(tree, effectiveType);
    if (protect) {
      final protectedSource = protectBookDocument(
        serializeXml(tree),
        effectiveType,
      );
      try {
        tree = effectiveType == htmlMediaType
            ? parseHtmlDocument(protectedSource, scripting: true)
            : parseXmlDocument(protectedSource);
      } on XmlSyntaxException catch (error) {
        throw ParseException(error);
      }
    }
    return _freeze(
      tree,
      effectiveType == htmlMediaType
          ? SourceParserMode.html
          : SourceParserMode.xhtml,
      errorClass,
      mediaType,
      htmlFallback,
    );
  }

  static SourceDocument _freeze(
    DomNode tree,
    SourceParserMode mode,
    String? errorClass,
    String originalType,
    bool htmlFallback,
  ) {
    final order = <DomNode>[];
    final parents = <int?>[];
    final slots = <int>[];
    final childLists = <List<int>>[];
    final stack = <(DomNode, int?, int)>[];
    for (var slot = tree.children.length - 1; slot >= 0; slot--) {
      stack.add((tree.children[slot], null, slot));
    }
    while (stack.isNotEmpty) {
      final (node, parent, slot) = stack.removeLast();
      if (node.kind == DomKind.doctype) continue;
      final index = order.length;
      order.add(node);
      parents.add(parent);
      slots.add(slot);
      childLists.add([]);
      if (parent != null) childLists[parent].add(index);
      // Template contents live in a separate fragment, outside childNodes.
      final hidden =
          node.isElement &&
          node.localName == 'template' &&
          node.namespaceUri == xhtmlNamespace;
      if (!hidden) {
        for (
          var childSlot = node.children.length - 1;
          childSlot >= 0;
          childSlot--
        ) {
          stack.add((node.children[childSlot], index, childSlot));
        }
      }
    }
    int? rootIndex;
    for (var index = 0; index < order.length; index++) {
      if (parents[index] == null && order[index].isElement) {
        rootIndex = index;
        break;
      }
    }
    if (rootIndex == null) {
      throw const ParseException(FormatException('Missing document element'));
    }
    int? bodyIndex;
    final root = order[rootIndex];
    if (root.localName == 'html' && root.namespaceUri == xhtmlNamespace) {
      for (final child in childLists[rootIndex]) {
        final candidate = order[child];
        if (candidate.isElement &&
            candidate.namespaceUri == xhtmlNamespace &&
            (candidate.localName == 'body' ||
                candidate.localName == 'frameset')) {
          bodyIndex = child;
          break;
        }
      }
    }
    final nodes = <SourceNode>[
      for (var index = 0; index < order.length; index++)
        _sourceNode(
          order[index],
          index,
          parents[index],
          slots[index],
          childLists[index],
        ),
    ];
    return SourceDocument(
      nodes: nodes,
      documentElementIndex: rootIndex,
      bodyIndex: bodyIndex,
      parserMode: mode,
      parserErrorClass: errorClass,
      originalMediaType: originalType,
      htmlFallback: htmlFallback,
    );
  }

  static SourceNode _sourceNode(
    DomNode node,
    int index,
    int? parent,
    int slot,
    List<int> children,
  ) {
    final kind = switch (node.kind) {
      DomKind.element => SourceNodeKind.element,
      DomKind.text => SourceNodeKind.text,
      DomKind.cdata => SourceNodeKind.cdata,
      DomKind.comment => SourceNodeKind.comment,
      _ => SourceNodeKind.processingInstruction,
    };
    final isElement = node.isElement;
    return SourceNode(
      index: index,
      kind: kind,
      childSlot: slot,
      parentIndex: parent,
      namespaceUri: isElement ? node.namespaceUri : null,
      localName: isElement ? node.localName : null,
      id: isElement ? node.attr('id') ?? '' : null,
      text: isElement ? null : node.data,
      children: children,
      attributes: [
        for (final attribute in node.attributes)
          SourceAttribute(
            qualifiedName: attribute.qualifiedName,
            localName: attribute.localName,
            namespaceUri: attribute.namespaceUri,
            value: attribute.value,
          ),
      ],
    );
  }
}
