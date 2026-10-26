import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';

/// Declared bounds enforced before any entry is expanded.
final class EpubLimits {
  const EpubLimits({
    this.maxArchiveBytes = 256 * 1024 * 1024,
    this.maxEntries = 20000,
    this.maxEntryBytes = 64 * 1024 * 1024,
    this.maxTotalBytes = 1024 * 1024 * 1024,
  });

  final int maxArchiveBytes;
  final int maxEntries;
  final int maxEntryBytes;
  final int maxTotalBytes;
}

/// A ZIP container with limits, keyed by exact entry name (last duplicate
/// wins, like `fflate.unzipSync`). Entries are expanded lazily and the
/// expanded size is checked against the declared bound.
final class EpubArchive {
  EpubArchive._(this._entries, this.limits);

  factory EpubArchive.open(
    Uint8List bytes, {
    EpubLimits limits = const EpubLimits(),
  }) {
    ReaderWorkGuard.check(ReaderWork.parsing);
    if (bytes.length > limits.maxArchiveBytes) {
      throw const ParseException(FormatException('EPUB archive is too large'));
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } on Object catch (error) {
      throw ParseException(
        FormatException('Invalid ZIP: ${error.runtimeType}'),
      );
    }
    if (archive.isEmpty) {
      throw const ParseException(FormatException('Not a ZIP archive'));
    }
    if (archive.length > limits.maxEntries) {
      throw const ParseException(FormatException('Too many ZIP entries'));
    }
    final entries = <String, ArchiveFile>{};
    var total = 0;
    for (final file in archive) {
      if (file.size > limits.maxEntryBytes) {
        throw const ParseException(FormatException('ZIP entry is too large'));
      }
      total += file.size;
      if (total > limits.maxTotalBytes) {
        throw const ParseException(FormatException('ZIP expands too much'));
      }
      entries[file.name] = file;
    }
    return EpubArchive._(entries, limits);
  }

  final Map<String, ArchiveFile> _entries;
  final EpubLimits limits;

  Iterable<String> get names => _entries.keys;

  bool contains(String name) => _entries.containsKey(name);

  /// Declared uncompressed size, 0 when the entry is absent.
  int size(String name) => _entries[name]?.size ?? 0;

  Uint8List? bytes(String name) {
    ReaderWorkGuard.check(ReaderWork.storage);
    final file = _entries[name];
    if (file == null) return null;
    final Uint8List data;
    try {
      data = file.readBytes() ?? Uint8List(0);
    } on Object catch (error) {
      throw ParseException(
        FormatException('Corrupt ZIP entry: ${error.runtimeType}'),
      );
    }
    if (data.length > limits.maxEntryBytes) {
      throw const ParseException(FormatException('ZIP entry is too large'));
    }
    return data;
  }

  /// UTF-8 text with replacement characters; one leading byte-order mark is
  /// dropped by the decoder, like `fflate.strFromU8` through `TextDecoder`.
  /// Null when absent.
  String? text(String name) {
    ReaderWorkGuard.check(ReaderWork.storage);
    final data = bytes(name);
    if (data == null) return null;
    return utf8.decode(data, allowMalformed: true);
  }
}
