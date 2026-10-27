// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_snapshot_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(librarySnapshotCache)
final librarySnapshotCacheProvider = LibrarySnapshotCacheProvider._();

final class LibrarySnapshotCacheProvider
    extends
        $FunctionalProvider<
          LibrarySnapshotCache,
          LibrarySnapshotCache,
          LibrarySnapshotCache
        >
    with $Provider<LibrarySnapshotCache> {
  LibrarySnapshotCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'librarySnapshotCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$librarySnapshotCacheHash();

  @$internal
  @override
  $ProviderElement<LibrarySnapshotCache> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LibrarySnapshotCache create(Ref ref) {
    return librarySnapshotCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibrarySnapshotCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibrarySnapshotCache>(value),
    );
  }
}

String _$librarySnapshotCacheHash() =>
    r'7b9d868d2337727d0ada7cc6b7904b4aa6d09602';
