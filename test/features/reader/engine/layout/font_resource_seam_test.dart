import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';

/// Avoid allocating a 32 MiB test font: verify the declared-size preflight
/// occurs before any bytes are requested, including at the exact cap.
final class _FontSource implements ReaderResourceSource {
  _FontSource(this.length, this.value);
  final int length;
  final Uint8List? value;
  int reads = 0;
  int sizes = 0;
  @override
  Uint8List? bytes(String path) {
    reads++;
    return value;
  }

  @override
  int size(String path) {
    sizes++;
    return length;
  }

  @override
  bool contains(String path) => value != null;
  @override
  void dispose() {}
}

void main() {
  const faces = [StyleFontFace(family: 'Fixture', archivePath: 'font.ttf')];
  test(
    '32 MiB font cap checks declared size before reading through the seam',
    () async {
      final registry = FontRegistry();
      expect(registry.maxFontBytes, 32 * 1024 * 1024);
      final source = _FontSource(registry.maxFontBytes + 1, Uint8List(12));
      expect(
        await registry.loadResources(source, faces, scope: 'oversize'),
        isEmpty,
      );
      expect(source.sizes, 1);
      expect(source.reads, 0);
      expect(registry.records.single.loaded, isFalse);
      expect(registry.records.single.failure, 'FontFormatException');
    },
  );

  test('exact-cap invalid font is read and falls back; absent font also falls back', () async {
    final exact = _FontSource(32 * 1024 * 1024, Uint8List(12));
    final registry = FontRegistry();
    expect(await registry.loadResources(exact, faces, scope: 'exact'), isEmpty);
    expect(exact.reads, 1);
    expect(registry.records.single.loaded, isFalse);
    final missing = _FontSource(0, null);
    expect(
      await registry.loadResources(missing, faces, scope: 'missing'),
      isEmpty,
    );
    expect(missing.sizes, 1);
    expect(missing.reads, 1);
    expect(
      registry.records.every(
        (record) => record.failure == 'FontFormatException',
      ),
      isTrue,
    );
  });
}
