import 'package:shiori/features/reader/data/epub/epub_url.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';

const svgNamespace = 'http://www.w3.org/2000/svg';
const xlinkNamespace = 'http://www.w3.org/1999/xlink';

const _graphicNames = {
  'circle',
  'ellipse',
  'foreignObject',
  'image',
  'line',
  'path',
  'polygon',
  'polyline',
  'rect',
  'text',
  'use',
};
const _definitionNames = {
  'defs',
  'clipPath',
  'marker',
  'mask',
  'pattern',
  'symbol',
};

/// JavaScript `Number(x)` restricted to what the reference guard feeds it.
double _number(String? value) {
  if (value == null) return 0;
  final trimmed = value.trim();
  if (trimmed.isEmpty) return 0;
  return double.tryParse(trimmed) ?? double.nan;
}

double _finiteDimension(double value) =>
    value.isFinite && value > 0 ? value : 0;

/// An intrinsic size in CSS px; zero components mean unknown.
typedef SvgSize = ({double width, double height});

/// Port of `svgDimensions` (`contentImage.ts:197`) without the rendered-box
/// fallback, which needs a browser layout: unknown stays zero.
SvgSize svgIntrinsicSize(SourceDocument document, int svgIndex) {
  final svg = document.node(svgIndex);
  final box = (svg.attribute('viewBox') ?? '')
      .trim()
      .split(RegExp(r'[\s,]+'))
      .map((part) => part.isEmpty ? 0.0 : (double.tryParse(part) ?? double.nan))
      .toList();
  if (box.length == 4 && box.every((value) => value.isFinite)) {
    final width = _finiteDimension(box[2]);
    final height = _finiteDimension(box[3]);
    if (width > 0 && height > 0) return (width: width, height: height);
  }
  double dimension(String name) {
    final raw = (svg.attribute(name) ?? '').replaceAll(
      RegExp(r'px$', caseSensitive: false),
      '',
    );
    return _finiteDimension(_number(raw));
  }

  final width = dimension('width');
  final height = dimension('height');
  if (width > 0 && height > 0) return (width: width, height: height);
  return (width: 0, height: 0);
}

/// Depth-first descendants of [index] (excluding it).
Iterable<SourceNode> _descendants(SourceDocument document, int index) sync* {
  final stack = <int>[...document.node(index).children.reversed];
  while (stack.isNotEmpty) {
    final node = document.node(stack.removeLast());
    yield node;
    for (var k = node.children.length - 1; k >= 0; k--) {
      stack.add(node.children[k]);
    }
  }
}

bool _insideDefinition(SourceDocument document, SourceNode node, int svg) {
  for (
    var parent = node.parentIndex;
    parent != null && parent != svg;
    parent = document.node(parent).parentIndex
  ) {
    if (_definitionNames.contains(document.node(parent).localName)) {
      return true;
    }
  }
  return false;
}

String? _imageHref(SourceNode image) =>
    image.attribute('href') ??
    image.attribute('xlink:href') ??
    [
      for (final attribute in image.attributes)
        if (attribute.localName == 'href' &&
            attribute.namespaceUri == xlinkNamespace)
          attribute.value,
    ].firstOrNull;

