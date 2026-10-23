import 'dart:convert';
import 'dart:typed_data';

import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/canonical/fnv1a64.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/epub/epub_package.dart';
import 'package:shiori/features/reader/data/epub/epub_url.dart';
import 'package:shiori/features/reader/data/source/dom_node.dart';
import 'package:shiori/features/reader/data/source/dom_serializer.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';

/// Shape of the stand-in for a reference Blob URL embedded in rewritten
/// stylesheet text. The reference puts a random `blob:` URL (fixed length for
/// one origin) into `<style>` text; the token keeps that length so UTF-16
/// offsets of head text match, and its ordinal identifies the referenced
/// resource group (sorted alias sets of byte-identical resources).
final class ResourceTokenScheme {
  const ResourceTokenScheme({
    this.prefix = 'shiori-resource:',
    this.urlLength = 64,
  });

  final String prefix;
  final int urlLength;

  String token(int ordinal) {
    final text = '$prefix${ordinal.toString().padLeft(4, '0')}';
    if (text.length > urlLength) {
      throw StateError('Resource token longer than the reference URL length');
    }
    return text.padRight(urlLength, '_');
  }
}

final _scriptType = RegExp(r'/(x-)?(javascript|ecmascript)');
final _cssUrl = RegExp(
  r'''url\(\s*["']?([^'"\n]*?)\s*["']?\s*\)''',
  caseSensitive: false,
);
final _cssImport = RegExp(
  r'''@import\s*["']([^"'\n]*?)["']''',
  caseSensitive: false,
);
final _processingHref = RegExp(
  r'''(?:^|\s*)(href\s*=\s*['"])([^'"]*)(['"])''',
  caseSensitive: false,
);
final _srcset = RegExp(r'(\s*)(.+?)\s*((?:\s[\d.]+[wx])+\s*(?:,|$)|,\s+|$)');

/// Resource graph discovered by loading every spine section, as the oracle
/// does, so token ordinals match the reference alias grouping.
final class EpubResourceGraph {
  EpubResourceGraph._(this._ordinals);

  final Map<String, int> _ordinals;

  /// Ordinal of the resource group behind [href], or null if never loaded.
  int? ordinalOf(String href) => _ordinals[href];
}

/// Re-implementation of the foliate-js `Loader` resource rewriting, enough to
/// reproduce the text that reaches `protectBookDocument` for each section.
/// Attribute URLs are left as written in the package; only `<style>` text
/// carries (length-neutral) resource tokens, and loads are performed for
/// every reference so the loaded set matches the reference.
final class EpubSectionLoader {
  EpubSectionLoader(
    this._archive,
    this._package, {
    this.tokens = const ResourceTokenScheme(),
  });

  final EpubArchive _archive;
  final EpubPackage _package;
  final ResourceTokenScheme tokens;
  EpubResourceGraph? _graph;

  /// Discovers (once) which resources the reference would load.
  EpubResourceGraph get graph => _graph ??= _discover();

  /// Parses and rewrites one spine section into its final source document.
  ProjectedSection project(EpubManifestItem item) {
    final text = _archive.text(item.href);
    if (text == null || text.isEmpty) {
      throw const ParseException(FormatException('Empty section resource'));
    }
    final run = _Run(_archive, _package, (href) {
      final ordinal = graph.ordinalOf(href);
      return tokens.token(ordinal ?? 0);
    });
    final document = const SourceParser().parse(
      text,
      mediaType: item.mediaType ?? xhtmlMediaType,
      transform: (tree, effectiveType) =>
          run.rewrite(tree, effectiveType, item.href, const []),
    );
    return ProjectedSection(document: document, rawText: text);
  }

  EpubResourceGraph _discover() {
    final run = _Run(_archive, _package, (href) => '<$href>');
    for (final spine in _package.spine) {
      final item = _package.itemById(spine.idref);
      if (item == null) continue;
      run.loadItem(item, const []);
    }
    return EpubResourceGraph._(run.ordinals());
  }
}

final class ProjectedSection {
  const ProjectedSection({required this.document, required this.rawText});

  final SourceDocument document;
  final String rawText;
}

/// One loader instance: its cache persists across sections, like a reference
/// `Loader`.
final class _Run {
  _Run(this._archive, this._package, this._urlFor);

  final EpubArchive _archive;
  final EpubPackage _package;
  final String Function(String href) _urlFor;
  final Set<String> _cache = {};
  final List<(String href, String key)> _records = [];

  Map<String, int> ordinals() {
    ReaderWorkGuard.check(ReaderWork.jsonSerialization);
    final groups = <String, Set<String>>{};
    final latest = <String, String>{};
    for (final (href, key) in _records) {
      groups.putIfAbsent(key, () => {}).add(href);
      latest[href] = key;
    }
    final encoded = <String, String>{
      for (final entry in groups.entries)
        entry.key: jsonEncode((entry.value.toList()..sort())),
    };
    final ordered = encoded.values.toSet().toList()..sort();
    return {
      for (final entry in latest.entries)
        entry.key: ordered.indexOf(encoded[entry.value]!),
    };
  }

