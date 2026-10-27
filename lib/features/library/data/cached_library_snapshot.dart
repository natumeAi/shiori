import 'dart:convert';

import 'package:shiori/core/network/transport_response.dart';
import 'package:shiori/core/storage/stored_snapshot.dart';
import 'package:shiori/features/library/data/library_decode_exception.dart';
import 'package:shiori/features/library/data/library_index.dart';

/// Validated payload and its immutable joins; metadata never substitutes for decode.
final class CachedLibrarySnapshot {
  const CachedLibrarySnapshot(this.stored, this.index);

  final StoredSnapshot stored;
  final LibraryIndex index;

  static CachedLibrarySnapshot? restore(StoredSnapshot? stored) {
    if (stored == null || stored.schemaVersion != 1) return null;
    try {
      final snapshot = decodeSnapshot(jsonDecode(stored.payload));
      final index = LibraryIndex.fromSnapshot(snapshot);
      if (snapshot.schemaVersion != stored.schemaVersion ||
          snapshot.version != stored.revision) {
        return null;
      }
      return CachedLibrarySnapshot(stored, index);
    } on FormatException {
      return null;
    } on LibraryDecodeException {
      return null;
    }
  }

  factory CachedLibrarySnapshot.fromResponse(
    TransportResponse<Object?> response,
    DateTime fetchedAt,
  ) {
    final snapshot = decodeSnapshot(response.body);
    final index = LibraryIndex.fromSnapshot(snapshot);
    final text = response.rawJsonText;
    if (response.statusCode != 200 || text == null) {
      throw const LibraryDecodeException(LibraryInvariant.shape);
    }
    final etag = _header(response.headers, 'etag', LibraryInvariant.etagHeader);
    final revision = _header(
      response.headers,
      'x-library-revision',
      LibraryInvariant.revisionHeader,
    );
    if (revision != null &&
        (!RegExp(r'^\d+$').hasMatch(revision) ||
            int.tryParse(revision) != snapshot.version)) {
      throw const LibraryDecodeException(LibraryInvariant.revisionHeader);
    }
    return CachedLibrarySnapshot(
      StoredSnapshot(
        payload: text,
        schemaVersion: snapshot.schemaVersion,
        revision: snapshot.version,
        etag: etag,
        fetchedAt: fetchedAt.toUtc(),
      ),
      index,
    );
  }
}

String? _header(
  Map<String, List<String>> headers,
  String name,
  LibraryInvariant invariant,
) {
  final entries = headers.entries.where((e) => e.key.toLowerCase() == name);
  if (entries.isEmpty) return null;
  final values = entries.expand((e) => e.value).toList();
  if (values.length != 1) throw LibraryDecodeException(invariant);
  return values.single;
}
