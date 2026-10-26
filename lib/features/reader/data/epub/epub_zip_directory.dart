part of 'epub_archive.dart';

typedef _ZipRecord = ({
  int central,
  int offset,
  int end,
  int compressed,
  int expanded,
});

/// Reads only fixed fields and bounded views until the entire ZIP is admitted.
/// No strings, extras, payload buffers or package ZIP objects are hydrated here.
final class _ZipDirectoryReader {
  _ZipDirectoryReader(this.input, this.limits);

  final InputStream input;
  final EpubLimits limits;
  var _metadata = 0;

  List<_ZipRecord> validate() {
    // EOCD plus its maximum 16-bit archive comment; no whole-file reverse scan.
    final tailStart = max(0, input.totalLength - 22 - 65535);
    final tail = _view(tailStart, input.totalLength - tailStart).toUint8List();
    final bytes = ByteData.sublistView(tail);
    var end = -1;
    for (var i = tail.length - 22; i >= 0; i--) {
      if (bytes.getUint32(i, Endian.little) == ZipDirectory.eocdSignature &&
          bytes.getUint16(i + 20, Endian.little) == tail.length - i - 22) {
        end = tailStart + i;
        break;
      }
    }
    if (end < 0) throw const FormatException('Missing ZIP directory');
    final (:count, :size, :start, boundary: directoryEnd) = _directory(end);
    if (count == 0 ||
        count > limits.maxEntries ||
        size > limits.maxDirectoryBytes ||
        start > directoryEnd ||
        size > directoryEnd - start) {
      throw const FormatException('Invalid ZIP directory bounds');
    }
    if (directoryEnd - start - size >= 4 &&
        _view(start + size, 4).readUint32() ==
            ZipDirectory.zip64EocdSignature) {
      throw const FormatException('Missing ZIP64 locator');
    }
    return _entries(start, size, count);
  }

  ({int count, int size, int start, int boundary}) _directory(int end) {
    final eocd = _view(end + 4, 18);
    final disk = eocd.readUint16();
    final startDisk = eocd.readUint16();
    final diskCount = eocd.readUint16();
    final count = eocd.readUint16();
    final size = eocd.readUint32();
    final start = eocd.readUint32();
    _charge(eocd.readUint16());
    final locatorPosition = end - 20;
    if (locatorPosition < 0 ||
        _view(locatorPosition, 4).readUint32() !=
            ZipDirectory.zip64EocdLocatorSignature) {
      if (disk != 0 ||
          startDisk != 0 ||
          diskCount != count ||
          count == 0xffff ||
          size == 0xffffffff ||
          start == 0xffffffff) {
        throw const FormatException('Invalid ZIP directory or missing ZIP64');
      }
      return (count: count, size: size, start: start, boundary: end);
    }
    final locator = _view(locatorPosition + 4, 16);
    final locatorDisk = locator.readUint32();
    final target = _uint64(locator);
    if (locatorDisk != 0 ||
        locator.readUint32() != 1 ||
        target > locatorPosition - 56) {
      throw const FormatException('Invalid ZIP64 locator');
    }
    final record = _view(target, locatorPosition - target);
    if (record.readUint32() != ZipDirectory.zip64EocdSignature) {
      throw const FormatException('Missing ZIP64 directory');
    }
    final recordSize = _uint64(record);
    if (recordSize < 44 || recordSize != record.length) {
      throw const FormatException('Invalid ZIP64 directory length');
    }
    _charge(recordSize - 44);
    record.skip(4);
    final resolvedDisk = record.readUint32();
    final resolvedStartDisk = record.readUint32();
    final resolvedDiskCount = _uint64(record);
    final resolvedCount = _uint64(record);
    final resolvedSize = _uint64(record);
    final resolvedStart = _uint64(record);
    if (resolvedDisk != 0 ||
        resolvedStartDisk != 0 ||
        resolvedDiskCount != resolvedCount ||
        !_matches(disk, resolvedDisk, 0xffff) ||
        !_matches(startDisk, resolvedStartDisk, 0xffff) ||
        !_matches(diskCount, resolvedDiskCount, 0xffff) ||
        !_matches(count, resolvedCount, 0xffff) ||
        !_matches(size, resolvedSize, 0xffffffff) ||
        !_matches(start, resolvedStart, 0xffffffff)) {
      throw const FormatException('Inconsistent ZIP64 directory');
    }
    return (
      count: resolvedCount,
      size: resolvedSize,
      start: resolvedStart,
      boundary: target,
    );
  }

