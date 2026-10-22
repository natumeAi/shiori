// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'probe_storage_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ProbeStorageController)
final probeStorageControllerProvider = ProbeStorageControllerProvider._();

final class ProbeStorageControllerProvider
    extends $AsyncNotifierProvider<ProbeStorageController, ProbeSavedState> {
  ProbeStorageControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'probeStorageControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$probeStorageControllerHash();

  @$internal
  @override
  ProbeStorageController create() => ProbeStorageController();
}

String _$probeStorageControllerHash() =>
    r'82f3e035a35ffe2da1d004a46566833c58b8924c';

abstract class _$ProbeStorageController
    extends $AsyncNotifier<ProbeSavedState> {
  FutureOr<ProbeSavedState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<ProbeSavedState>, ProbeSavedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ProbeSavedState>, ProbeSavedState>,
              AsyncValue<ProbeSavedState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
