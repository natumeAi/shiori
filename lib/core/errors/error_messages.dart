import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/l10n/l10n.dart';

/// Maps any error that reaches the UI to a localized, user-facing message.
String errorMessage(BuildContext context, Object error) {
  final l10n = context.l10n;
  return switch (_unwrap(error)) {
    NetworkException() => l10n.errorNetwork,
    UnauthorizedException() => l10n.errorUnauthorized,
    ServerException() || ParseException() => l10n.errorServer,
    _ => l10n.errorUnexpected,
  };
}

/// Riverpod 3 wraps errors from dependent providers in [ProviderException],
/// once per level of the dependency chain.
Object _unwrap(Object error) => switch (error) {
  ProviderException(:final exception) => _unwrap(exception),
  _ => error,
};
