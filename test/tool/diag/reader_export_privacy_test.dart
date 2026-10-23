import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/source/source_node.dart';

import '../../features/reader/engine/layout/layout_test_support.dart';

void main() {
  test('all synthetic export fixtures contain no bundled fixture sentences', () {
    final manifest = jsonDecode(
      File('assets/reader_fixtures/manifest.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final files = Directory('test/fixtures/reader/exports')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    final texts = [for (final file in files) file.readAsStringSync()];
    var sentencesChecked = 0;
    for (final item in manifest['fixtures'] as List<Object?>) {
      final id = (item as Map<String, Object?>)['id'] as String;
      final book = openFixture(id);
      final sentences = <String>{};
      for (var section = 0; section < book.sections.length; section++) {
        for (final node in book.loadSection(section).nodes) {
          if (node.kind != SourceNodeKind.text) continue;
          final text = node.text?.trim() ?? '';
          var sentenceStart = 0;
          // A delimiter-only search stays linear on the long unpunctuated
          // paragraph, unlike a greedy sentence regexp with a required suffix.
          for (final match in RegExp('[。！？.!?]').allMatches(text)) {
            final sentence = text.substring(sentenceStart, match.end).trim();
            sentenceStart = match.end;
            if (sentence.isNotEmpty &&
                !RegExp(r'^[。！？.!?]+$').hasMatch(sentence)) {
              sentences.add(sentence);
            }
          }
          // Also catch unsentenced prose fragments used by the existing export
          // privacy test. Short numeric/formatting nodes are not book sentences.
          if (text.length >= 12) sentences.add(text.substring(0, 12));
        }
      }
      for (final sentence in sentences) {
        sentencesChecked++;
        for (var i = 0; i < texts.length; i++) {
          // Boolean actual/expected avoids printing the fixture prose on failure.
          expect(
            texts[i].contains(sentence),
            false,
            reason: 'Prose collision in export index $i, synthetic fixture $id',
          );
        }
      }
    }
    expect(sentencesChecked, greaterThan(0));
    expect(files, hasLength(12));
    for (final text in texts) {
      expect(text.contains('epubcfi('), false);
      expect(text.contains('.epub'), false);
      final raw = jsonDecode(text) as Map<String, Object?>;
      expect(raw['bookSha256'], 'a' * 64);
      expect(raw['fixtureId'], 'synthetic-export');
    }
  });
}
