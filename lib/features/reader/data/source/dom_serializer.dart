import 'package:shiori/features/reader/data/source/dom_node.dart';

const _voidElements = {
  'area',
  'base',
  'basefont',
  'bgsound',
  'br',
  'col',
  'embed',
  'frame',
  'hr',
  'img',
  'input',
  'keygen',
  'link',
  'menuitem',
  'meta',
  'param',
  'source',
  'track',
  'wbr',
};

String _escapeText(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _escapeAttribute(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll('\t', '&#9;')
    .replaceAll('\n', '&#10;')
    .replaceAll('\r', '&#13;');

/// `XMLSerializer.serializeToString` for a document tree: well-formed XML
/// syntax with namespace declarations added where an element or attribute
/// needs one. HTML-namespace void elements self-close; other empty HTML
/// elements keep an explicit end tag so an HTML reparse sees the same tree.
String serializeXml(DomNode document) {
  final out = StringBuffer();
  // Work items are DomNode (open) or String (literal text, e.g. an end tag).
  final stack = <Object>[];
  final scopes = <DomNode, Map<String, String>>{};
  const rootScope = <String, String>{};
  for (var k = document.children.length - 1; k >= 0; k--) {
    stack.add(document.children[k]);
    scopes[document.children[k]] = rootScope;
  }
  while (stack.isNotEmpty) {
    final item = stack.removeLast();
    if (item is String) {
      out.write(item);
      continue;
    }
    final node = item as DomNode;
    final scope = scopes.remove(node) ?? rootScope;
    switch (node.kind) {
      case DomKind.document:
        break;
      case DomKind.doctype:
        out.write('<!DOCTYPE ${node.target}');
        final publicId = node.publicId ?? '';
        final systemId = node.systemId ?? '';
        if (publicId.isNotEmpty) {
          out.write(' PUBLIC "$publicId"');
        } else if (systemId.isNotEmpty) {
          out.write(' SYSTEM');
        }
        if (systemId.isNotEmpty) out.write(' "$systemId"');
        out.write('>');
      case DomKind.text:
        out.write(_escapeText(node.data ?? ''));
      case DomKind.cdata:
        out.write('<![CDATA[${node.data ?? ''}]]>');
      case DomKind.comment:
        out.write('<!--${node.data ?? ''}-->');
      case DomKind.pi:
        final data = node.data ?? '';
        out.write('<?${node.target}${data.isEmpty ? '' : ' $data'}?>');
      case DomKind.element:
        final local = Map<String, String>.of(scope);
        final declarations = <String>[];
        final desired = node.namespaceUri ?? '';
        final elementPrefix = node.prefix ?? '';
        final attributes = <String>[];
        for (final attribute in node.attributes) {
          if (attribute.isNamespaceDeclaration) {
            final key = attribute.prefix == null ? '' : attribute.localName;
            if (key == elementPrefix && attribute.value != desired) {
              // The element's own namespace wins over a conflicting
              // declaration attribute.
              continue;
            }
            local[key] = attribute.value;
            declarations.add(
              ' ${attribute.qualifiedName}="${_escapeAttribute(attribute.value)}"',
            );
          }
        }
        if (elementPrefix != 'xml' && (local[elementPrefix] ?? '') != desired) {
          local[elementPrefix] = desired;
          declarations.add(
            elementPrefix.isEmpty
                ? ' xmlns="${_escapeAttribute(desired)}"'
                : ' xmlns:$elementPrefix="${_escapeAttribute(desired)}"',
          );
        }
        var generated = 0;
        for (final attribute in node.attributes) {
          if (attribute.isNamespaceDeclaration) continue;
          final ns = attribute.namespaceUri;
          var qualified = attribute.localName;
          if (ns != null) {
            var prefix = attribute.prefix;
            if (ns == xmlNamespace) {
              prefix = 'xml';
            } else {
              if (prefix == null || prefix.isEmpty) {
                prefix = 'ns${++generated}';
              }
              if (local[prefix] != ns) {
                local[prefix] = ns;
                declarations.add(' xmlns:$prefix="${_escapeAttribute(ns)}"');
              }
            }
            qualified = '$prefix:${attribute.localName}';
          }
          attributes.add(' $qualified="${_escapeAttribute(attribute.value)}"');
        }
        final name = node.qualifiedName;
        out
          ..write('<$name')
          ..writeAll(declarations)
          ..writeAll(attributes);
        if (node.children.isEmpty) {
          final isHtml = node.namespaceUri == xhtmlNamespace;
          if (!isHtml || _voidElements.contains(node.localName)) {
            out.write(' />');
          } else {
            out.write('></$name>');
          }
        } else {
          out.write('>');
          stack.add('</$name>');
          for (var k = node.children.length - 1; k >= 0; k--) {
            stack.add(node.children[k]);
            scopes[node.children[k]] = local;
          }
        }
    }
  }
  return out.toString();
}
