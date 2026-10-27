// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publication_cache.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(publicationCache)
final publicationCacheProvider = PublicationCacheProvider._();

final class PublicationCacheProvider
    extends
        $FunctionalProvider<
          AsyncValue<PublicationCache>,
          PublicationCache,
          FutureOr<PublicationCache>
        >
    with $FutureModifier<PublicationCache>, $FutureProvider<PublicationCache> {
  PublicationCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'publicationCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$publicationCacheHash();

  @$internal
  @override
  $FutureProviderElement<PublicationCache> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<PublicationCache> create(Ref ref) {
    return publicationCache(ref);
  }
}

String _$publicationCacheHash() => r'acdaef9b58f2563d270c77845fced98c3d0995f1';

@ProviderFor(_publicationCacheScope)
final _publicationCacheScopeProvider = _PublicationCacheScopeProvider._();

final class _PublicationCacheScopeProvider
    extends
        $FunctionalProvider<
          _PublicationCacheScope,
          _PublicationCacheScope,
          _PublicationCacheScope
        >
    with $Provider<_PublicationCacheScope> {
  _PublicationCacheScopeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'_publicationCacheScopeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$_publicationCacheScopeHash();

  @$internal
  @override
  $ProviderElement<_PublicationCacheScope> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  _PublicationCacheScope create(Ref ref) {
    return _publicationCacheScope(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(_PublicationCacheScope value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<_PublicationCacheScope>(value),
    );
  }
}

String _$_publicationCacheScopeHash() =>
    r'0730b21ff0075e2847a0cddc1b26782baeb0b819';
