import 'package:shiori/core/config/server_key.dart';

/// Local metadata; timestamps are stored as UTC microseconds since epoch.
final class ServerRecord {
  const ServerRecord({
    required this.key,
    required this.createdAt,
    required this.lastUsedAt,
  });

  final ServerKey key;
  final DateTime createdAt;
  final DateTime lastUsedAt;
}
