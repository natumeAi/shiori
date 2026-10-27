import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/library/data/library_decode_exception.dart';
import 'package:shiori/features/library/data/library_index.dart';
import 'package:shiori/features/library/data/models/book_response.dart';
import 'package:shiori/features/library/data/models/server_timestamp.dart';

import 'library_test_support.dart';

Matcher invariant(LibraryInvariant value) => throwsA(
  isA<LibraryDecodeException>().having((e) => e.invariant, 'invariant', value),
);

void main() {
  for (final name in [
    'typical',
    'minimal',
    'empty',
    'explicit_offset',
    'additive',
  ]) {
    test('valid snapshot fixture $name', () {
      final dto = decodeSnapshot(payload('snapshot_$name.json'));
      final index = LibraryIndex.fromSnapshot(dto);
      expect(index.books.length, dto.books.length);
      expect(index.folders.length, dto.folders.length);
    });
  }
  const invalid = {
    'schema_version': LibraryInvariant.schemaVersion,
    'missing_nullable': LibraryInvariant.requiredField,
    'unsafe_id': LibraryInvariant.safeInteger,
    'non_positive_id': LibraryInvariant.positiveId,
    'fractional_id': LibraryInvariant.safeInteger,
    'duplicate_book_id': LibraryInvariant.duplicateBookId,
    'missing_folder_book': LibraryInvariant.folderBook,
    'missing_shelf_record': LibraryInvariant.shelfRecord,
    'shelf_enum': LibraryInvariant.shelfType,
  };
  for (final entry in invalid.entries) {
    test('invalid fixture names ${entry.key}', () {
      expect(
        () => LibraryIndex.fromSnapshot(
          decodeSnapshot(payload('snapshot_invalid_${entry.key}.json')),
        ),
        invariant(entry.value),
      );
    });
  }
  test('null, zero and fractional progress remain distinct', () {
    final books = decodeSnapshot(payload()).books;
    expect(books[0].readingProgress, isNull);
    expect(books[1].readingProgress, 0);
    expect(books[2].readingProgress, 0.375);
    expect(books[0].readingUpdatedAt, isNull);
    expect(books[1].readingUpdatedAt, isNotNull);
  });
  for (final field in [
    'author',
    'folderId',
    'readingProgress',
    'readingUpdatedAt',
  ]) {
    test('required nullable $field accepts null and rejects missing', () {
      final body = payload('snapshot_minimal.json');
      records(body, 'books').first[field] = null;
      expect(decodeSnapshot(body).books, hasLength(1));
      records(body, 'books').first.remove(field);
      expect(
        () => decodeSnapshot(body),
        invariant(LibraryInvariant.requiredField),
      );
    });
  }
  for (final value in [-0.001, 1.001, double.nan, double.infinity, '0', true]) {
    test('rejects progress $value', () {
      final body = payload();
      records(body, 'books').first['readingProgress'] = value;
      expect(() => decodeSnapshot(body), invariant(LibraryInvariant.progress));
    });
  }
  for (final field in ['version', 'schemaVersion']) {
    for (final value in [-1, 0.1, 9007199254740992, null, '1']) {
      test('rejects invalid $field $value', () {
        final body = payload();
        snapshot(body)[field] = value;
        expect(
          () => decodeSnapshot(body),
          invariant(LibraryInvariant.safeInteger),
        );
      });
    }
  }
  test('full detail preserves fields and ignores additive keys', () {
    final body = payload('book_detail.json');
    final book = body['book']! as Map<String, Object?>;
    body['future'] = true;
    book['future'] = true;
    final dto = decodeLibraryValue(() => BookResponse.fromJson(body).book);
    expect(dto.description, 'Synthetic fixture description.');
    expect(dto.language, 'en');
    expect(dto.coverThumbnailSmallPath, isNotNull);
    expect(dto.toJson()['createdAt'], book['createdAt']);
    book.remove('publisher');
    expect(
      () => decodeLibraryValue(() => BookResponse.fromJson(body)),
      invariant(LibraryInvariant.requiredField),
    );
  });
  test('SQLite UTC and explicit offsets preserve raw and instant', () {
    final utc = decodeSnapshot(payload('snapshot_minimal.json'))
        .books
        .first
        .updatedAt;
    final offset = decodeSnapshot(payload('snapshot_explicit_offset.json'))
        .books
        .first
        .updatedAt;
    expect(utc.utc, DateTime.utc(2026, 1, 2, 3, 4, 5));
    expect(offset.utc, utc.utc);
    expect(utc.raw, '2026-01-02 03:04:05');
    expect(offset.raw, '2026-01-02T11:04:05+08:00');
    expect(ServerTimestamp.parse('2026-01-02T03:04:05Z').utc, utc.utc);
    expect(ServerTimestamp.parse('2026-01-01T22:04:05-05:00').utc, utc.utc);
  });
  for (final raw in [
    '2026-01-02T03:04:05',
    '2026-02-30 00:00:00',
    '2026-01-01 24:00:00',
    '2026-01-01T00:00:00+24:00',
    'invalid',
  ]) {
    test('rejects ambiguous or invalid timestamp $raw', () {
      expect(
        () => ServerTimestamp.parse(raw),
        invariant(LibraryInvariant.timestamp),
      );
    });
  }
}
