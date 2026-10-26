// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'server_activation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ServerActivationController)
final serverActivationControllerProvider =
    ServerActivationControllerProvider._();

final class ServerActivationControllerProvider
    extends
        $AsyncNotifierProvider<
          ServerActivationController,
          ServerActivationState
        > {
  ServerActivationControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serverActivationControllerProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serverActivationControllerHash();

  @$internal
  @override
  ServerActivationController create() => ServerActivationController();
}

String _$serverActivationControllerHash() =>
    r'2f1c1e74b6a41398dc09cc1c7aee644fbd1fab2c';

abstract class _$ServerActivationController
    extends $AsyncNotifier<ServerActivationState> {
  FutureOr<ServerActivationState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<ServerActivationState>, ServerActivationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ServerActivationState>,
                ServerActivationState
              >,
              AsyncValue<ServerActivationState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
