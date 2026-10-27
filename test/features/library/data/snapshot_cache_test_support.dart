import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:shiori/core/config/server_key.dart';
import 'package:shiori/core/storage/stored_snapshot.dart';
import 'package:shiori/features/library/data/library_snapshot_cache.dart';

import '../../../core/network/fake_server_adapter.dart';
import 'library_test_support.dart';

StoredSnapshot storedFixture({
  String name = 'snapshot_typical.json',
  String? etag = 'W/"opaque exact"',
  int schema = 1,
  int? revision,
}) => StoredSnapshot(
  payload: fixture(name),
  schemaVersion: schema,
  revision: revision ?? (snapshot(payload(name))['version']! as num).toInt(),
  etag: etag,
  fetchedAt: DateTime.utc(2026, 10, 26),
);

ResponseBody responseFixture(String name) {
  final manifest = payload('manifest.json');
  final descriptor = (manifest['responses']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .singleWhere((entry) => entry['name'] == name);
  final headers = (descriptor['headers']! as Map<String, Object?>).map(
    (key, value) => MapEntry(key, [value! as String]),
  );
  return ResponseBody.fromString(
    descriptor['bodyFile'] == null
        ? ''
        : fixture(descriptor['bodyFile']! as String),
    descriptor['status']! as int,
    headers: headers,
  );
}

final class MemorySnapshotCache implements LibrarySnapshotCache {
  final values = <ServerKey, StoredSnapshot>{};
  int reads = 0;
  int writes = 0;
  Object? readError;
  Object? writeError;
  Future<void> Function()? beforeWrite;

  @override
  Future<StoredSnapshot?> read(ServerKey key) async {
    reads++;
    if (readError != null) throw readError!;
    return values[key];
  }

  @override
  Future<void> replace(
    ServerKey key,
    StoredSnapshot snapshot, {
    required void Function() checkActive,
  }) async {
    await beforeWrite?.call();
    checkActive();
    if (writeError != null) throw writeError!;
    writes++;
    values[key] = snapshot;
  }
}

ResponseBody snapshotRevision(int revision) {
  final body = payload('snapshot_empty.json');
  snapshot(body)['version'] = revision;
  return jsonBody(jsonEncode(body), 200, {
    'etag': ['"$revision"'],
  });
}
