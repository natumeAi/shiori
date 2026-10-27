// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_publication_worker.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sessionPublicationWorker)
final sessionPublicationWorkerProvider = SessionPublicationWorkerFamily._();

final class SessionPublicationWorkerProvider
    extends
        $FunctionalProvider<
          SessionPublicationWorker,
          SessionPublicationWorker,
          SessionPublicationWorker
        >
    with $Provider<SessionPublicationWorker> {
  SessionPublicationWorkerProvider._({
    required SessionPublicationWorkerFamily super.from,
    required ServerSession super.argument,
  }) : super(
         retry: null,
         name: r'sessionPublicationWorkerProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionPublicationWorkerHash();

  @override
  String toString() {
    return r'sessionPublicationWorkerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<SessionPublicationWorker> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SessionPublicationWorker create(Ref ref) {
    final argument = this.argument as ServerSession;
    return sessionPublicationWorker(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionPublicationWorker value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionPublicationWorker>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SessionPublicationWorkerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionPublicationWorkerHash() =>
    r'64e8983428b6e5d444624b5dbc73381eddee220c';

final class SessionPublicationWorkerFamily extends $Family
    with $FunctionalFamilyOverride<SessionPublicationWorker, ServerSession> {
  SessionPublicationWorkerFamily._()
    : super(
        retry: null,
        name: r'sessionPublicationWorkerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  SessionPublicationWorkerProvider call(ServerSession session) =>
      SessionPublicationWorkerProvider._(argument: session, from: this);

  @override
  String toString() => r'sessionPublicationWorkerProvider';
}
