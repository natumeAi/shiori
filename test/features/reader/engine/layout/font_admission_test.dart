import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_budget.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/layout/font_format.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/layout/scene_resource_budget.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';

final class _Source implements ReaderResourceSource {
  _Source(this.value);
  final Uint8List value;
  @override
  Uint8List bytes(String path) => value;
  @override
  bool contains(String path) => true;
  @override
  int size(String path) => value.length;
  @override
  void dispose() {}
}

const _sfntPath = 'tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf';
const _woffPath = 'test/fixtures/reader/fixed_layout/Roboto-Regular.woff';
const _faces = [StyleFontFace(family: 'Author', archivePath: 'font')];

double _width(String alias) {
  final builder = ui.ParagraphBuilder(
    ui.ParagraphStyle(
      fontFamily: alias,
      fontSize: 20,
      textDirection: ui.TextDirection.ltr,
    ),
  );
  builder.addText('Ab fi e\u0301 Z');
  final paragraph = builder.build()
    ..layout(const ui.ParagraphConstraints(width: 1000));
  final width = paragraph.maxIntrinsicWidth;
  paragraph.dispose();
  return width;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'two registries coalesce pending bytes/face across CSS aliases and books',
    () async {
      final budget = ProcessFontBudget();
      final gate = Completer<void>();
      var registrations = 0;
      Future<void> register(Uint8List bytes, String alias) {
        registrations++;
        expect(budget.pendingFaces, 1);
        expect(budget.pendingBytes, bytes.length);
        return gate.future;
      }

      final first = FontRegistry(processBudget: budget, register: register);
      final second = FontRegistry(processBudget: budget, register: register);
      final source = _Source(File(_sfntPath).readAsBytesSync());
      final a = first.loadResources(source, _faces, scope: 'book-a');
      final b = second.loadResources(source, const [
        StyleFontFace(family: 'Other', archivePath: 'other'),
      ], scope: 'book-b');
      expect(registrations, 1);
      gate.complete();
      expect((await a)['author'], (await b)['other']);
      expect(budget.registeredFaces, 1);
      expect(first.records.single.alias, startsWith('shiori-face-'));
    },
  );

  test(
    'process exhaustion propagates even in reflow; required failure is typed',
    () async {
      final registry = FontRegistry(
        processBudget: ProcessFontBudget(maxBytes: 1),
      );
      await expectLater(
        registry.loadResources(
          _Source(File(_sfntPath).readAsBytesSync()),
          _faces,
          scope: 'limit',
        ),
        throwsA(
          isA<SceneAdmissionException>().having(
            (e) => e.failure,
            'failure',
            SceneAdmissionFailure.processFontExhausted,
          ),
        ),
      );
      final bad = _Source(Uint8List(12));
      expect(
        await registry.loadResources(bad, _faces, scope: 'fallback'),
        isEmpty,
      );
      await expectLater(
        registry.loadResources(
          bad,
          _faces,
          scope: 'fallback',
          requiredFonts: true,
        ),
        throwsA(
          isA<RequiredFontException>().having(
            (e) => e.cause,
            'cause',
            isA<FontFormatException>(),
          ),
        ),
      );
      final native = FontRegistry(
        processBudget: ProcessFontBudget(),
        register: (_, _) async => throw StateError('native'),
      );
      await expectLater(
        native.loadResources(
          _Source(File(_sfntPath).readAsBytesSync()),
          _faces,
          scope: 'required',
          requiredFonts: true,
        ),
        throwsA(isA<RequiredFontException>()),
      );
      expect(native.processBudget.uncertainFaces, 1);
    },
  );

  test(
    'converted WOFF shapes like pinned SFNT and differs from absent family',
    () async {
      final budget = ProcessFontBudget();
      final registry = FontRegistry(processBudget: budget);
      // Register and shape the converted bytes before loading the SFNT control.
      final woff = await registry.loadResources(
        _Source(File(_woffPath).readAsBytesSync()),
        _faces,
        scope: 'woff',
        requiredFonts: true,
      );
      final woffWidth = _width(woff['author']!);
      final sfnt = await registry.loadResources(
        _Source(File(_sfntPath).readAsBytesSync()),
        _faces,
        scope: 'sfnt',
        requiredFonts: true,
      );
      final sfntWidth = _width(sfnt['author']!);
      final absentWidth = _width('shiori-absent-a3-control');
      expect(woffWidth, closeTo(sfntWidth, 0.0001));
      expect((woffWidth - absentWidth).abs(), greaterThan(1));
      // ignore: avoid_print
      print('A3 shaping: WOFF=$woffWidth SFNT=$sfntWidth absent=$absentWidth');
    },
  );

  test(
    'canceling one WOFF waiter retains physical conversion and other consumer',
    () async {
      final encoded = ReaderResourceBudget();
      final process = ProcessFontBudget();
      final gate = Completer<void>();
      final token = PublicationCancellation();
      final registry = FontRegistry(
        processBudget: process,
        conversionBudget: encoded,
        register: (_, _) => gate.future,
      );
      final source = _Source(File(_woffPath).readAsBytesSync());
      final a = registry.loadResources(
        source,
        _faces,
        scope: 'a',
        cancellation: token,
      );
      final aCheck = expectLater(a, throwsA(isA<ProcessFontLoadCanceled>()));
      final b = registry.loadResources(source, _faces, scope: 'b');
      token.cancel();
      await aCheck;
      expect(encoded.reservedBytes, greaterThan(0));
      expect(process.pendingFaces, 1);
      gate.complete();
      expect(await b, isNotEmpty);
      expect(encoded.accountedBytes, 0);
      expect(process.registeredFaces, 1);
    },
  );

  test('WOFF2 remains a typed unsupported format before native work', () async {
    final registry = FontRegistry(
      processBudget: ProcessFontBudget(),
      register: (_, _) async => fail('WOFF2 crossed native boundary'),
    );
    final bytes = File('test/fixtures/reader/fixed_layout/Roboto-Regular.woff2')
        .readAsBytesSync();
    await expectLater(
      registry.loadResources(
        _Source(bytes),
        _faces,
        scope: 'woff2',
        requiredFonts: true,
      ),
      throwsA(
        isA<RequiredFontException>().having(
          (e) => e.cause,
          'cause',
          isA<FontFormatException>().having(
            (e) => e.failure,
            'failure',
            FontFormatFailure.unsupportedFormat,
          ),
        ),
      ),
    );
    expect(registry.processBudget.faces, 0);
  });
}
