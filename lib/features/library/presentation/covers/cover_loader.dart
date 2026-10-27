import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/config/session_publication_guard.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/data/library_session_scope.dart';
import 'package:shiori/features/library/presentation/covers/cover_failure.dart';
import 'package:shiori/features/library/presentation/covers/cover_lease.dart';
import 'package:shiori/features/library/presentation/covers/cover_load_result.dart';
import 'package:shiori/features/servers/data/server_activation_dependencies.dart';

part 'cover_loader.g.dart';
part 'cover_loader_decode.dart';

/// Session-owned memory caches. Phase D may add a disk source behind _readEncoded;
/// it must share that phase's cross-server quota, not persist here independently.
final class CoverLoader {
  CoverLoader(
    this._transport,
    SessionPublicationGuard guard, {
    this.encodedBudget = defaultBudget,
    this.decodedBudget = defaultBudget,
  }) : _scope = LibrarySessionScope(_transport.session, guard) {
    if (encodedBudget < 1 || decodedBudget < 4) {
      throw ArgumentError('Invalid cover budget');
    }
    _unregister = guard.onRetire(session, dispose);
  }

  static const defaultBudget = 16 * 1024 * 1024;
  static const individualLimit = 8 * 1024 * 1024;
  final SessionTransport _transport;
  final LibrarySessionScope _scope;
  final int encodedBudget;
  final int decodedBudget;
  final _encoded = <(ServerSession, String), Uint8List>{};
  final _decoded = <(ServerSession, String), _DecodedCover>{};
  final _pending = <(ServerSession, String), Future<_DecodedCover>>{};
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

  Future<CoverLoadResult> load(String? serverCoverPath) async {
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
      final key = (session, serverCoverPath);
      var entry = _decoded.remove(key);
      if (entry != null) _decoded[key] = entry;
      final encoded = _encoded.remove(key);
      if (encoded != null) _encoded[key] = encoded;
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

  Future<_DecodedCover> _fetch((ServerSession, String) key) async {
    final bytes = _encoded[key] ?? await _readEncoded(key.$2);
    final entry = await _decodeAndCache(key, bytes);
    _scope.check();
    if (!_encoded.containsKey(key) && bytes.length <= encodedBudget) {
      while (_encodedBytes + bytes.length > encodedBudget) {
        _encodedBytes -= _encoded.remove(_encoded.keys.first)!.length;
      }
      _scope.publish(() {
        _encoded[key] = bytes;
        _encodedBytes += bytes.length;
      });
    }
    return entry;
  }

  // Phase D source seam: any disk lookup must use that phase's shared quota.
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
  );
  ref.onDispose(loader.dispose);
  return loader;
}
