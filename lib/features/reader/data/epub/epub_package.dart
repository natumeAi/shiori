import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/epub/epub_url.dart';
import 'package:shiori/features/reader/data/source/dom_node.dart';
import 'package:shiori/features/reader/data/source/xml_parser.dart';

const containerNamespace = 'urn:oasis:names:tc:opendocument:xmlns:container';
const opfNamespace = 'http://www.idpf.org/2007/opf';
const epubNamespace = 'http://www.idpf.org/2007/ops';
const ncxNamespace = 'http://www.daisy.org/z3986/2005/ncx/';
const ncxMediaType = 'application/x-dtbncx+xml';
const _renditionPrefix = 'http://www.idpf.org/vocab/rendition/#';
const _reservedPrefixes = {
  'a11y': 'http://www.idpf.org/epub/vocab/package/a11y/#',
  'dcterms': 'http://purl.org/dc/terms/',
  'marc': 'http://id.loc.gov/vocabulary/',
  'media': 'http://www.idpf.org/epub/vocab/overlays/#',
  'onix': 'http://www.editeur.org/ONIX/book/codelists/current.html#',
  'rendition': _renditionPrefix,
  'schema': 'http://schema.org/',
  'xsd': 'http://www.w3.org/2001/XMLSchema#',
  'msv': 'http://www.idpf.org/epub/vocab/structure/magazine/#',
  'prism':
      'http://www.prismstandard.org/specifications/3.0/PRISM_CV_Spec_3.0.htm#',
};

/// A manifest `item`. [href] is resolved against the package document and
/// URI-decoded, like the reference. [mediaType] is the declared type.
final class EpubManifestItem {
  const EpubManifestItem({
    required this.href,
    required this.id,
    required this.mediaType,
    this.properties,
    this.mediaOverlay,
  });

  final String href;
  final String? id;
  final String? mediaType;
  final List<String>? properties;
  final String? mediaOverlay;
}

/// A spine `itemref` in package order, including `linear="no"` entries.
final class EpubSpineItem {
  const EpubSpineItem({
    required this.sectionIndex,
    required this.idref,
    required this.id,
    required this.linear,
    required this.properties,
    required this.href,
    required this.cfiBase,
  });

  /// Zero-based index in the original OPF itemref list.
  final int sectionIndex;
  final String? idref;
  final String? id;
  final String? linear;
  final List<String>? properties;

  /// Resolved manifest href; null when [idref] is not in the manifest.
  final String? href;

  /// `epubcfi(/6/2[itemref-id])`-style base from the actual OPF structure.
  final String cfiBase;

  bool get isLinear => linear != 'no';
}

/// A table-of-contents entry. Navigation hrefs keep any `#fragment`.
final class EpubTocItem {
  const EpubTocItem({
    required this.href,
    this.label,
    this.labelAbsent = false,
    this.subitems,
    this.hasSubitemsKey = true,
  });

  final String? label;

  /// True when the reference leaves the label undefined (no anchor element).
  final bool labelAbsent;
  final String? href;
  final List<EpubTocItem>? subitems;

  /// NCX leaf points carry no `subitems` key at all.
  final bool hasSubitemsKey;

  Map<String, Object?> toJson() => {
    if (!labelAbsent) 'label': label,
    'href': href,
    if (hasSubitemsKey)
      'subitems': subitems?.map((item) => item.toJson()).toList(),
  };
}

final class EpubPackage {
  const EpubPackage({
    required this.opfPath,
    required this.manifest,
    required this.spine,
    required this.toc,
    required this.direction,
    required this.rendition,
    required this.navPath,
    required this.ncxPath,
  });

  final String opfPath;
  final List<EpubManifestItem> manifest;
  final List<EpubSpineItem> spine;
  final List<EpubTocItem>? toc;
  final String? direction;
  final Map<String, String?> rendition;
  final String? navPath;
  final String? ncxPath;

  EpubManifestItem? itemById(String? id) {
    if (id == null) return null;
    for (final item in manifest) {
      if (item.id == id) return item;
    }
    return null;
  }

  EpubManifestItem? itemByHref(String href) {
    for (final item in manifest) {
      if (item.href == href) return item;
    }
    return null;
  }
}

/// Element lookup that ignores the namespace when it never appears in the
/// document, like the reference `childGetter`.
final class _Children {
  _Children(DomNode root, this.namespace)
    : _useNamespace = _uses(root, namespace);

  final String namespace;
  final bool _useNamespace;

  static bool _uses(DomNode document, String namespace) {
    final root = document.documentElement;
    if (root == null) return false;
    final defaultNamespace = root.prefix == null
        ? root.namespaceUri
        : root.attrNs(xmlnsNamespace, 'xmlns');
    if (defaultNamespace == namespace) return true;
    if (root.prefix != null && root.namespaceUri == namespace) return true;
    for (final attribute in root.attributes) {
      if (attribute.prefix == 'xmlns' && attribute.value == namespace) {
        return true;
      }
    }
    return false;
  }

