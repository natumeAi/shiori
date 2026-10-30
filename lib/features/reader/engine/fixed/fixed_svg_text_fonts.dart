import 'dart:typed_data';
import 'dart:convert';

import 'package:csslib/visitor.dart';
import 'package:shiori/features/reader/data/epub/epub_url.dart';
import 'package:shiori/features/reader/data/layout/authored_dimension_resolver.dart';
import 'package:shiori/features/reader/data/layout/authored_page_size.dart';
import 'package:shiori/features/reader/data/layout/section_source_facts.dart';
import 'package:shiori/features/reader/data/source/source_parser.dart';

import 'package:shiori/features/reader/engine/fixed/fixed_source_lease.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_graphics.dart';
import 'package:shiori/features/reader/engine/fixed/svg/svg_presentation.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/woff2_decoder.dart';
import 'package:shiori/features/reader/engine/layout/woff_decoder.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/css_stylesheet.dart';
import 'package:shiori/features/reader/engine/text/harfbuzz/harfbuzz.dart';

/// Section-bound resources outlive the scene; physical registration belongs to
/// FontRegistry and the preparation operation's existing drain barrier.
final class FixedSvgTextFontService implements SvgTextFontService {
  FixedSvgTextFontService(this.source, this.registry);
  final FixedSourceLease source;
  final FontRegistry registry;
  late final SvgPresentation presentation = _presentation();
  int liveLeases = 0;
  @override
  bool get available => true;

  Map<String, String> inheritedStyle(int index) {
    final style = source.styles.styleOf(index)!;
    return {
      'font-family': style.fontFamilies.join(','),
      'font-size': '${style.fontSize}',
      'font-weight': '${style.fontWeight}',
      'font-style': style.fontStyle == StyleFontStyle.normal
          ? 'normal'
          : 'italic',
      'writing-mode': style.writingMode == StyleWritingMode.horizontalTb
          ? 'horizontal-tb'
          : 'vertical-rl',
      'direction': style.direction == StyleDirection.ltr ? 'ltr' : 'rtl',
    };
  }

  SvgPresentation _presentation() {
    final dimensions = resolveAuthoredDimensions(
      source: extractSectionSourceFacts(source.document),
      packageRendition: source.rendition.effective,
    );
    if (dimensions is! ResolvedDimensions) {
      throw const SvgFeatureRefusal(0, 'svg-text-css-viewport');
    }
    final media = CssSheetBuilder(
      viewportWidth: dimensions.size.width,
      viewportHeight: dimensions.size.height,
    );
    String pathOf(String href, String base) =>
        resolveUrl(href, base).split('#').first;
    final sheets = <String>[];
    void collect(String text, String base, Set<String> active) {
      if (active.length > 4) {
        throw const SvgFeatureRefusal(0, 'svg-text-css-depth');
      }
      final sheet = SvgPresentation.parseStylesheet(text);
      for (final top in sheet.topLevels) {
        if (top is ImportDirective) {
          final queries = top.mediaQueries
              .map((query) {
                final printer = CssPrinter();
                query.visit(printer);
                return printer.toString();
              })
              .join(', ');
          if (!media.matchesMediaAttribute(queries)) continue;
          var href = top.import;
          if (href.startsWith('"') || href.startsWith("'")) {
            href = href.substring(1, href.length - 1);
          }
          if (isExternalUrl(href)) continue;
          final path = pathOf(href, base);
          if (active.contains(path)) {
            throw const SvgFeatureRefusal(0, 'svg-text-css-cycle');
          }
          final bytes = source.resources.bytes(path);
          if (bytes == null) {
            throw const SvgFeatureRefusal(0, 'svg-text-css-resource');
          }
          collect(utf8.decode(bytes), path, {...active, path});
        } else {
          final printer = CssPrinter();
          top.visit(printer);
          sheets.add(printer.toString());
        }
      }
    }

    // The loader replaces inline @import URLs with length-neutral resource
    // tokens. Recover authored style text by ordinal, as CssStyleResolver does.
    final styleCount = source.document.nodes
        .where((node) => node.localName == 'style')
        .length;
    List<String>? recoverOriginalStyles() {
      if (styleCount == 0) return null;
      try {
        final raw = source.resources.bytes(source.page.stableId);
        if (raw != null) {
          final original = const SourceParser().parse(
            utf8.decode(raw, allowMalformed: true),
            mediaType: source.document.originalMediaType ?? xhtmlMediaType,
            protect: false,
          );
          final styles = [
            for (final node in original.nodes)
              if (node.localName == 'style')
                node.children.map((i) => original.node(i).text ?? '').join(),
          ];
          return styles.length == styleCount ? styles : null;
        }
      } on Object {
        // Synthetic/injected sources may have no matching archive document.
        // Use their supplied style text, just as CssStyleResolver does.
      }
      return null;
    }

    late final originalStyles = recoverOriginalStyles();
    var styleOrdinal = 0;
    for (final node in source.document.nodes) {
      if (node.localName == 'style') {
        final ordinal = styleOrdinal++;
        final type = node.attribute('type')?.trim().toLowerCase();
        if (type != null && type.isNotEmpty && type != 'text/css') continue;
        if (!media.matchesMediaAttribute(node.attribute('media'))) continue;
        final projected = node.children
            .map((i) => source.document.node(i).text ?? '')
            .join();
        // Font-face URLs do not participate in this presentation cascade. Only
        // imports need authored URLs recovered from the archive; ordinary rules
        // can be admitted/refused using the already loaded projected section.
        final hasImport = SvgPresentation.parseStylesheet(projected).topLevels
            .any((top) => top is ImportDirective);
        final text = hasImport
            ? (originalStyles?[ordinal] ?? projected)
            : projected;
        collect(text, source.page.stableId, {});
      } else if (node.localName == 'link') {
        final type = node.attribute('type')?.trim().toLowerCase();
        if (type != null && type.isNotEmpty && type != 'text/css') continue;
        final rel = node.attribute('rel')?.toLowerCase().split(RegExp(r'\s+'));
        final href = node.attribute('href');
        if (rel == null || !rel.contains('stylesheet') || href == null) {
          continue;
        }
        if (rel.contains('alternate') || isExternalUrl(href)) continue;
        if (!media.matchesMediaAttribute(node.attribute('media'))) continue;
        final path = pathOf(href, source.page.stableId);
        final bytes = source.resources.bytes(path);
        if (bytes == null) {
          throw SvgFeatureRefusal(node.index, 'svg-text-css-resource');
        }
        collect(utf8.decode(bytes), path, {path});
      }
    }
    return SvgPresentation.resolve(
      source.document,
      sheets,
      viewportWidth: dimensions.size.width,
      viewportHeight: dimensions.size.height,
    );
  }

