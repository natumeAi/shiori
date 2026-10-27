import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/cache_reservation.dart';

/// Shared removable-byte admission; callers serialize measurement and eviction.
/// A reservation stays charged until its bytes are measured on disk or removed.
final class CacheBudget {
  CacheBudget({this.limit = 512 * 1024 * 1024}) {
    if (limit < 1) throw ArgumentError('Invalid cache limit');
  }

  final int limit;
  static const coverLimit = 16 * 1024 * 1024;
  static const coverIndividualLimit = 8 * 1024 * 1024;
  final _subBudgets = <String, CacheDiskSubBudget>{};

  CacheDiskSubBudget? subBudget(String name) => _subBudgets[name];

  /// Configure a removable namespace on the owner's admission queue. Rebinding
  /// preserves file charges when the publication service is invalidated.
  CacheDiskSubBudget configureSubBudget(
    String name, {
    required AppDirectories directories,
    required int limit,
    required int individualLimit,
    required Future<CacheReservation?> Function(int) reserve,
    required Future<T> Function<T>(Future<T> Function()) serialize,
  }) {
    final owner = _subBudgets[name] ??= CacheDiskSubBudget(
      name: name,
      directories: directories,
      limit: limit,
      individualLimit: individualLimit,
      reserve: reserve,
      serialize: serialize,
    );
    owner.reserve = reserve;
    owner.serialize = serialize;
    return owner;
  }

  int _reserved = 0;
  int get reservedBytes => _reserved;

  bool fits(int bytes, int usedBytes) => usedBytes + _reserved + bytes <= limit;

  CacheReservation reserve(int bytes, {required int usedBytes}) {
    if (bytes < 0 || !fits(bytes, usedBytes)) {
      throw StateError('Cache reservation requires prior admission');
    }
    _reserved += bytes;
    return CacheReservation(bytes, () => _reserved -= bytes);
  }
}

/// A disk-only LRU sub-budget. Inputs are generated SHA-256 namespace/key pairs;
/// feature code owns resource identity and content validation.
final class CacheDiskSubBudget {
  CacheDiskSubBudget({
    required this.name,
    required this.directories,
    required this.limit,
    required this.individualLimit,
    required this.reserve,
    required this.serialize,
    DateTime Function()? now,
  }) : now = now ?? DateTime.now {
    if (!RegExp(r'^[a-z]+$').hasMatch(name) ||
        limit < 1 ||
        individualLimit < 1) {
      throw ArgumentError('Invalid disk sub-budget');
    }
  }

  final String name;
  final AppDirectories directories;
  final int limit;
  final int individualLimit;
  final DateTime Function() now;
  Future<CacheReservation?> Function(int) reserve;
  Future<T> Function<T>(Future<T> Function()) serialize;
  final _entries = <String, _DiskEntry>{};
  final _cleanup = <String, CacheReservation>{};
  static final _hash = RegExp(r'^[a-f0-9]{64}$');
  static final _fileName = RegExp(r'^[a-f0-9]{64}\.cache$');
  int get encodedBytes => _entries.values.fold(0, (sum, e) => sum + e.bytes);
  int get _cleanupBytes =>
      _cleanup.values.fold(0, (sum, charge) => sum + charge.bytes);

  void _checkPath(String relative) {
    final parts = relative.split('/');
    if (parts.length != 2 ||
        !_hash.hasMatch(parts.first) ||
        !_fileName.hasMatch(parts.last)) {
      throw ArgumentError('Invalid generated cache path');
    }
  }

