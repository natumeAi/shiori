// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_snapshot_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(librarySnapshotRepository)
final librarySnapshotRepositoryProvider = LibrarySnapshotRepositoryFamily._();

final class LibrarySnapshotRepositoryProvider
    extends
        $FunctionalProvider<
          LibrarySnapshotRepository,
          LibrarySnapshotRepository,
          LibrarySnapshotRepository
        >
    with $Provider<LibrarySnapshotRepository> {
  LibrarySnapshotRepositoryProvider._({
    required LibrarySnapshotRepositoryFamily super.from,
    required ServerSession super.argument,
  }) : super(
         retry: null,
         name: r'librarySnapshotRepositoryProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$librarySnapshotRepositoryHash();

  @override
  String toString() {
    return r'librarySnapshotRepositoryProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<LibrarySnapshotRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  LibrarySnapshotRepository create(Ref ref) {
    final argument = this.argument as ServerSession;
    return librarySnapshotRepository(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibrarySnapshotRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibrarySnapshotRepository>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LibrarySnapshotRepositoryProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$librarySnapshotRepositoryHash() =>
    r'4626e47a538cddf68229696929952498b8803a1c';

final class LibrarySnapshotRepositoryFamily extends $Family
    with $FunctionalFamilyOverride<LibrarySnapshotRepository, ServerSession> {
  LibrarySnapshotRepositoryFamily._()
    : super(
        retry: null,
        name: r'librarySnapshotRepositoryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  LibrarySnapshotRepositoryProvider call(ServerSession session) =>
      LibrarySnapshotRepositoryProvider._(argument: session, from: this);

  @override
  String toString() => r'librarySnapshotRepositoryProvider';
}
