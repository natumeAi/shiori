import 'package:shiori/features/reader/data/source/dom_node.dart';
import 'package:xml/xml.dart' show XmlDefaultEntityMapping;

/// A well-formedness or namespace error. The message never contains document
/// text, so it is safe for private books.
final class XmlSyntaxException implements Exception {
  const XmlSyntaxException(this.message, this.line, this.column);

  final String message;
  final int line;
  final int column;

  @override
  String toString() => 'XML error at $line:$column: $message';
}

/// Strict XML 1.0 + Namespaces parser used where the browser reference uses
/// `DOMParser`. Anything a browser XML parser rejects throws
/// [XmlSyntaxException], which selects the HTML fallback for XHTML sections.
DomNode parseXmlDocument(String source) => _XmlParser(source).parse();

const _predefinedEntities = {
  'lt': '<',
  'gt': '>',
  'amp': '&',
  'apos': "'",
  'quot': '"',
};

final Map<String, String> _xhtmlEntities = Map.unmodifiable(
  XmlDefaultEntityMapping.html().entities,
);

final class _XmlParser {
  _XmlParser(String source)
    : _s = source.replaceAll('\r\n', '\n').replaceAll('\r', '\n');

  final String _s;
  int _i = 0;
  final Map<String, String> _customEntities = {};
  bool _xhtmlDoctype = false;

  Never _fail(String message, [int? at]) {
    final position = at ?? _i;
    var line = 1;
    var column = 1;
    for (var k = 0; k < position && k < _s.length; k++) {
      if (_s.codeUnitAt(k) == 0x0a) {
        line++;
        column = 1;
      } else {
        column++;
      }
    }
    throw XmlSyntaxException(message, line, column);
  }

  DomNode parse() {
    _validateCharacters();
    final document = DomNode(DomKind.document);
    if (_s.startsWith('<?xml') && _s.length > 5 && _isSpace(_s.codeUnitAt(5))) {
      final end = _s.indexOf('?>');
      if (end < 0) _fail('unterminated XML declaration');
      _i = end + 2;
    }
    var seenDoctype = false;
    var seenRoot = false;
    while (_i < _s.length) {
      final c = _s.codeUnitAt(_i);
      if (_isSpace(c)) {
        _i++;
      } else if (_s.startsWith('<!--', _i)) {
        document.add(_comment());
      } else if (_s.startsWith('<?', _i)) {
        document.add(_processingInstruction());
      } else if (_s.startsWith('<!DOCTYPE', _i)) {
        if (seenDoctype || seenRoot) _fail('misplaced doctype');
        seenDoctype = true;
        document.add(_doctype());
      } else if (c == 0x3c) {
        if (seenRoot) _fail('multiple root elements');
        seenRoot = true;
        document.add(_elementTree(const {'xml': xmlNamespace}));
      } else {
        _fail('content outside the root element');
      }
    }
    if (!seenRoot) _fail('missing root element');
    return document;
  }

  void _validateCharacters() {
    for (var k = 0; k < _s.length; k++) {
      final c = _s.codeUnitAt(k);
      if (c >= 0x20 && c < 0xd800) continue;
      if (c == 0x09 || c == 0x0a) continue;
      if (c >= 0xd800 && c <= 0xdbff) {
        if (k + 1 < _s.length) {
          final d = _s.codeUnitAt(k + 1);
          if (d >= 0xdc00 && d <= 0xdfff) {
            k++;
            continue;
          }
        }
        _fail('invalid surrogate', k);
      }
      if (c >= 0xe000 && c <= 0xfffd) continue;
      _fail('invalid XML character', k);
    }
  }

  static bool _isSpace(int c) => c == 0x20 || c == 0x09 || c == 0x0a;

  static bool _isNameStart(int c) =>
      c == 0x3a ||
      (c >= 0x41 && c <= 0x5a) ||
      c == 0x5f ||
      (c >= 0x61 && c <= 0x7a) ||
      (c >= 0xc0 && c <= 0xd6) ||
      (c >= 0xd8 && c <= 0xf6) ||
      (c >= 0xf8 && c <= 0x2ff) ||
      (c >= 0x370 && c <= 0x37d) ||
      (c >= 0x37f && c <= 0x1fff) ||
      (c >= 0x200c && c <= 0x200d) ||
      (c >= 0x2070 && c <= 0x218f) ||
      (c >= 0x2c00 && c <= 0x2fef) ||
      (c >= 0x3001 && c <= 0xd7ff) ||
      (c >= 0xd800 && c <= 0xdfff) ||
      (c >= 0xf900 && c <= 0xfdcf) ||
      (c >= 0xfdf0 && c <= 0xfffd);

