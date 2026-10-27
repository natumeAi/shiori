import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/l10n/l10n.dart';

class LibraryFeedback extends StatelessWidget {
  const LibraryFeedback({required this.message, this.onRetry, super.key});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Semantics(liveRegion: true, child: Text(message)),
        if (onRetry != null)
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ),
      ],
    ),
  );
}

String libraryErrorMessage(BuildContext context, Object error) {
  if (error is ProviderException) {
    return libraryErrorMessage(context, error.exception);
  }
  final l10n = context.l10n;
  return switch (error) {
    NetworkException() => l10n.serverConnectionFailed,
    UnauthorizedException() => l10n.serverAccessDenied,
    TlsException() => l10n.serverTlsFailed,
    RedirectException() => l10n.serverFinalAddress,
    ParseException() => l10n.serverUnexpectedResponse,
    _ => l10n.libraryLoadFailed,
  };
}
