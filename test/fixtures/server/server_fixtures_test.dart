import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _root = 'test/fixtures/server';
Map<String, Object?> _map(Object? value) => value as Map<String, Object?>;
List<Map<String, Object?>> _rows(Object? value) =>
    (value as List<Object?>).map(_map).toList();
Map<String, Object?> _load(String name) =>
    _map(jsonDecode(File('$_root/$name').readAsStringSync()));

// Fixture integrity only: these selected rules are not a production DTO decoder.
Set<String> _violations(Map<String, Object?> snapshot) {
  final errors = <String>{};
  final books = _rows(snapshot['books']);
  final folders = _rows(snapshot['folders']);
  final shelf = _rows(snapshot['shelf']);
  final bookIds = books.map((book) => book['id']).toSet();
  final folderIds = folders.map((folder) => folder['id']).toSet();
  if (snapshot['schemaVersion'] != 1) errors.add('schema_version');
  if (bookIds.length != books.length) errors.add('duplicate_book_id');
  for (final book in books) {
    const nullable = [
      'folderId',
      'author',
      'identifier',
      'coverPath',
      'coverUrl',
      'coverThumbnailUrl',
      'coverThumbnail2xUrl',
      'coverThumbnailVersion',
      'readingProgress',
      'readingUpdatedAt',
    ];
    if (nullable.any((key) => !book.containsKey(key))) {
      errors.add('missing_nullable');
    }
  }
  for (final record in [...books, ...folders, ...shelf]) {
    final id = record['id'];
    if (id is! int || id <= 0 || id > 9007199254740991) {
      errors.add('invalid_id');
    }
  }
  for (final folder in folders) {
    for (final key in ['bookIds', 'previewBookIds']) {
      if ((folder[key] as List<Object?>).any((id) => !bookIds.contains(id))) {
        errors.add('missing_folder_book');
      }
    }
  }
  for (final item in shelf) {
    switch (item['type']) {
      case 'book':
        if (!bookIds.contains(item['id'])) errors.add('missing_shelf_record');
      case 'folder':
        if (!folderIds.contains(item['id'])) errors.add('missing_shelf_record');
      default:
        errors.add('shelf_enum');
    }
  }
  return errors;
}

