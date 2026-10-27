import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/data/covers/cover_disk_store.dart';
import 'package:shiori/features/library/data/library_session_scope.dart';
import 'package:shiori/features/library/data/publications/publication_cache.dart';
import 'package:shiori/features/library/presentation/covers/cover_failure.dart';
import 'package:shiori/features/library/presentation/covers/cover_lease.dart';
import 'package:shiori/features/library/presentation/covers/cover_load_result.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

part 'cover_loader.g.dart';
part 'cover_loader_decode.dart';

typedef _CoverKey = (ServerSession, String);

/// Decoded pixels also depend on the requested display width.
typedef _DecodedKey = (ServerSession, String, int?);

/// Session-owned memory caches backed by removable, server-namespaced covers.
final class CoverLoader {
  CoverLoader(
    this._transport,
    SessionPublicationGuard guard, {
    this.encodedBudget = defaultBudget,
    this.decodedBudget = defaultDecodedBudget,
    this._decodeFrame,
    this.diskStore,
  }) : _scope = LibrarySessionScope(_transport.session, guard) {
    if (encodedBudget < 1 || decodedBudget < 4) {
      throw ArgumentError('Invalid cover budget');
    }
    _unregister = guard.onRetire(session, dispose);
  }

  static const defaultBudget = CoverDiskStore.defaultLimit;
  static const defaultDecodedBudget = 128 * 1024 * 1024;

  /// Pixel ceiling for one decoded cover, whatever width was requested.
  static const individualDecodedLimit = 16 * 1024 * 1024;
  static const individualLimit = CoverDiskStore.individualLimit;
  final SessionTransport _transport;
  final LibrarySessionScope _scope;
  final int encodedBudget;
  final int decodedBudget;
  final Future<CoverDiskStore?> Function()? diskStore;
  // Allows lifecycle tests to hold a real native frame until retirement.
  final Future<ui.FrameInfo> Function(ui.Codec)? _decodeFrame;
  final _encoded = <_CoverKey, Uint8List>{};
  final _decoded = <_DecodedKey, _DecodedCover>{};
  final _pending = <_DecodedKey, Future<_DecodedCover>>{};
  void Function()? _unregister;
  int _encodedBytes = 0;
  int _decodedBytes = 0;
  int _reservedBytes = 0;
  bool _disposed = false;

  ServerSession get session => _transport.session;
  bool get isActive => !_disposed && _scope.guard.isCurrent(session);
  int get encodedBytes => _encodedBytes;
  int get decodedBytes => _decodedBytes;
  int get reservedBytes => _reservedBytes;
  int get encodedCount => _encoded.length;
  int get decodedCount => _decoded.length;

  /// [maxWidth] is the displayed width in physical pixels; null keeps the
  /// source width within [individualDecodedLimit].
  Future<CoverLoadResult> load(String? serverCoverPath, {int? maxWidth}) async {
    if (maxWidth != null && maxWidth < 1) {
      throw ArgumentError.value(maxWidth, 'maxWidth');
    }
    try {
      _scope.check();
      if (serverCoverPath == null || serverCoverPath.isEmpty) {
        return const CoverPlaceholder(CoverFailure.missing);
      }
      try {
        session.endpoint.cover(serverCoverPath);
      } on FormatException {
        return const CoverPlaceholder(CoverFailure.invalidPath);
      }
      final path = (session, serverCoverPath);
      final key = (session, serverCoverPath, maxWidth);
      var entry = _decoded.remove(key);
      if (entry != null) _decoded[key] = entry;
      final encoded = _encoded.remove(path);
      if (encoded != null) _encoded[path] = encoded;
      final _DecodedCover resolved =
          entry ??
          await _scope.wait<_DecodedCover>(
            _pending[key] ??= _fetch(key).whenComplete(() {
              _pending.remove(key);
            }),
          );
      _scope.check();
      if (!identical(_decoded[key], resolved)) throw CoverFailure.cacheBusy;
      resolved.leases++;
      return CoverLoaded(CoverLease(resolved.image, () => resolved.leases--));
    } on RequestCancelled {
      return const CoverPlaceholder(CoverFailure.cancelled);
    } on CoverFailure catch (reason) {
      return CoverPlaceholder(reason);
    } on NetworkException {
      return const CoverPlaceholder(CoverFailure.network);
    } on AppException {
      return const CoverPlaceholder(CoverFailure.unavailable);
    }
  }

