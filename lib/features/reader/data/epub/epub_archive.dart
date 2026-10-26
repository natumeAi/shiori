import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';

part 'epub_zip_directory.dart';

/// Declared bounds enforced before any entry is expanded.
final class EpubLimits {
  const EpubLimits({
    this.maxArchiveBytes = 256 * 1024 * 1024,
    this.maxEntries = 20000,
    this.maxEntryBytes = 64 * 1024 * 1024,
    this.maxTotalBytes = 1024 * 1024 * 1024,
    this.maxDirectoryBytes = 16 * 1024 * 1024,
    this.maxMetadataBytes = 8 * 1024 * 1024,
  });

  final int maxArchiveBytes;
  final int maxEntries;
  final int maxEntryBytes;
  final int maxTotalBytes;
  final int maxDirectoryBytes;

  /// Central/local names and extras, comments and ZIP64 EOCD extensible bytes.
  final int maxMetadataBytes;
}

/// A ZIP container with limits, keyed by exact entry name (last duplicate
/// wins, like `fflate.unzipSync`). Opening never expands entry content.
final class EpubArchive {
  EpubArchive._(this._entries, this.limits, this._file);

  factory EpubArchive.open(
    Uint8List bytes, {
    EpubLimits limits = const EpubLimits(),
  }) {
    ReaderWorkGuard.check(ReaderWork.parsing);
    if (bytes.length > limits.maxArchiveBytes) {
      throw const ParseException(FormatException('EPUB archive is too large'));
    }
    return _open(InputMemoryStream(bytes), limits);
  }

  /// Owns one shared file handle until [close]; callers keep the file immutable.
  factory EpubArchive.openFile(
    String path, {
    EpubLimits limits = const EpubLimits(),
  }) {
    ReaderWorkGuard.check(ReaderWork.parsing);
    InputFileStream? input;
    try {
      if (File(path).lengthSync() > limits.maxArchiveBytes) {
        throw const ParseException(
          FormatException('EPUB archive is too large'),
        );
      }
      input = InputFileStream(path);
      return _open(input, limits, file: input);
    } on Object catch (error) {
      input?.closeSync();
      if (error is ParseException) rethrow;
      throw _invalidZip(error);
    }
  }

  static EpubArchive _open(
    InputStream input,
    EpubLimits limits, {
    InputFileStream? file,
  }) {
    try {
      if (input.totalLength > limits.maxArchiveBytes) {
        throw const FormatException('EPUB archive is too large');
      }
      final directory = _ZipDirectoryReader(input, limits).validate();
      final entries = <String, ZipFileHeader>{};
      // All physical headers, metadata and local ranges are admitted before
      // the package materializes any name, extra field or local header.
      for (final admitted in directory) {
        final record = input.subset(position: admitted.central);
        record.skip(4);
        final header = ZipFileHeader()..read(record);
        // Package metadata decoding cannot choose sizes or offsets for I/O.
        header
          ..compressedSize = admitted.compressed
          ..uncompressedSize = admitted.expanded
          ..localHeaderOffset = admitted.offset
          ..diskNumberStart = 0;
        header.file = ZipFile(header)
          ..read(
            input.subset(
              position: admitted.offset,
              length: admitted.end - admitted.offset,
            ),
          );
        entries[header.filename] = header;
      }
      return EpubArchive._(entries, limits, file);
    } on Object catch (error) {
      if (error is ParseException) rethrow;
      throw _invalidZip(error);
    }
  }

  static ParseException _invalidZip(Object error) =>
      ParseException(FormatException('Invalid ZIP: ${error.runtimeType}'));

  final Map<String, ZipFileHeader> _entries;
  final InputFileStream? _file;
  bool _closed = false;
  final EpubLimits limits;

  Iterable<String> get names => _entries.keys;

  bool contains(String name) => _entries.containsKey(name);

  /// Declared uncompressed size, 0 when the entry is absent.
  int size(String name) => _entries[name]?.uncompressedSize ?? 0;

  Uint8List? bytes(String name) {
    ReaderWorkGuard.check(ReaderWork.storage);
    if (_closed) {
      throw const ParseException(FormatException('ZIP archive is closed'));
    }
    final header = _entries[name];
    if (header == null) return null;
    try {
      final output = _BoundedEntrySink(
        min(header.uncompressedSize, limits.maxEntryBytes),
      );
      // Link mode bits are deliberately ignored: every entry is ordinary bytes.
      final file = header.file!;
      if (header.compressionMethod == 8 && file.length == 0) {
        throw const FormatException('Empty deflate stream');
      }
      // On native platforms this uses chunked platform zlib through
      // decodeLimited. A missing zero-output tail can be accepted only when
      // the emitted length and CRC below still match the stored entry.
      file.decompress(output);
      if (output.exceeded || output.length != header.uncompressedSize) {
        throw const FormatException('Invalid ZIP entry length');
      }
      final data = output.getBytes();
      if (getCrc32(data) != header.crc32) {
        throw const FormatException('Invalid ZIP entry checksum');
      }
      return data;
    } on Object catch (error) {
      throw ParseException(
        FormatException('Corrupt ZIP entry: ${error.runtimeType}'),
      );
    }
  }

  /// In-memory archives need no cleanup. File-backed close is idempotent.
  void close() {
    ReaderWorkGuard.check(ReaderWork.storage);
    if (_file == null || _closed) return;
    _file.closeSync();
    _closed = true;
    _entries.clear();
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

/// No write can accumulate bytes beyond the admitted declared entry size.
final class _BoundedEntrySink extends OutputStream {
  _BoundedEntrySink(int limit)
    : _bytes = Uint8List(limit),
      super(byteOrder: ByteOrder.littleEndian);

  final Uint8List _bytes;
  @override
  int get length => _length;
  var _length = 0;
  bool exceeded = false;

  void _check(int count) {
    if (count < 0 || count > _bytes.length - _length) {
      exceeded = true;
      throw const FormatException('ZIP output exceeds declared bound');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    _bytes[_length++] = value;
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final count = length ?? bytes.length;
    _check(count);
    _bytes.setRange(_length, _length + count, bytes);
    _length += count;
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    while (!stream.isEOS) {
      writeBytes(stream.readBytes(min(65536, stream.length)).toUint8List());
    }
  }

  @override
  Uint8List subset(int start, [int? end]) => Uint8List.sublistView(
    _bytes,
    start < 0 ? length + start : start,
    end == null ? length : (end < 0 ? length + end : end),
  );
  @override
  void clear() => _length = 0;
  @override
  void flush() {}
}
