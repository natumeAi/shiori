// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cover_loader.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(coverLoader)
final coverLoaderProvider = CoverLoaderFamily._();

final class CoverLoaderProvider
    extends $FunctionalProvider<CoverLoader, CoverLoader, CoverLoader>
    with $Provider<CoverLoader> {
  CoverLoaderProvider._({
    required CoverLoaderFamily super.from,
    required ServerSession super.argument,
  }) : super(
         retry: null,
         name: r'coverLoaderProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$coverLoaderHash();

  @override
  String toString() {
    return r'coverLoaderProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<CoverLoader> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  CoverLoader create(Ref ref) {
    final argument = this.argument as ServerSession;
    return coverLoader(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CoverLoader value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CoverLoader>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is CoverLoaderProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$coverLoaderHash() => r'75656ed925adc2e77199c9e1e6917e4c646d5eaa';

final class CoverLoaderFamily extends $Family
    with $FunctionalFamilyOverride<CoverLoader, ServerSession> {
  CoverLoaderFamily._()
    : super(
        retry: null,
        name: r'coverLoaderProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  CoverLoaderProvider call(ServerSession session) =>
      CoverLoaderProvider._(argument: session, from: this);

  @override
  String toString() => r'coverLoaderProvider';
}
