import 'package:flutter/widgets.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/features/servers/data/server_activation_failure.dart';
import 'package:shiori/l10n/l10n.dart';

String endpointIssueMessage(BuildContext context, ServerEndpointIssue issue) {
  final l10n = context.l10n;
  return switch (issue) {
    ServerEndpointIssue.scheme => l10n.serverUrlScheme,
    ServerEndpointIssue.host => l10n.serverUrlHost,
    ServerEndpointIssue.userInfo => l10n.serverUrlCredentials,
    ServerEndpointIssue.query => l10n.serverUrlQuery,
    ServerEndpointIssue.fragment => l10n.serverUrlFragment,
    ServerEndpointIssue.percentEscape => l10n.serverUrlEscape,
    ServerEndpointIssue.backslash => l10n.serverUrlBackslash,
    ServerEndpointIssue.port => l10n.serverUrlPort,
    ServerEndpointIssue.ipv6ZoneIdentifier => l10n.serverUrlZone,
    ServerEndpointIssue.invalidAddress => l10n.serverUrlInvalid,
  };
}

String activationFailureMessage(
  BuildContext context,
  ServerActivationFailure failure,
) {
  final l10n = context.l10n;
  return switch (failure.kind) {
    ActivationFailureKind.invalidEndpoint => endpointIssueMessage(
      context,
      failure.endpointIssue ?? ServerEndpointIssue.invalidAddress,
    ),
    ActivationFailureKind.network => l10n.serverConnectionFailed,
    ActivationFailureKind.tls => l10n.serverTlsFailed,
    ActivationFailureKind.unauthorized => l10n.serverAccessDenied,
    ActivationFailureKind.wrongService => l10n.serverWrongService,
    ActivationFailureKind.databaseUnconfigured =>
      l10n.serverLibraryUnconfigured,
    ActivationFailureKind.databaseFailed => l10n.serverLibraryUnavailable,
    ActivationFailureKind.incompatibleSnapshot => l10n.serverUnsupportedVersion,
    ActivationFailureKind.malformedHealth ||
    ActivationFailureKind.malformedSnapshot => l10n.serverUnexpectedResponse,
    ActivationFailureKind.redirect => l10n.serverFinalAddress,
    ActivationFailureKind.http => l10n.serverResponseFailed,
    ActivationFailureKind.storage => l10n.serverSaveFailed,
  };
}
