// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'publication_download_service.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(publicationDownloadService)
final publicationDownloadServiceProvider = PublicationDownloadServiceFamily._();

final class PublicationDownloadServiceProvider
    extends
        $FunctionalProvider<
          PublicationDownloadService,
          PublicationDownloadService,
          PublicationDownloadService
        >
    with $Provider<PublicationDownloadService> {
  PublicationDownloadServiceProvider._({
    required PublicationDownloadServiceFamily super.from,
    required ServerSession super.argument,
  }) : super(
         retry: null,
         name: r'publicationDownloadServiceProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$publicationDownloadServiceHash();

  @override
  String toString() {
    return r'publicationDownloadServiceProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $ProviderElement<PublicationDownloadService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PublicationDownloadService create(Ref ref) {
    final argument = this.argument as ServerSession;
    return publicationDownloadService(ref, argument);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PublicationDownloadService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PublicationDownloadService>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is PublicationDownloadServiceProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$publicationDownloadServiceHash() =>
    r'e0d13c3d3202b334231471670b6b0f073210254e';

final class PublicationDownloadServiceFamily extends $Family
    with $FunctionalFamilyOverride<PublicationDownloadService, ServerSession> {
  PublicationDownloadServiceFamily._()
    : super(
        retry: null,
        name: r'publicationDownloadServiceProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  PublicationDownloadServiceProvider call(ServerSession session) =>
      PublicationDownloadServiceProvider._(argument: session, from: this);

  @override
  String toString() => r'publicationDownloadServiceProvider';
}
