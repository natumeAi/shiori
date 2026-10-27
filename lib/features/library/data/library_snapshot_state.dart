import 'package:shiori/features/library/data/cached_library_snapshot.dart';

/// A refresh failure accompanies retained data rather than replacing it.
final class LibrarySnapshotState {
  const LibrarySnapshotState({
    this.snapshot,
    this.stale = true,
    this.refreshing = false,
    this.error,
  });

  final CachedLibrarySnapshot? snapshot;
  final bool stale;
  final bool refreshing;
  final Object? error;
}
