import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';

/// The registration adapter may report this only when the engine definitely
/// accepted no registration. Other failures retain an uncertain process charge.
final class ProcessFontRegistrationRejected implements Exception {
  const ProcessFontRegistrationRejected();
}

final class ProcessFontLoadCanceled implements Exception {
  const ProcessFontLoadCanceled();
}

/// Process lifetime admissions; a book close cannot unload registered fonts.
/// A3 integrates this owner into FontRegistry. No production reset/unload API.
final class ProcessFontBudget {
  ProcessFontBudget({this.maxBytes = 64 * 1024 * 1024, this.maxFaces = 32}) {
    if (maxBytes <= 0 || maxFaces <= 0) {
      throw ArgumentError('Invalid font limits');
    }
  }
  static final shared = ProcessFontBudget();
  final int maxBytes, maxFaces;
  final Map<String, Future<String>> _loads = {};
  int _bytes = 0, _faces = 0;
  int _pendingBytes = 0, _pendingFaces = 0;
  int _registeredBytes = 0, _registeredFaces = 0;
  int _uncertainBytes = 0, _uncertainFaces = 0;
  int _peakBytes = 0, _peakFaces = 0;

  /// Admitted input bytes/faces: pending + registered + uncertain. This does
  /// not measure engine font memory. No book/instance-close operation clears it.
  int get bytes => _bytes;
  int get faces => _faces;
  int get pendingBytes => _pendingBytes;
  int get pendingFaces => _pendingFaces;
  int get registeredBytes => _registeredBytes;
  int get registeredFaces => _registeredFaces;
  int get uncertainBytes => _uncertainBytes;
  int get uncertainFaces => _uncertainFaces;
  int get peakBytes => _peakBytes;
  int get peakFaces => _peakFaces;

  /// Coalesces bytes+face before registering. [face] identifies collection
  /// index/weight/style, independent of archive path or CSS family aliases.
  /// The caller supplies canonical face descriptors and immutable bytes until
  /// registration completes. Format validation belongs before this boundary;
  /// admission does not prove SFNT/WOFF engine support. Cancellation abandons
  /// only this waiter: started native registration cannot safely be undone.
  Future<String> load(
    Uint8List bytes, {
    required String face,
    required Future<void> Function(Uint8List bytes, String alias) register,
    PublicationCancellation? cancellation,
  }) {
    ReaderWorkGuard.check(ReaderWork.fontLoad);
    if (cancellation?.isCanceled ?? false) {
      throw const ProcessFontLoadCanceled();
    }
    if (bytes.isEmpty || face.trim().isEmpty) {
      throw ArgumentError('Font bytes and face must be nonempty');
    }
    final length = bytes.length;
    if (length > maxBytes) {
      throw const SceneAdmissionException(
        SceneAdmissionFailure.processFontExhausted,
      );
    }
    final digest = sha256.convert(bytes).toString();
    final key = '$digest|$face';
    if (_loads[key] case final existing?) {
      return _wait(existing, cancellation);
    }
    if (length > maxBytes - _bytes || _faces >= maxFaces) {
      throw const SceneAdmissionException(
        SceneAdmissionFailure.processFontExhausted,
      );
    }
    _bytes += length;
    _faces++;
    _pendingBytes += length;
    _pendingFaces++;
    if (_bytes > _peakBytes) _peakBytes = _bytes;
    if (_faces > _peakFaces) _peakFaces = _faces;
    final done = Completer<String>();
    _loads[key] = done.future;
    final alias = 'shiori-face-${sha256.convert(utf8.encode(key))}';
    Future<void>.sync(() => register(bytes, alias)).then(
      (_) {
        _pendingBytes -= length;
        _pendingFaces--;
        _registeredBytes += length;
        _registeredFaces++;
        done.complete(alias);
      },
      onError: (Object error, StackTrace stack) {
        _pendingBytes -= length;
        _pendingFaces--;
        if (error is ProcessFontRegistrationRejected) {
          _loads.remove(key);
          _bytes -= length;
          _faces--;
        } else {
          // A failed Future does not itself prove the engine retained nothing.
          // Cache the failed attempt so retry cannot register/charge it again.
          _uncertainBytes += length;
          _uncertainFaces++;
        }
        done.completeError(error, stack);
      },
    );
    return _wait(done.future, cancellation);
  }

  Future<String> _wait(
    Future<String> load,
    PublicationCancellation? cancellation,
  ) {
    if (cancellation == null) return load;
    final waiter = Completer<String>();
    final unsubscribe = cancellation.listen(() {
      if (!waiter.isCompleted) {
        waiter.completeError(const ProcessFontLoadCanceled());
      }
    });
    load.then(
      (alias) {
        unsubscribe();
        if (!waiter.isCompleted) waiter.complete(alias);
      },
      onError: (Object error, StackTrace stack) {
        unsubscribe();
        if (!waiter.isCompleted) waiter.completeError(error, stack);
      },
    );
    return waiter.future;
  }
}
