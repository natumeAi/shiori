// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_activation_dependencies.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// App composition must override this port with the SQLite adapter.

@ProviderFor(serverSelectionStore)
final serverSelectionStoreProvider = ServerSelectionStoreProvider._();

/// App composition must override this port with the SQLite adapter.

final class ServerSelectionStoreProvider
    extends
        $FunctionalProvider<
          ServerSelectionStore,
          ServerSelectionStore,
          ServerSelectionStore
        >
    with $Provider<ServerSelectionStore> {
  /// App composition must override this port with the SQLite adapter.
  ServerSelectionStoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverSelectionStoreProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverSelectionStoreHash();

  @$internal
  @override
  $ProviderElement<ServerSelectionStore> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ServerSelectionStore create(Ref ref) {
    return serverSelectionStore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServerSelectionStore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerSelectionStore>(value),
    );
  }
}

String _$serverSelectionStoreHash() =>
    r'c1d9032019ce592aae8e81f0fc50d0add35fb3f9';

/// App composition must override this port with the Phase C validator.

@ProviderFor(candidateSnapshotValidator)
final candidateSnapshotValidatorProvider =
    CandidateSnapshotValidatorProvider._();

/// App composition must override this port with the Phase C validator.

final class CandidateSnapshotValidatorProvider
    extends
        $FunctionalProvider<
          CandidateSnapshotValidator,
          CandidateSnapshotValidator,
          CandidateSnapshotValidator
        >
    with $Provider<CandidateSnapshotValidator> {
  /// App composition must override this port with the Phase C validator.
  CandidateSnapshotValidatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'candidateSnapshotValidatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$candidateSnapshotValidatorHash();

  @$internal
  @override
  $ProviderElement<CandidateSnapshotValidator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CandidateSnapshotValidator create(Ref ref) {
    return candidateSnapshotValidator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CandidateSnapshotValidator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CandidateSnapshotValidator>(value),
    );
  }
}

String _$candidateSnapshotValidatorHash() =>
    r'c6f65d1d1b1d36819b76ee6b2c56ac8201b73c51';

/// Temporary transports have no active-session provider identity.

@ProviderFor(candidateTransportFactory)
final candidateTransportFactoryProvider = CandidateTransportFactoryProvider._();

/// Temporary transports have no active-session provider identity.

final class CandidateTransportFactoryProvider
    extends
        $FunctionalProvider<
          CandidateTransportFactory,
          CandidateTransportFactory,
          CandidateTransportFactory
        >
    with $Provider<CandidateTransportFactory> {
  /// Temporary transports have no active-session provider identity.
  CandidateTransportFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'candidateTransportFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$candidateTransportFactoryHash();

  @$internal
  @override
  $ProviderElement<CandidateTransportFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CandidateTransportFactory create(Ref ref) {
    return candidateTransportFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CandidateTransportFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CandidateTransportFactory>(value),
    );
  }
}

String _$candidateTransportFactoryHash() =>
    r'0181165ff54be13e4dee6522e02472ad5901dce7';

/// Read dynamically so retiring a family does not rebuild the coordinator that
/// owns that retirement. Other consumers still watch the session family.

@ProviderFor(activeSessionTransportFactory)
final activeSessionTransportFactoryProvider =
    ActiveSessionTransportFactoryProvider._();

/// Read dynamically so retiring a family does not rebuild the coordinator that
/// owns that retirement. Other consumers still watch the session family.

final class ActiveSessionTransportFactoryProvider
    extends
        $FunctionalProvider<
          CandidateTransportFactory,
          CandidateTransportFactory,
          CandidateTransportFactory
        >
    with $Provider<CandidateTransportFactory> {
  /// Read dynamically so retiring a family does not rebuild the coordinator that
  /// owns that retirement. Other consumers still watch the session family.
  ActiveSessionTransportFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'activeSessionTransportFactoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$activeSessionTransportFactoryHash();

  @$internal
  @override
  $ProviderElement<CandidateTransportFactory> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  CandidateTransportFactory create(Ref ref) {
    return activeSessionTransportFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CandidateTransportFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CandidateTransportFactory>(value),
    );
  }
}

String _$activeSessionTransportFactoryHash() =>
    r'30133b96781d41cb5bc6b9efea572e9dd80a55ee';

@ProviderFor(sessionPublicationGuard)
final sessionPublicationGuardProvider = SessionPublicationGuardProvider._();

final class SessionPublicationGuardProvider
    extends
        $FunctionalProvider<
          SessionPublicationGuard,
          SessionPublicationGuard,
          SessionPublicationGuard
        >
    with $Provider<SessionPublicationGuard> {
  SessionPublicationGuardProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sessionPublicationGuardProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sessionPublicationGuardHash();

  @$internal
  @override
  $ProviderElement<SessionPublicationGuard> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionPublicationGuard create(Ref ref) {
    return sessionPublicationGuard(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionPublicationGuard value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionPublicationGuard>(value),
    );
  }
}

String _$sessionPublicationGuardHash() =>
    r'06525b24dd0f7a7cde2992f2c6d8b1c98f303707';
