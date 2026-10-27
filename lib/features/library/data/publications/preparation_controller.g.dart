// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'preparation_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// UI-facing ownership; explicit prepare/retry, no side effects during build.

@ProviderFor(PreparationController)
final preparationControllerProvider = PreparationControllerFamily._();

/// UI-facing ownership; explicit prepare/retry, no side effects during build.
final class PreparationControllerProvider
    extends $NotifierProvider<PreparationController, PreparationState> {
  /// UI-facing ownership; explicit prepare/retry, no side effects during build.
  PreparationControllerProvider._({
    required PreparationControllerFamily super.from,
    required (ServerSession, BookKey) super.argument,
  }) : super(
         retry: null,
         name: r'preparationControllerProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$preparationControllerHash();

  @override
  String toString() {
    return r'preparationControllerProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  PreparationController create() => PreparationController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PreparationState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PreparationState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PreparationControllerProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$preparationControllerHash() =>
    r'bb27f9ab39ae29fa16556a7efcc643114d94035d';

/// UI-facing ownership; explicit prepare/retry, no side effects during build.

final class PreparationControllerFamily extends $Family
    with
        $ClassFamilyOverride<
          PreparationController,
          PreparationState,
          PreparationState,
          PreparationState,
          (ServerSession, BookKey)
        > {
  PreparationControllerFamily._()
    : super(
        retry: null,
        name: r'preparationControllerProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// UI-facing ownership; explicit prepare/retry, no side effects during build.

  PreparationControllerProvider call(ServerSession session, BookKey key) =>
      PreparationControllerProvider._(argument: (session, key), from: this);

  @override
  String toString() => r'preparationControllerProvider';
}

/// UI-facing ownership; explicit prepare/retry, no side effects during build.

abstract class _$PreparationController extends $Notifier<PreparationState> {
  late final _$args = ref.$arg as (ServerSession, BookKey);
  ServerSession get session => _$args.$1;
  BookKey get key => _$args.$2;

  PreparationState build(ServerSession session, BookKey key);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<PreparationState, PreparationState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PreparationState, PreparationState>,
              PreparationState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args.$1, _$args.$2));
  }
}
