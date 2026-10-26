// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'session_transport.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The coordinator must dispose/invalidate a retired session family instance.

@ProviderFor(sessionTransport)
final sessionTransportProvider = SessionTransportFamily._();

/// The coordinator must dispose/invalidate a retired session family instance.

final class SessionTransportProvider
    extends
        $FunctionalProvider<
          SessionTransport,
          SessionTransport,
          SessionTransport
        >
    with $Provider<SessionTransport> {
  /// The coordinator must dispose/invalidate a retired session family instance.
  SessionTransportProvider._({
    required SessionTransportFamily super.from,
    required ServerSession super.argument,
  }) : super(
         retry: null,
         name: r'sessionTransportProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sessionTransportHash();

  @override
  String toString() {
    return r'sessionTransportProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<SessionTransport> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SessionTransport create(Ref ref) {
    final argument = this.argument as ServerSession;
    return sessionTransport(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SessionTransport value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SessionTransport>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SessionTransportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sessionTransportHash() => r'9e6930304f130c89a4357f37a82e1ccf4de14d41';

/// The coordinator must dispose/invalidate a retired session family instance.

final class SessionTransportFamily extends $Family
    with $FunctionalFamilyOverride<SessionTransport, ServerSession> {
  SessionTransportFamily._()
    : super(
        retry: null,
        name: r'sessionTransportProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// The coordinator must dispose/invalidate a retired session family instance.

  SessionTransportProvider call(ServerSession session) =>
      SessionTransportProvider._(argument: session, from: this);

  @override
  String toString() => r'sessionTransportProvider';
}
