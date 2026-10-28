import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/resources/reader_resource_source.dart';
import 'package:shiori/features/reader/data/worker/publication_cancellation.dart';
import 'package:shiori/features/reader/engine/layout/font_mapping.dart';
import 'package:shiori/features/reader/engine/layout/font_registry.dart';
import 'package:shiori/features/reader/engine/layout/process_font_budget.dart';
import 'package:shiori/features/reader/engine/style/computed_style.dart';
import 'package:shiori/features/reader/engine/style/style_resolver.dart';

final class _Resources implements ReaderResourceSource {
  final bytesValue = File(
    'tool/oracle/fixtures/styles/EPUB/fonts/Roboto-Regular.ttf',
  ).readAsBytesSync();
  @override
  Uint8List bytes(String path) => bytesValue;
  @override
  int size(String path) => bytesValue.length;
  @override
  bool contains(String path) => true;
  @override
  void dispose() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'CSS style then weight order, family order and the 400/500 interval',
    () {
      final faces = [
        for (final family in ['First', 'Second'])
          for (final style in StyleFontStyle.values)
            for (final weight in [100, 300, 400, 500, 600, 900])
              (
                face: StyleFontFace(
                  family: family,
                  archivePath: 'same',
                  weight: weight,
                  style: style,
                ),
                alias: '$family-$weight-${style.name}',
              ),
      ];
      for (final row in [
        (200, 100),
        (350, 300),
        (400, 400),
        (450, 500),
        (500, 500),
        (550, 600),
        (700, 900),
        (950, 900),
      ]) {
        final selected = resolveFontFaces(
          ['"First"', 'Second'],
          weight: row.$1,
          style: StyleFontStyle.italic,
          faces: faces,
        );
        expect(selected.primary, 'First-${row.$2}-italic');
        expect(selected.fallback, ['Second-${row.$2}-italic']);
      }
      final normal = faces
          .where(
            (f) =>
                f.face.weight == 400 && f.face.style == StyleFontStyle.normal,
          )
          .toList();
      expect(
        resolveFontFaces(
          ['First'],
          weight: 900,
          style: StyleFontStyle.italic,
          faces: normal,
        ).primary,
        'First-400-normal',
      );
      final middle = faces
          .where((f) => [300, 400, 600].contains(f.face.weight))
          .toList();
      expect(
        resolveFontFaces(
          ['First'],
          weight: 450,
          style: StyleFontStyle.normal,
          faces: middle,
        ).primary,
        'First-400-normal',
      );
    },
  );

  test('same family/path retains distinct descriptor aliases; reflow keeps its map', () async {
    final registry = FontRegistry(
      processBudget: ProcessFontBudget(),
      register: (_, _) async {},
    );
    final faces = [
      for (final style in StyleFontStyle.values)
        for (final weight in [400, 700])
          StyleFontFace(
            family: 'Author',
            archivePath: 'same',
            weight: weight,
            style: style,
          ),
    ];
    final reflow = await registry.loadResources(
      _Resources(),
      faces,
      scope: 'book',
      requiredFonts: true,
    );
    expect(registry.records.length, 4);
    expect(registry.records.map((r) => r.alias).toSet().length, 4);
    expect(reflow['author'], registry.records.last.alias);
    for (final record in registry.records) {
      expect(
        registry
            .selectFace(
              ['Author'],
              scope: 'book',
              faces: faces,
              weight: record.weight,
              style: record.style,
            )
            .primary,
        record.alias,
      );
    }
    await registry.drainFonts();
  });

  test(
    'both canceled registries drain one coalesced native registration',
    () async {
      final budget = ProcessFontBudget(), native = Completer<void>();
      var registrations = 0;
      Future<void> register(Uint8List _, String alias) {
        registrations++;
        return native.future;
      }

      final a = FontRegistry(processBudget: budget, register: register);
      final b = FontRegistry(processBudget: budget, register: register);
      final ta = PublicationCancellation(), tb = PublicationCancellation();
      const faces = [StyleFontFace(family: 'Author', archivePath: 'same')];
      final wa = expectLater(
        a.loadResources(_Resources(), faces, scope: 'a', cancellation: ta),
        throwsA(isA<ProcessFontLoadCanceled>()),
      );
      final wb = expectLater(
        b.loadResources(_Resources(), faces, scope: 'b', cancellation: tb),
        throwsA(isA<ProcessFontLoadCanceled>()),
      );
      ta.cancel();
      tb.cancel();
      await Future.wait([wa, wb]);
      var drained = false;
      final drain = Future.wait([a.drainFonts(), b.drainFonts()])
          .then((_) => drained = true);
      await Future<void>.delayed(Duration.zero);
      expect(drained, false);
      expect(registrations, 1);
      expect(budget.pendingFaces, 1);
      native.complete();
      await drain;
      expect(budget.registeredFaces, 1);
      expect(a.records, isEmpty);
      expect(b.records, isEmpty);
    },
  );
}