  Future<Uint8List?> read(String relative, {required void Function() check}) =>
      serialize(() async {
        check();
        _checkPath(relative);
        try {
          final file = await _file(relative);
          check();
          if (file == null) return null;
          final length = await file.length();
          check();
          if (length < 1 ||
              length > individualLimit ||
              length > limit ||
              _entries[relative]?.bytes != length) {
            await _remove(relative, file, check: check);
            return null;
          }
          final builder = BytesBuilder(copy: false);
          var overflow = false;
          await for (final chunk in file.openRead()) {
            check();
            if (builder.length + chunk.length > individualLimit ||
                builder.length + chunk.length > limit) {
              overflow = true;
              break;
            }
            builder.add(chunk);
          }
          check();
          if (overflow || builder.length != length) {
            await _remove(relative, file, check: check);
            return null;
          }
          final entry = _entries.remove(relative);
          if (entry != null) _entries[relative] = entry;
          await file.setLastModified(now().toUtc());
          check();
          return builder.takeBytes();
        } on FileSystemException {
          return null;
        }
      });

  Future<void> invalidate(String relative, {required void Function() check}) =>
      serialize(() async {
        check();
        _checkPath(relative);
        final file = await _file(relative);
        check();
        if (file != null) await _remove(relative, file, check: check);
      });

  Future<void> _remove(
    String relative,
    File file, {
    void Function()? check,
  }) async {
    final exists = await file.exists();
    check?.call();
    if (exists) await file.delete();
    _entries.remove(relative)?.reservation.release();
  }

  Future<bool> _evict({void Function()? check}) async {
    if (_entries.isEmpty) return false;
    final relative = _entries.keys.first;
    final file = await _file(relative);
    check?.call();
    if (file != null) {
      await _remove(relative, file, check: check);
    } else {
      _entries.remove(relative)?.reservation.release();
    }
    return true;
  }
}

final class _DiskEntry {
  _DiskEntry(this.bytes, this.reservation);
  final int bytes;
  final CacheReservation reservation;
}

extension _DiskSubBudgetFiles on CacheDiskSubBudget {
  Future<Directory?> _directory({String? server, bool create = false}) async {
    var dir = await directories.caches();
    for (final part in ['shiori', 'v1', name, ?server]) {
      dir = Directory.fromUri(dir.uri.resolve('$part/'));
      final type = await FileSystemEntity.type(dir.path, followLinks: false);
      if (type == FileSystemEntityType.notFound) {
        if (!create) return null;
        await dir.create();
      } else if (type != FileSystemEntityType.directory) {
        throw const FileSystemException('Invalid cache directory');
      }
    }
    return dir;
  }

  Future<File?> _file(String relative) async {
    final parts = relative.split('/');
    final dir = await _directory(server: parts.first);
    if (dir == null) return null;
    final file = File.fromUri(dir.uri.resolve(parts.last));
    final type = await FileSystemEntity.type(file.path, followLinks: false);
    if (type == FileSystemEntityType.notFound) return null;
    if (type != FileSystemEntityType.file) {
      throw const FileSystemException('Invalid cache file');
    }
    return file;
  }
}

extension CacheDiskReconciliation on CacheDiskSubBudget {
  Future<void> reconcile() => serialize(reconcileInQueue);

