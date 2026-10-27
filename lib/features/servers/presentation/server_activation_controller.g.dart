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
    r'a4d23ec55213d0541f32cab3241479985e50d9ca';

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
