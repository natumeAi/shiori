import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/features/library/data/publications/download_exception.dart';

part 'publication_staging.g.dart';

/// Shared across sessions: one transfer and one reserved compressed file.
final class PublicationStaging {
  PublicationStaging(this.directories, {this.openWriter});
  final AppDirectories directories;
  final Future<StagingWriter> Function(File)? openWriter;
  Future<void> _tail = Future.value();
  final Set<StagingFile> _owned = {};
  bool _reserved = false;

  bool owns(StagingFile file) => _owned.contains(file);

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

  Future<Directory> directory() async {
    final root = await directories.caches();
    return Directory('${root.path}/shiori/v1/staging').create(recursive: true);
  }

  Future<StagingFile> create() async {
    if (_reserved) throw const DownloadException(DownloadFailure.stagingBusy);
    _reserved = true;
    try {
      final dir = await directory();
      final random = Random.secure();
      final name = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final file = await File('${dir.path}/$name.part').create(exclusive: true);
      final owned = StagingFile._(file, this);
      _owned.add(owned);
      return owned;
    } catch (_) {
      _reserved = false;
      rethrow;
    }
  }

  /// Startup only: nonrecursive, regular .part files in this exact directory.
  /// Live files are excluded even if startup cleanup overlaps a transfer.
  Future<void> cleanupAbandoned() => serialize(() async {
    try {
      final dir = await directory();
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File &&
            entity.path.endsWith('.part') &&
            !_owned.any(
              (owned) => File(owned.path).absolute.uri == entity.absolute.uri,
            )) {
          await entity.delete();
        }
      }
    } on FileSystemException {
      throw const DownloadException(DownloadFailure.storage);
    }
  });
}

/// Ownership passes to D2 on success. Discard on failure; release the reservation
/// only after D2 has moved/deleted this file, never while it remains in staging.
final class StagingFile {
  StagingFile._(this._file, this._owner);
  final File _file;
  final PublicationStaging _owner;
  String get path => _file.path;
  bool _released = false;

  Future<StagingWriter> open() async => _owner.openWriter != null
      ? _owner.openWriter!(_file)
      : _FileWriter(await _file.open(mode: FileMode.write));

  Future<void> discard() async {
    if (_released) return;
    try {
      if (await _file.exists()) await _file.delete();
      releaseAfterMove();
    } on FileSystemException {
      throw const DownloadException(DownloadFailure.storage);
    }
  }

  void releaseAfterMove() {
    if (_released) return;
    _released = true;
    _owner._owned.remove(this);
    _owner._reserved = false;
  }
}

abstract interface class StagingWriter {
  Future<void> write(List<int> bytes);
  Future<void> flush();
  Future<void> close();
}

final class _FileWriter implements StagingWriter {
  _FileWriter(this.file);
  final RandomAccessFile file;
  @override
  Future<void> write(List<int> bytes) async {
    await file.writeFrom(bytes);
  }

  @override
  Future<void> flush() async {
    await file.flush();
  }

  @override
  Future<void> close() async {
    await file.close();
  }
}

@Riverpod(keepAlive: true)
PublicationStaging publicationStaging(Ref ref) =>
    PublicationStaging(ref.watch(appDirectoriesProvider));