void main() {
  final manifest = _load('manifest.json');
  final inventory = _rows(manifest['fixtures']);

  test('README, manifest and disk inventory agree; all bodies parse', () {
    final names = inventory.map((entry) => entry['file'] as String).toList();
    expect(names.toSet(), hasLength(names.length));
    final actual = Directory(_root)
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.json') || name.endsWith('.html'));
    expect(actual, unorderedEquals(names));
    final readme = File('$_root/README.md').readAsStringSync();
    final documented = RegExp(
      r'^\| `([^`]+\.(?:json|html))` \|',
      multiLine: true,
    ).allMatches(readme).map((match) => match[1]);
    expect(documented, unorderedEquals(names));
    for (final entry in inventory) {
      final name = entry['file'] as String;
      if (entry['format'] == 'json') {
        expect(_load(name), isNotEmpty, reason: name);
      } else {
        final html = File('$_root/$name').readAsStringSync();
        expect(html, startsWith('<!doctype html>'));
        expect(html, contains('</html>'));
        expect(() => jsonDecode(html), throwsFormatException);
      }
    }
  });

  test('valid snapshots pass and invalid snapshots violate one named rule', () {
    for (final entry in inventory) {
      final name = entry['file'] as String;
      if (!name.startsWith('snapshot_')) continue;
      final expected = entry['violation'];
      expect(
        _violations(_map(_load(name)['snapshot'])),
        expected == null ? isEmpty : unorderedEquals([expected]),
        reason: name,
      );
    }
  });

  test('typical snapshot preserves ordered joins, typed keys and progress', () {
    final snapshot = _map(_load('snapshot_typical.json')['snapshot']);
    final books = _rows(snapshot['books']);
    expect(books.map((book) => book['readingProgress']), [
      null,
      0,
      0.375,
      null,
    ]);
    for (final folder in _rows(snapshot['folders'])) {
      final members =
          books.where((book) => book['folderId'] == folder['id']).toList()
            ..sort(
              (a, b) =>
                  (a['sortOrder'] as int).compareTo(b['sortOrder'] as int),
            );
      final ids = members.map((book) => book['id']).toList();
      expect(folder['bookIds'], ids);
      expect(folder['bookCount'], ids.length);
      expect(folder['previewBookIds'], ids.take(4).toList());
    }
    final shelf = _rows(snapshot['shelf']);
    expect(
      shelf.map((item) => '${item['type']}:${item['id']}').toSet(),
      hasLength(shelf.length),
    );
    expect(shelf.where((item) => item['id'] == 7).map((item) => item['type']), [
      'book',
      'folder',
    ]);
    for (final recent in _rows(snapshot['recent'])) {
      final progress = _map(recent['progress']);
      final book = books.singleWhere((book) => book['id'] == recent['bookId']);
      expect(progress['bookId'], book['id']);
      expect(progress['progress'], book['readingProgress']);
      expect(progress['updatedAt'], book['readingUpdatedAt']);
      expect(progress.keys, containsAll(['chapterCount', 'chapterIndex']));
    }
    final raw = _rows(_map(_load('snapshot_minimal.json')['snapshot'])['books'])
        .single['updatedAt'];
    final offset = _rows(
      _map(_load('snapshot_explicit_offset.json')['snapshot'])['books'],
    ).single['updatedAt'];
    expect(raw, '2026-01-02 03:04:05');
    expect(DateTime.parse(offset as String).toUtc(), DateTime.parse('${raw}Z'));
    final detail = _map(_load('book_detail.json')['book']);
    expect(
      detail.keys,
      containsAll([
        'description',
        'publisher',
        'language',
        'coverThumbnailSmallPath',
        'coverThumbnailLargePath',
      ]),
    );
    expect(detail.containsKey('readingProgress'), isFalse);
    expect(_load('book_not_found.json'), {'error': 'Book not found'});
    expect(_load('health_database_error.json'), _load('error_500.json'));
  });

  test('descriptors preserve bodyless 304s and file validator variants', () {
    final responses = _rows(manifest['responses']);
    Map<String, Object?> named(String name) =>
        responses.singleWhere((response) => response['name'] == name);
    for (final response in responses) {
      if (response['status'] == 304) {
        expect(response['bodyKind'], 'absent');
        expect(response.containsKey('bodyFile'), isFalse);
      }
      if (response['bodyFile'] case final String file) {
        expect(inventory.any((entry) => entry['file'] == file), isTrue);
      }
    }
    expect(_map(named('snapshot_200')['headers'])['ETag'], '"library-42"');
    expect(_map(named('snapshot_200')['headers'])['X-Library-Revision'], '42');
    for (final name in ['file_200_length', 'file_200_chunked']) {
      final headers = _map(named(name)['headers']);
      expect(headers['Content-Type'], 'application/epub+zip');
      expect(headers['ETag'], startsWith('W/"'));
      expect(headers['Last-Modified'], isNotEmpty);
      expect(headers.containsKey('Content-Length'), name == 'file_200_length');
    }
    final noValidators = _map(named('file_200_no_validators')['headers']);
    expect(noValidators.keys, isNot(contains('ETag')));
    expect(noValidators.keys, isNot(contains('Last-Modified')));
    expect(
      responses.map((response) => response['status']),
      containsAll([200, 304, 206, 412, 416]),
    );
  });

  test(
    'URL vectors contain five exact prefixed requests and zero-traffic rejects',
    () {
      final urls = _load('url_resolution.json');
      for (final entry in _rows(urls['accepted'])) {
        final root = entry['canonicalRoot'] as String;
        final requests = _map(entry['requests']);
        expect(
          requests.keys,
          containsAll([
            'api/health',
            'api/library/snapshot',
            'api/books/7',
            'api/books/7/file',
          ]),
        );
        expect(requests, hasLength(5));
        for (final request in requests.entries) {
          final suffix = request.key.replaceFirst(RegExp(r'^/'), '');
          expect(request.value, '$root$suffix');
          expect(Uri.parse(request.value as String).hasAuthority, isTrue);
        }
      }
      final rejected = _rows(urls['rejected']);
      expect(
        rejected.map((entry) => entry['reason']),
        containsAll([
          'userinfo',
          'query',
          'fragment',
          'non_http_scheme',
          'malformed_host',
          'invalid_port_large',
          'backslash',
          'invalid_percent_escape',
        ]),
      );
      expect(rejected.every((entry) => entry['expectedRequests'] == 0), isTrue);
    },
  );
}
