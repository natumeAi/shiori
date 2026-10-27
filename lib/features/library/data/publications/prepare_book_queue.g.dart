// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prepare_book_queue.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(prepareBookQueue)
final prepareBookQueueProvider = PrepareBookQueueProvider._();

final class PrepareBookQueueProvider
    extends
        $FunctionalProvider<
          PrepareBookQueue,
          PrepareBookQueue,
          PrepareBookQueue
        >
    with $Provider<PrepareBookQueue> {
  PrepareBookQueueProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'prepareBookQueueProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$prepareBookQueueHash();

  @$internal
  @override
  $ProviderElement<PrepareBookQueue> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  PrepareBookQueue create(Ref ref) {
    return prepareBookQueue(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrepareBookQueue value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrepareBookQueue>(value),
    );
  }
}

String _$prepareBookQueueHash() => r'289f1e2e76077bcb52c380e234cc76f2c8bac771';