  static bool _isNameChar(int c) =>
      _isNameStart(c) ||
      c == 0x2d ||
      c == 0x2e ||
      (c >= 0x30 && c <= 0x39) ||
      c == 0xb7 ||
      (c >= 0x300 && c <= 0x36f) ||
      (c >= 0x203f && c <= 0x2040);

  String _name() {
    final start = _i;
    if (_i >= _s.length || !_isNameStart(_s.codeUnitAt(_i))) {
      _fail('expected a name');
    }
    _i++;
    while (_i < _s.length && _isNameChar(_s.codeUnitAt(_i))) {
      _i++;
    }
    return _s.substring(start, _i);
  }

  void _skipSpace() {
    while (_i < _s.length && _isSpace(_s.codeUnitAt(_i))) {
      _i++;
    }
  }

  DomNode _comment() {
    final end = _s.indexOf('-->', _i + 4);
    if (end < 0) _fail('unterminated comment');
    final body = _s.substring(_i + 4, end);
    if (body.contains('--') || body.endsWith('-')) {
      _fail('"--" inside a comment');
    }
    _i = end + 3;
    return DomNode(DomKind.comment, data: body);
  }

  DomNode _processingInstruction() {
    _i += 2;
    final target = _name();
    if (target.toLowerCase() == 'xml') _fail('misplaced XML declaration');
    String data;
    if (_s.startsWith('?>', _i)) {
      data = '';
      _i += 2;
    } else {
      if (_i >= _s.length || !_isSpace(_s.codeUnitAt(_i))) {
        _fail('malformed processing instruction');
      }
      _skipSpace();
      final end = _s.indexOf('?>', _i);
      if (end < 0) _fail('unterminated processing instruction');
      data = _s.substring(_i, end);
      _i = end + 2;
    }
    return DomNode(DomKind.pi, target: target, data: data);
  }

  String _quoted() {
    if (_i >= _s.length) _fail('expected a quoted literal');
    final quote = _s.codeUnitAt(_i);
    if (quote != 0x22 && quote != 0x27) _fail('expected a quoted literal');
    final end = _s.indexOf(String.fromCharCode(quote), _i + 1);
    if (end < 0) _fail('unterminated literal');
    final value = _s.substring(_i + 1, end);
    _i = end + 1;
    return value;
  }

  DomNode _doctype() {
    _i += 9;
    if (_i >= _s.length || !_isSpace(_s.codeUnitAt(_i))) {
      _fail('malformed doctype');
    }
    _skipSpace();
    final node = DomNode(DomKind.doctype, target: _name());
    _skipSpace();
    if (_s.startsWith('PUBLIC', _i)) {
      _i += 6;
      _skipSpace();
      node.publicId = _quoted();
      _skipSpace();
      node.systemId = _quoted();
      _skipSpace();
    } else if (_s.startsWith('SYSTEM', _i)) {
      _i += 6;
      _skipSpace();
      node.systemId = _quoted();
      _skipSpace();
    }
    _xhtmlDoctype =
        node.publicId != null && node.publicId!.startsWith('-//W3C//DTD XHTML');
    if (_i < _s.length && _s.codeUnitAt(_i) == 0x5b) {
      _i++;
      _internalSubset();
      _skipSpace();
    }
    if (_i >= _s.length || _s.codeUnitAt(_i) != 0x3e) {
      _fail('unterminated doctype');
    }
    _i++;
    return node;
  }

  void _internalSubset() {
    while (true) {
      _skipSpace();
      if (_i >= _s.length) _fail('unterminated internal subset');
      final c = _s.codeUnitAt(_i);
      if (c == 0x5d) {
        _i++;
        return;
      }
      if (_s.startsWith('<!--', _i)) {
        _comment();
      } else if (_s.startsWith('<?', _i)) {
        _processingInstruction();
      } else if (_s.startsWith('<!ENTITY', _i)) {
        _entityDeclaration();
      } else if (_s.startsWith('<!', _i)) {
        _skipDeclaration();
      } else if (c == 0x25) {
        final end = _s.indexOf(';', _i);
        if (end < 0) _fail('malformed parameter entity');
        _i = end + 1;
      } else {
        _fail('malformed internal subset');
      }
    }
  }

