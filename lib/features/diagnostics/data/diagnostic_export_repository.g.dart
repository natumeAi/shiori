// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'diagnostic_export_repository.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(diagnosticExportRepository)
final diagnosticExportRepositoryProvider =
    DiagnosticExportRepositoryProvider._();

final class DiagnosticExportRepositoryProvider
    extends
        $FunctionalProvider<
          DiagnosticExportRepository,
          DiagnosticExportRepository,
          DiagnosticExportRepository
        >
    with $Provider<DiagnosticExportRepository> {
  DiagnosticExportRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'diagnosticExportRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$diagnosticExportRepositoryHash();

  @$internal
  @override
  $ProviderElement<DiagnosticExportRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  DiagnosticExportRepository create(Ref ref) {
    return diagnosticExportRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DiagnosticExportRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DiagnosticExportRepository>(value),
    );
  }
}

String _$diagnosticExportRepositoryHash() =>
    r'478ee5b61eaea9cbdef01dc80e056e432918c7df';
