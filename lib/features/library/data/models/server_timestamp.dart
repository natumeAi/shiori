import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:shiori/features/library/data/library_decode_exception.dart';

/// Server wire value plus an explicit UTC instant; never device-local time.
final class ServerTimestamp {
  const ServerTimestamp._(this.raw, this.utc);
  final String raw;
  final DateTime utc;

  static final _pattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[ T](\d{2}):(\d{2}):(\d{2})(\.\d{1,6})?(Z|[+-]\d{2}:\d{2})?$',
  );

  factory ServerTimestamp.parse(String raw) {
    final match = _pattern.firstMatch(raw);
    if (match == null ||
        (match[8] == null && (raw[10] != ' ' || match[7] != null))) {
      throw const LibraryDecodeException(LibraryInvariant.timestamp);
    }
    final parts = [for (var i = 1; i <= 6; i++) int.parse(match[i]!)];
    final calendar = DateTime.utc(parts[0], parts[1], parts[2]);
    if (calendar.year != parts[0] ||
        calendar.month != parts[1] ||
        calendar.day != parts[2] ||
        parts[3] > 23 ||
        parts[4] > 59 ||
        parts[5] > 59) {
      throw const LibraryDecodeException(LibraryInvariant.timestamp);
    }
    final offset = match[8];
    if (offset != null &&
        offset != 'Z' &&
        (int.parse(offset.substring(1, 3)) > 23 ||
            int.parse(offset.substring(4)) > 59)) {
      throw const LibraryDecodeException(LibraryInvariant.timestamp);
    }
    return ServerTimestamp._(
      raw,
      DateTime.parse(offset == null ? '${raw}Z' : raw).toUtc(),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ServerTimestamp && raw == other.raw && utc == other.utc;
  @override
  int get hashCode => Object.hash(raw, utc);
}

class ServerTimestampConverter
    implements JsonConverter<ServerTimestamp, String> {
  const ServerTimestampConverter();
  @override
  ServerTimestamp fromJson(String json) => ServerTimestamp.parse(json);
  @override
  String toJson(ServerTimestamp object) => object.raw;
}