  void _skipDeclaration() {
    while (_i < _s.length) {
      final c = _s.codeUnitAt(_i);
      if (c == 0x22 || c == 0x27) {
        _quoted();
      } else if (c == 0x3e) {
        _i++;
        return;
      } else {
        _i++;
      }
    }
    _fail('unterminated declaration');
  }

  void _entityDeclaration() {
    _i += 8;
    _skipSpace();
    if (_i < _s.length && _s.codeUnitAt(_i) == 0x25) {
      _skipDeclaration();
      return;
    }
    final name = _name();
    _skipSpace();
    if (_i < _s.length &&
        (_s.codeUnitAt(_i) == 0x22 || _s.codeUnitAt(_i) == 0x27)) {
      final value = _quoted();
      if (value.contains('<') || (value.contains('&') && _hasNamedRef(value))) {
        _fail('unsupported entity replacement text');
      }
      _customEntities.putIfAbsent(name, () => _decode(value, attribute: false));
    }
    _skipDeclaration();
  }

  static bool _hasNamedRef(String value) => RegExp(r'&[^#]').hasMatch(value);

  /// Parses one element and its content. Iterative to survive deep nesting.
  DomNode _elementTree(Map<String, String> rootScope) {
    final elements = <DomNode>[];
    final scopes = <Map<String, String>>[];
    DomNode? root;

    void openElement(Map<String, String> parentScope) {
      final start = _i;
      _i++;
      final qualified = _name();
      final raw = <(String, String)>[];
      var selfClosing = false;
      while (true) {
        final before = _i;
        _skipSpace();
        if (_i >= _s.length) _fail('unterminated start tag');
        final c = _s.codeUnitAt(_i);
        if (c == 0x3e) {
          _i++;
          break;
        }
        if (c == 0x2f) {
          if (!_s.startsWith('/>', _i)) _fail('malformed start tag');
          _i += 2;
          selfClosing = true;
          break;
        }
        if (_i == before) _fail('missing whitespace before attribute');
        final name = _name();
        _skipSpace();
        if (_i >= _s.length || _s.codeUnitAt(_i) != 0x3d) {
          _fail('attribute without a value');
        }
        _i++;
        _skipSpace();
        if (_i >= _s.length) _fail('unterminated start tag');
        final quote = _s.codeUnitAt(_i);
        if (quote != 0x22 && quote != 0x27) _fail('unquoted attribute value');
        final end = _s.indexOf(String.fromCharCode(quote), _i + 1);
        if (end < 0) _fail('unterminated attribute value');
        final rawValue = _s.substring(_i + 1, end);
        if (rawValue.contains('<')) _fail('"<" in an attribute value');
        _i = end + 1;
        raw.add((name, _decode(rawValue, attribute: true)));
      }

      var scope = parentScope;
      var copied = false;
      void declare(String prefix, String uri) {
        if (!copied) {
          scope = Map<String, String>.of(parentScope);
          copied = true;
        }
        scope[prefix] = uri;
      }

      for (final (name, value) in raw) {
        if (name == 'xmlns') {
          declare('', value);
        } else if (name.startsWith('xmlns:')) {
          final prefix = name.substring(6);
          if (prefix.isEmpty || prefix.contains(':')) {
            _fail('malformed namespace declaration', start);
          }
          if (prefix == 'xmlns' || (prefix == 'xml' && value != xmlNamespace)) {
            _fail('reserved namespace prefix', start);
          }
          if (value.isEmpty) _fail('empty prefixed namespace', start);
          declare(prefix, value);
        }
      }

      final (elementPrefix, elementLocal) = _split(qualified, start);
      String? elementNs;
      if (elementPrefix == null) {
        final declared = scope[''];
        elementNs = (declared == null || declared.isEmpty) ? null : declared;
      } else {
        elementNs = scope[elementPrefix];
        if (elementNs == null) _fail('undeclared namespace prefix', start);
      }
      final element = DomNode(
        DomKind.element,
        localName: elementLocal,
        prefix: elementPrefix,
        namespaceUri: elementNs,
      );
      final seen = <String>{};
      for (final (name, value) in raw) {
        late final DomAttribute attribute;
        if (name == 'xmlns') {
          attribute = DomAttribute(
            localName: 'xmlns',
            value: value,
            namespaceUri: xmlnsNamespace,
          );
        } else if (name.startsWith('xmlns:')) {
          attribute = DomAttribute(
            localName: name.substring(6),
            prefix: 'xmlns',
            value: value,
            namespaceUri: xmlnsNamespace,
          );
        } else {
          final (prefix, local) = _split(name, start);
          String? ns;
          if (prefix != null) {
            ns = scope[prefix];
            if (ns == null) _fail('undeclared attribute prefix', start);
          }
          attribute = DomAttribute(
            localName: local,
            prefix: prefix,
            value: value,
            namespaceUri: ns,
          );
        }
        if (!seen.add('${attribute.namespaceUri}|${attribute.localName}')) {
          _fail('duplicate attribute', start);
        }
        element.attributes.add(attribute);
      }
      if (elements.isEmpty) {
        root = element;
      } else {
        elements.last.add(element);
      }
      if (!selfClosing) {
        elements.add(element);
        scopes.add(scope);
      }
    }

    openElement(rootScope);
    if (elements.isEmpty) return root!;
    while (elements.isNotEmpty) {
      if (_i >= _s.length) _fail('unexpected end of document');
      final current = elements.last;
      if (_s.codeUnitAt(_i) != 0x3c) {
        final end = _s.indexOf('<', _i);
        final stop = end < 0 ? _s.length : end;
        final raw = _s.substring(_i, stop);
        if (raw.contains(']]>')) _fail('"]]>" in text');
        _i = stop;
        current.add(
          DomNode(DomKind.text, data: _decode(raw, attribute: false)),
        );
      } else if (_s.startsWith('</', _i)) {
        _i += 2;
        final name = _name();
        _skipSpace();
        if (_i >= _s.length || _s.codeUnitAt(_i) != 0x3e) {
          _fail('malformed end tag');
        }
        _i++;
        if (name != current.qualifiedName) _fail('mismatched end tag');
        elements.removeLast();
        scopes.removeLast();
      } else if (_s.startsWith('<!--', _i)) {
        current.add(_comment());
      } else if (_s.startsWith('<![CDATA[', _i)) {
        final end = _s.indexOf(']]>', _i + 9);
        if (end < 0) _fail('unterminated CDATA section');
        current.add(DomNode(DomKind.cdata, data: _s.substring(_i + 9, end)));
        _i = end + 3;
      } else if (_s.startsWith('<?', _i)) {
        current.add(_processingInstruction());
      } else if (_s.startsWith('<!', _i)) {
        _fail('unexpected markup declaration');
      } else {
        openElement(scopes.last);
      }
    }
    return root!;
  }

