import 'package:shiori/features/library/data/library_decode_exception.dart';

const maxSafeInteger = 9007199254740991;

int safeInteger(Object? value) {
  if (value is! num ||
      !value.isFinite ||
      value < -maxSafeInteger ||
      value > maxSafeInteger ||
      value != value.truncateToDouble()) {
    throw const LibraryDecodeException(LibraryInvariant.safeInteger);
  }
  return value.toInt();
}

int nonnegativeInteger(Object? value) {
  final result = safeInteger(value);
  if (result < 0) {
    throw const LibraryDecodeException(LibraryInvariant.safeInteger);
  }
  return result;
}

int positiveId(Object? value) {
  final result = safeInteger(value);
  if (result <= 0) {
    throw const LibraryDecodeException(LibraryInvariant.positiveId);
  }
  return result;
}

int? nullableId(Object? value) => value == null ? null : positiveId(value);
int? nullableCount(Object? value) => value == null ? null : positiveId(value);
int? nullableIndex(Object? value) => value == null ? null : safeInteger(value);
List<int> idList(Object? value) =>
    (value as List<Object?>).map(positiveId).toList();

double progressValue(Object? value) {
  if (value is! num || !value.isFinite || value < 0 || value > 1) {
    throw const LibraryDecodeException(LibraryInvariant.progress);
  }
  return value.toDouble();
}

double? nullableProgress(Object? value) =>
    value == null ? null : progressValue(value);

int snapshotSchemaVersion(Object? value) {
  final version = nonnegativeInteger(value);
  if (version != 1) {
    throw const LibraryDecodeException(LibraryInvariant.schemaVersion);
  }
  return version;
}