  /// Admission owner calls this while it already holds its shared queue.
  Future<void> reconcileInQueue() async {
    final root = await _directory();
    final files = <({String relative, File file, int bytes, DateTime at})>[];
    if (root != null) {
      await for (final entity in root.list(followLinks: false)) {
        if (entity is File) {
          await entity.delete();
        } else if (entity is Directory &&
            CacheDiskSubBudget._hash.hasMatch(
              entity.uri.pathSegments.where((part) => part.isNotEmpty).last,
            )) {
          final server = entity.uri.pathSegments
              .where((part) => part.isNotEmpty)
              .last;
          await for (final child in entity.list(followLinks: false)) {
            if (child is! File) continue;
            final name = child.uri.pathSegments.last;
            final stat = await child.stat();
            if (!CacheDiskSubBudget._fileName.hasMatch(name) ||
                stat.size < 1 ||
                stat.size > individualLimit ||
                stat.size > limit) {
              await child.delete();
            } else {
              files.add((
                relative: '$server/$name',
                file: child,
                bytes: stat.size,
                at: stat.modified,
              ));
            }
          }
        }
      }
    }
    for (final path in _cleanup.keys.toList()) {
      final file = await _file(path);
      if (file != null) await file.delete();
      files.removeWhere((file) => file.relative == path);
      _cleanup.remove(path)!.release();
    }
    final present = files.map((f) => f.relative).toSet();
    for (final key in _entries.keys.toList()) {
      if (!present.contains(key)) _entries.remove(key)!.reservation.release();
    }
    files.sort((a, b) {
      final order = a.at.compareTo(b.at);
      return order != 0 ? order : a.relative.compareTo(b.relative);
    });
    var total = files.fold(0, (sum, f) => sum + f.bytes);
    while (total > limit) {
      final file = files.removeAt(0);
      await _remove(file.relative, file.file);
      total -= file.bytes;
    }
    // Preserve newest covers when publication usage prevents restoration.
    for (final file in files.reversed) {
      final existing = _entries[file.relative];
      if (existing != null && existing.bytes == file.bytes) continue;
      _entries.remove(file.relative)?.reservation.release();
      final charge = await reserve(file.bytes);
      if (charge == null) {
        await file.file.delete();
      } else {
        _entries[file.relative] = _DiskEntry(file.bytes, charge);
      }
    }
    final ordered = <String, _DiskEntry>{};
    for (final file in files) {
      final entry = _entries[file.relative];
      if (entry != null) ordered[file.relative] = entry;
    }
    _entries
      ..clear()
      ..addAll(ordered);
  }
}

extension CacheDiskWriting on CacheDiskSubBudget {
  Future<bool> write(
    String relative,
    Uint8List bytes, {
    required void Function() check,
    Future<void> Function()? beforeRename,
  }) => serialize(() async {
    check();
    _checkPath(relative);
    if (bytes.isEmpty ||
        bytes.length > individualLimit ||
        bytes.length > limit) {
      return false;
    }
    CacheReservation? charge;
    File? pending;
    String? pendingRelative;
    try {
      if (_entries.containsKey(relative) && await _file(relative) != null) {
        check();
        return true;
      }
      _entries.remove(relative)?.reservation.release();
      while (encodedBytes + _cleanupBytes + bytes.length > limit) {
        check();
        if (!await _evict(check: check)) return false;
      }
      check();
      charge = await reserve(bytes.length);
      while (charge == null && _entries.isNotEmpty) {
        check();
        await _evict(check: check);
        check();
        charge = await reserve(bytes.length);
      }
      check();
      if (charge == null) return false;
      final server = relative.split('/').first;
      final dir = (await _directory(server: server, create: true))!;
      check();
      final random = Random.secure();
      final token = List.generate(
        16,
        (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      pendingRelative = '$server/$token.part';
      pending = File.fromUri(dir.uri.resolve('$token.part'));
      await pending.create(exclusive: true);
      check();
      await pending.writeAsBytes(bytes, flush: true);
      check();
      await beforeRename?.call();
      check();
      final destination = File.fromUri(
        dir.uri.resolve(relative.split('/').last),
      );
      final type = await FileSystemEntity.type(
        destination.path,
        followLinks: false,
      );
      check();
      if (type != FileSystemEntityType.notFound) return false;
      await pending.rename(destination.path);
      pending = destination;
      pendingRelative = relative;
      check();
      await destination.setLastModified(now().toUtc());
      check();
      _entries[relative] = _DiskEntry(bytes.length, charge);
      charge = null; // Persisted file owns the reservation until deletion.
      pending = null;
      return true;
    } on FileSystemException {
      return false;
    } finally {
      if (charge != null) {
        try {
          if (pending != null && await pending.exists()) await pending.delete();
          charge.release();
        } on FileSystemException {
          _cleanup[pendingRelative!] = charge;
        }
      }
    }
  });
}
