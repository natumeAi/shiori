// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'library_snapshot_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(LibrarySnapshotController)
final librarySnapshotControllerProvider = LibrarySnapshotControllerFamily._();

final class LibrarySnapshotControllerProvider
    extends $NotifierProvider<LibrarySnapshotController, LibrarySnapshotState> {
  LibrarySnapshotControllerProvider._({
    required LibrarySnapshotControllerFamily super.from,
    required ServerSession super.argument,
  }) : super(
         retry: null,
         name: r'librarySnapshotControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$librarySnapshotControllerHash();

  @override
  String toString() {
    return r'librarySnapshotControllerProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  LibrarySnapshotController create() => LibrarySnapshotController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(LibrarySnapshotState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<LibrarySnapshotState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is LibrarySnapshotControllerProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$librarySnapshotControllerHash() =>
    r'c3dcae517470f6a4db28cdbdb5df5c17d415bf74';

final class LibrarySnapshotControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          LibrarySnapshotController,
          LibrarySnapshotState,
          LibrarySnapshotState,
          LibrarySnapshotState,
          ServerSession
        > {
  LibrarySnapshotControllerFamily._()
    : super(
        retry: null,
        name: r'librarySnapshotControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LibrarySnapshotControllerProvider call(ServerSession session) =>
      LibrarySnapshotControllerProvider._(argument: session, from: this);

  @override
  String toString() => r'librarySnapshotControllerProvider';
}

abstract class _$LibrarySnapshotController
    extends $Notifier<LibrarySnapshotState> {
  late final _$args = ref.$arg as ServerSession;
  ServerSession get session => _$args;

  LibrarySnapshotState build(ServerSession session);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<LibrarySnapshotState, LibrarySnapshotState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<LibrarySnapshotState, LibrarySnapshotState>,
              LibrarySnapshotState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
