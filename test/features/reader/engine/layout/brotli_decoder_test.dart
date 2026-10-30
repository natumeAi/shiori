import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:crypto/crypto.dart';
import 'package:shiori/features/reader/engine/layout/brotli_decoder.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';

const root = 'test/fixtures/reader/fonts/';
const dictionaryText =
    'time down life left back code data show only site city open just like '
    'free work text year over body love form book play live line help home '
    'side more word long them view find page days full head term each area '
    'from true mark able upon high date land news even next case both post '
    'used made hand here what name. The quick brown fox jumps over the lazy '
    'dog. THE QUICK BROWN FOX. Compression and transformation of the information. ';

Uint8List vectorInput(String kind) => Uint8List.fromList(switch (kind) {
  'dictionary' => utf8.encode(dictionaryText),
  'repeat' => List.generate(16384, (i) => i & 255),
  'mixed' => utf8.encode(
    'Hello, world! Καλημέρα 世界 café — Brotli dictionary and context models.\n' *
        600,
  ),
  'random' => File('${root}random.bin').readAsBytesSync(),
  _ => throw StateError(kind),
});

Matcher failure(FontFormatFailure value) => throwsA(
  isA<FontFormatException>().having((e) => e.failure, 'failure', value),
);

void main() {
  Uint8List hex(String s) => Uint8List.fromList([
    for (var i = 0; i < s.length; i += 2)
      int.parse(s.substring(i, i + 2), radix: 16),
  ]);
  final vectors = jsonDecode(
    File('${root}brotli-vectors.json').readAsStringSync(),
  ) as List<dynamic>;
  for (final dynamic entry in vectors) {
    final v = entry as Map<String, dynamic>;
    test('Brotli 1.2.0 ${v['file']} byte equality', () {
      final source = File('$root${v['file']}').readAsBytesSync();
      final expected = vectorInput(v['kind'] as String);
      expect(expected.length, v['size']);
      expect(sha256.convert(expected).toString(), v['sha256']);
      expect(
        const BrotliDecoder().decode(source, exactOutputBytes: expected.length),
        expected,
      );
      expect(
        BrotliDecoder(maxOutputBytes: expected.length + 10).decode(source),
        expected,
      );
    });
  }
  test('Roboto stream has exact declared size', () {
    final woff = File('test/fixtures/reader/fixed_layout/Roboto-Regular.woff2')
        .readAsBytesSync();
    final size = ByteData.sublistView(woff).getUint32(20);
    final result = const BrotliDecoder().decode(
      Uint8List.sublistView(woff, 97, 97 + size),
      exactOutputBytes: 171363,
    );
    expect(result.length, 171363);
    expect(
      sha256.convert(result).toString(),
      'e352319f73b29d722f92528eb4fb1b6ca51a6f05ab10eef31668fb3d27ed5fab',
    );
  });
  test('all 121 static dictionary transforms match native Brotli oracle', () {
    final vectors = jsonDecode(
      File('${root}dictionary-transforms.json').readAsStringSync(),
    ) as List;
    expect(vectors, hasLength(121));
    for (final v in vectors) {
      final output = hex(v['output'] as String);
      expect(
        const BrotliDecoder().decode(
          hex(v['br'] as String),
          exactOutputBytes: output.length,
        ),
        output,
        reason: 'transform ${v['transform']}',
      );
    }
  });
  final structural = jsonDecode(
    File('${root}brotli-structure.json').readAsStringSync(),
  ) as List;
  for (final v in structural) {
    test('Brotli structure ${v['name']} matches native oracle', () {
      final output = hex(v['output'] as String);
      expect(
        const BrotliDecoder().decode(
          hex(v['br'] as String),
          exactOutputBytes: output.length,
        ),
        output,
      );
    });
  }
  test('truncation, trailing input and output bounds fail typed', () {
    final source = File('${root}repeat-q11-w24.br').readAsBytesSync();
    for (var i = 0; i < source.length; i++) {
      expect(
        () => const BrotliDecoder().decode(
          Uint8List.sublistView(source, 0, i),
          exactOutputBytes: 16384,
        ),
        throwsA(isA<FontFormatException>()),
        reason: 'prefix $i',
      );
    }
    expect(
      () => const BrotliDecoder().decode(
        Uint8List.fromList([...source, 0]),
        exactOutputBytes: 16384,
      ),
      failure(FontFormatFailure.malformed),
    );
    expect(
      () => const BrotliDecoder().decode(source, exactOutputBytes: 16383),
      failure(FontFormatFailure.limitExceeded),
    );
    expect(
      () => const BrotliDecoder().decode(source, exactOutputBytes: 16385),
      failure(FontFormatFailure.malformed),
    );
    expect(
      () =>
          const BrotliDecoder(maxOutputBytes: 100)
              .decode(source, exactOutputBytes: 101),
      failure(FontFormatFailure.limitExceeded),
    );
    expect(
      () => const BrotliDecoder(maxInputBytes: 1).decode(source),
      failure(FontFormatFailure.limitExceeded),
    );
    expect(
      const BrotliDecoder(maxOutputBytes: 0).decode(Uint8List.fromList([6])),
      isEmpty,
    );
    expect(
      () => const BrotliDecoder().decode(Uint8List.fromList([0x11])),
      failure(FontFormatFailure.malformed),
    ); // reserved WBITS=9
  });
}
