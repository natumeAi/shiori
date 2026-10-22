// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'probe_marker_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(probeMarkerRepository)
final probeMarkerRepositoryProvider = ProbeMarkerRepositoryProvider._();

final class ProbeMarkerRepositoryProvider
    extends
        $FunctionalProvider<
          ProbeMarkerRepository,
          ProbeMarkerRepository,
          ProbeMarkerRepository
        >
    with $Provider<ProbeMarkerRepository> {
  ProbeMarkerRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'probeMarkerRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$probeMarkerRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProbeMarkerRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProbeMarkerRepository create(Ref ref) {
    return probeMarkerRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProbeMarkerRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProbeMarkerRepository>(value),
    );
  }
}

String _$probeMarkerRepositoryHash() =>
    r'518cc0721e478363bde835da03457ac81ffc8a29';