/// The archive path of the raster behind a plain SVG wrapper, or null when
/// the reference guard (`originalResourceFromSvgImage`, `contentImage.ts:
/// 403`) refuses the fast path: exactly one graphic that is an `image` at
/// the origin covering the whole view box, with no transform, clip, filter
/// or mask on it or its ancestors up to the svg, and no `slice` aspect.
String? svgWrapperResource(
  SourceDocument document,
  int svgIndex,
  String sectionHref,
) {
  final size = svgIntrinsicSize(document, svgIndex);
  if (size.width == 0 || size.height == 0) return null;
  final graphics = [
    for (final node in _descendants(document, svgIndex))
      if (node.kind == SourceNodeKind.element &&
          _graphicNames.contains(node.localName) &&
          !_insideDefinition(document, node, svgIndex))
        node,
  ];
  if (graphics.length != 1 || graphics.single.localName != 'image') {
    return null;
  }
  final image = graphics.single;
  final x = _number(image.attribute('x'));
  final y = _number(image.attribute('y'));
  final width = _finiteDimension(_number(image.attribute('width')));
  final height = _finiteDimension(_number(image.attribute('height')));
  const forbidden = ['transform', 'clip-path', 'filter', 'mask'];
  if (!x.isFinite ||
      !y.isFinite ||
      x != 0 ||
      y != 0 ||
      width != size.width ||
      height != size.height ||
      forbidden.any((name) => image.attribute(name) != null) ||
      RegExp(
        r'\bslice\b',
        caseSensitive: false,
      ).hasMatch(image.attribute('preserveAspectRatio') ?? '')) {
    return null;
  }
  for (
    var ancestor = image.parentIndex;
    ancestor != null && ancestor != svgIndex;
    ancestor = document.node(ancestor).parentIndex
  ) {
    final node = document.node(ancestor);
    if (forbidden.any((name) => node.attribute(name) != null)) return null;
  }
  final source = _imageHref(image) ?? '';
  if (source.isEmpty || source.startsWith('#')) return null;
  if (isExternalUrl(source)) return null;
  return resolveUrl(source, sectionHref);
}

/// SVG constructs the vector renderer cannot paint. Their presence makes the
/// block supported-with-difference and shows a marker.
List<String> svgPartialFeatures(SourceDocument document, int svgIndex) {
  final found = <String>{};
  for (final node in _descendants(document, svgIndex)) {
    if (node.kind != SourceNodeKind.element) continue;
    final name = node.localName ?? '';
    switch (name) {
      case 'text' || 'tspan' || 'textPath':
        found.add('text');
      case 'foreignObject':
        found.add('foreignObject');
      case 'filter':
        found.add('filter');
      case 'image':
        final href = _imageHref(node) ?? '';
        if (!href.startsWith('data:')) found.add('external-image');
      case 'use':
        final href = _imageHref(node) ?? '';
        if (!href.startsWith('#')) found.add('external-use');
    }
  }
  return found.toList()..sort();
}

String _escape(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;');

String _escapeAttribute(String value) =>
    _escape(value).replaceAll('"', '&quot;');

/// Serializes the subtree at [svgIndex] as standalone SVG markup, adding the
/// namespace declarations the source relied on.
String serializeSvg(SourceDocument document, int svgIndex) {
  final out = StringBuffer();
  void write(int index, String? parentNamespace, bool isRoot) {
    final node = document.node(index);
    switch (node.kind) {
      case SourceNodeKind.text || SourceNodeKind.cdata:
        out.write(_escape(node.text ?? ''));
      case SourceNodeKind.element:
        final name = node.localName ?? 'g';
        out.write('<$name');
        final namespace = node.namespaceUri ?? svgNamespace;
        final declared = node.attributes.any(
          (attribute) => attribute.qualifiedName == 'xmlns',
        );
        if (!declared && (isRoot || namespace != parentNamespace)) {
          out.write(' xmlns="${_escapeAttribute(namespace)}"');
        }
        if (isRoot &&
            !node.attributes.any(
              (attribute) => attribute.qualifiedName == 'xmlns:xlink',
            ) &&
            node.attributes.any(
              (attribute) => attribute.qualifiedName.startsWith('xlink:'),
            )) {
          out.write(' xmlns:xlink="$xlinkNamespace"');
        }
        for (final attribute in node.attributes) {
          out.write(
            ' ${attribute.qualifiedName}="'
            '${_escapeAttribute(attribute.value)}"',
          );
        }
        if (node.children.isEmpty) {
          out.write('/>');
        } else {
          out.write('>');
          for (final child in node.children) {
            write(child, namespace, false);
          }
          out.write('</$name>');
        }
      case SourceNodeKind.comment || SourceNodeKind.processingInstruction:
        break;
    }
  }

  write(svgIndex, null, true);
  return out.toString();
}
