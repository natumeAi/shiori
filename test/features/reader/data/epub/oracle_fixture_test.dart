import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/reader/data/epub/epub_book.dart';

import 'oracle_comparison.dart';

const _fixtureIds = [
  'cfi-structure',
  'chapters',
  'html-fallback',
  'images',
  'inert-content',
  'long-content',
  'one-page',
  'opf-variants',
  'styles',
  'unicode',
  'unsupported-fixed',
  'unsupported-rtl',
  'unsupported-vertical',
];

void main() {
  group('synthetic fixtures equal the WebKit oracle vectors', () {
    for (final id in _fixtureIds) {
      test(id, () {
        final book = EpubBook.open(
          File('assets/reader_fixtures/$id.epub').readAsBytesSync(),
          tokens: oracleTokens,
        );
        final vector = readJsonObject(
          'test/fixtures/reader/oracle/$id.webkit.json',
        );
        expect(compareBookToVector(book, vector), isEmpty);
      });
    }
  });
  group('native CFI resolve and export equal the WebKit samples', () {
    for (final id in _fixtureIds) {
      test(id, () {
        final book = EpubBook.open(
          File('assets/reader_fixtures/$id.epub').readAsBytesSync(),
          tokens: oracleTokens,
        );
        final vector = readJsonObject(
          'test/fixtures/reader/oracle/$id.webkit.json',
        );
        final result = compareNativeCfi(book, vector);
        expect(result.samples, greaterThan(0));
        expect(result.failures, isEmpty);
      });
    }
  });
}
