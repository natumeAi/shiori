import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/request_cancelled.dart';
import 'package:shiori/core/network/session_transport.dart';
import 'package:shiori/features/library/data/library_snapshot_validator.dart';
import 'package:shiori/features/servers/data/snapshot_validation_exception.dart';

import '../../../core/network/fake_server_adapter.dart';
import 'library_test_support.dart';

void main() {
  SessionTransport transport(
    String raw, {
    int status = 200,
    Map<String, List<String>> headers = const {},
  }) {
    final value = SessionTransport(
      session(),
      adapter: FakeServerAdapter((_, _) => jsonBody(raw, status, headers)),
    );
    addTearDown(value.dispose);
    return value;
  }

  final now = DateTime.utc(2026, 10, 26, 1, 2, 3, 4, 567);
  final validator = LibrarySnapshotValidator(now: () => now);
  Matcher issue(SnapshotValidationIssue value) => throwsA(
    isA<SnapshotValidationException>().having((e) => e.issue, 'issue', value),
  );

  test(
    'unconditional candidate request retains validators, payload and time',
    () async {
      final raw = fixture('snapshot_additive.json');
      final adapter = FakeServerAdapter(
        (_, _) => jsonBody(raw, 200, {
          'ETag': [' W/"opaque: AbC/42" '],
          'X-Library-Revision': ['42'],
        }),
      );
      final candidate = SessionTransport(session(), adapter: adapter);
      addTearDown(candidate.dispose);
      final value = await validator.validate(candidate);
      expect(value.schemaVersion, 1);
      expect(value.revision, 42);
      expect(value.etag, ' W/"opaque: AbC/42" ');
      expect(value.fetchedAt, now);
      expect(value.payloadText, raw);
      expect(
        utf8.encode(value.payloadText),
        File('test/fixtures/server/snapshot_additive.json').readAsBytesSync(),
      );
      final request = adapter.requests.single;
      expect(request.method, 'GET');
      expect(request.uri.path, '/Reader/api/library/snapshot');
      expect(request.headers.containsKey('If-None-Match'), isFalse);
      expect(request.headers.containsKey('If-Modified-Since'), isFalse);
    },
  );
  test(
    'missing validators is valid, using body revision including zero',
    () async {
      final value = await validator.validate(
        transport(fixture('snapshot_empty.json')),
      );
      expect(value.revision, 0);
      expect(value.etag, isNull);
    },
  );
  for (final name in [
    'typical',
    'minimal',
    'empty',
    'explicit_offset',
    'additive',
  ]) {
    test('validator accepts fixture $name', () async {
      final raw = fixture('snapshot_$name.json');
      final value = await validator.validate(transport(raw));
      expect(value.schemaVersion, 1);
      expect(value.payloadText, raw);
      expect(
        utf8.encode(value.payloadText),
        File('test/fixtures/server/snapshot_$name.json').readAsBytesSync(),
      );
    });
  }
  test(
    'validated text keeps Unicode, escapes and original number notation',
    () async {
      final raw = fixture('snapshot_minimal.json')
          .replaceFirst('"version": 42', '"version": 42.0')
          .replaceFirst(
            '"snapshot": {',
            '"snapshot": {"future": {"text":"雪📚", "escaped":"\\u96ea", "value":1.0e-7},',
          );
      final value = await validator.validate(transport(raw));
      expect(value.revision, 42);
      expect(value.payloadText, raw);
      expect(utf8.encode(value.payloadText), utf8.encode(raw));
    },
  );
  for (final name in [
    'schema_version',
    'missing_nullable',
    'unsafe_id',
    'non_positive_id',
    'fractional_id',
    'duplicate_book_id',
    'missing_folder_book',
    'missing_shelf_record',
    'shelf_enum',
  ]) {
    test('validator classifies invalid fixture $name', () async {
      await expectLater(
        validator.validate(transport(fixture('snapshot_invalid_$name.json'))),
        issue(
          name == 'schema_version'
              ? SnapshotValidationIssue.incompatible
              : SnapshotValidationIssue.malformed,
        ),
      );
    });
  }
  for (final revision in [
    '41',
    '43',
    '-1',
    '42.0',
    'unknown',
    '',
    '9007199254740992',
    '42\n',
  ]) {
    test(
      'rejects disagreeing or malformed revision header $revision',
      () async {
        await expectLater(
          validator.validate(
            transport(
              fixture('snapshot_minimal.json'),
              headers: {
                'x-library-revision': [revision],
              },
            ),
          ),
          issue(SnapshotValidationIssue.malformed),
        );
      },
    );
  }
  for (final header in ['etag', 'x-library-revision']) {
    test('rejects multiple $header values', () async {
      await expectLater(
        validator.validate(
          transport(
            fixture('snapshot_minimal.json'),
            headers: {
              header: ['42', '42'],
            },
          ),
        ),
        issue(SnapshotValidationIssue.malformed),
      );
    });
  }
  for (final raw in ['[]', '{}', '{"snapshot":null}', 'not JSON']) {
    test('malformed envelope is typed', () async {
      await expectLater(
        validator.validate(transport(raw)),
        issue(SnapshotValidationIssue.malformed),
      );
    });
  }
  test('unsolicited 304 fails without retry', () async {
    final adapter = FakeServerAdapter((_, _) => jsonBody('', 304));
    final candidate = SessionTransport(session(), adapter: adapter);
    addTearDown(candidate.dispose);
    await expectLater(
      validator.validate(candidate),
      throwsA(
        isA<ServerException>().having((e) => e.statusCode, 'status', 304),
      ),
    );
    expect(adapter.requests, hasLength(1));
  });
  test('candidate disposal remains cancellation', () async {
    final candidate = transport(fixture('snapshot_minimal.json'));
    candidate.dispose();
    await expectLater(
      validator.validate(candidate),
      throwsA(isA<RequestCancelled>()),
    );
  });
}