  List<_ZipRecord> _entries(int start, int size, int count) {
    final raw = _view(start, size);
    final records = <_ZipRecord>[];
    final offsets = <int>{};
    final ranges = <({int start, int end})>[];
    var total = 0;
    while (!raw.isEOS) {
      if (records.length >= count || raw.length < 46) {
        throw const FormatException('Invalid ZIP entry count');
      }
      final central = start + raw.position;
      if (raw.readUint32() != ZipFileHeader.signature) {
        throw const FormatException('Invalid ZIP directory header');
      }
      raw.skip(4);
      final flags = raw.readUint16();
      final method = raw.readUint16();
      _checkEncoding(flags, method);
      raw.skip(8);
      var compressed = raw.readUint32();
      var expanded = raw.readUint32();
      final name = raw.readUint16();
      final extra = raw.readUint16();
      final comment = raw.readUint16();
      var entryDisk = raw.readUint16();
      raw.skip(6);
      var offset = raw.readUint32();
      _charge(name + extra + comment);
      if (name + extra + comment > raw.length) {
        throw const FormatException('Truncated ZIP directory header');
      }
      raw.skip(name);
      final resolved = _extra(
        raw.readBytes(extra),
        expanded: expanded,
        compressed: compressed,
        offset: offset,
        disk: entryDisk,
      );
      compressed = resolved.compressed;
      expanded = resolved.expanded;
      offset = resolved.offset;
      entryDisk = resolved.disk;
      if (expanded > limits.maxEntryBytes ||
          expanded > limits.maxTotalBytes - total ||
          entryDisk != 0) {
        throw const FormatException('ZIP expansion exceeds bounds');
      }
      total += expanded; // Counts overwritten physical entries as well.
      raw.skip(comment);
      if (!offsets.add(offset)) {
        throw const FormatException('Aliased ZIP local header');
      }
      final end = _localEnd(offset, start, compressed, method);
      ranges.add((start: offset, end: end));
      records.add((
        central: central,
        offset: offset,
        end: end,
        compressed: compressed,
        expanded: expanded,
      ));
    }
    if (records.length != count) {
      throw const FormatException('Invalid ZIP entry count');
    }
    ranges.sort((a, b) => a.start.compareTo(b.start));
    for (var i = 1; i < ranges.length; i++) {
      if (ranges[i].start < ranges[i - 1].end) {
        throw const FormatException('Overlapping ZIP entries');
      }
    }
    return records;
  }

