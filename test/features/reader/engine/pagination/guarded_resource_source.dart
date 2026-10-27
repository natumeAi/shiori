import 'dart:typed_data';

import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';

/// Place only resource access in the forbidden-I/O zone. Real layout, fonts,
/// image decoding and pagination run normally outside that zone. Any lazy
/// EpubArchive.bytes fallback inside the resource source would assert.
final class GuardedResourceSource implements ReaderResourceSource {
  GuardedResourceSource(this.source);
  final ReaderResourceSource source;
  int reads = 0;
  int sizes = 0;
  int presenceChecks = 0;
  int disposals = 0;

  @override
  Uint8List? bytes(String path) {
    reads++;
    return ReaderWorkGuard.callback(() => source.bytes(path));
  }

  @override
  bool contains(String path) {
    presenceChecks++;
    return ReaderWorkGuard.callback(() => source.contains(path));
  }

  @override
  int size(String path) {
    sizes++;
    return ReaderWorkGuard.callback(() => source.size(path));
  }

  @override
  void dispose() {
    disposals++;
    source.dispose();
  }
}
