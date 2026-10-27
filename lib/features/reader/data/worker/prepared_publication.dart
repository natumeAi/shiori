import 'package:shiori/core/config/content_identity.dart';
import 'package:shiori/features/reader/data/worker/publication_layout_facts.dart';
import 'package:shiori/features/reader/data/worker/publication_snapshot.dart';

/// Detached import result. No source loader, archive, callback or file handle.
final class PreparedPublication {
  const PreparedPublication({
    required this.identity,
    required this.snapshot,
    required this.metadata,
    required this.layoutFacts,
    required this.firstSection,
  });
  final ContentIdentity identity;
  final PublicationSnapshot snapshot;
  final PublicationMetadata metadata;
  final PublicationLayoutFacts layoutFacts;
  final FirstSectionReadiness firstSection;
}

final class PublicationMetadata {
  PublicationMetadata({
    required List<String> titles,
    required List<String> creators,
    required List<String> languages,
    required List<String> identifiers,
  }) : titles = List.unmodifiable(titles),
       creators = List.unmodifiable(creators),
       languages = List.unmodifiable(languages),
       identifiers = List.unmodifiable(identifiers);
  final List<String> titles;
  final List<String> creators;
  final List<String> languages;
  final List<String> identifiers;
}

final class FirstSectionReadiness {
  FirstSectionReadiness({
    required this.sectionIndex,
    required this.href,
    required this.cfiBase,
    required this.parserUsed,
    required this.parserErrorClass,
    required this.canonicalVersion,
    required this.canonicalLength,
    required this.canonicalSignature,
    required List<PublicationResourceReference> resources,
  }) : resources = List.unmodifiable(resources);
  final int sectionIndex;
  final String href;
  final String cfiBase;
  final String parserUsed;
  final String? parserErrorClass;
  final int canonicalVersion;
  final int canonicalLength;
  final String canonicalSignature;
  final List<PublicationResourceReference> resources;
}

final class PublicationResourceReference {
  const PublicationResourceReference({
    required this.sourcePath,
    required this.url,
    required this.path,
    required this.mediaType,
    required this.present,
  });
  final String sourcePath;
  final String url;

  /// Null for external/data/fragment-only references; never fetched remotely.
  final String? path;
  final String? mediaType;
  final bool present;
}
