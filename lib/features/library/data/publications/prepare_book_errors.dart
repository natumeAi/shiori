part of 'prepare_book_service.dart';

PrepareBookException _preparationError(Object error) {
  if (error is ProviderException) return _preparationError(error.exception);
  if (error is PrepareBookException) return error;
  final failure = switch (error) {
    DownloadException(:final failure) => switch (failure) {
      DownloadFailure.storage => PrepareBookFailure.storage,
      DownloadFailure.stagingBusy => PrepareBookFailure.cacheBusy,
      DownloadFailure.tooLarge => PrepareBookFailure.tooLarge,
      DownloadFailure.invalidValidators => PrepareBookFailure.invalidStructure,
    },
    PublicationCacheException(:final failure) => switch (failure) {
      PublicationCacheFailure.storage => PrepareBookFailure.storage,
      PublicationCacheFailure.cacheBusy => PrepareBookFailure.cacheBusy,
      PublicationCacheFailure.tooLarge => PrepareBookFailure.tooLarge,
      PublicationCacheFailure.invalidGeneration =>
        PrepareBookFailure.invalidStructure,
    },
    PublicationImportException() ||
    ParseException() => PrepareBookFailure.invalidStructure,
    PublicationWorkerException(:final failure) => switch (failure) {
      PublicationWorkerFailure.resourceTooLarge => PrepareBookFailure.tooLarge,
      PublicationWorkerFailure.incompatibleIdentity =>
        PrepareBookFailure.unsupportedStructure,
      PublicationWorkerFailure.queueFull => PrepareBookFailure.cacheBusy,
      _ => PrepareBookFailure.workerUnavailable,
    },
    FileSystemException() || StorageException() => PrepareBookFailure.storage,
    NetworkException() => PrepareBookFailure.network,
    UnauthorizedException() => PrepareBookFailure.unauthorized,
    TlsException() => PrepareBookFailure.tls,
    RedirectException() => PrepareBookFailure.redirect,
    ServerException(statusCode: 404) => PrepareBookFailure.unavailable,
    ServerException() => PrepareBookFailure.server,
    _ => PrepareBookFailure.workerUnavailable,
  };
  return PrepareBookException(failure);
}
