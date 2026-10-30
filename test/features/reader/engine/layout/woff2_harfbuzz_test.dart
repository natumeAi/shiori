import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/engine/layout/woff2_decoder.dart';

import '../../../../../tool/reader/harfbuzz_probe_ffi.dart';
import '../../../../../tool/reader/harfbuzz_probe_shape.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final reason = !Platform.isWindows || !File(harfBuzzProbeLibrary).existsSync()
      ? 'Existing Windows HarfBuzz host module is absent; no download attempted.'
      : null;
  test(
    'converted WOFF2 glyph IDs, advances and clusters equal SFNT in HarfBuzz',
    () {
      final api = HbApi();
      final ledger = HbLedger();
      final reference = HbShaper(
        api,
        ledger,
        File('tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf')
            .readAsBytesSync(),
      );
      final expected = reference.shape('Ab fi e\u0301 Z');
      try {
        for (final path in [
          'test/fixtures/reader/fixed_layout/Roboto-Regular.woff2',
          'test/fixtures/reader/fonts/roboto-transformed.woff2',
        ]) {
          final font = const Woff2Decoder().decode(
            File(path).readAsBytesSync(),
          );
          final shaper = HbShaper(api, ledger, font.bytes);
          final actual = shaper.shape('Ab fi e\u0301 Z');
          try {
            expect(actual.width, 72.763671875);
            expect(actual.width, expected.width);
            expect(
              actual.glyphs.map(
                (g) => [g.id, g.cluster, g.advance, g.xOffset, g.yOffset],
              ),
              expected.glyphs.map(
                (g) => [g.id, g.cluster, g.advance, g.xOffset, g.yOffset],
              ),
            );
          } finally {
            actual.close();
            shaper.close();
            font.dispose();
          }
        }
      } finally {
        expected.close();
        reference.close();
      }
      expect(ledger.live.values, everyElement(0));
      expect(ledger.bytes.values, everyElement(0));
    },
    skip: reason,
  );
}