  int _localEnd(int offset, int central, int compressed, int method) {
    if (offset > central - 30) {
      throw const FormatException('Invalid ZIP local header offset');
    }
    final local = _view(offset, central - offset);
    if (local.readUint32() != ZipFile.zipSignature) {
      throw const FormatException('Invalid ZIP local header');
    }
    local.skip(2);
    final flags = local.readUint16();
    final localMethod = local.readUint16();
    _checkEncoding(flags, localMethod);
    if (localMethod != method) {
      throw const FormatException('Inconsistent ZIP compression');
    }
    local.skip(8);
    final localCompressed = local.readUint32();
    final localExpanded = local.readUint32();
    final name = local.readUint16();
    final extra = local.readUint16();
    _charge(name + extra);
    if (name + extra > local.length ||
        compressed > local.length - name - extra) {
      throw const FormatException('Truncated ZIP entry data');
    }
    local.skip(name);
    final resolved = _extra(
      local.readBytes(extra),
      expanded: localExpanded,
      compressed: localCompressed,
    );
    if (resolved.expanded > limits.maxEntryBytes ||
        resolved.expanded > limits.maxTotalBytes ||
        resolved.compressed > central - offset - local.position) {
      throw const FormatException('Invalid ZIP local sizes');
    }
    var end = offset + local.position + compressed;
    // ZipFile.read also reads a descriptor at hydration. Keep that read inside
    // this entry's disjoint range, including the optional four-byte signature.
    if (flags & 8 != 0) {
      final descriptorSize = resolved.zip64 ? 20 : 12;
      if (central - end < descriptorSize) {
        throw const FormatException('Truncated ZIP descriptor');
      }
      final signed = _view(end, 4).readUint32() == 0x08074b50;
      end += descriptorSize + (signed ? 4 : 0);
      if (end > central) {
        throw const FormatException('Truncated ZIP descriptor');
      }
    }
    return end;
  }

  InputStream _view(int start, int length) {
    if (start < 0 ||
        length < 0 ||
        start > input.totalLength ||
        length > input.totalLength - start) {
      throw const FormatException('Invalid ZIP range');
    }
    return input.subset(position: start, length: length);
  }

  void _charge(int bytes) {
    if (bytes > limits.maxMetadataBytes - _metadata) {
      throw const FormatException('ZIP metadata exceeds bounds');
    }
    _metadata += bytes;
  }

  ({int expanded, int compressed, int offset, int disk, bool zip64}) _extra(
    InputStream extra, {
    required int expanded,
    required int compressed,
    int offset = 0,
    int disk = 0,
  }) {
    final needExpanded = expanded == 0xffffffff;
    final needCompressed = compressed == 0xffffffff;
    final needOffset = offset == 0xffffffff;
    final needDisk = disk == 0xffff;
    var zip64 = false;
    // Match the package's tolerance for trailing or truncated unknown extras,
    // but ZIP64 payloads and all fields required by sentinels must be complete.
    while (extra.length >= 4) {
      final id = extra.readUint16();
      final length = extra.readUint16();
      if (id != 1) {
        extra.skip(min(length, extra.length));
        continue;
      }
      if (zip64 || length > extra.length) {
        throw const FormatException('Invalid ZIP64 extra field');
      }
      zip64 = true;
      final data = extra.readBytes(length);
      if (needExpanded) expanded = _uint64(data);
      if (needCompressed) compressed = _uint64(data);
      if (needOffset) offset = _uint64(data);
      if (needDisk) {
        if (data.length < 4) {
          throw const FormatException('Missing ZIP64 disk field');
        }
        disk = data.readUint32();
      }
    }
    if (!zip64 && (needExpanded || needCompressed || needOffset || needDisk)) {
      throw const FormatException('Missing ZIP64 extra field');
    }
    return (
      expanded: expanded,
      compressed: compressed,
      offset: offset,
      disk: disk,
      zip64: zip64,
    );
  }

  static bool _matches(int legacy, int resolved, int sentinel) =>
      legacy == sentinel || legacy == resolved;

  static int _uint64(InputStream data) {
    if (data.length < 8) {
      throw const FormatException('Truncated ZIP64 field');
    }
    final low = data.readUint32();
    final high = data.readUint32();
    // Dart native ints are signed. Reject before arithmetic can wrap negative.
    if (high > 0x7fffffff) {
      throw const FormatException('ZIP64 field exceeds bounds');
    }
    return high * 0x100000000 + low;
  }

  static void _checkEncoding(int flags, int method) {
    if (flags & 0x41 != 0) throw const FormatException('Encrypted ZIP entry');
    if (method != 0 && method != 8) {
      throw const FormatException('Unsupported ZIP compression');
    }
  }
}
