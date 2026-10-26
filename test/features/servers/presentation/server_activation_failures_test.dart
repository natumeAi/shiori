import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/retry_policy.dart';
import 'package:shiori/features/servers/data/server_activation_failure.dart';
import 'package:shiori/features/servers/data/snapshot_validation_exception.dart';

import '../server_activation_test_support.dart';

void main() {
  final cases = <(String, ActivationFailureKind, ResponseBody Function())>[
    (
      'wrong service',
      ActivationFailureKind.wrongService,
      () => jsonBody(fixture('health_wrong_service.json')),
    ),
    (
      'database unconfigured',
      ActivationFailureKind.databaseUnconfigured,
      () => jsonBody(fixture('health_database_unconfigured.json')),
    ),
    (
      'database failed',
      ActivationFailureKind.databaseFailed,
      () => jsonBody(fixture('health_database_error.json'), 500),
    ),
    (
      'malformed health',
      ActivationFailureKind.malformedHealth,
      () => jsonBody('{}'),
    ),
    (
      'HTML login',
      ActivationFailureKind.malformedHealth,
      () => ResponseBody.fromString(
        fixture('proxy_login.html'),
        200,
        headers: {
          'content-type': ['text/html'],
        },
      ),
    ),
    ('401', ActivationFailureKind.unauthorized, () => jsonBody('{}', 401)),
    ('403', ActivationFailureKind.unauthorized, () => jsonBody('{}', 403)),
    ('HTTP unavailable', ActivationFailureKind.http, () => jsonBody('{}', 503)),
    (
      'outside redirect',
      ActivationFailureKind.redirect,
      () => jsonBody('', 302, {
        'location': ['https://other.example.test/Reader/api/health'],
      }),
    ),
  ];
  for (final (label, kind, response) in cases) {
    test(
      '$label has distinct safe feedback and preserves previous selection',
      () async {
        var failCandidate = false;
        final h = ActivationHarness(
          respond: (_, _, index) => failCandidate
              ? response()
              : jsonBody(index == 0 ? fixture('health_ok.json') : '{}'),
        );
        await h.restore();
        await h.activate('a');
        final old = h.state.session;
        failCandidate = true;
        await h.activate('b');
        expect(h.state.session, same(old));
        expect(h.state.failure!.kind, kind);
        expect(h.store.commits, hasLength(1));
        expect(h.activeAdapters.single.closed, isFalse);
        expect(h.candidates.last.forceClosed, isTrue);
        expect(h.candidates.last.requests, hasLength(1));
        if (kind == ActivationFailureKind.http) {
          expect(h.state.failure!.statusCode, 503);
        }
        if (kind == ActivationFailureKind.redirect) {
          expect(
            h.state.failure!.redirectIssue,
            RedirectIssue.outsideDeployment,
          );
        }
      },
    );
  }

  for (final (type, kind) in [
    (DioExceptionType.badCertificate, ActivationFailureKind.tls),
    (DioExceptionType.connectionTimeout, ActivationFailureKind.network),
    (DioExceptionType.receiveTimeout, ActivationFailureKind.network),
  ]) {
    test(
      '${type.name} is classified distinctly without losing active data',
      () async {
        var failCandidate = false;
        var retries = 0;
        final h = ActivationHarness(
          retry: (count, error) {
            retries++;
            return retryNetworkErrors(count, error);
          },
          respond: (_, options, index) {
            if (failCandidate) {
              throw DioException(requestOptions: options, type: type);
            }
            return jsonBody(index == 0 ? fixture('health_ok.json') : '{}');
          },
        );
        await h.restore();
        await h.activate('a');
        final old = h.state.session;
        failCandidate = true;
        await h.activate('b');
        expect(h.state.failure!.kind, kind);
        expect(h.state.session, same(old));
        // Candidate actions own recoverable feedback; no failed provider/retry.
        expect(retries, 0);
        expect(h.candidates.last.requests, hasLength(1));
      },
    );
  }

  for (final issue in SnapshotValidationIssue.values) {
    test(
      'snapshot ${issue.name} prevents commit and preserves old session',
      () async {
        final validator = FakeSnapshotValidator();
        final h = ActivationHarness(validator: validator);
        await h.restore();
        await h.activate('a');
        final old = h.state.session;
        validator.respond = (_) => throw SnapshotValidationException(issue);
        await h.activate('b');
        expect(
          h.state.failure!.kind,
          issue == SnapshotValidationIssue.incompatible
              ? ActivationFailureKind.incompatibleSnapshot
              : ActivationFailureKind.malformedSnapshot,
        );
        expect(h.state.session, same(old));
        expect(h.store.commits, hasLength(1));
      },
    );
  }

  test('snapshot transport malformed JSON is a snapshot failure', () async {
    final h = ActivationHarness(
      respond: (_, _, index) =>
          jsonBody(index == 0 ? fixture('health_ok.json') : '{'),
    );
    await h.restore();
    await h.activate('a');
    expect(h.state.failure!.kind, ActivationFailureKind.malformedSnapshot);
    expect(h.store.commits, isEmpty);
  });

  test('validator cancellation is consumed with no error or retry', () async {
    final validator = FakeSnapshotValidator()
      ..respond = (_) => throw const RequestCancelled();
    final h = ActivationHarness(validator: validator);
    await h.restore();
    await h.activate('a');
    expect(h.state.failure, isNull);
    expect(h.store.commits, isEmpty);
    expect(retryNetworkErrors(0, const RequestCancelled()), isNull);
  });
}
