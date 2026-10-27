import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/storage/app_directories.dart';
import 'package:shiori/core/storage/cache_budget.dart';
import 'package:shiori/core/storage/cache_reservation.dart';
import 'package:shiori/features/library/data/library_session_scope.dart';

/// Cover identity/session adapter over the shared removable disk sub-budget.
final class CoverDiskStore {
  CoverDiskStore({
    required AppDirectories directories,
    required Future<CacheReservation?> Function(int) reserve,
    required Future<T> Function<T>(Future<T> Function()) serialize,
    int limit = defaultLimit,
    this.beforeRename,
    DateTime Function()? now,
  }) : _disk = CacheDiskSubBudget(
         name: 'covers',
         directories: directories,
         limit: limit,
         individualLimit: individualLimit,
         reserve: reserve,
         serialize: serialize,
         now: now,
       );

  CoverDiskStore.fromBudget(CacheBudget budget)
    : _disk =
          budget.subBudget('covers') ??
          (throw StateError('Cover sub-budget has not been reconciled')),
      beforeRename = null;

  static const defaultLimit = CacheBudget.coverLimit;
  static const individualLimit = CacheBudget.coverIndividualLimit;
  final CacheDiskSubBudget _disk;
  final Future<void> Function()? beforeRename;
  int get encodedBytes => _disk.encodedBytes;

  String _relative(ServerSession session, String path) {
    session.endpoint.cover(path);
    final digest = sha256.convert(utf8.encode(path)).toString();
    return '${session.serverKey.value}/$digest.cache';
  }

  Future<Uint8List?> read(LibrarySessionScope scope, String path) =>
      _disk.read(_relative(scope.session, path), check: scope.check);

  Future<void> invalidate(LibrarySessionScope scope, String path) =>
      _disk.invalidate(_relative(scope.session, path), check: scope.check);

  /// Only the loader's successfully decoded bytes may be admitted here.
  Future<bool> write(LibrarySessionScope scope, String path, Uint8List bytes) =>
      _disk.write(
        _relative(scope.session, path),
        bytes,
        check: scope.check,
        beforeRename: beforeRename == null
            ? null
            : () => scope.wait(beforeRename!()),
      );

  Future<void> reconcile() => _disk.reconcile();
}
