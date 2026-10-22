import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
import 'package:shiori/features/reader/data/source/dom_node.dart';

/// Parses [source] with the HTML5 tree builder and converts the result to the
/// shared tree.
///
/// The tree builder always treats `<noscript>` content as raw text, which is
/// what a script-enabled document (the reference's final iframe load) sees.
/// By default scripting is disabled, like `DOMParser`: each raw `<noscript>`
/// text is then reparsed as an HTML fragment so its markup becomes elements.
DomNode parseHtmlDocument(String source, {bool scripting = false}) {
  final document = html_parser.parse(source);
  final root = DomNode(DomKind.document);
  for (final node in document.nodes) {
    final converted = _convert(node);
    if (converted != null) root.add(converted);
  }
  if (!scripting) _expandNoscript(root);
  return root;
}

void _expandNoscript(DomNode root) {
  final pending = root.descendantElements.toList();
  while (pending.isNotEmpty) {
    final element = pending.removeLast();
    if (element.localName != 'noscript' ||
        element.namespaceUri != xhtmlNamespace ||
        element.children.length != 1 ||
        element.children.first.kind != DomKind.text) {
      continue;
    }
    final fragment = html_parser.parseFragment(
      element.children.first.data ?? '',
      container: 'div',
    );
    final children = <DomNode>[];
    for (final node in fragment.nodes) {
      final converted = _convert(node);
      if (converted != null) children.add(converted);
    }
    element.replaceChildren(children);
    for (final child in children) {
      if (child.isElement) {
        pending.add(child);
        pending.addAll(child.descendantElements);
      }
    }
  }
}

DomNode? _convert(html.Node node) {
  // Iterative so pathological nesting cannot overflow the stack.
  final result = _shallow(node);
  if (result == null) return null;
  final stack = <(html.Node, DomNode)>[(node, result)];
  while (stack.isNotEmpty) {
    final (source, target) = stack.removeLast();
    for (final child in source.nodes) {
      final converted = _shallow(child);
      if (converted == null) continue;
      target.add(converted);
      if (child is html.Element) stack.add((child, converted));
    }
  }
  return result;
}

DomNode? _shallow(html.Node node) {
  if (node is html.Element) {
    final attributes = <DomAttribute>[];
    node.attributes.forEach((key, value) {
      if (key is html.AttributeName) {
        attributes.add(
          DomAttribute(
            localName: key.name,
            prefix: key.prefix,
            namespaceUri: key.namespace,
            value: value,
          ),
        );
      } else {
        attributes.add(DomAttribute(localName: key.toString(), value: value));
      }
    });
    return DomNode(
      DomKind.element,
      localName: node.localName,
      namespaceUri: node.namespaceUri,
      attributes: attributes,
    );
  }
  if (node is html.Text) return DomNode(DomKind.text, data: node.data);
  if (node is html.Comment) return DomNode(DomKind.comment, data: node.data);
  if (node is html.DocumentType) {
    return DomNode(DomKind.doctype, target: node.name)
      ..publicId = node.publicId
      ..systemId = node.systemId;
  }
  return null;
}
