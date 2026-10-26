import 'package:shiori/core/config/selection_storage_exception.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/servers/data/health_validation_exception.dart';
import 'package:shiori/features/servers/data/snapshot_validation_exception.dart';

enum ActivationFailureKind {
  invalidEndpoint,
  wrongService,
  databaseUnconfigured,
  databaseFailed,
  malformedHealth,
  incompatibleSnapshot,
  malformedSnapshot,
  tls,
  unauthorized,
  network,
  redirect,
  http,
  storage,
}

/// Feedback accompanies active data, and retains no private exceptions/bodies.
final class ServerActivationFailure implements Exception {
  const ServerActivationFailure(
    this.kind, {
    this.endpointIssue,
    this.storageIssue,
    this.redirectIssue,
    this.statusCode,
  });

  final ActivationFailureKind kind;
  final ServerEndpointIssue? endpointIssue;
  final SelectionStorageIssue? storageIssue;
  final RedirectIssue? redirectIssue;
  final int? statusCode;

  static ServerActivationFailure? classify(Object error) => switch (error) {
    HealthValidationException(:final issue) => ServerActivationFailure(
      switch (issue) {
        HealthIssue.wrongService => ActivationFailureKind.wrongService,
        HealthIssue.databaseUnconfigured =>
          ActivationFailureKind.databaseUnconfigured,
        HealthIssue.databaseFailed => ActivationFailureKind.databaseFailed,
        HealthIssue.malformed => ActivationFailureKind.malformedHealth,
      },
    ),
    SnapshotValidationException(:final issue) => ServerActivationFailure(
      switch (issue) {
        SnapshotValidationIssue.incompatible =>
          ActivationFailureKind.incompatibleSnapshot,
        SnapshotValidationIssue.malformed =>
          ActivationFailureKind.malformedSnapshot,
      },
    ),
    SelectionStorageException(:final issue) => ServerActivationFailure(
      ActivationFailureKind.storage,
      storageIssue: issue,
    ),
    TlsException() => const ServerActivationFailure(ActivationFailureKind.tls),
    UnauthorizedException() => const ServerActivationFailure(
      ActivationFailureKind.unauthorized,
    ),
    NetworkException() => const ServerActivationFailure(
      ActivationFailureKind.network,
    ),
    RedirectException(:final issue) => ServerActivationFailure(
      ActivationFailureKind.redirect,
      redirectIssue: issue,
    ),
    ServerException(:final statusCode) => ServerActivationFailure(
      ActivationFailureKind.http,
      statusCode: statusCode,
    ),
    ParseException() => const ServerActivationFailure(
      ActivationFailureKind.malformedSnapshot,
    ),
    _ => null,
  };
}
