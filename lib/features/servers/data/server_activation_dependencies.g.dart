// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_activation_dependencies.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Production uses the container-owned SQLite worker; tests may override the port.

@ProviderFor(serverSelectionStore)
final serverSelectionStoreProvider = ServerSelectionStoreProvider._();

/// Production uses the container-owned SQLite worker; tests may override the port.

final class ServerSelectionStoreProvider
    extends
        $FunctionalProvider<
          ServerSelectionStore,
          ServerSelectionStore,
          ServerSelectionStore
        >
    with $Provider<ServerSelectionStore> {
  /// Production uses the container-owned SQLite worker; tests may override the port.
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
    r'047beb4a610ae47d936a69abc38abae526c0e21a';

/// Phase C supplies validation. Until configured, activation fails recoverably
/// as an incompatible snapshot without dispatching a commit.

@ProviderFor(candidateSnapshotValidator)
final candidateSnapshotValidatorProvider =
    CandidateSnapshotValidatorProvider._();

/// Phase C supplies validation. Until configured, activation fails recoverably
/// as an incompatible snapshot without dispatching a commit.

final class CandidateSnapshotValidatorProvider
    extends
        $FunctionalProvider<
          CandidateSnapshotValidator,
          CandidateSnapshotValidator,
          CandidateSnapshotValidator
        >
    with $Provider<CandidateSnapshotValidator> {
  /// Phase C supplies validation. Until configured, activation fails recoverably
  /// as an incompatible snapshot without dispatching a commit.
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
    r'a15c5d735839f28d4098a2d2b6c95b1c2e9c3b1e';

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

@ProviderFor(serverActivationSerializer)
final serverActivationSerializerProvider =
    ServerActivationSerializerProvider._();

final class ServerActivationSerializerProvider
    extends
        $FunctionalProvider<
          ServerActivationSerializer,
          ServerActivationSerializer,
          ServerActivationSerializer
        >
    with $Provider<ServerActivationSerializer> {
  ServerActivationSerializerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverActivationSerializerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverActivationSerializerHash();

  @$internal
  @override
  $ProviderElement<ServerActivationSerializer> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ServerActivationSerializer create(Ref ref) {
    return serverActivationSerializer(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServerActivationSerializer value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServerActivationSerializer>(value),
    );
  }
}

String _$serverActivationSerializerHash() =>
    r'95f442aa92d33d39367acc42914e6a14e22c5212';
