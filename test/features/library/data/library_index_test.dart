import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/features/library/data/library_decode_exception.dart';
import 'package:shiori/features/library/data/library_index.dart';
import 'package:shiori/features/library/data/models/shelf_ref.dart';

import 'library_test_support.dart';
import 'snapshot_models_test.dart' show invariant;

void main() {
  test('equal numeric book/folder IDs remain independent and ordered', () {
    final index = LibraryIndex.fromSnapshot(decodeSnapshot(payload()));
    expect(index.books[7]!.folderId, isNull);
    expect(index.folders[7]!.bookIds, [10, 9]);
    expect(index.shelf.take(2).map((ref) => ref.id), [7, 7]);
    expect(index.shelf[0], isA<ShelfBookRef>());
    expect(index.shelf[1], isA<ShelfFolderRef>());
    expect(index.recent.map((e) => e.bookId), [9, 8]);
    expect(() => index.books.clear(), throwsUnsupportedError);
    expect(() => index.folders.clear(), throwsUnsupportedError);
    expect(() => index.folders[7]!.bookIds.clear(), throwsUnsupportedError);
    expect(
      () => index.folders[7]!.previewBookIds.clear(),
      throwsUnsupportedError,
    );
    expect(() => index.shelf.clear(), throwsUnsupportedError);
    expect(() => index.recent.clear(), throwsUnsupportedError);
  });

  void rejects(
    String name,
    LibraryInvariant issue,
    void Function(Map<String, Object?> body) mutate,
  ) {
    test(name, () {
      final body = payload();
      mutate(body);
      expect(
        () => LibraryIndex.fromSnapshot(decodeSnapshot(body)),
        invariant(issue),
      );
    });
  }

  rejects('duplicate folder IDs', LibraryInvariant.duplicateFolderId, (body) {
    (snapshot(body)['folders']! as List<Object?>).add(
      records(body, 'folders').first,
    );
  });
  rejects('missing folder member', LibraryInvariant.folderBook, (body) {
    records(body, 'folders').first['bookIds'] = [999];
  });
  rejects('folder count differs', LibraryInvariant.folderCount, (body) {
    records(body, 'folders').first['bookCount'] = 1;
  });
  rejects('preview is not first four', LibraryInvariant.folderPreview, (body) {
    records(body, 'folders').first['previewBookIds'] = [9, 10];
  });
  rejects(
    'preview cannot refer outside folder',
    LibraryInvariant.folderPreview,
    (body) {
      records(body, 'folders').first['previewBookIds'] = [7];
    },
  );
  rejects('duplicate membership', LibraryInvariant.folderOwnership, (body) {
    records(body, 'folders').first['bookIds'] = [10, 10];
  });
  rejects(
    'folder cannot contain a root book',
    LibraryInvariant.folderOwnership,
    (body) {
      records(body, 'folders').first['bookIds'] = [7];
    },
  );
  rejects('book owning an absent folder', LibraryInvariant.folderOwnership, (
    body,
  ) {
    records(body, 'books').first['folderId'] = 999;
  });
  rejects('book absent from owner list', LibraryInvariant.folderOwnership, (
    body,
  ) {
    records(body, 'books')[1]['folderId'] = 7;
  });
  rejects('folder books out of order', LibraryInvariant.folderOrder, (body) {
    records(body, 'folders').first['bookIds'] = [9, 10];
  });
  rejects('shelf missing folder', LibraryInvariant.shelfRecord, (body) {
    records(body, 'shelf')[1]['id'] = 999;
  });
  rejects(
    'shelf cannot contain folder member',
    LibraryInvariant.shelfOwnership,
    (body) {
      records(body, 'shelf').first['id'] = 9;
    },
  );
  rejects('shelf duplicate', LibraryInvariant.shelfDuplicate, (body) {
    (snapshot(body)['shelf']! as List<Object?>).add(
      records(body, 'shelf').first,
    );
  });
  rejects('shelf omits a root book', LibraryInvariant.shelfOwnership, (body) {
    (snapshot(body)['shelf']! as List<Object?>).removeAt(0);
  });
  rejects('shelf omits a folder', LibraryInvariant.shelfOwnership, (body) {
    (snapshot(body)['shelf']! as List<Object?>).removeAt(1);
  });
  rejects('shelf order differs from entity', LibraryInvariant.shelfOwnership, (
    body,
  ) {
    records(body, 'shelf').first['sortOrder'] = 5;
  });
  rejects('shelf unsorted', LibraryInvariant.shelfOrder, (body) {
    final shelf = snapshot(body)['shelf']! as List<Object?>;
    final first = shelf.removeAt(0);
    shelf.add(first);
  });
  rejects('recent missing book', LibraryInvariant.recentBook, (body) {
    records(body, 'recent').first['bookId'] = 999;
  });
  rejects('recent inner identity mismatch', LibraryInvariant.recentBook, (
    body,
  ) {
    (records(body, 'recent').first['progress']!
            as Map<String, Object?>)['bookId'] =
        8;
  });
  rejects('recent duplicate', LibraryInvariant.recentDuplicate, (body) {
    (snapshot(body)['recent']! as List<Object?>).add(
      records(body, 'recent').first,
    );
  });
  for (final tuple in [
    [null, 0],
    [2, null],
    [2, -2],
    [2, 2],
  ]) {
    rejects('invalid chapter tuple $tuple', LibraryInvariant.chapterProgress, (
      body,
    ) {
      final progress =
          records(body, 'recent').first['progress']! as Map<String, Object?>;
      progress['chapterCount'] = tuple[0];
      progress['chapterIndex'] = tuple[1];
    });
  }
  test('known chapter count permits pre-spine index -1', () {
    final body = payload();
    final progress =
        records(body, 'recent').first['progress']! as Map<String, Object?>;
    progress['chapterCount'] = 2;
    progress['chapterIndex'] = -1;
    expect(
      LibraryIndex.fromSnapshot(decodeSnapshot(body)).recent,
      hasLength(2),
    );
  });
}
