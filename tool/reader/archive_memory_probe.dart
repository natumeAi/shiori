// Manual host experiment: dart run tool/reader/archive_memory_probe.dart
// Each measurement runs in a fresh process; never run by flutter test.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';

import '../../test/features/reader/data/epub/raw_zip_test_support.dart';

const _mib = 1024 * 1024;

Future<void> main(List<String> args) async {
  if (args.length == 3 && args.first == '--measure') {
    _measure(args[1], args[2]);
    return;
  }
  final temp = Directory.systemTemp.createTempSync('shiori-archive-rss-');
  try {
    stdout.writeln(
      'Host ${Platform.operatingSystem}; Dart ${Platform.version.split(' ').first}',
    );
    for (final count in [20, 200]) {
      final file = File('${temp.path}/generated-$count.zip');
      _writeStoredArchive(file.path, count);
      stdout.writeln(
        'Generated ${file.lengthSync()} bytes ($count x 1 MiB stored entries)',
      );
      for (final mode in ['file', 'memory']) {
        final result = await Process.run(Platform.resolvedExecutable, [
          'run',
          Platform.script.toFilePath(),
          '--measure',
          file.path,
          mode,
        ]);
        stdout.write(result.stdout);
        if (result.exitCode != 0) {
          stderr.write(result.stderr);
          throw StateError('RSS measurement failed: ${result.exitCode}');
        }
      }
      file.deleteSync();
    }
    for (final entries in [1000, 20000]) {
      final file = File('${temp.path}/aliased-$entries.zip')
        ..writeAsBytesSync(aliasedMetadataZip(entries: entries));
      stdout.writeln(
        'Generated ${file.lengthSync()} bytes ($entries aliased local headers, '
        '60000-byte local extra)',
      );
      for (final mode in ['hostile-file', 'hostile-memory']) {
        final result = await Process.run(Platform.resolvedExecutable, [
          'run',
          Platform.script.toFilePath(),
          '--measure',
          file.path,
          mode,
        ]);
        stdout.write(result.stdout);
        if (result.exitCode != 0) {
          stderr.write(result.stderr);
          throw StateError(
            'Hostile RSS measurement failed: ${result.exitCode}',
          );
        }
      }
      file.deleteSync();
    }
  } finally {
    temp.deleteSync(recursive: true);
    stdout.writeln('Temporary archives deleted.');
  }
}

void _measure(String path, String mode) {
  // Warm the directory/read/checksum paths without retaining a large archive.
  final warm = EpubArchive.open(
    Uint8List.fromList(
      ZipEncoder().encode(
        Archive()..addFile(ArchiveFile('warm', 1024, Uint8List(1024))),
      ),
    ),
  );
  warm.bytes('warm');
  warm.close();
  final baseline = ProcessInfo.currentRss;
  if (mode.startsWith('hostile-')) {
    final baselineMax = ProcessInfo.maxRss;
    try {
      const limits = EpubLimits(maxEntryBytes: 0, maxTotalBytes: 0);
      final archive = mode == 'hostile-file'
          ? EpubArchive.openFile(path, limits: limits)
          : EpubArchive.open(File(path).readAsBytesSync(), limits: limits);
      archive.close();
      throw StateError('Hostile metadata archive was admitted');
    } on ParseException {
      final afterRejection = ProcessInfo.currentRss;
      stdout.writeln(
        jsonEncode({
          'mode': mode,
          'archiveBytes': File(path).lengthSync(),
          'rejectedAtOpen': true,
          'baselineRss': baseline,
          'rejectionRss': afterRejection,
          'rejectionDelta': afterRejection - baseline,
          'baselineMaxRss': baselineMax,
          'processMaxRss': ProcessInfo.maxRss,
        }),
      );
    }
    return;
  }
  final archive = mode == 'file'
      ? EpubArchive.openFile(path)
      : EpubArchive.open(File(path).readAsBytesSync());
  final afterOpen = ProcessInfo.currentRss;
  var sampledBytes = 0;
  try {
    final names = archive.names.toList();
    for (final index in {0, names.length ~/ 2, names.length - 1}) {
      final data = archive.bytes(names[index])!;
      if (data.length != _mib || data[123] != 123) {
        throw StateError('Generated sample did not round trip');
      }
      sampledBytes += data.length;
    }
    final afterReads = ProcessInfo.currentRss;
    stdout.writeln(
      jsonEncode({
        'mode': mode,
        'archiveBytes': File(path).lengthSync(),
        'entries': names.length,
        'sampledBytes': sampledBytes,
        'baselineRss': baseline,
        'openRss': afterOpen,
        'openDelta': afterOpen - baseline,
        'sampleRss': afterReads,
        'sampleDelta': afterReads - baseline,
        'processMaxRss': ProcessInfo.maxRss,
      }),
    );
  } finally {
    archive.close();
  }
}

// Stream one reused 1 MiB block to disk. Never construct the 200 MiB ZIP in
// the parent process's memory; only its small central directory is retained.
void _writeStoredArchive(String path, int count) {
  final block = Uint8List.fromList(List.generate(_mib, (i) => i & 255));
  final crc = getCrc32(block);
  final output = OutputFileStream(path);
  final directory = OutputMemoryStream();
  try {
    for (var i = 0; i < count; i++) {
      final name = utf8.encode('entry-$i');
      final offset = output.length;
      output
        ..writeUint32(0x04034b50)
        ..writeUint16(20)
        ..writeUint16(0)
        ..writeUint16(0)
        ..writeUint32(0)
        ..writeUint32(crc)
        ..writeUint32(block.length)
        ..writeUint32(block.length)
        ..writeUint16(name.length)
        ..writeUint16(0)
        ..writeBytes(name)
        ..writeBytes(block);
      directory
        ..writeUint32(0x02014b50)
        ..writeUint16(20)
        ..writeUint16(20)
        ..writeUint16(0)
        ..writeUint16(0)
        ..writeUint32(0)
        ..writeUint32(crc)
        ..writeUint32(block.length)
        ..writeUint32(block.length)
        ..writeUint16(name.length)
        ..writeUint16(0)
        ..writeUint16(0)
        ..writeUint16(0)
        ..writeUint16(0)
        ..writeUint32(0)
        ..writeUint32(offset)
        ..writeBytes(name);
    }
    final offset = output.length;
    output
      ..writeBytes(directory.getBytes())
      ..writeUint32(0x06054b50)
      ..writeUint32(0)
      ..writeUint16(count)
      ..writeUint16(count)
      ..writeUint32(directory.length)
      ..writeUint32(offset)
      ..writeUint16(0);
  } finally {
    output.closeSync();
  }
}
