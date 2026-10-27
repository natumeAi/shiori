import 'package:freezed_annotation/freezed_annotation.dart';

enum LibraryInvariant {
  shape,
  requiredField,
  schemaVersion,
  positiveId,
  safeInteger,
  progress,
  timestamp,
  shelfType,
  duplicateBookId,
  duplicateFolderId,
  folderBook,
  folderOwnership,
  folderCount,
  folderPreview,
  folderOrder,
  shelfRecord,
  shelfOwnership,
  shelfDuplicate,
  shelfOrder,
  recentBook,
  recentDuplicate,
  chapterProgress,
  detailIdentity,
  revisionHeader,
  etagHeader,
}

/// Fixed invariant names only: no JSON values, titles, paths or parsing causes.
final class LibraryDecodeException implements Exception {
  const LibraryDecodeException(this.invariant);
  final LibraryInvariant invariant;
  bool get incompatible => invariant == LibraryInvariant.schemaVersion;
}

T decodeLibraryValue<T>(T Function() decode) {
  try {
    return decode();
  } on CheckedFromJsonException catch (error) {
    Object? cause = error;
    while (cause is CheckedFromJsonException) {
      cause = cause.innerError;
    }
    if (cause is LibraryDecodeException) throw cause;
    throw LibraryDecodeException(
      cause is MissingRequiredKeysException
          ? LibraryInvariant.requiredField
          : LibraryInvariant.shape,
    );
  } on FormatException {
    throw const LibraryDecodeException(LibraryInvariant.shape);
  } on TypeError {
    throw const LibraryDecodeException(LibraryInvariant.shape);
  }
}