  static String _digest(Uint8List bytes) {
    final plain = Fnv1a64();
    final salted = Fnv1a64()..byte(0xff);
    for (final value in bytes) {
      plain.byte(value);
      salted.byte(value);
    }
    return '${bytes.length}:${plain.hex()}:${salted.hex()}';
  }

  static String _textDigest(String text) =>
      _digest(Uint8List.fromList(utf8.encode(text)));

  String? loadItem(EpubManifestItem item, List<String> parents) {
    final href = item.href;
    final mediaType = item.mediaType;
    if (mediaType != null && _scriptType.hasMatch(mediaType)) return null;
    if (_cache.contains(href)) return _urlFor(href);
    final replaced =
        const {
          xhtmlMediaType,
          htmlMediaType,
          'text/css',
          svgMediaType,
        }.contains(mediaType) &&
        parents.every((parent) => parent != href);
    if (replaced) return _loadReplaced(item, parents);
    final bytes = _archive.bytes(href);
    _cache.add(href);
    _records.add((
      href,
      'b:${_digest(bytes ?? Uint8List.fromList(utf8.encode('null')))}',
    ));
    return _urlFor(href);
  }

  String? _loadReplaced(EpubManifestItem item, List<String> parents) {
    final href = item.href;
    final text = _archive.text(href);
    if (text == null || text.isEmpty) return null;
    final String result;
    if (item.mediaType == 'text/css') {
      result = _replaceCss(text, href, parents);
    } else {
      final ParsedSection parsed;
      try {
        parsed = SourceParser.parseTree(text, item.mediaType!);
      } on Object catch (_) {
        // A resource the reference could not parse fails its own load; the
        // referencing document still sees the original URL.
        return null;
      }
      rewrite(parsed.tree, parsed.effectiveType, href, parents);
      result = serializeXml(parsed.tree);
    }
    if (result.isEmpty) return '';
    _cache.add(href);
    _records.add((href, 'r:${_textDigest(result)}'));
    return _urlFor(href);
  }

  String? _loadHref(String? value, String base, List<String> parents) {
    if (isExternalUrl(value)) return value;
    final path = resolveUrl(value, base);
    final item = _package.itemByHref(path);
    if (item == null) return value;
    return loadItem(item, [...parents, base]);
  }

  String _replaceCss(String text, String href, List<String> parents) {
    final replacedUrls = text.replaceAllMapped(
      _cssUrl,
      (match) => 'url("${_loadHref(match[1], href, parents)}")',
    );
    return replacedUrls.replaceAllMapped(
      _cssImport,
      (match) => '@import "${_loadHref(match[1], href, parents)}"',
    );
  }

  /// Applies the loader's document rewrite to [tree]: loads every referenced
  /// resource and replaces `<style>` text (element text becomes one Text
  /// node holding the rewritten stylesheet).
  void rewrite(
    DomNode tree,
    String effectiveType,
    String href,
    List<String> parents,
  ) {
    if (effectiveType == xhtmlMediaType || effectiveType == svgMediaType) {
      for (final child in tree.children) {
        if (child.kind != DomKind.pi) break;
        final data = child.data ?? '';
        if (data.isEmpty) continue;
        final match = _processingHref.firstMatch(data);
        if (match != null) _loadHref(match[2], href, parents);
        // The reference replaces the node and then follows the detached
        // node's (null) next sibling, so only the first non-empty one runs.
        break;
      }
    }
    final elements = _queryableElements(tree);
    void load(String? value) => _loadHref(value, href, parents);
    for (final element in elements) {
      if (element.localName == 'link' && element.attr('href') != null) {
        load(element.attr('href'));
      }
    }
    for (final element in elements) {
      final value = element.attr('src');
      if (value != null) load(value);
    }
    for (final element in elements) {
      final value = element.attr('poster');
      if (value != null) load(value);
    }
    for (final element in elements) {
      if (element.localName == 'object' && element.attr('data') != null) {
        load(element.attr('data'));
      }
    }
    for (final element in elements) {
      final hasNamespacedHref = element.attributes.any(
        (attribute) => attribute.localName == 'href',
      );
      if (hasNamespacedHref && element.attr('href') == null) {
        final value = element.attrNs(xlinkNamespace, 'href');
        if (value != null) load(value);
      }
    }
    for (final element in elements) {
      final value = element.attr('srcset');
      if (value == null) continue;
      for (final match in _srcset.allMatches(value)) {
        load(match[2]);
      }
    }
    for (final element in elements) {
      if (element.localName != 'style') continue;
      final text = element.textContent;
      if (text.isEmpty) continue;
      final replaced = _replaceCss(text, href, parents);
      element.replaceChildren([DomNode(DomKind.text, data: replaced)]);
    }
    for (final element in elements) {
      final value = element.attr('style');
      if (value != null) _replaceCss(value, href, parents);
    }
  }
}

/// Document-order elements visible to `querySelectorAll`: template contents
/// live in a separate fragment and are not searched.
List<DomNode> _queryableElements(DomNode tree) {
  final result = <DomNode>[];
  void walk(DomNode node) {
    for (final child in node.children) {
      if (!child.isElement) continue;
      result.add(child);
      if (child.localName == 'template' &&
          child.namespaceUri == xhtmlNamespace) {
        continue;
      }
      walk(child);
    }
  }

  walk(tree);
  return result;
}
