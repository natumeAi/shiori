// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'probe_sqlite_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(probeSqliteRepository)
final probeSqliteRepositoryProvider = ProbeSqliteRepositoryProvider._();

final class ProbeSqliteRepositoryProvider
    extends
        $FunctionalProvider<
          ProbeSqliteRepository,
          ProbeSqliteRepository,
          ProbeSqliteRepository
        >
    with $Provider<ProbeSqliteRepository> {
  ProbeSqliteRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'probeSqliteRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$probeSqliteRepositoryHash();

  @$internal
  @override
  $ProviderElement<ProbeSqliteRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ProbeSqliteRepository create(Ref ref) {
    return probeSqliteRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ProbeSqliteRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ProbeSqliteRepository>(value),
    );
  }
}

String _$probeSqliteRepositoryHash() =>
    r'24f1bfe49f096d123a55d92497a7528ee827f8c4';
