import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/source/dom_node.dart';
import 'package:shiori/features/reader/data/source/dom_serializer.dart';
import 'package:shiori/features/reader/data/source/html_adapter.dart';
import 'package:shiori/features/reader/data/source/xml_parser.dart';

const _blockedElements = {
  'script',
  'iframe',
  'frame',
  'frameset',
  'object',
  'embed',
  'base',
  'form',
  'animate',
  'animateMotion',
  'animateTransform',
  'set',
  'discard',
};

const _contentSecurityPolicy =
    "default-src 'none'; script-src 'none'; style-src 'unsafe-inline' blob: "
    'data:; img-src blob: data:; font-src blob: data:; media-src blob: data:; '
    "connect-src 'none'; frame-src 'none'; object-src 'none'; base-uri "
    "'none'; form-action 'none'";

final _urlNoise = RegExp(r'[\s\x00-\x20\x7f-\x9f]');
final _eventHandler = RegExp('^on', caseSensitive: false);
final _scriptUrl = RegExp(r'^(?:javascript|vbscript):', caseSensitive: false);

/// Port of the reference `protectBookDocument` (`contentSecurity.ts`): parse,
/// drop processing instructions, replace active elements with inert elements
/// at the same position (IDs and form children kept), remove event/script
/// attributes, prepend the CSP meta and serialize.
String protectBookDocument(String source, String type) {
  final mime = type == 'text/html' ? 'text/html' : type;
  final DomNode document;
  try {
    document = mime == 'text/html'
        ? parseHtmlDocument(source)
        : parseXmlDocument(source);
  } on XmlSyntaxException catch (error) {
    throw ParseException(error);
  }
  protectDocument(document);
  return serializeXml(document);
}

void protectDocument(DomNode document) {
  for (final node in document.descendants.toList()) {
    if (node.kind == DomKind.pi) node.remove();
  }
  final blocked = [
    for (final element in document.descendantElements)
      if (_blockedElements.contains(element.localName) ||
          (element.localName == 'meta' && element.attr('http-equiv') != null))
        element,
  ];
  for (final element in blocked) {
    final namespace = element.namespaceUri;
    final inert = DomNode(
      DomKind.element,
      localName: namespace == svgNamespace
          ? 'g'
          : namespace == mathNamespace
          ? 'mrow'
          : 'span',
      namespaceUri: namespace,
    );
    final id = element.attr('id') ?? '';
    if (id.isNotEmpty) {
      inert.attributes.add(DomAttribute(localName: 'id', value: id));
    }
    if (element.localName == 'form') {
      for (final child in List<DomNode>.of(element.children)) {
        child.remove();
        inert.add(child);
      }
    }
    element.replaceWith(inert);
  }
  for (final element in document.descendantElements) {
    element.attributes.removeWhere((attribute) {
      final url = attribute.value.replaceAll(_urlNoise, '');
      return _eventHandler.hasMatch(attribute.qualifiedName) ||
          _scriptUrl.hasMatch(url) ||
          attribute.qualifiedName == 'srcdoc';
    });
  }
  final root = document.documentElement;
  if (root != null &&
      root.localName == 'html' &&
      root.namespaceUri == xhtmlNamespace) {
    for (final child in root.childElements) {
      if (child.localName == 'head' && child.namespaceUri == xhtmlNamespace) {
        child.insert(
          0,
          DomNode(
            DomKind.element,
            localName: 'meta',
            namespaceUri: xhtmlNamespace,
            attributes: [
              DomAttribute(
                localName: 'http-equiv',
                value: 'Content-Security-Policy',
              ),
              DomAttribute(localName: 'content', value: _contentSecurityPolicy),
            ],
          ),
        );
        break;
      }
    }
  }
}
