import 'dart:convert';
import 'dart:io' as io;
import 'dart:typed_data';

import 'package:archive/archive.dart';

/// Physical records without encoder coalescing or header corrections.
final class RawZipEntry {
  RawZipEntry(
    this.name,
    List<int> content, {
    this.method = 0,
    int? declaredSize,
    int? crc,
    List<int>? compressed,
    this.flags = 0,
    this.localFlags,
    this.localMethod,
    this.mode = 0,
    this.localExtra = const [],
    this.centralExtra = const [],
    this.comment = const [],
    this.zip64Local = false,
    this.zip64Central = 0,
  }) : content = Uint8List.fromList(content),
       declaredSize = declaredSize ?? content.length,
       crc = crc ?? getCrc32(content),
       compressed = Uint8List.fromList(
         compressed ??
             (method == 8
                 ? io.ZLibEncoder(raw: true).convert(content)
                 : content),
       );

  final String name;
  final Uint8List content;
  final Uint8List compressed;
  final int method;
  final int declaredSize;
  final int crc;
  final int flags;
  final int? localFlags;
  final int? localMethod;
  final int mode;
  final List<int> localExtra;
  final List<int> centralExtra;
  final List<int> comment;
  final bool zip64Local;

  /// Sentinel mask: expanded (1), compressed (2), offset (4), disk (8).
  final int zip64Central;

  Uint8List localHeader() {
    final nameBytes = utf8.encode(name);
    final extra = [
      if (zip64Local)
        ...zip64Extra(
          expanded: flags & 8 == 0 ? declaredSize : 0,
          compressed: flags & 8 == 0 ? compressed.length : 0,
        ),
      ...localExtra,
    ];
    final out = OutputMemoryStream()
      ..writeUint32(0x04034b50)
      ..writeUint16(zip64Local ? 45 : 20)
      ..writeUint16(localFlags ?? flags)
      ..writeUint16(localMethod ?? method)
      ..writeUint32(0)
      ..writeUint32(flags & 8 == 0 ? crc : 0)
      ..writeUint32(
        zip64Local ? 0xffffffff : (flags & 8 == 0 ? compressed.length : 0),
      )
      ..writeUint32(
        zip64Local ? 0xffffffff : (flags & 8 == 0 ? declaredSize : 0),
      )
      ..writeUint16(nameBytes.length)
      ..writeUint16(extra.length)
      ..writeBytes(nameBytes)
      ..writeBytes(extra);
    return out.getBytes();
  }

  Uint8List centralHeader(int offset) {
    final nameBytes = utf8.encode(name);
    final extra = [
      if (zip64Central != 0)
        ...zip64Extra(
          expanded: zip64Central & 1 != 0 ? declaredSize : null,
          compressed: zip64Central & 2 != 0 ? compressed.length : null,
          offset: zip64Central & 4 != 0 ? offset : null,
          disk: zip64Central & 8 != 0 ? 0 : null,
        ),
      ...centralExtra,
    ];
    final out = OutputMemoryStream()
      ..writeUint32(0x02014b50)
      ..writeUint16(0x0314)
      ..writeUint16(zip64Central != 0 ? 45 : 20)
      ..writeUint16(flags)
      ..writeUint16(method)
      ..writeUint32(0)
      ..writeUint32(crc)
      ..writeUint32(zip64Central & 2 != 0 ? 0xffffffff : compressed.length)
      ..writeUint32(zip64Central & 1 != 0 ? 0xffffffff : declaredSize)
      ..writeUint16(nameBytes.length)
      ..writeUint16(extra.length)
      ..writeUint16(comment.length)
      ..writeUint16(zip64Central & 8 != 0 ? 0xffff : 0)
      ..writeUint16(0)
      ..writeUint32(mode << 16)
      ..writeUint32(zip64Central & 4 != 0 ? 0xffffffff : offset)
      ..writeBytes(nameBytes)
      ..writeBytes(extra)
      ..writeBytes(comment);
    return out.getBytes();
  }
}

Uint8List rawZip(
  List<RawZipEntry> entries, {
  List<int> archiveComment = const [],
  bool descriptorSignature = true,
  bool zip64End = false,
  bool endSentinels = true,
  List<int> zip64Extensible = const [],
}) {
  final data = OutputMemoryStream();
  final directory = OutputMemoryStream();
  for (final entry in entries) {
    directory.writeBytes(entry.centralHeader(data.length));
    data
      ..writeBytes(entry.localHeader())
      ..writeBytes(entry.compressed);
    if (entry.flags & 8 != 0) {
      if (descriptorSignature) data.writeUint32(0x08074b50);
      data.writeUint32(entry.crc);
      if (entry.zip64Local) {
        data
          ..writeUint64(entry.compressed.length)
          ..writeUint64(entry.declaredSize);
      } else {
        data
          ..writeUint32(entry.compressed.length)
          ..writeUint32(entry.declaredSize);
      }
    }
  }
  final offset = data.length;
  data.writeBytes(directory.getBytes());
  if (zip64End) {
    final target = data.length;
    data
      ..writeUint32(0x06064b50)
      ..writeUint64(44 + zip64Extensible.length)
      ..writeUint16(45)
      ..writeUint16(45)
      ..writeUint32(0)
      ..writeUint32(0)
      ..writeUint64(entries.length)
      ..writeUint64(entries.length)
      ..writeUint64(directory.length)
      ..writeUint64(offset)
      ..writeBytes(zip64Extensible)
      ..writeUint32(0x07064b50)
      ..writeUint32(0)
      ..writeUint64(target)
      ..writeUint32(1);
  }
  final sentinel = zip64End && endSentinels;
  data
    ..writeUint32(0x06054b50)
    ..writeUint32(0)
    ..writeUint16(sentinel ? 0xffff : entries.length)
    ..writeUint16(sentinel ? 0xffff : entries.length)
    ..writeUint32(sentinel ? 0xffffffff : directory.length)
    ..writeUint32(sentinel ? 0xffffffff : offset)
    ..writeUint16(archiveComment.length)
    ..writeBytes(archiveComment);
  return data.getBytes();
}

List<int> zip64Extra({int? expanded, int? compressed, int? offset, int? disk}) {
  final data = OutputMemoryStream();
  if (expanded != null) data.writeUint64(expanded);
  if (compressed != null) data.writeUint64(compressed);
  if (offset != null) data.writeUint64(offset);
  if (disk != null) data.writeUint32(disk);
  return (OutputMemoryStream()
        ..writeUint16(1)
        ..writeUint16(data.length)
        ..writeBytes(data.getBytes()))
      .getBytes();
}

/// Review regression: 107,053 bytes used to retain 60 MB of copied local extras.
Uint8List aliasedMetadataZip({
  int entries = 1000,
  int extraBytes = 60000,
  bool zip64 = false,
}) {
  final entry = RawZipEntry(
    'x',
    [],
    localExtra: Uint8List(extraBytes),
    zip64Local: zip64,
    zip64Central: zip64 ? 7 : 0,
  );
  final out = OutputMemoryStream()..writeBytes(entry.localHeader());
  final start = out.length;
  final central = entry.centralHeader(0);
  for (var i = 0; i < entries; i++) {
    out.writeBytes(central);
  }
  out
    ..writeUint32(0x06054b50)
    ..writeUint32(0)
    ..writeUint16(entries)
    ..writeUint16(entries)
    ..writeUint32(entries * central.length)
    ..writeUint32(start)
    ..writeUint16(0);
  return out.getBytes();
}
