import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart' as zip;
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/reader/data/epub/epub_archive.dart';
import 'package:shiori/features/reader/data/source/reader_work_guard.dart';

import 'raw_zip_test_support.dart';

void main() {
  final parseFailure = throwsA(isA<ParseException>());
  for (final fileBacked in [false, true]) {
    group(fileBacked ? 'file-backed ZIP' : 'memory ZIP', () {
      late Directory temp;
      var fileNumber = 0;
      final opened = <EpubArchive>[];
      setUp(() => temp = Directory.systemTemp.createTempSync('shiori-zip-'));
      tearDown(() {
        for (final archive in opened) {
          archive.close();
        }
        opened.clear();
        temp.deleteSync(recursive: true);
      });

      EpubArchive open(
        Uint8List bytes, {
        EpubLimits limits = const EpubLimits(),
      }) {
        final EpubArchive archive;
        if (fileBacked) {
          final file = File('${temp.path}/input-${fileNumber++}.zip')
            ..writeAsBytesSync(bytes);
          archive = EpubArchive.openFile(file.path, limits: limits);
        } else {
          archive = EpubArchive.open(bytes, limits: limits);
        }
        opened.add(archive);
        return archive;
      }

      test('last duplicate supplies bytes and size; names are exact', () {
        final archive = open(
          rawZip([
            RawZipEntry('x', utf8.encode('first'), method: 8),
            RawZipEntry('X', [7]),
            RawZipEntry('x', utf8.encode('last')),
          ]),
        );
        expect(archive.names, ['x', 'X']);
        expect(archive.size('x'), 4);
        expect(archive.text('x'), 'last');
        expect(archive.bytes('X'), [7]);
        expect(archive.contains('missing'), isFalse);
        expect(archive.size('missing'), 0);
        expect(archive.bytes('missing'), isNull);
      });

      test('every duplicate counts toward entry and total limits', () {
        final bytes = rawZip([
          RawZipEntry('x', [1, 2]),
          RawZipEntry('x', [3, 4]),
        ]);
        expect(
          () => open(bytes, limits: const EpubLimits(maxEntries: 1)),
          parseFailure,
        );
        expect(
          () => open(bytes, limits: const EpubLimits(maxTotalBytes: 3)),
          parseFailure,
        );
        expect(
          open(
            bytes,
            limits: const EpubLimits(maxEntries: 2, maxTotalBytes: 4),
          ).bytes('x'),
          [3, 4],
        );
      });

      test('entry count and declared sizes fail before expansion', () {
        final broken = RawZipEntry(
          'x',
          [],
          method: 8,
          compressed: [255],
          declaredSize: 3,
        );
        expect(
          () => open(
            rawZip([broken]),
            limits: const EpubLimits(maxEntryBytes: 2),
          ),
          parseFailure,
        );
        expect(
          () => open(
            rawZip([broken, broken]),
            limits: const EpubLimits(maxEntries: 1),
          ),
          parseFailure,
        );
        expect(
          () => open(
            rawZip([broken, broken]),
            limits: const EpubLimits(maxTotalBytes: 5),
          ),
          parseFailure,
        );
      });

      test('archive byte limit is checked before ZIP parsing', () {
        expect(
          () =>
              open(Uint8List(10), limits: const EpubLimits(maxArchiveBytes: 9)),
          parseFailure,
        );
      });

      for (final method in [0, 8]) {
        test(
          'method $method reads correctly including empty and descriptor entries',
          () {
            final content = List.generate(100000, (i) => i % 251);
            final archive = open(
              rawZip([
                RawZipEntry('x', content, method: method),
                RawZipEntry('empty', [], method: method),
                RawZipEntry('descriptor', [1, 2, 3], method: method, flags: 8),
              ]),
            );
            expect(archive.bytes('x'), content);
            expect(archive.bytes('empty'), isEmpty);
            expect(archive.bytes('descriptor'), [1, 2, 3]);
            expect(archive.bytes('x'), content); // repeated lazy reads
          },
        );

        test('method $method rejects too much output before accumulation', () {
          // Much more than the 7-byte sink. A post-expansion length check would
          // accumulate all 8 MiB; this must stop on the first oversized write.
          final archive = open(
            rawZip([
              RawZipEntry(
                'x',
                Uint8List(8 * 1024 * 1024),
                method: method,
                declaredSize: 7,
              ),
            ]),
            limits: const EpubLimits(maxEntryBytes: 7, maxTotalBytes: 7),
          );
          expect(() => archive.bytes('x'), parseFailure);
        });

        test('method $method rejects shorter output and CRC mismatch', () {
          final archive = open(
            rawZip([
              RawZipEntry('short', [1, 2], method: method, declaredSize: 3),
              RawZipEntry('crc', [3, 4], method: method, crc: 123),
            ]),
          );
          expect(() => archive.bytes('short'), parseFailure);
          expect(() => archive.bytes('crc'), parseFailure);
        });
      }

      test('truncated and empty compressed data fail recoverably', () {
        final entry = RawZipEntry(
          'x',
          utf8.encode('hello hello hello'),
          method: 8,
        );
        final archive = open(
          rawZip([
            RawZipEntry(
              'truncated',
              entry.content,
              method: 8,
              compressed: entry.compressed.sublist(0, 3),
            ),
            RawZipEntry(
              'empty',
              [],
              method: 8,
              compressed: [],
              declaredSize: 4,
            ),
            RawZipEntry('empty-zero', [], method: 8, compressed: []),
          ]),
        );
        expect(() => archive.bytes('truncated'), parseFailure);
        expect(() => archive.bytes('empty'), parseFailure);
        expect(() => archive.bytes('empty-zero'), parseFailure);
      });

      test('every proper compressed prefix fails or returns exact content', () {
        final entry = RawZipEntry(
          'x',
          utf8.encode('hello hello hello'),
          method: 8,
        );
        for (var length = 0; length < entry.compressed.length; length++) {
          final archive = open(
            rawZip([
              RawZipEntry(
                'x',
                entry.content,
                method: 8,
                compressed: entry.compressed.sublist(0, length),
              ),
            ]),
          );
          final Uint8List? data;
          try {
            data = archive.bytes('x');
          } on ParseException {
            continue;
          }
          final reason = 'compressed prefix $length/${entry.compressed.length}';
          expect(data, entry.content, reason: reason);
          expect(data!.length, entry.declaredSize, reason: reason);
          expect(zip.getCrc32(data), entry.crc, reason: reason);
        }
      });

      test(
        'native accepts missing zero-output final byte with verified content',
        () {
          final entry = RawZipEntry(
            'x',
            utf8.encode('hello hello hello'),
            method: 8,
          );
          final prefix = entry.compressed.sublist(
            0,
            entry.compressed.length - 1,
          );
          final archive = open(
            rawZip([
              RawZipEntry('x', entry.content, method: 8, compressed: prefix),
              RawZipEntry(
                'short',
                entry.content,
                method: 8,
                compressed: prefix,
                declaredSize: entry.content.length + 1,
              ),
              RawZipEntry(
                'crc',
                entry.content,
                method: 8,
                compressed: prefix,
                crc: 123,
              ),
            ]),
          );
          final data = archive.bytes('x')!;
          expect(data, entry.content);
          expect(data.length, entry.declaredSize);
          expect(zip.getCrc32(data), entry.crc);
          expect(() => archive.bytes('short'), parseFailure);
          expect(() => archive.bytes('crc'), parseFailure);
        },
      );

      test('valid level-1 deflate of repeated zero bytes round trips', () {
        final content = Uint8List(1024);
        final compressed = ZLibEncoder(raw: true, level: 1).convert(content);
        final archive = open(
          rawZip([
            RawZipEntry('x', content, method: 8, compressed: compressed),
          ]),
        );
        expect(archive.bytes('x'), content);
      });

      test(
        'symlink expansion is untouched at open; links are ordinary bytes',
        () {
          final archive = open(
            rawZip([
              RawZipEntry(
                'bomb',
                Uint8List(1024 * 1024),
                method: 8,
                mode: 0xa1ff,
                declaredSize: 1,
              ),
              RawZipEntry('link', utf8.encode('target'), mode: 0xa1ff),
              RawZipEntry('target', [9]),
            ]),
          );
          expect(archive.names, ['bomb', 'link', 'target']);
          expect(archive.text('link'), 'target');
          expect(() => archive.bytes('bomb'), parseFailure);
        },
      );

      test('unknown methods and encryption in either header are rejected', () {
        for (final entry in [
          RawZipEntry('x', [], method: 12),
          RawZipEntry('x', [], method: 99),
          RawZipEntry('x', [], flags: 1),
          RawZipEntry('x', [], localFlags: 1),
          RawZipEntry('x', [], flags: 0x40),
          RawZipEntry('x', [], localMethod: 8),
        ]) {
          expect(() => open(rawZip([entry])), parseFailure);
        }
      });

      test('aliased local extras fail at open with zero expansion limits', () {
        final hostile = aliasedMetadataZip();
        expect(hostile.length, 107053);
        expect(
          () => open(
            hostile,
            limits: const EpubLimits(maxEntryBytes: 0, maxTotalBytes: 0),
          ),
          parseFailure,
        );
        // The default physical-entry ceiling must not multiply the local extra.
        expect(() => open(aliasedMetadataZip(entries: 20000)), parseFailure);
      });

      test('directory and all variable metadata have independent budgets', () {
        final bytes = rawZip(
          [
            RawZipEntry(
              'x',
              [],
              localExtra: Uint8List(7),
              centralExtra: Uint8List(9),
              comment: Uint8List(11),
            ),
          ],
          archiveComment: [1, 2, 3],
        );
        // Central fixed header 46 + name 1 + extra 9 + comment 11 = 67.
        // Variable bytes: local 8 + central 21 + archive comment 3 = 32.
        expect(
          open(
            bytes,
            limits: const EpubLimits(
              maxDirectoryBytes: 67,
              maxMetadataBytes: 32,
            ),
          ).bytes('x'),
          isEmpty,
        );
        expect(
          () => open(
            bytes,
            limits: const EpubLimits(
              maxDirectoryBytes: 66,
              maxMetadataBytes: 32,
            ),
          ),
          parseFailure,
        );
        expect(
          () => open(
            bytes,
            limits: const EpubLimits(
              maxDirectoryBytes: 67,
              maxMetadataBytes: 31,
            ),
          ),
          parseFailure,
        );
        final duplicates = rawZip([
          RawZipEntry('x', [], localExtra: Uint8List(32)),
          RawZipEntry('x', [], localExtra: Uint8List(32)),
        ]);
        expect(
          () =>
              open(duplicates, limits: const EpubLimits(maxMetadataBytes: 67)),
          parseFailure,
        );
        expect(
          open(
            duplicates,
            limits: const EpubLimits(maxMetadataBytes: 68),
          ).bytes('x'),
          isEmpty,
        );
      });

      test('overlapping local headers, data and directory are rejected', () {
        final nested = RawZipEntry('z', [3]);
        final bytes = rawZip([
          RawZipEntry('x', [...nested.localHeader(), ...nested.compressed]),
          RawZipEntry('y', [2]),
        ]);
        final central = ByteData.sublistView(bytes)
            .getUint32(bytes.length - 6, Endian.little);
        for (final mutate in <void Function(ByteData)>[
          // Second header inside the first entry's data, with a valid signature.
          (v) => v.setUint32(central + 47 + 42, 31, Endian.little),
          // First data range crosses the next local header.
          (v) => v.setUint32(central + 20, 33, Endian.little),
          // First data range crosses the central directory.
          (v) => v.setUint32(central + 20, central - 30, Endian.little),
          // Hydration would read a descriptor from the next local header.
          (v) => v.setUint16(6, 8, Endian.little),
        ]) {
          final corrupt = Uint8List.fromList(bytes);
          mutate(ByteData.sublistView(corrupt));
          expect(() => open(corrupt), parseFailure);
        }
      });

      test('local offsets must precede the directory and stay in the ZIP', () {
        final bytes = rawZip([RawZipEntry('x', [])]);
        final central = 31;
        for (final offset in [
          central - 29,
          central,
          bytes.length,
          0xfffffffe,
        ]) {
          final corrupt = Uint8List.fromList(bytes);
          ByteData.sublistView(corrupt)
              .setUint32(central + 42, offset, Endian.little);
          expect(() => open(corrupt), parseFailure);
        }
      });

      test('unsigned descriptors and reverse directory order stay valid', () {
        final bytes = rawZip([
          RawZipEntry('x', [1], flags: 8),
          RawZipEntry('x', [2], flags: 8),
        ], descriptorSignature: false);
        expect(open(bytes).bytes('x'), [2]);
        final central = ByteData.sublistView(bytes)
            .getUint32(bytes.length - 6, Endian.little);
        final first = bytes.sublist(central, central + 47);
        bytes.setRange(
          central,
          central + 47,
          bytes.sublist(central + 47, central + 94),
        );
        bytes.setRange(central + 47, central + 94, first);
        expect(open(bytes).bytes('x'), [1]);
      });

      test('EOCD search is bounded and respects archive comment framing', () {
        final comment = Uint8List(65535);
        ByteData.sublistView(comment).setUint32(0, 0x06054b50, Endian.little);
        expect(
          open(
            rawZip([
              RawZipEntry('x', [1]),
            ], archiveComment: comment),
          ).bytes('x'),
          [1],
        );
        final corrupt = rawZip([RawZipEntry('x', [])]);
        ByteData.sublistView(corrupt)
            .setUint16(corrupt.length - 2, 1, Endian.little);
        expect(() => open(corrupt), parseFailure);
      });

      test('ZIP64 missing required fields and malformed end records fail', () {
        final bytes = rawZip([RawZipEntry('x', [])]);
        final end = bytes.length - 22;
        const central = 31;
        final cases = <Uint8List>[];
        for (final mutate in <void Function(ByteData)>[
          (v) => v.setUint16(end + 8, 0xffff, Endian.little),
          (v) => v.setUint16(end + 10, 0xffff, Endian.little),
          (v) => v.setUint32(end + 12, 0xffffffff, Endian.little),
          (v) => v.setUint32(end + 16, 0xffffffff, Endian.little),
          (v) => v.setUint32(central + 20, 0xffffffff, Endian.little),
          (v) => v.setUint32(central + 24, 0xffffffff, Endian.little),
          (v) => v.setUint16(central + 34, 0xffff, Endian.little),
          (v) => v.setUint32(central + 42, 0xffffffff, Endian.little),
          (v) => v.setUint32(18, 0xffffffff, Endian.little),
          (v) => v.setUint32(22, 0xffffffff, Endian.little),
        ]) {
          final corrupt = Uint8List.fromList(bytes);
          mutate(ByteData.sublistView(corrupt));
          cases.add(corrupt);
        }
        // A bare locator or record without a valid target/locator is malformed.
        for (final signature in [0x07064b50, 0x06064b50]) {
          final gap = Uint8List(signature == 0x07064b50 ? 20 : 56);
          ByteData.sublistView(gap).setUint32(0, signature, Endian.little);
          cases.add(
            Uint8List.fromList([
              ...bytes.sublist(0, end),
              ...gap,
              ...bytes.sublist(end),
            ]),
          );
        }
        for (final corrupt in cases) {
          expect(
            () => open(corrupt),
            throwsA(
              isA<ParseException>().having(
                (e) => e.cause.toString(),
                'content-free cause',
                'FormatException: Invalid ZIP: FormatException',
              ),
            ),
          );
        }
      });

      test('ZIP64 local repack of one-page EPUB preserves all entry bytes', () {
        final source = File('assets/reader_fixtures/one-page.epub')
            .readAsBytesSync();
        final original = open(source);
        final directory = zip.ZipDirectory()
          ..read(zip.InputMemoryStream(source));
        expect(directory.fileHeaders, hasLength(6));
        expect(directory.fileHeaders.first.filename, 'mimetype');
        final repacked = rawZip([
          for (final header in directory.fileHeaders)
            RawZipEntry(
              header.filename,
              original.bytes(header.filename)!,
              method: header.compressionMethod,
              compressed: header.file!.getRawContent(),
              zip64Local: header.filename != 'mimetype',
            ),
        ]);
        expect(repacked, hasLength(2230));
        final archive = open(repacked);
        expect(archive.names, original.names);
        for (final name in original.names) {
          expect(archive.size(name), original.size(name));
          expect(archive.bytes(name), original.bytes(name), reason: name);
        }
      });

      test('ZIP64 central fields resolve only the selected sentinels', () {
        for (var mask = 0; mask < 16; mask++) {
          for (final local in [false, true]) {
            final archive = open(
              rawZip(
                [
                  RawZipEntry(
                    'x',
                    [1, 2, 3],
                    method: 8,
                    zip64Local: local,
                    zip64Central: mask,
                  ),
                ],
                zip64End: true,
                endSentinels: mask.isEven,
              ),
            );
            expect(archive.size('x'), 3);
            expect(archive.bytes('x'), [1, 2, 3]);
          }
        }
        // ID 1 alone is valid when no field in its header is a sentinel.
        expect(
          open(
            rawZip([
              RawZipEntry(
                'x',
                [4],
                localExtra: zip64Extra(),
                centralExtra: zip64Extra(),
              ),
            ]),
          ).bytes('x'),
          [4],
        );
        // Central-only extras also work without ZIP64 end records.
        expect(
          open(
            rawZip([
              RawZipEntry('x', [5], zip64Central: 15),
            ]),
          ).bytes('x'),
          [5],
        );
      });

      test('ZIP64 local extras follow each size sentinel independently', () {
        for (var mask = 0; mask < 4; mask++) {
          final bytes = rawZip([
            RawZipEntry(
              'x',
              [6],
              localExtra: zip64Extra(
                expanded: mask & 1 != 0 ? 1 : null,
                compressed: mask & 2 != 0 ? 1 : null,
              ),
            ),
          ]);
          final fields = ByteData.sublistView(bytes);
          if (mask & 1 != 0) fields.setUint32(22, 0xffffffff, Endian.little);
          if (mask & 2 != 0) fields.setUint32(18, 0xffffffff, Endian.little);
          expect(open(bytes).bytes('x'), [6]);
        }
      });

      test('ZIP64 signed and unsigned descriptors occupy their full range', () {
        for (final signed in [false, true]) {
          final archive = open(
            rawZip(
              [
                RawZipEntry(
                  'x',
                  [7],
                  zip64Local: true,
                  zip64Central: 3,
                  flags: 8,
                ),
                RawZipEntry('y', [8], zip64Local: true, flags: 8),
              ],
              descriptorSignature: signed,
              zip64End: true,
            ),
          );
          expect(archive.bytes('x'), [7]);
          expect(archive.bytes('y'), [8]);
        }
      });

      test(
        'malformed ZIP64 records, extras and unbounded values fail at open',
        () {
          final valid = rawZip([
            RawZipEntry(
              'private-entry-marker',
              [1],
              zip64Local: true,
              zip64Central: 15,
            ),
          ], zip64End: true);
          final record = valid.length - 98;
          final locator = valid.length - 42;
          final end = valid.length - 22;
          final central = ByteData.sublistView(valid)
              .getUint64(record + 48, Endian.little);
          final localExtra = 30 + 'private-entry-marker'.length;
          final centralExtra = central + 46 + 'private-entry-marker'.length;
          for (final mutate in <void Function(ByteData)>[
            (v) => v.setUint64(locator + 8, valid.length, Endian.little),
            (v) => v.setUint64(locator + 8, central, Endian.little),
            (v) => v.setUint32(locator + 4, 1, Endian.little),
            (v) => v.setUint32(locator + 16, 2, Endian.little),
            (v) => v.setUint32(record, 0, Endian.little),
            (v) => v.setUint64(record + 4, 43, Endian.little),
            (v) => v.setUint64(record + 4, 45, Endian.little),
            (v) => v.setUint64(record + 4, 0x100000000, Endian.little),
            (v) => v.setUint32(record + 16, 1, Endian.little),
            (v) => v.setUint32(record + 20, 1, Endian.little),
            (v) => v.setUint64(record + 24, 2, Endian.little),
            (v) => v.setUint64(record + 24, 0x100000001, Endian.little),
            (v) => v.setUint64(record + 32, 20001, Endian.little),
            (v) => v.setUint64(record + 40, valid.length, Endian.little),
            (v) => v.setUint64(record + 48, valid.length, Endian.little),
            (v) => v.setUint64(record + 48, 0x100000000, Endian.little),
            (v) => v.setUint32(record + 52, 0x80000000, Endian.little),
            (v) => v.setUint16(end + 10, 2, Endian.little),
            (v) => v.setUint32(end + 12, 0, Endian.little),
            (v) => v.setUint32(end + 16, 0, Endian.little),
            (v) => v.setUint16(centralExtra, 2, Endian.little),
            (v) => v.setUint16(centralExtra + 2, 27, Endian.little),
            (v) => v.setUint16(centralExtra + 2, 29, Endian.little),
            (v) => v.setUint64(centralExtra + 4, 0x100000000, Endian.little),
            (v) => v.setUint32(centralExtra + 8, 0x80000000, Endian.little),
            (v) => v.setUint64(centralExtra + 12, valid.length, Endian.little),
            (v) => v.setUint64(centralExtra + 20, central, Endian.little),
            (v) => v.setUint64(centralExtra + 20, 0x100000000, Endian.little),
            (v) => v.setUint32(centralExtra + 28, 1, Endian.little),
            (v) => v.setUint16(localExtra, 2, Endian.little),
            (v) => v.setUint16(localExtra + 2, 15, Endian.little),
            (v) => v.setUint16(localExtra + 2, 17, Endian.little),
            (v) => v.setUint64(localExtra + 4, 0x100000000, Endian.little),
            (v) => v.setUint64(localExtra + 12, valid.length, Endian.little),
          ]) {
            final corrupt = Uint8List.fromList(valid);
            mutate(ByteData.sublistView(corrupt));
            expect(
              () => open(corrupt),
              throwsA(
                isA<ParseException>().having(
                  (e) => e.cause.toString(),
                  'content-free cause',
                  'FormatException: Invalid ZIP: FormatException',
                ),
              ),
            );
          }
        },
      );

      test(
        'ZIP64 aliases, overlaps and directory crossing fail before hydration',
        () {
          for (final count in [1000, 20000]) {
            expect(
              () => open(
                aliasedMetadataZip(entries: count, zip64: true),
                limits: const EpubLimits(maxEntryBytes: 0, maxTotalBytes: 0),
              ),
              parseFailure,
            );
          }
          final nested = RawZipEntry('z', [3]);
          final valid = rawZip([
            RawZipEntry(
              'x',
              [...nested.localHeader(), ...nested.compressed],
              zip64Local: true,
              zip64Central: 7,
            ),
            RawZipEntry('y', [2], zip64Local: true, zip64Central: 7),
          ], zip64End: true);
          final central = ByteData.sublistView(valid)
              .getUint64(valid.length - 50, Endian.little);
          for (final mutate in <void Function(ByteData)>[
            // Alias; nested header; data overlapping next header or directory.
            (v) => v.setUint64(central + 75 + 67, 0, Endian.little),
            (v) => v.setUint64(central + 75 + 67, 51, Endian.little),
            (v) => v.setUint64(central + 59, 33, Endian.little),
            (v) => v.setUint64(central + 59, central - 50, Endian.little),
            // ZIP64 descriptor would consume the following local header.
            (v) => v.setUint16(6, 8, Endian.little),
          ]) {
            final corrupt = Uint8List.fromList(valid);
            mutate(ByteData.sublistView(corrupt));
            expect(() => open(corrupt), parseFailure);
          }
        },
      );

      test('ZIP64 fields obey entry, total, count and metadata budgets', () {
        final entries = [
          RawZipEntry('x', [1, 2], zip64Local: true, zip64Central: 7),
          RawZipEntry('x', [3, 4], zip64Local: true, zip64Central: 7),
        ];
        final bytes = rawZip(
          entries,
          zip64End: true,
          zip64Extensible: [1, 2, 3],
        );
        const exact = EpubLimits(
          maxEntryBytes: 2,
          maxTotalBytes: 4,
          maxEntries: 2,
          maxDirectoryBytes: 150,
          maxMetadataBytes: 103,
        );
        expect(open(bytes, limits: exact).bytes('x'), [3, 4]);
        for (final limits in [
          const EpubLimits(maxEntries: 1),
          const EpubLimits(maxEntryBytes: 1),
          const EpubLimits(maxTotalBytes: 3),
          const EpubLimits(maxDirectoryBytes: 149),
          const EpubLimits(maxMetadataBytes: 102),
        ]) {
          expect(() => open(bytes, limits: limits), parseFailure);
        }
        // The extensible sector alone cannot evade the variable metadata cap.
        expect(
          () => open(
            rawZip(entries, zip64End: true, zip64Extensible: Uint8List(104)),
            limits: exact,
          ),
          parseFailure,
        );
      });

      test('bad directory signatures, lengths, counts and offsets fail', () {
        final valid = rawZip([
          RawZipEntry('x', [1]),
          RawZipEntry('y', [2]),
        ]);
        final view = ByteData.sublistView(valid);
        final end = valid.length - 22;
        final central = view.getUint32(end + 16, Endian.little);
        for (final mutation in <void Function(ByteData)>[
          (v) => v.setUint32(central, 0, Endian.little),
          (v) => v.setUint32(central + 47, 0, Endian.little),
          (v) => v.setUint16(central + 28, 65535, Endian.little),
          (v) => v.setUint16(end + 10, 1, Endian.little),
          (v) => v.setUint32(end + 12, 93, Endian.little),
          (v) => v.setUint32(end + 16, 0xffffffff, Endian.little),
          (v) => v.setUint32(central + 42, 0xfffffffe, Endian.little),
          (v) => v.setUint32(0, 0, Endian.little),
          (v) => v.setUint32(central + 20, 0xfffffffe, Endian.little),
          (v) => v.setUint16(end + 4, 1, Endian.little),
        ]) {
          final corrupt = Uint8List.fromList(valid);
          mutation(ByteData.sublistView(corrupt));
          expect(() => open(corrupt), parseFailure);
        }
        expect(() => open(Uint8List.fromList([1, 2, 3])), parseFailure);
        expect(() => open(valid.sublist(0, valid.length - 10)), parseFailure);
      });
    });
  }

  test(
    'file-backed and memory reads agree; close releases the shared handle',
    () {
      final temp = Directory.systemTemp.createTempSync('shiori-zip-close-');
      final file = File('${temp.path}/input.zip');
      final bytes = rawZip([
        RawZipEntry('x', [1, 2, 3], method: 8),
        RawZipEntry('x', [4, 5]),
        RawZipEntry('y', [6, 7], method: 8),
      ]);
      file.writeAsBytesSync(bytes);
      final memory = EpubArchive.open(bytes);
      final disk = EpubArchive.openFile(file.path);
      try {
        expect(disk.names, memory.names);
        for (final name in disk.names) {
          expect(disk.size(name), memory.size(name));
          expect(disk.bytes(name), memory.bytes(name));
        }
        disk.close();
        disk.close();
        expect(() => disk.bytes('x'), parseFailure);
        file.deleteSync(); // Windows must no longer have an open handle.
        expect(file.existsSync(), isFalse);
        memory.close(); // Deliberately a no-op for probe/test compatibility.
        expect(memory.bytes('x'), [4, 5]);
      } finally {
        disk.close();
        temp.deleteSync(recursive: true);
      }
    },
  );

  test('failed file opens release handles and redact filesystem paths', () {
    final temp = Directory.systemTemp.createTempSync('shiori-zip-failure-');
    try {
      final file = File('${temp.path}/input.zip')..writeAsBytesSync([1, 2, 3]);
      expect(() => EpubArchive.openFile(file.path), parseFailure);
      file.deleteSync();
      expect(() => EpubArchive.openFile(file.path), parseFailure);
    } finally {
      temp.deleteSync(recursive: true);
    }
  });

  test('file open and close retain reader callback guards', () {
    expect(
      () => ReaderWorkGuard.callback(() => EpubArchive.openFile('unused')),
      throwsAssertionError,
    );
    final memory = EpubArchive.open(rawZip([RawZipEntry('x', [])]));
    expect(() => ReaderWorkGuard.callback(memory.close), throwsAssertionError);
  });
}
