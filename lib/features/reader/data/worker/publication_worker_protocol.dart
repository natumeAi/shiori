import 'dart:isolate';

import 'package:shiori/features/reader/data/source/source_document.dart';
import 'package:shiori/features/reader/data/worker/publication_snapshot.dart';
import 'package:shiori/features/reader/data/worker/publication_tag.dart';

/// The generation also distinguishes reopens with an identical caller tag.
sealed class PublicationRequest {
  const PublicationRequest(this.id, this.tag, this.generation);

  final int id;
  final PublicationTag tag;
  final int generation;
}

final class OpenPublication extends PublicationRequest {
  const OpenPublication(super.id, super.tag, super.generation, this.path);
  final String path;
}

final class LoadPublicationSection extends PublicationRequest {
  const LoadPublicationSection(
    super.id,
    super.tag,
    super.generation,
    this.index,
  );
  final int index;
}

final class ReadPublicationResource extends PublicationRequest {
  const ReadPublicationResource(
    super.id,
    super.tag,
    super.generation,
    this.path,
  );
  final String path;
}

final class ClosePublication extends PublicationRequest {
  const ClosePublication(super.id, super.tag, super.generation);
}

sealed class PublicationResponse {
  const PublicationResponse(this.id, this.tag, this.generation);
  final int id;
  final PublicationTag tag;
  final int generation;
}

final class PublicationOpened extends PublicationResponse {
  const PublicationOpened(super.id, super.tag, super.generation, this.snapshot);
  final PublicationSnapshot snapshot;
}

final class PublicationSectionLoaded extends PublicationResponse {
  const PublicationSectionLoaded(
    super.id,
    super.tag,
    super.generation,
    this.document,
  );
  final SourceDocument document;
}

final class PublicationResourceRead extends PublicationResponse {
  const PublicationResourceRead(
    super.id,
    super.tag,
    super.generation,
    this.bytes,
    this.length,
  );

  /// Null means an absent resource; a present zero-byte entry is not absent.
  final TransferableTypedData? bytes;
  final int length;
}

final class PublicationClosed extends PublicationResponse {
  const PublicationClosed(super.id, super.tag, super.generation);
}

final class PublicationFailed extends PublicationResponse {
  const PublicationFailed(super.id, super.tag, super.generation, this.error);
  final Exception error;
}
