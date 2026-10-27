import 'package:shiori/features/library/data/library_decode_exception.dart';
import 'package:shiori/features/library/data/models/library_snapshot.dart';
import 'package:shiori/features/library/data/models/recent_entry.dart';
import 'package:shiori/features/library/data/models/shelf_ref.dart';
import 'package:shiori/features/library/data/models/snapshot_book.dart';
import 'package:shiori/features/library/data/models/snapshot_folder.dart';
import 'package:shiori/features/library/data/models/snapshot_response.dart';

/// Validated joins with independent book/folder namespaces and wire ordering.
final class LibraryIndex {
  LibraryIndex._(this.books, this.folders, this.shelf, this.recent);

  final Map<int, SnapshotBook> books;
  final Map<int, SnapshotFolder> folders;
  final List<ShelfRef> shelf;
  final List<RecentEntry> recent;

  factory LibraryIndex.fromSnapshot(LibrarySnapshot snapshot) {
    final books = <int, SnapshotBook>{};
    final folders = <int, SnapshotFolder>{};
    for (final book in snapshot.books) {
      _require(!books.containsKey(book.id), LibraryInvariant.duplicateBookId);
      books[book.id] = book;
    }
    for (final folder in snapshot.folders) {
      _require(
        !folders.containsKey(folder.id),
        LibraryInvariant.duplicateFolderId,
      );
      folders[folder.id] = folder.copyWith(
        bookIds: List.unmodifiable(folder.bookIds),
        previewBookIds: List.unmodifiable(folder.previewBookIds),
      );
    }
    final memberships = <int>{};
    for (final folder in folders.values) {
      SnapshotBook? previous;
      for (final id in folder.bookIds) {
        final book = books[id];
        _require(book != null, LibraryInvariant.folderBook);
        _require(
          book!.folderId == folder.id && memberships.add(id),
          LibraryInvariant.folderOwnership,
        );
        if (previous != null) {
          _require(
            _ordered(previous.sortOrder, previous.id, book.sortOrder, id),
            LibraryInvariant.folderOrder,
          );
        }
        previous = book;
      }
      _require(
        folder.bookCount == folder.bookIds.length,
        LibraryInvariant.folderCount,
      );
      final expectedPreview = folder.bookIds.take(4).toList();
      _require(
        folder.previewBookIds.length == expectedPreview.length &&
            Iterable<int>.generate(expectedPreview.length)
                .every((i) => expectedPreview[i] == folder.previewBookIds[i]),
        LibraryInvariant.folderPreview,
      );
    }
    for (final book in books.values) {
      _require(
        book.folderId == null ||
            (folders.containsKey(book.folderId) &&
                memberships.contains(book.id)),
        LibraryInvariant.folderOwnership,
      );
    }
    final shelfBooks = <int>{};
    final shelfFolders = <int>{};
    ShelfRef? previousRef;
    for (final ref in snapshot.shelf) {
      final int? order;
      switch (ref) {
        case ShelfBookRef():
          final book = books[ref.id];
          _require(book != null, LibraryInvariant.shelfRecord);
          _require(book!.folderId == null, LibraryInvariant.shelfOwnership);
          _require(shelfBooks.add(ref.id), LibraryInvariant.shelfDuplicate);
          order = book.sortOrder;
        case ShelfFolderRef():
          final folder = folders[ref.id];
          _require(folder != null, LibraryInvariant.shelfRecord);
          _require(shelfFolders.add(ref.id), LibraryInvariant.shelfDuplicate);
          order = folder!.sortOrder;
      }
      _require(ref.sortOrder == order, LibraryInvariant.shelfOwnership);
      _require(
        previousRef == null || _shelfOrdered(previousRef, ref),
        LibraryInvariant.shelfOrder,
      );
      previousRef = ref;
    }
    _require(
      shelfFolders.length == folders.length &&
          books.values.every(
            (b) => b.folderId != null || shelfBooks.contains(b.id),
          ),
      LibraryInvariant.shelfOwnership,
    );
    final recentIds = <int>{};
    for (final entry in snapshot.recent) {
      _require(
        books.containsKey(entry.bookId) &&
            entry.progress.bookId == entry.bookId,
        LibraryInvariant.recentBook,
      );
      _require(recentIds.add(entry.bookId), LibraryInvariant.recentDuplicate);
      final position = entry.progress;
      _require(
        (position.chapterCount == null && position.chapterIndex == null) ||
            (position.chapterCount != null &&
                position.chapterIndex != null &&
                position.chapterIndex! >= -1 &&
                position.chapterIndex! < position.chapterCount!),
        LibraryInvariant.chapterProgress,
      );
    }
    return LibraryIndex._(
      Map.unmodifiable(books),
      Map.unmodifiable(folders),
      List.unmodifiable(snapshot.shelf),
      List.unmodifiable(snapshot.recent),
    );
  }
}

LibrarySnapshot decodeSnapshot(Object? body) => decodeLibraryValue(
  () => SnapshotResponse.fromJson(body as Map<String, Object?>).snapshot,
);

bool _ordered(int aOrder, int aId, int bOrder, int bId) =>
    aOrder < bOrder || (aOrder == bOrder && aId < bId);

bool _shelfOrdered(ShelfRef first, ShelfRef second) {
  if (first.sortOrder != second.sortOrder) {
    return first.sortOrder < second.sortOrder;
  }
  if (first is ShelfBookRef && second is ShelfFolderRef) return true;
  if (first is ShelfFolderRef && second is ShelfBookRef) return false;
  return first.id < second.id;
}

void _require(bool condition, LibraryInvariant invariant) {
  if (!condition) throw LibraryDecodeException(invariant);
}
