part of 'publication_cache.dart';

final class _PublicationFiles {
  _PublicationFiles(this.caches, this.root);
  final Directory caches;
  final Directory root;

  static Future<_PublicationFiles> open(PublicationStaging staging) async {
    try {
      final caches = await staging.directories.caches();
      final root = Directory.fromUri(
        caches.uri.resolve('shiori/v1/publications/'),
      );
      final files = _PublicationFiles(caches, root);
      await files._directories(['shiori', 'v1', 'publications'], create: true);
      return files;
    } on FileSystemException {
      throw const PublicationCacheException(PublicationCacheFailure.storage);
    }
  }

  Future<bool> _directories(List<String> parts, {bool create = false}) async {
    var dir = caches;
    for (final part in parts) {
      dir = Directory.fromUri(dir.uri.resolve('$part/'));
      final type = await FileSystemEntity.type(dir.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        if (!create) return false;
        await dir.create();
      } else if (type != FileSystemEntityType.directory) {
        throw const PublicationCacheException(PublicationCacheFailure.storage);
      }
    }
    return true;
  }

  File file(StoredPublication p) =>
      File.fromUri(caches.uri.resolve(p.relativePath));

  Future<File> destination(StoredPublication p) async {
    await _directories(p.relativePath.split('/')..removeLast(), create: true);
    return file(p);
  }

  Future<bool> matches(
    StoredPublication p, {
    bool digest = false,
    void Function()? check,
  }) async {
    if (!p.isValidated || !p.hasExpectedPath || p.byteLength < 1) return false;
    if (!await _directories(p.relativePath.split('/')..removeLast())) {
      return false;
    }
    return matchesFile(file(p), p.byteLength, digest ? p.sha256 : null, check);
  }

  Future<bool> matchesFile(
    File file,
    int bytes,
    String? digest,
    void Function()? check,
  ) async {
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return false;
    if (type != FileSystemEntityType.file) {
      throw const PublicationCacheException(PublicationCacheFailure.storage);
    }
    if (await file.length() != bytes) return false;
    check?.call();
    if (digest != null) {
      final actual = await sha256
          .bind(
            file.openRead().map((chunk) {
              check?.call();
              return chunk;
            }),
          )
          .single;
      check?.call();
      if (actual.toString() != digest || await file.length() != bytes) {
        return false;
      }
    }
    return true;
  }

  LocalPublication local(StoredPublication p) => LocalPublication(
    key: p.key,
    path: file(p).path,
    byteLength: p.byteLength,
    digest: p.sha256,
    etag: p.etag,
    lastModified: p.lastModified,
  );

  /// Follow neither directory nor file links, and never visit another root.
  Stream<File> all() async* {
    if (!await _directories(['shiori', 'v1', 'publications'])) return;
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is File) yield entity;
    }
  }

  Future<int> usedBytes() async {
    var used = 0;
    await for (final file in all()) {
      used += await file.length();
    }
    return used;
  }
}
