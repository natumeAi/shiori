// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diagnostic_recorder.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(diagnosticRecorder)
final diagnosticRecorderProvider = DiagnosticRecorderProvider._();

final class DiagnosticRecorderProvider
    extends
        $FunctionalProvider<
          DiagnosticRecorder,
          DiagnosticRecorder,
          DiagnosticRecorder
        >
    with $Provider<DiagnosticRecorder> {
  DiagnosticRecorderProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diagnosticRecorderProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diagnosticRecorderHash();

  @$internal
  @override
  $ProviderElement<DiagnosticRecorder> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DiagnosticRecorder create(Ref ref) {
    return diagnosticRecorder(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiagnosticRecorder value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiagnosticRecorder>(value),
    );
  }
}

String _$diagnosticRecorderHash() =>
    r'974fd9c4ae403e12f23a4d486aa110221c916974';