  bool _matches(DomNode element, String name) => _useNamespace
      ? element.namespaceUri == namespace && element.localName == name
      : element.localName == name;

  DomNode? one(DomNode? parent, String name) {
    if (parent == null) return null;
    for (final child in parent.childElements) {
      if (_matches(child, name)) return child;
    }
    return null;
  }

  List<DomNode> all(DomNode parent, String name) => [
    for (final child in parent.childElements)
      if (_matches(child, name)) child,
  ];

  List<DomNode> deep(DomNode parent, String name) => [
    for (final element in parent.descendantElements)
      if (_useNamespace
          ? element.namespaceUri == namespace && element.localName == name
          : element.qualifiedName == name)
        element,
  ];
}

final _whitespaceRun = RegExp(r'[\t\n\f\r ]+');

String _elementText(DomNode? element) {
  if (element == null) return '';
  return element.textContent
      .replaceAll(_whitespaceRun, ' ')
      .replaceAll(RegExp(r'^[\t\n\f\r ]+|[\t\n\f\r ]+$'), '');
}

DomNode? _loadXml(EpubArchive archive, String path) {
  final text = archive.text(path);
  if (text == null || text.isEmpty) return null;
  try {
    return parseXmlDocument(text);
  } on XmlSyntaxException catch (error) {
    throw ParseException(error);
  }
}

String _escapeCfi(String value) =>
    value.replaceAllMapped(RegExp(r'[\^\[\](),;=]'), (m) => '^${m[0]}');

/// Opens the package named by `META-INF/container.xml`.
EpubPackage readEpubPackage(EpubArchive archive) {
  final container = _loadXml(archive, 'META-INF/container.xml');
  if (container == null) {
    throw const ParseException(FormatException('Missing container file'));
  }
  String? opfPath;
  for (final element in container.descendantElements) {
    if (element.namespaceUri == containerNamespace &&
        element.localName == 'rootfile' &&
        element.attrQualified('media-type') ==
            'application/oebps-package+xml') {
      opfPath = element.attrQualified('full-path');
      break;
    }
  }
  if (opfPath == null) {
    throw const ParseException(FormatException('No package document'));
  }
  final opf = _loadXml(archive, opfPath);
  final root = opf?.documentElement;
  if (opf == null || root == null) {
    throw const ParseException(FormatException('Missing package document'));
  }
  final children = _Children(opf, opfNamespace);
  final manifestElement = children.one(root, 'manifest');
  final spineElement = children.one(root, 'spine');
  if (manifestElement == null || spineElement == null) {
    throw const ParseException(FormatException('Malformed package document'));
  }

  List<String>? splitList(String? value) => value?.split(RegExp(r'\s'));

  final manifest = [
    for (final item in children.all(manifestElement, 'item'))
      EpubManifestItem(
        href: resolveUrl(item.attrQualified('href'), opfPath),
        id: item.attrQualified('id'),
        mediaType: item.attrQualified('media-type'),
        properties: splitList(item.attrQualified('properties')),
        mediaOverlay: item.attrQualified('media-overlay'),
      ),
  ];
  final byId = <String?, EpubManifestItem>{};
  for (final item in manifest) {
    byId.putIfAbsent(item.id, () => item);
  }

  final itemrefs = children.all(spineElement, 'itemref');
  if (itemrefs.isEmpty) {
    throw const ParseException(FormatException('Empty spine'));
  }
  final spineParent = spineElement.parent!;
  final spineIndex = _cfiIndex(spineParent, spineElement);
  final spineBase = '/$spineIndex${_cfiId(spineElement)}';
  final spine = <EpubSpineItem>[
    for (var index = 0; index < itemrefs.length; index++)
      () {
        final itemref = itemrefs[index];
        final idref = itemref.attrQualified('idref');
        return EpubSpineItem(
          sectionIndex: index,
          idref: idref,
          id: itemref.attrQualified('id'),
          linear: itemref.attrQualified('linear'),
          properties: splitList(itemref.attrQualified('properties')),
          href: byId[idref]?.href,
          cfiBase:
              'epubcfi($spineBase/${_cfiIndex(spineElement, itemref)}${_cfiId(itemref)})',
        );
      }(),
  ];

  String? navPath;
  for (final item in manifest) {
    if (item.properties?.contains('nav') ?? false) {
      navPath = item.href;
      break;
    }
  }
  final tocId = spineElement.attrQualified('toc');
  String? ncxPath = byId[tocId]?.href;
  if (ncxPath == null) {
    for (final item in manifest) {
      if (item.mediaType == ncxMediaType) {
        ncxPath = item.href;
        break;
      }
    }
  }

  List<EpubTocItem>? toc;
  if (navPath != null) {
    try {
      toc = _parseNav(_loadXml(archive, navPath), navPath);
    } on Object catch (_) {
      toc = null;
    }
  }
  if (toc == null && ncxPath != null) {
    try {
      toc = _parseNcx(_loadXml(archive, ncxPath), ncxPath);
    } on Object catch (_) {
      toc = null;
    }
  }

  return EpubPackage(
    opfPath: opfPath,
    manifest: manifest,
    spine: spine,
    toc: toc,
    direction: spineElement.attrQualified('page-progression-direction'),
    rendition: _rendition(children, root),
    navPath: navPath,
    ncxPath: ncxPath,
  );
}

