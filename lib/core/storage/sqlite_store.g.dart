// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sqlite_store.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// One owner per provider scope, retained between listeners. Invalidation or
/// scope disposal drains it even if disposal races asynchronous initialization.

@ProviderFor(sqliteStore)
final sqliteStoreProvider = SqliteStoreProvider._();

/// One owner per provider scope, retained between listeners. Invalidation or
/// scope disposal drains it even if disposal races asynchronous initialization.

final class SqliteStoreProvider
    extends
        $FunctionalProvider<
          AsyncValue<SqliteStore>,
          SqliteStore,
          FutureOr<SqliteStore>
        >
    with $FutureModifier<SqliteStore>, $FutureProvider<SqliteStore> {
  /// One owner per provider scope, retained between listeners. Invalidation or
  /// scope disposal drains it even if disposal races asynchronous initialization.
  SqliteStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sqliteStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sqliteStoreHash();

  @$internal
  @override
  $FutureProviderElement<SqliteStore> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SqliteStore> create(Ref ref) {
    return sqliteStore(ref);
  }
}

String _$sqliteStoreHash() => r'5193062461c728d1cbf986cbf4b5d66ca5a91291';

@ProviderFor(_storeOwners)
final _storeOwnersProvider = _StoreOwnersProvider._();

final class _StoreOwnersProvider
    extends $FunctionalProvider<_StoreOwners, _StoreOwners, _StoreOwners>
    with $Provider<_StoreOwners> {
  _StoreOwnersProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_storeOwnersProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_storeOwnersHash();

  @$internal
  @override
  $ProviderElement<_StoreOwners> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  _StoreOwners create(Ref ref) {
    return _storeOwners(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(_StoreOwners value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<_StoreOwners>(value),
    );
  }
}

String _$_storeOwnersHash() => r'20bdd1a591b59d46f1563e9a59e4275b12f1b6c1';
