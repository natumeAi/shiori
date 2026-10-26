import 'package:shiori/features/reader/data/epub/epub_package.dart';

/// Detached, deeply immutable package metadata. Contains no archive or loader.
final class PublicationSnapshot {
  PublicationSnapshot(EpubPackage package) : package = _freezePackage(package) {
    sections = List.unmodifiable([
      for (final spine in this.package.spine)
        if (this.package.itemById(spine.idref) case final item?)
          PublicationSectionSnapshot(spine: spine, item: item),
    ]);
  }

  final EpubPackage package;
  late final List<PublicationSectionSnapshot> sections;
}

final class PublicationSectionSnapshot {
  const PublicationSectionSnapshot({required this.spine, required this.item});

  final EpubSpineItem spine;
  final EpubManifestItem item;
}

List<String>? _strings(List<String>? values) =>
    values == null ? null : List.unmodifiable(values);

EpubPackage _freezePackage(EpubPackage package) => EpubPackage(
  opfPath: package.opfPath,
  manifest: List.unmodifiable([
    for (final item in package.manifest)
      EpubManifestItem(
        href: item.href,
        id: item.id,
        mediaType: item.mediaType,
        properties: _strings(item.properties),
        mediaOverlay: item.mediaOverlay,
      ),
  ]),
  spine: List.unmodifiable([
    for (final item in package.spine)
      EpubSpineItem(
        sectionIndex: item.sectionIndex,
        idref: item.idref,
        id: item.id,
        linear: item.linear,
        properties: _strings(item.properties),
        href: item.href,
        cfiBase: item.cfiBase,
      ),
  ]),
  toc: _freezeToc(package.toc),
  direction: package.direction,
  rendition: Map.unmodifiable(package.rendition),
  navPath: package.navPath,
  ncxPath: package.ncxPath,
);

List<EpubTocItem>? _freezeToc(List<EpubTocItem>? items) => items == null
    ? null
    : List.unmodifiable([
        for (final item in items)
          EpubTocItem(
            href: item.href,
            label: item.label,
            labelAbsent: item.labelAbsent,
            hasSubitemsKey: item.hasSubitemsKey,
            subitems: _freezeToc(item.subitems),
          ),
      ]);