  Future<_DecodedCover> _fetch(_DecodedKey key) async {
    final path = (key.$1, key.$2);
    final disk = _encoded.containsKey(path) ? null : await _disk();
    _scope.check();
    var cached = _encoded[path];
    var fromDisk = false;
    if (cached == null && disk != null) {
      cached = await _bestEffort<Uint8List?>(() => disk.read(_scope, key.$2));
      fromDisk = cached != null;
    }
    var bytes = cached ?? await _readEncoded(key.$2);
    late _DecodedCover entry;
    try {
      entry = await _decodeAndCache(key, bytes);
    } on CoverFailure catch (failure) {
      if (!fromDisk || failure != CoverFailure.nonImage) rethrow;
      await _bestEffort(() => disk!.invalidate(_scope, key.$2));
      _scope.check();
      bytes = await _readEncoded(key.$2);
      entry = await _decodeAndCache(key, bytes);
      fromDisk = false;
    }
    _scope.check();
    if (!_encoded.containsKey(path) && bytes.length <= encodedBudget) {
      while (_encodedBytes + bytes.length > encodedBudget) {
        _encodedBytes -= _encoded.remove(_encoded.keys.first)!.length;
      }
      _scope.publish(() {
        _encoded[path] = bytes;
        _encodedBytes += bytes.length;
      });
    }
    if (!fromDisk && disk != null) {
      entry.leases++;
      try {
        await _bestEffort(() => disk.write(_scope, key.$2, bytes));
      } finally {
        entry.leases--;
      }
    }
    _scope.check();
    return entry;
  }

  Future<CoverDiskStore?> _disk() =>
      _bestEffort<CoverDiskStore?>(() async => diskStore?.call());

  Future<T?> _bestEffort<T>(Future<T> Function() operation) async {
    try {
      return await _scope.wait(operation());
    } on RequestCancelled {
      rethrow;
    } catch (_) {
      _scope.check();
      return null;
    }
  }

  Future<Uint8List> _readEncoded(String path) async {
    try {
      return (await _scope.wait(
        _transport.getBytes(path, maxBytes: individualLimit),
      )).body;
    } on ParseException {
      // URI validation already succeeded; the bounded byte reader overflowed.
      throw CoverFailure.oversized;
    }
  }

  void _reserve(int bytes) {
    for (final key in _decoded.keys.toList()) {
      if (_decodedBytes + _reservedBytes + bytes <= decodedBudget) break;
      final entry = _decoded[key]!;
      if (entry.leases != 0) continue;
      _decoded.remove(key);
      _decodedBytes -= entry.bytes;
      entry.image.dispose();
    }
    if (_decodedBytes + _reservedBytes + bytes > decodedBudget) {
      throw CoverFailure.cacheBusy;
    }
    _reservedBytes += bytes;
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _scope.dispose();
    _unregister?.call();
    _encoded.clear();
    _encodedBytes = 0;
    for (final entry in _decoded.values) {
      entry.image.dispose();
    }
    _decoded.clear();
    _decodedBytes = 0;
    _pending.clear();
    // Native decodes release their reservation in finally, even after retirement.
  }
}

final class _DecodedCover {
  _DecodedCover(this.image) : bytes = image.width * image.height * 4;
  final ui.Image image;
  final int bytes;
  int leases = 0;
}

@Riverpod(keepAlive: true)
CoverLoader coverLoader(Ref ref, ServerSession session) {
  final loader = CoverLoader(
    ref.watch(sessionTransportProvider(session)),
    ref.watch(sessionPublicationGuardProvider),
    diskStore: () async {
      final cache = await ref.read(publicationCacheProvider.future);
      if (!ref.mounted) throw const RequestCancelled();
      return CoverDiskStore.fromBudget(cache.budget);
    },
  );
  ref.onDispose(loader.dispose);
  return loader;
}
