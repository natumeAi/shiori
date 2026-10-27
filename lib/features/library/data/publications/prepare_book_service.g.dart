// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'prepare_book_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(prepareBookService)
final prepareBookServiceProvider = PrepareBookServiceFamily._();

final class PrepareBookServiceProvider
    extends
        $FunctionalProvider<
          PrepareBookService,
          PrepareBookService,
          PrepareBookService
        >
    with $Provider<PrepareBookService> {
  PrepareBookServiceProvider._({
    required PrepareBookServiceFamily super.from,
    required ServerSession super.argument,
  }) : super(
         retry: null,
         name: r'prepareBookServiceProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$prepareBookServiceHash();

  @override
  String toString() {
    return r'prepareBookServiceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<PrepareBookService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PrepareBookService create(Ref ref) {
    final argument = this.argument as ServerSession;
    return prepareBookService(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PrepareBookService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PrepareBookService>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PrepareBookServiceProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$prepareBookServiceHash() =>
    r'ebf9e6b17356a9b8a7bbff6649dc866fde7d577a';

final class PrepareBookServiceFamily extends $Family
    with $FunctionalFamilyOverride<PrepareBookService, ServerSession> {
  PrepareBookServiceFamily._()
    : super(
        retry: null,
        name: r'prepareBookServiceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  PrepareBookServiceProvider call(ServerSession session) =>
      PrepareBookServiceProvider._(argument: session, from: this);

  @override
  String toString() => r'prepareBookServiceProvider';
}

@ProviderFor(publicationContentChanges)
final publicationContentChangesProvider = PublicationContentChangesFamily._();

final class PublicationContentChangesProvider
    extends
        $FunctionalProvider<
          AsyncValue<ContentChange>,
          ContentChange,
          Stream<ContentChange>
        >
    with $FutureModifier<ContentChange>, $StreamProvider<ContentChange> {
  PublicationContentChangesProvider._({
    required PublicationContentChangesFamily super.from,
    required ServerSession super.argument,
  }) : super(
         retry: null,
         name: r'publicationContentChangesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$publicationContentChangesHash();

  @override
  String toString() {
    return r'publicationContentChangesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<ContentChange> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<ContentChange> create(Ref ref) {
    final argument = this.argument as ServerSession;
    return publicationContentChanges(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is PublicationContentChangesProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$publicationContentChangesHash() =>
    r'449a15d35310c864f138e99545e7e20843c88e0d';

final class PublicationContentChangesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<ContentChange>, ServerSession> {
  PublicationContentChangesFamily._()
    : super(
        retry: null,
        name: r'publicationContentChangesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  PublicationContentChangesProvider call(ServerSession session) =>
      PublicationContentChangesProvider._(argument: session, from: this);

  @override
  String toString() => r'publicationContentChangesProvider';
}
