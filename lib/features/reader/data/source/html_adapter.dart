import 'package:html/dom.dart' as html;
import 'package:html/parser.dart' as html_parser;
// The public parser exposes its tokenizer seam; token types live under src.
// ignore: implementation_imports
import 'package:html/src/token.dart';
// ignore: implementation_imports
import 'package:html/src/tokenizer.dart';
import 'package:shiori/features/reader/data/source/dom_node.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';

/// Parses [source] with the HTML5 tree builder and converts the result to the
/// shared tree.
///
/// Scripting is disabled by default, like DOMParser. Body noscript children
/// participate in normal tree building; head noscript uses a fragment adapter.
/// The final scripting-enabled projection keeps noscript content as raw text.
DomNode parseHtmlDocument(String source, {bool scripting = false}) {
  ReaderWorkGuard.check(ReaderWork.parsing);
  final tokenizer = _ProjectionTokenizer(source, scripting);
  final document = html_parser.HtmlParser(tokenizer).parse();
  final root = DomNode(DomKind.document);
  for (final node in document.nodes) {
    final converted = _convert(node, tokenizer.names);
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
        element.parent?.localName != 'head' ||
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

DomNode? _convert(html.Node node, [Map<html.Node, String> names = const {}]) {
  // Iterative so pathological nesting cannot overflow the stack.
  final result = _shallow(node, names);
  if (result == null) return null;
  final stack = <(html.Node, DomNode)>[(node, result)];
  while (stack.isNotEmpty) {
    final (source, target) = stack.removeLast();
    for (final child in source.nodes) {
      final converted = _shallow(child, names);
      if (converted == null) continue;
      target.add(converted);
      if (child is html.Element) stack.add((child, converted));
    }
  }
  return result;
}

DomNode? _shallow(html.Node node, Map<html.Node, String> names) {
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
      localName: names[node] ?? node.localName,
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

/// Template fragments cannot change the outer insertion/formatting stack.
/// Tokenization preserves comments, quoted attributes and raw-text strings
/// containing apparent template end tags. Fragment children never project.
final class _ProjectionTokenizer extends HtmlTokenizer {
  _ProjectionTokenizer(super.source, this.scripting);
  final bool scripting;
  final Map<html.Node, String> names = {};
  String? _pendingName;
  String? _pendingTokenName;
  bool _template = false;
  Token? _replacement;
  int _serial = 0;

  @override
  Token get current => _replacement ?? super.current;

  @override
  bool moveNext() {
    _replacement = null;
    if (_pendingName != null) {
      final node = parser!.tree.openElements.last;
      // Some insertion modes ignore unknown tags; never rename an ancestor.
      if (node.localName == _pendingTokenName) names[node] = _pendingName!;
      _pendingName = null;
      _pendingTokenName = null;
    }
    if (_template) {
      _template = false;
      _skipTemplate();
      _replacement = EndTagToken('style');
      return true;
    }
    if (!super.moveNext()) return false;
    final token = super.current;
    if (token is StartTagToken &&
        !parser!.inForeignContent(token, token.kind)) {
      if (token.name == 'template') {
        // Style is allowed in head/body and opens an isolated text phase.
        token.name = 'style';
        _pendingName = 'template';
        _pendingTokenName = token.name;
        _template = true;
      } else if (!scripting &&
          token.name == 'noscript' &&
          parser!.tree.openElements.any((n) => n.localName == 'body')) {
        // Generic inline insertion with normal child tree building. A nested
        // block can close an ancestor p and pop noscript out of the stack.
        token.name = '${_serial++}-noscript';
        _pendingName = 'noscript';
        _pendingTokenName = token.name;
      }
    } else if (!scripting && token is EndTagToken && token.name == 'noscript') {
      for (final node in parser!.tree.openElements.reversed) {
        if (names[node] == 'noscript') {
          token.name = node.localName;
          break;
        }
      }
    }
    return true;
  }

  void _skipTemplate() {
    state = dataState;
    var depth = 1;
    while (super.moveNext()) {
      final token = super.current;
      if (token is StartTagToken) {
        if (token.name == 'template') depth++;
        if (token.name == 'script') {
          state = scriptDataState;
        } else if (const {
              'style',
              'xmp',
              'iframe',
              'noembed',
              'noframes',
              'textarea',
              'title',
            }.contains(token.name) ||
            (scripting && token.name == 'noscript')) {
          state = rawtextState;
        }
      } else if (token is EndTagToken && token.name == 'template') {
        if (--depth == 0) break;
      }
    }
    state = dataState;
  }
}
