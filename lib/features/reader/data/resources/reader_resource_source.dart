import 'dart:convert';
import 'dart:typed_data';

import 'package:shiori/features/reader/data/source/reader_work_guard.dart';

/// Synchronous encoded-resource access. Product implementations already own
/// these bytes; the engine never starts asynchronous I/O through this seam.
abstract interface class ReaderResourceSource {
  Uint8List? bytes(String path);
  bool contains(String path);
  int size(String path);

  /// Releases this section's ownership. Idempotent; archive adapters own no file.
  void dispose();
}

/// Content-free diagnostics: never pass a resource path or original URL.
enum ReaderResourceMiss { absent, notPreloaded, disposed, retired }

/// The archive's UTF-8 replacement/BOM semantics, shared by pure-Dart engine
/// style/support readers. Product preparation receives worker-resolved styles.
extension ReaderResourceText on ReaderResourceSource {
  String? text(String path) {
    ReaderWorkGuard.check(ReaderWork.storage);
    final data = bytes(path);
    return data == null ? null : utf8.decode(data, allowMalformed: true);
  }
}
