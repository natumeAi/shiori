import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:shiori/core/config/book_key.dart';

/// A caller-verified immutable generation, pinned by its owner during download.
final class LocalPublication {
  const LocalPublication({
    required this.key,
    required this.path,
    required this.byteLength,
    required this.digest,
    this.etag,
    this.lastModified,
  });

  final BookKey key;
  final String path;
  final int byteLength;
  final String digest;
  final String? etag;
  final String? lastModified;

  /// Always recheck existence/length; rehash small generations incrementally.
  /// Larger generations rely on the caller's prior verification and pin.
  Future<bool> isUsable(int maxBytes, void Function() check) async {
    if (byteLength < 1 ||
        byteLength > maxBytes ||
        !RegExp(r'^[0-9a-f]{64}$').hasMatch(digest)) {
      return false;
    }
    try {
      final file = File(path);
      if (await file.length() != byteLength) return false;
      check();
      if (byteLength <= 8 * 1024 * 1024) {
        final actual = await sha256
            .bind(
              file.openRead().map((chunk) {
                check();
                return chunk;
              }),
            )
            .single;
        check();
        if (actual.toString() != digest) return false;
        if (await file.length() != byteLength) return false;
      }
      check();
      return true;
    } on FileSystemException {
      return false;
    }
  }
}
