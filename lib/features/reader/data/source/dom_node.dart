/// Mutable parse-time tree used while a section is parsed, rewritten,
/// serialized and reparsed. The immutable [SourceDocument] is frozen from it.
enum DomKind { document, element, text, cdata, comment, pi, doctype }

const xhtmlNamespace = 'http://www.w3.org/1999/xhtml';
const svgNamespace = 'http://www.w3.org/2000/svg';
const mathNamespace = 'http://www.w3.org/1998/Math/MathML';
const xmlnsNamespace = 'http://www.w3.org/2000/xmlns/';
const xmlNamespace = 'http://www.w3.org/XML/1998/namespace';
const xlinkNamespace = 'http://www.w3.org/1999/xlink';

final class DomAttribute {
  DomAttribute({
    required this.localName,
    required this.value,
    this.prefix,
    this.namespaceUri,
  });

  String localName;
  String? prefix;
  String? namespaceUri;
  String value;

  String get qualifiedName => prefix == null ? localName : '$prefix:$localName';

  bool get isNamespaceDeclaration =>
      namespaceUri == xmlnsNamespace ||
      (prefix == null && localName == 'xmlns') ||
      prefix == 'xmlns';
}

final class DomNode {
  DomNode(
    this.kind, {
    this.localName,
    this.prefix,
    this.namespaceUri,
    this.data,
    this.target,
    List<DomAttribute>? attributes,
    List<DomNode>? children,
  }) : attributes = attributes ?? [],
       children = children ?? [] {
    for (final child in this.children) {
      child.parent = this;
    }
  }

  DomKind kind;

  /// Element local name.
  String? localName;
  String? prefix;
  String? namespaceUri;

  /// Text, CDATA, comment and processing-instruction data. For a doctype this
  /// holds the serialized `PUBLIC`/`SYSTEM` identifiers.
  String? data;

  /// Processing-instruction target or doctype name.
  String? target;

  /// Doctype external identifiers (null when absent).
  String? publicId;
  String? systemId;
  final List<DomAttribute> attributes;
  final List<DomNode> children;
  DomNode? parent;

  bool get isElement => kind == DomKind.element;

  String get qualifiedName =>
      prefix == null ? localName! : '$prefix:$localName';

  /// Attribute value by no-namespace local name (CSS `[name]` semantics).
  String? attr(String name) {
    for (final attribute in attributes) {
      if (attribute.namespaceUri == null &&
          attribute.prefix == null &&
          attribute.localName == name) {
        return attribute.value;
      }
    }
    return null;
  }

  /// Attribute value by namespace and local name.
  String? attrNs(String? namespaceUri, String name) {
    for (final attribute in attributes) {
      if (attribute.namespaceUri == namespaceUri &&
          attribute.localName == name) {
        return attribute.value;
      }
    }
    return null;
  }

  /// Attribute value by qualified name, like `Element.getAttribute`.
  String? attrQualified(String name) {
    for (final attribute in attributes) {
      if (attribute.qualifiedName == name) return attribute.value;
    }
    return null;
  }

  String get id => attr('id') ?? '';

  void add(DomNode child) {
    child.parent = this;
    children.add(child);
  }

  void insert(int index, DomNode child) {
    child.parent = this;
    children.insert(index, child);
  }

  /// Replaces this node in its parent, like `Node.replaceWith`.
  void replaceWith(DomNode other) {
    final owner = parent;
    if (owner == null) return;
    final index = owner.children.indexOf(this);
    if (index < 0) return;
    owner.children[index] = other;
    other.parent = owner;
    parent = null;
  }

  void remove() {
    final owner = parent;
    if (owner == null) return;
    owner.children.remove(this);
    parent = null;
  }

  void replaceChildren(List<DomNode> nodes) {
    for (final child in children) {
      child.parent = null;
    }
    children.clear();
    for (final node in nodes) {
      add(node);
    }
  }

  /// Pre-order descendants (excluding this node), without recursion.
  Iterable<DomNode> get descendants sync* {
    final stack = <DomNode>[];
    for (var k = children.length - 1; k >= 0; k--) {
      stack.add(children[k]);
    }
    while (stack.isNotEmpty) {
      final node = stack.removeLast();
      yield node;
      for (var k = node.children.length - 1; k >= 0; k--) {
        stack.add(node.children[k]);
      }
    }
  }

  Iterable<DomNode> get descendantElements =>
      descendants.where((node) => node.isElement);

  Iterable<DomNode> get childElements =>
      children.where((node) => node.isElement);

  DomNode? get documentElement {
    for (final child in children) {
      if (child.isElement) return child;
    }
    return null;
  }

  /// Concatenated Text and CDATA descendants, like `Node.textContent`.
  String get textContent {
    if (kind == DomKind.text || kind == DomKind.cdata) return data ?? '';
    final buffer = StringBuffer();
    for (final node in descendants) {
      if (node.kind == DomKind.text || node.kind == DomKind.cdata) {
        buffer.write(node.data);
      }
    }
    return buffer.toString();
  }
}