  (String?, String) _split(String qualified, int at) {
    final colon = qualified.indexOf(':');
    if (colon < 0) return (null, qualified);
    if (colon == 0 ||
        colon == qualified.length - 1 ||
        qualified.indexOf(':', colon + 1) >= 0) {
      _fail('malformed qualified name', at);
    }
    return (qualified.substring(0, colon), qualified.substring(colon + 1));
  }

  String _decode(String raw, {required bool attribute}) {
    if (!raw.contains('&') && !(attribute && raw.contains(RegExp('[\t\n]')))) {
      return raw;
    }
    final out = StringBuffer();
    for (var k = 0; k < raw.length;) {
      final c = raw.codeUnitAt(k);
      if (c != 0x26) {
        // Attribute-value normalization: literal tab/newline become a space.
        out.writeCharCode(attribute && (c == 0x09 || c == 0x0a) ? 0x20 : c);
        k++;
        continue;
      }
      final end = raw.indexOf(';', k + 1);
      if (end < 0) _fail('unterminated entity reference');
      final name = raw.substring(k + 1, end);
      out.write(_entity(name));
      k = end + 1;
    }
    return out.toString();
  }

  String _entity(String name) {
    if (name.startsWith('#')) {
      final hex = name.startsWith('#x');
      final digits = name.substring(hex ? 2 : 1);
      final valid = hex
          ? RegExp(r'^[0-9a-fA-F]+$').hasMatch(digits)
          : RegExp(r'^[0-9]+$').hasMatch(digits);
      final code = valid && digits.length <= 8
          ? int.parse(digits, radix: hex ? 16 : 10)
          : null;
      if (code == null ||
          !(code == 0x09 ||
              code == 0x0a ||
              code == 0x0d ||
              (code >= 0x20 && code <= 0xd7ff) ||
              (code >= 0xe000 && code <= 0xfffd) ||
              (code >= 0x10000 && code <= 0x10ffff))) {
        _fail('invalid character reference');
      }
      return String.fromCharCode(code);
    }
    final value =
        _predefinedEntities[name] ??
        _customEntities[name] ??
        (_xhtmlDoctype ? _xhtmlEntities[name] : null);
    if (value == null) _fail('unknown entity reference');
    return value;
  }
}
