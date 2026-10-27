// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publication_staging.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(publicationStaging)
final publicationStagingProvider = PublicationStagingProvider._();

final class PublicationStagingProvider
    extends
        $FunctionalProvider<
          PublicationStaging,
          PublicationStaging,
          PublicationStaging
        >
    with $Provider<PublicationStaging> {
  PublicationStagingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'publicationStagingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$publicationStagingHash();

  @$internal
  @override
  $ProviderElement<PublicationStaging> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PublicationStaging create(Ref ref) {
    return publicationStaging(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PublicationStaging value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PublicationStaging>(value),
    );
  }
}

String _$publicationStagingHash() =>
    r'3cd42fa380c0cc08befedc5ac2124c311330dec7';
