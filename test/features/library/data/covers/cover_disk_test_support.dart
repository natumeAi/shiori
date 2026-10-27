import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shiori/core/storage/cache_budget.dart';
import 'package:shiori/features/library/data/covers/cover_disk_store.dart';
import 'package:shiori/features/library/data/library_session_scope.dart';

import '../publications/cache_test_support.dart';

final class CoverDiskFixture {
  CoverDiskFixture(
    this.publications, {
    int limit = CoverDiskStore.defaultLimit,
    Future<void> Function()? beforeRename,
  }) {
    disk = CoverDiskStore(
      directories: publications,
      limit: limit,
      serialize: serialize,
      reserve: (bytes) async {
        final used = await publicationBytes();
        final budget = publications.cache.budget;
        return budget.fits(bytes, used)
            ? budget.reserve(bytes, usedBytes: used)
            : null;
      },
      now: () => publications.time,
      beforeRename: beforeRename,
    );
  }

  final CacheFixture publications;
  late final CoverDiskStore disk;
  Future<void> _tail = Future.value();
  CacheBudget get budget => publications.cache.budget;
  LibrarySessionScope scope() =>
      LibrarySessionScope(publications.session, publications.guard);

  Future<T> serialize<T>(Future<T> Function() action) async {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    await previous;
    try {
      return await action();
    } finally {
      done.complete();
    }
  }

  Future<int> publicationBytes() async {
    final dir = Directory(
      '${publications.root.path}/caches/shiori/v1/publications',
    );
    var bytes = 0;
    if (await dir.exists()) {
      await for (final entity in dir.list(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is File) bytes += await entity.length();
      }
    }
    return bytes;
  }

  File file(String path) => File(
    '${publications.root.path}/caches/shiori/v1/'
    'covers/${publications.session.serverKey.value}/'
    '${sha256.convert(utf8.encode(path))}.cache',
  );

  Directory get root =>
      Directory('${publications.root.path}/caches/shiori/v1/covers');
}
