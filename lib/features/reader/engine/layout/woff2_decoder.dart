import 'dart:typed_data';

import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/engine/layout/brotli_decoder.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';
import 'package:shiori/features/reader/engine/layout/woff_decoder.dart';

part 'woff2_binary.dart';
part 'woff2_directory.dart';
part 'woff2_glyf.dart';
part 'woff2_points.dart';
part 'woff2_metrics.dart';

/// W3C WOFF2 2.0 single-face conversion, with pure Dart RFC 7932 decoding.
/// Both temporary reconstruction storage and the SFNT buffer are admitted
/// before allocation. Only the SFNT charge survives conversion.
final class Woff2Decoder {
  const Woff2Decoder({
    this.maxBytes = 32 * 1024 * 1024,
    this.maxTableBytes = 16 * 1024 * 1024,
    this.maxTables = 128,
  });
  final int maxBytes, maxTableBytes, maxTables;

  ConvertedFont decode(Uint8List source, {ReaderResourceBudget? budget}) {
    final directory = _Directory(source, maxBytes, maxTableBytes, maxTables);
    final owner = (budget ?? ReaderResourceBudget.shared).createSession();
    ReaderResourceReservation? temporary, scratchCharge;
    try {
      temporary = owner.reserve({'woff2-stream': directory.streamSize});
      final stream = BrotliDecoder(maxOutputBytes: maxBytes).decode(
        Uint8List.sublistView(
          source,
          directory.streamOffset,
          directory.streamOffset + directory.compressedSize,
        ),
        exactOutputBytes: directory.streamSize,
      );
      final head = directory.table('head');
      if (head == null || head.size < 54) throw _malformed;
      final glyf = directory.table('glyf'), loca = directory.table('loca');
      final hmtx = directory.table('hmtx');
      _GlyphScratch? scratch;
      int? indexFormat;
      if ((glyf?.transformed ?? false) || (hmtx?.transformed ?? false)) {
        final maxp = directory.table('maxp');
        if (maxp == null || maxp.size < 6) throw _malformed;
        final count = ByteData.sublistView(maxp.view(stream)).getUint16(4);
        scratchCharge = owner.reserve({
          'woff2-glyph-work': _GlyphScratch.byteSize(count),
        });
        scratch = _GlyphScratch(count);
      }
      for (final t in directory.tables) {
        t.outputSize = t.original;
      }
      if (glyf?.transformed ?? false) {
        final reconstruction = _Glyf(
          glyf!.view(stream),
          scratch!,
          maxTableBytes,
        );
        indexFormat = reconstruction.indexFormat;
        if (ByteData.sublistView(head.view(stream)).getInt16(50) !=
            indexFormat) {
          throw _malformed;
        }
        glyf.outputSize = reconstruction.run();
        loca!.outputSize =
            (reconstruction.count + 1) * (indexFormat == 0 ? 2 : 4);
        if (loca.outputSize != loca.original) throw _malformed;
      }
      var length = 12 + directory.tables.length * 16;
      final tables = directory.tables.toList()
        ..sort((a, b) => a.tag.compareTo(b.tag));
      for (final t in tables) {
        if (t.outputSize > maxTableBytes) throw _limit;
        t.offset = length;
        length += sfntPaddedLength(t.outputSize);
        if (length > maxBytes) throw _limit;
      }
      owner.reserve({'sfnt': length});
      final bytes = Uint8List(length);
      final output = ByteData.sublistView(bytes);
      final count = tables.length;
      final selector = count.bitLength - 1;
      output.setUint32(0, directory.flavor);
      output.setUint16(4, count);
      output.setUint16(6, (1 << selector) * 16);
      output.setUint16(8, selector);
      output.setUint16(10, count * 16 - (1 << selector) * 16);
      Uint8List target(_Table t) =>
          Uint8List.sublistView(bytes, t.offset, t.offset + t.outputSize);
      for (final t in tables) {
        if (!t.transformed) target(t).setAll(0, t.view(stream));
      }
      if (glyf?.transformed ?? false) {
        _Glyf(glyf!.view(stream), scratch!, maxTableBytes).run(target(glyf));
        final loc = _Writer(loca!.outputSize, target(loca));
        for (final at in scratch.locations) {
          if (indexFormat == 0) {
            loc.u16(at >> 1);
          } else {
            loc.u32(at);
          }
        }
        output.setUint16(head.offset + 50, indexFormat!);
      }
      if (hmtx?.transformed ?? false) {
        if (glyf == null || loca == null) throw _malformed;
        if (!glyf.transformed) {
          _readXMin(target(glyf), target(loca), target(head), scratch!);
        }
        final hhea = directory.table('hhea');
        if (hhea == null || hhea.size < 36) throw _malformed;
        final metrics = ByteData.sublistView(hhea.view(stream)).getUint16(34);
        _hmtx(hmtx!.view(stream), target(hmtx), metrics, scratch!.xMin);
      }
      output.setUint32(head.offset + 8, 0);
      for (var i = 0; i < tables.length; i++) {
        final t = tables[i], at = 12 + i * 16;
        output.setUint32(at, t.tag);
        output.setUint32(at + 4, sfntChecksum(target(t)));
        output.setUint32(at + 8, t.offset);
        output.setUint32(at + 12, t.outputSize);
      }
      output.setUint32(
        head.offset + 8,
        (0xb1b0afba - sfntChecksum(bytes)) & 0xffffffff,
      );
      return ConvertedFont.admitted(bytes, owner);
    } on Object {
      owner.retire();
      rethrow;
    } finally {
      scratchCharge?.dispose();
      temporary?.dispose();
    }
  }
}