/// CFI step index of [child] among [parent]'s element children: even step
/// `2 * (position + 1)`, comments and processing instructions ignored.
int _cfiIndex(DomNode parent, DomNode child) {
  var position = 0;
  for (final element in parent.childElements) {
    if (identical(element, child)) return 2 * (position + 1);
    position++;
  }
  throw const ParseException(FormatException('Detached package element'));
}

String _cfiId(DomNode element) {
  final id = element.attr('id') ?? '';
  return id.isEmpty ? '' : '[${_escapeCfi(id)}]';
}

Map<String, String?> _rendition(_Children children, DomNode root) {
  final result = <String, String?>{};
  final metadata = children.one(root, 'metadata');
  if (metadata == null) return result;
  final prefixes = Map<String, String>.of(_reservedPrefixes);
  final declared = root.attrNs(epubNamespace, 'prefix') ?? root.attr('prefix');
  if (declared != null && declared.isNotEmpty) {
    for (final match in RegExp(r'(.+): +(.+)[ \t\r\n]*').allMatches(declared)) {
      prefixes[match.group(1)!] = match.group(2)!;
    }
  }
  for (final meta in children.all(metadata, 'meta')) {
    if (meta.attrQualified('name') != null) continue;
    if (meta.attrQualified('refines') != null) continue;
    final property = meta.attrQualified('property');
    if (property == null) continue;
    final parts = property.split(':');
    final prefix = parts.length > 1 ? parts[0] : null;
    final reference = parts.length > 1 ? parts[1] : parts[0];
    final base = prefixes[prefix];
    final resolved = base == null ? property : base + reference;
    if (!resolved.startsWith(_renditionPrefix)) continue;
    final key = _camel(resolved.substring(_renditionPrefix.length));
    result.putIfAbsent(key, () => _elementText(meta));
  }
  return result;
}

String _camel(String value) => value.toLowerCase().replaceAllMapped(
  RegExp(r'[-:](.)'),
  (match) => match.group(1)!.toUpperCase(),
);

String? _resolveNavHref(String? href, String base) =>
    href == null || href.isEmpty ? null : decodeUri(resolveUrl(href, base));

List<EpubTocItem>? _parseNav(DomNode? document, String navPath) {
  if (document == null) throw const FormatException('Missing navigation');
  final children = _Children(document, xhtmlNamespace);
  final root = document.documentElement!;

  List<EpubTocItem>? parseOl(DomNode? list) {
    if (list == null) return null;
    return [
      for (final item in children.all(list, 'li'))
        () {
          final anchor = children.one(item, 'a') ?? children.one(item, 'span');
          final href = _resolveNavHref(anchor?.attrQualified('href'), navPath);
          final text = _elementText(anchor);
          return EpubTocItem(
            label: text.isNotEmpty ? text : anchor?.attrQualified('title'),
            labelAbsent: text.isEmpty && anchor == null,
            href: href,
            subitems: parseOl(children.one(item, 'ol')),
          );
        }(),
    ];
  }

  List<EpubTocItem>? toc;
  for (final nav in children.deep(root, 'nav')) {
    final type =
        nav.attrNs(epubNamespace, 'type')?.split(RegExp(r'\s')) ?? const [];
    if (type.contains('toc')) toc ??= parseOl(children.one(nav, 'ol'));
  }
  return toc;
}

List<EpubTocItem>? _parseNcx(DomNode? document, String ncxPath) {
  if (document == null) throw const FormatException('Missing navigation');
  final children = _Children(document, ncxNamespace);
  final root = document.documentElement!;

  EpubTocItem parsePoint(DomNode element) {
    final label = children.one(element, 'navLabel');
    final content = children.one(element, 'content');
    if (content == null) throw const FormatException('Missing content');
    final points = children.all(element, 'navPoint');
    return EpubTocItem(
      label: _elementText(label),
      href: _resolveNavHref(content.attrQualified('src'), ncxPath),
      subitems: points.isEmpty ? null : points.map(parsePoint).toList(),
    );
  }

  final map = children.one(root, 'navMap');
  if (map == null) return null;
  return [for (final point in children.all(map, 'navPoint')) parsePoint(point)];
}
