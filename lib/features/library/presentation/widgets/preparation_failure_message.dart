import 'package:flutter/widgets.dart';
import 'package:shiori/features/library/data/publications/prepare_book_exception.dart';
import 'package:shiori/l10n/l10n.dart';

String preparationFailureMessage(
  BuildContext context,
  PrepareBookFailure failure,
) {
  final l10n = context.l10n;
  return switch (failure) {
    PrepareBookFailure.unavailable => l10n.libraryPreparationUnavailable,
    PrepareBookFailure.network => l10n.serverConnectionFailed,
    PrepareBookFailure.tooLarge => l10n.libraryPreparationTooLarge,
    PrepareBookFailure.cacheBusy => l10n.libraryPreparationBusy,
    PrepareBookFailure.invalidStructure => l10n.libraryPreparationInvalid,
    PrepareBookFailure.unsupportedStructure =>
      l10n.libraryPreparationUnsupported,
    PrepareBookFailure.storage => l10n.libraryPreparationStorage,
    PrepareBookFailure.unauthorized => l10n.serverAccessDenied,
    PrepareBookFailure.tls => l10n.serverTlsFailed,
    PrepareBookFailure.server => l10n.serverResponseFailed,
    PrepareBookFailure.redirect => l10n.serverFinalAddress,
    PrepareBookFailure.workerUnavailable => l10n.libraryPreparationInterrupted,
  };
}