  @override
  Future<FixedSvgTextFontLease> acquire(SvgTextFontRequest request) async {
    source.requireLive();
    if (!identical(request.document, source.document)) {
      throw const RequiredFontException('svg-text-font-document');
    }
    final assets = <SvgTextFontAsset>[];
    final admitted = <SvgTextFontAsset, HarfBuzzAdmittedFont>{};
    final conversions = <ConvertedFont>[];
    try {
      for (final face in source.styles.fontFaces) {
        if (!request.families.contains(face.family.toLowerCase())) continue;
        final identity = registry.admittedIdentity(
          source.page.content.sha256,
          face,
        );
        var bytes = source.resources.bytes(face.archivePath);
        if (bytes == null) {
          throw const RequiredFontException('svg-text-font-missing');
        }
        if (bytes.length > registry.maxFontBytes) {
          throw const RequiredFontException('svg-text-font-limit');
        }
        final tag = bytes.length < 4
            ? 0
            : ByteData.sublistView(bytes).getUint32(0);
        if (tag == 0x774f4632 || tag == 0x774f4646) {
          final converted = tag == 0x774f4632
              ? Woff2Decoder(maxBytes: registry.maxFontBytes)
                    .decode(bytes, budget: registry.conversionBudget)
              : WoffDecoder(maxBytes: registry.maxFontBytes)
                    .decode(bytes, budget: registry.conversionBudget);
          conversions.add(converted);
          bytes = converted.bytes;
        }
        final token = await HarfBuzzAdmittedFont.load(
          bytes.asUnmodifiableView(),
          faceDescriptor: identity.descriptor,
          processFonts: registry.processBudget,
          faceIndex: identity.faceIndex,
          // A successful record must already have registered these exact bytes.
          // A changed resource cannot create an unregistered process entry.
          register: (_, _) async {
            throw const RequiredFontException('svg-text-font-identity');
          },
        );
        if (token.alias != identity.alias) {
          throw const RequiredFontException('svg-text-font-identity');
        }
        final asset = SvgTextFontAsset(
          family: face.family.toLowerCase(),
          bytes: ByteData.sublistView(token.bytes).asUnmodifiableView(),
          faceIndex: identity.faceIndex,
          weight: face.weight,
          italic: face.style != StyleFontStyle.normal,
        );
        assets.add(asset);
        admitted[asset] = token;
      }
      if (assets.isEmpty) {
        throw const RequiredFontException('svg-text-font-unadmitted');
      }
      liveLeases++;
      return FixedSvgTextFontLease(
        assets,
        admitted,
        () {
          for (final converted in conversions.reversed) {
            converted.dispose();
          }
          liveLeases--;
        },
        selectFace: (families, weight, italic) {
          final selected = registry.selectFace(
            families,
            scope: source.page.content.sha256,
            faces: source.styles.fontFaces,
            weight: weight,
            style: italic ? StyleFontStyle.italic : StyleFontStyle.normal,
          );
          for (final entry in admitted.entries) {
            if (entry.value.alias == selected.primary) return entry.key;
          }
          throw const RequiredFontException('svg-text-font-unadmitted');
        },
      );
    } catch (_) {
      for (final converted in conversions.reversed) {
        converted.dispose();
      }
      rethrow;
    }
  }
}

/// Adds already coalesced HarfBuzz tokens to the host's byte lease. The token
/// carries the actual process owner; the text feature never assumes a global.
final class FixedSvgTextFontLease implements SvgTextFontLease {
  FixedSvgTextFontLease(
    List<SvgTextFontAsset> fonts,
    Map<SvgTextFontAsset, HarfBuzzAdmittedFont> admitted,
    this._release, {
    required this.selectFace,
  }) : fonts = List.unmodifiable(fonts),
       admitted = Map.unmodifiable(admitted);
  @override
  final List<SvgTextFontAsset> fonts;
  final Map<SvgTextFontAsset, HarfBuzzAdmittedFont> admitted;
  final SvgTextFontAsset Function(List<String>, int, bool) selectFace;
  void Function()? _release;
  @override
  int get bytes => fonts.fold(0, (sum, font) => sum + font.bytes.lengthInBytes);
  @override
  void release() {
    final action = _release;
    _release = null;
    action?.call();
  }
}
