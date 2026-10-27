import 'dart:typed_data';

import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/canonical/canonical_text.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/epub/epub_loader.dart';
import 'package:shiori/features/reader/data/epub/epub_package.dart';
import 'package:shiori/features/reader/data/source/source_document.dart';

/// A spine entry that has a manifest item (the reference drops the rest).
final class EpubSection {
  const EpubSection({required this.spine, required this.item});

  final EpubSpineItem spine;
  final EpubManifestItem item;
}

/// An opened EPUB: archive with limits, package, spine sections and the
/// reference loader projection. Pure Dart; safe to use inside an isolate.
final class EpubBook {
  EpubBook._(this.archive, this.package, this.sections, this._loader);

  factory EpubBook.open(
    Uint8List bytes, {
    EpubLimits limits = const EpubLimits(),
    ResourceTokenScheme tokens = const ResourceTokenScheme(),
  }) {
    final archive = EpubArchive.open(bytes, limits: limits);
    final package = readEpubPackage(archive);
    return EpubBook.fromArchive(archive, package, tokens: tokens);
  }

  /// Uses an already validated archive without copying its compressed bytes.
  /// The caller retains ownership and must close the archive, including when
  /// package/source preparation fails. This object stays inside the worker.
  factory EpubBook.fromArchive(
    EpubArchive archive,
    EpubPackage package, {
    ResourceTokenScheme tokens = const ResourceTokenScheme(),
  }) {
    final sections = <EpubSection>[
      for (final spine in package.spine)
        if (package.itemById(spine.idref) case final item?)
          EpubSection(spine: spine, item: item),
    ];
    if (sections.isEmpty) {
      throw const ParseException(FormatException('No readable sections'));
    }
    return EpubBook._(
      archive,
      package,
      sections,
      EpubSectionLoader(archive, package, tokens: tokens),
    );
  }

  final EpubArchive archive;
  final EpubPackage package;
  final List<EpubSection> sections;
  final EpubSectionLoader _loader;

  /// Final projected document of section [index] (index into [sections]).
  SourceDocument loadSection(int index) =>
      _loader.project(sections[index].item).document;

  /// Canonical text index of a projected section.
  CanonicalIndex canonicalIndex(SourceDocument document) =>
      CanonicalIndex.build(document);
}
