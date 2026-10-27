// Streaming synthetic EPUB generator for the standalone host RSS experiment.
import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../../test/features/reader/data/worker/import_test_support.dart';

void writePublicationMemoryFixture(String path) {
  const count = 200;
  const mib = 1024 * 1024;
  final small = importEntries(
    sources: [
      sourcePage(
        body: [for (var i = 0; i < 4; i++) '<img src="image-$i.png"/>'].join(),
      ),
    ],
  );
  small['EPUB/package.opf'] = small['EPUB/package.opf']!.replaceFirst(
    '</manifest>',
    '${[for (var i = 0; i < count; i++) '<item id="i$i" href="image-$i.png" media-type="image/png"/>'].join()}</manifest>',
  );
  // Preserve a valid tiny PNG prefix and pad the encoded entry to 1 MiB. This
  // experiment measures encoded access; it never claims image decode coverage.
  final image = Uint8List(mib);
  final archive = ZipDecoder().decodeBytes(importZip(small));
  image.setAll(0, archive.findFile('EPUB/page.png')!.content);
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
      add('EPUB/image-$i.png', image);
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
