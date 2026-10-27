import 'dart:typed_data';

import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';

/// Compatibility access for bundled probes and existing in-memory tests.
/// Read, presence and declared-size semantics are exactly the archive's.
final class ArchiveReaderResourceSource implements ReaderResourceSource {
  const ArchiveReaderResourceSource(this.archive);
  final EpubArchive archive;

  @override
  Uint8List? bytes(String path) => archive.bytes(path);
  @override
  bool contains(String path) => archive.contains(path);
  @override
  int size(String path) => archive.size(path);
  @override
  void dispose() {}
}
