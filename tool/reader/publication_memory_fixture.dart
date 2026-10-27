// Streaming synthetic EPUB generator for the standalone host RSS experiment.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../test/features/reader/data/worker/import_test_support.dart';

const publicationMemoryImageEntries = 200;
const publicationMemoryPreloadedEntries = 4;
const publicationMemoryPreloadedImageBytes = 104857;

void writePublicationMemoryFixture(
  String path, {
  required int unreadImageBytes,
}) {
  const count = publicationMemoryImageEntries;
  final small = importEntries(
    sources: [
      sourcePage(
        body: [
          for (var i = 0; i < publicationMemoryPreloadedEntries; i++)
            '<img src="image-$i.png"/>',
        ].join(),
      ),
    ],
  );
  // The loader discovers resources across the whole spine. Keep the extra
  // images in a manifest-listed supplementary section outside that spine so
  // neither prepare nor preload requests their payloads. Both sizes have the
  // same OPF, section bytes, names and entry count.
  small['EPUB/supplement.xhtml'] = sourcePage(
    body: [
      for (var i = publicationMemoryPreloadedEntries; i < count; i++)
        '<img src="image-$i.png"/>',
    ].join(),
  );
  small['EPUB/package.opf'] = small['EPUB/package.opf']!.replaceFirst(
    '</manifest>',
    '<item id="supplement" href="supplement.xhtml" '
        'media-type="application/xhtml+xml"/>'
        '${[for (var i = 0; i < count; i++) '<item id="i$i" href="image-$i.png" media-type="image/png"/>'].join()}</manifest>',
  );
  // Preserve a valid tiny PNG prefix and pad only the encoded payload. This
  // experiment measures encoded access; it never claims image decode coverage.
  final archive = ZipDecoder().decodeBytes(importZip(small));
  final prefix = archive.findFile('EPUB/page.png')!.content;
  final preloadedImage = Uint8List(publicationMemoryPreloadedImageBytes)
    ..setAll(0, prefix);
  final unreadImage = Uint8List(unreadImageBytes)..setAll(0, prefix);
  final output = OutputFileStream(path);
  final directory = OutputMemoryStream();
  var entries = 0;
  void add(String name, List<int> bytes) {
    entries++;
    final encodedName = utf8.encode(name);
    final crc = getCrc32(bytes);
    final offset = output.length;
    output
      ..writeUint32(0x04034b50)
      ..writeUint16(20)
      ..writeUint16(0)
      ..writeUint16(0)
      ..writeUint32(0)
      ..writeUint32(crc)
      ..writeUint32(bytes.length)
      ..writeUint32(bytes.length)
      ..writeUint16(encodedName.length)
      ..writeUint16(0)
      ..writeBytes(encodedName)
      ..writeBytes(bytes);
    directory
      ..writeUint32(0x02014b50)
      ..writeUint16(20)
      ..writeUint16(20)
      ..writeUint16(0)
      ..writeUint16(0)
      ..writeUint32(0)
      ..writeUint32(crc)
      ..writeUint32(bytes.length)
      ..writeUint32(bytes.length)
      ..writeUint16(encodedName.length)
      ..writeUint16(0)
      ..writeUint16(0)
      ..writeUint16(0)
      ..writeUint16(0)
      ..writeUint32(0)
      ..writeUint32(offset)
      ..writeBytes(encodedName);
  }

  try {
    for (final entry in archive.files) {
      if (entry.isFile) add(entry.name, entry.content);
    }
    for (var i = 0; i < count; i++) {
      add(
        'EPUB/image-$i.png',
        i < publicationMemoryPreloadedEntries ? preloadedImage : unreadImage,
      );
    }
    final offset = output.length;
    output
      ..writeBytes(directory.getBytes())
      ..writeUint32(0x06054b50)
      ..writeUint32(0)
      ..writeUint16(entries)
      ..writeUint16(entries)
      ..writeUint32(directory.length)
      ..writeUint32(offset)
      ..writeUint16(0);
  } finally {
    output.closeSync();
  }
}
