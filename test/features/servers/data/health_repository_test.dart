import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/servers/data/health_repository.dart';
import 'package:shiori/features/servers/data/health_validation_exception.dart';
import 'package:shiori/features/servers/data/models/server_health.dart';

import '../server_activation_test_support.dart';

void main() {
  Future<void> check(
    String body,
    HealthIssue? issue, {
    int status = 200,
  }) async {
    final adapter = FakeServerAdapter((_, _) => jsonBody(body, status));
    final transport = SessionTransport(
      ServerSession(endpoint: endpoint('health'), generation: 1),
      adapter: adapter,
    );
    addTearDown(transport.dispose);
    final request = HealthRepository(transport).validate();
    if (issue == null) {
      expect((await request).database, 'ok');
    } else {
      await expectLater(
        request,
        throwsA(
          isA<HealthValidationException>().having(
            (e) => e.issue,
            'issue',
            issue,
          ),
        ),
      );
    }
    expect(adapter.requests.single.uri.path, '/Reader/api/health');
    expect(adapter.requests.single.method, 'GET');
    expect(
      adapter.requests.single.headers.keys,
      isNot(contains('If-None-Match')),
    );
  }

  for (final file in ['health_ok.json', 'health_additive.json']) {
    test(
      '$file is usable, including additive fields',
      () => check(fixture(file), null),
    );
  }
  test(
    'wrong-service fixture is a distinct failure',
    () => check(fixture('health_wrong_service.json'), HealthIssue.wrongService),
  );
  test(
    'unconfigured database fixture is a distinct failure',
    () => check(
      fixture('health_database_unconfigured.json'),
      HealthIssue.databaseUnconfigured,
    ),
  );
  test(
    'failed database is the actual HTTP 500 envelope',
    () => check(
      fixture('health_database_error.json'),
      HealthIssue.databaseFailed,
      status: 500,
    ),
  );

  for (final field in ['status', 'service', 'database']) {
    for (final badValue in [null, 42, <Object?>[]]) {
      test('checked DTO rejects $field with ${badValue.runtimeType}', () {
        final body =
            jsonDecode(fixture('health_ok.json')) as Map<String, Object?>;
        body[field] = badValue;
        expect(
          () => ServerHealth.fromJson(body),
          throwsA(isA<CheckedFromJsonException>()),
        );
      });
    }
    test('missing $field becomes malformed health at repository boundary', () {
      final body =
          jsonDecode(fixture('health_ok.json')) as Map<String, Object?>;
      body.remove(field);
      return check(jsonEncode(body), HealthIssue.malformed);
    });
  }
  for (final body in [
    'null',
    '[]',
    '"ok"',
    '{}',
    '{',
    '<html>login</html>',
    '{"status":"failed","service":"epub-reader-server","database":"ok"}',
    '{"status":"ok","service":"epub-reader-server","database":"error"}',
  ]) {
    test(
      'malformed body case ${body.hashCode} is typed',
      () => check(body, HealthIssue.malformed),
    );
  }
}
