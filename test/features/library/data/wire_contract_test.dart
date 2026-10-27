import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/library/data/library_decode_exception.dart';
import 'package:shiori/features/library/data/library_index.dart';
import 'package:shiori/features/library/data/models/book_response.dart';

import 'library_test_support.dart';
import 'snapshot_models_test.dart' show invariant;

void main() {
  final typical = payload();
  final requiredFields = {
    'books': records(typical, 'books').first.keys.toList(),
    'folders': records(typical, 'folders').first.keys.toList(),
    'shelf': ['id', 'sortOrder'],
    'recent': ['bookId', 'progress'],
  };
  for (final record in requiredFields.entries) {
    for (final field in record.value) {
      test('${record.key} requires key $field', () {
        final body = payload();
        records(body, record.key).first.remove(field);
        expect(
          () => decodeSnapshot(body),
          invariant(LibraryInvariant.requiredField),
        );
      });
    }
  }
  final position =
      records(typical, 'recent').first['progress']! as Map<String, Object?>;
  for (final field in position.keys) {
    test('recent reading position requires key $field', () {
      final body = payload();
      (records(body, 'recent').first['progress']! as Map<String, Object?>)
          .remove(field);
      expect(
        () => decodeSnapshot(body),
        invariant(LibraryInvariant.requiredField),
      );
    });
  }
  final detail = payload('book_detail.json')['book']! as Map<String, Object?>;
  for (final field in detail.keys) {
    test('full Book requires key $field', () {
      final body = payload('book_detail.json');
      (body['book']! as Map<String, Object?>).remove(field);
      expect(
        () => decodeLibraryValue(() => BookResponse.fromJson(body)),
        invariant(LibraryInvariant.requiredField),
      );
    });
  }
  for (final field in [
    'snapshot',
    'schemaVersion',
    'version',
    'books',
    'folders',
    'shelf',
    'recent',
  ]) {
    test('snapshot envelope requires $field', () {
      final body = payload();
      if (field == 'snapshot') {
        body.remove(field);
      } else {
        snapshot(body).remove(field);
      }
      expect(
        () => decodeSnapshot(body),
        invariant(LibraryInvariant.requiredField),
      );
    });
  }
  test('Book envelope requires book', () {
    expect(
      () => decodeLibraryValue(() => BookResponse.fromJson({})),
      invariant(LibraryInvariant.requiredField),
    );
  });

  for (final value in [
    -1,
    0.5,
    9007199254740992,
    double.infinity,
    '4096',
    null,
  ]) {
    test('snapshot file size rejects $value', () {
      final body = payload();
      records(body, 'books').first['fileSize'] = value;
      expect(
        () => decodeSnapshot(body),
        invariant(LibraryInvariant.safeInteger),
      );
    });
  }
  test('safe integer boundaries are accepted without rounding', () {
    final body = payload('snapshot_minimal.json');
    snapshot(body)['version'] = 9007199254740991;
    records(body, 'books').first['id'] = 9007199254740991;
    records(body, 'books').first['fileSize'] = 0;
    records(body, 'shelf').first['id'] = 9007199254740991;
    final dto = decodeSnapshot(body);
    final index = LibraryIndex.fromSnapshot(dto);
    expect(index.books.keys.single, 9007199254740991);
    expect(dto.version, 9007199254740991);
    expect(index.books.values.single.fileSize, 0);
  });
  for (final value in [
    -9223372036854775808,
    -9007199254740992,
    9007199254740992,
    0.5,
    double.nan,
    double.infinity,
  ]) {
    test('signed sort order rejects unsafe number $value', () {
      final body = payload();
      records(body, 'books').first['sortOrder'] = value;
      expect(
        () => decodeSnapshot(body),
        invariant(LibraryInvariant.safeInteger),
      );
    });
  }

  test('timestamp conversion applies at all nested DTO levels', () {
    const offset = '2026-01-02T11:04:05.123456+08:00';
    final body = payload();
    records(body, 'books')[1]['readingUpdatedAt'] = offset;
    records(body, 'folders').first['updatedAt'] = offset;
    (records(body, 'recent').first['progress']!
            as Map<String, Object?>)['updatedAt'] =
        offset;
    final dto = decodeSnapshot(body);
    for (final timestamp in [
      dto.books[1].readingUpdatedAt!,
      dto.folders.first.updatedAt,
      dto.recent.first.progress.updatedAt,
    ]) {
      expect(timestamp.utc, DateTime.utc(2026, 1, 2, 3, 4, 5, 123, 456));
      expect(timestamp.raw, offset);
    }
    final encoded = dto.toJson();
    final recent =
        (encoded['recent']! as List<Object?>).first! as Map<String, Object?>;
    expect((recent['progress']! as Map<String, Object?>)['updatedAt'], offset);
  });
}
