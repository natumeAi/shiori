// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_directories.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(appDirectories)
final appDirectoriesProvider = AppDirectoriesProvider._();

final class AppDirectoriesProvider
    extends $FunctionalProvider<AppDirectories, AppDirectories, AppDirectories>
    with $Provider<AppDirectories> {
  AppDirectoriesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDirectoriesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDirectoriesHash();

  @$internal
  @override
  $ProviderElement<AppDirectories> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDirectories create(Ref ref) {
    return appDirectories(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDirectories value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDirectories>(value),
    );
  }
}

String _$appDirectoriesHash() => r'f9039179bc824bbc34cc0f28ce0a59f44836d989';
