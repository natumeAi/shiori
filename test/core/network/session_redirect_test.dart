import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/core/config/server_endpoint.dart';
import 'package:shiori/core/config/server_session.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/core/network/session_transport.dart';

import 'fake_server_adapter.dart';

void main() {
  SessionTransport transport(
    FakeServerAdapter adapter, [
    String root = 'https://private.example.test:9443/deployment/',
  ]) {
    final value = SessionTransport(
      ServerSession(
        endpoint: ServerEndpoint.parse(root).endpoint!,
        generation: 1,
      ),
      adapter: adapter,
    );
    addTearDown(value.dispose);
    return value;
  }

  ResponseBody redirect(String? location, [int status = 302]) =>
      ResponseBody.fromBytes(
        [],
        status,
        headers: {
          if (location != null) 'location': [location],
        },
      );

  for (final status in [301, 302, 303, 307, 308]) {
    test('manual $status relative redirect retains prefix and GET', () async {
      final adapter = FakeServerAdapter((options, index) {
        expect(options.followRedirects, isFalse);
        expect(options.method, 'GET');
        expect(options.headers['If-None-Match'], 'W/"opaque"');
        if (index == 0) return redirect('../target?secret=private', status);
        expect(
          options.uri.toString(),
          'https://private.example.test:9443/deployment/api/target?secret=private',
        );
        return jsonBody();
      });
      await transport(adapter)
          .getJson(['api', 'library', 'snapshot'], ifNoneMatch: 'W/"opaque"');
      expect(adapter.requests, hasLength(2));
    });
  }

  for (final count in [5, 6]) {
    test(
      'chain of $count redirects ${count == 5 ? 'succeeds' : 'fails'}',
      () async {
        final adapter = FakeServerAdapter(
          (_, index) => index < count
              ? redirect('/deployment/api/hop${index + 1}')
              : jsonBody(),
        );
        final request = transport(adapter).getJson(['api', 'health']);
        if (count == 5) {
          await request;
        } else {
          await expectLater(
            request,
            throwsA(
              isA<RedirectException>().having(
                (e) => e.issue,
                'issue',
                RedirectIssue.limit,
              ),
            ),
          );
        }
        expect(adapter.requests, hasLength(6));
      },
    );
  }

  test('loop stops before repeating an actual request', () async {
    final adapter = FakeServerAdapter(
      (_, index) => index == 0
          ? redirect('/deployment/api/second')
          : redirect('/deployment/api/health#ignored'),
    );
    await expectLater(
      transport(adapter).getJson(['api', 'health']),
      throwsA(
        isA<RedirectException>().having(
          (e) => e.issue,
          'issue',
          RedirectIssue.loop,
        ),
      ),
    );
    expect(adapter.requests, hasLength(2));
  });

  final rejected = <String?, RedirectIssue>{
    'https://other.test/deployment/api/health': RedirectIssue.outsideDeployment,
    '//other.test/deployment/api/health': RedirectIssue.outsideDeployment,
    'https://private.example.test:9444/deployment/api/health':
        RedirectIssue.outsideDeployment,
    '/deployment-other/api/health': RedirectIssue.outsideDeployment,
    '/api/health': RedirectIssue.outsideDeployment,
    '../../api/health': RedirectIssue.outsideDeployment,
    'http://private.example.test:9443/deployment/api/health':
        RedirectIssue.outsideDeployment,
    'https://user@private.example.test:9443/deployment/api/health':
        RedirectIssue.outsideDeployment,
    'https://@private.example.test:9443/deployment/api/health':
        RedirectIssue.outsideDeployment,
    '/deployment/api/%2e%2e%2fsecret': RedirectIssue.invalidTarget,
    '/deployment/api/%5csecret': RedirectIssue.invalidTarget,
    '/deployment/api/%zz': RedirectIssue.invalidTarget,
    '/deployment/api/with space': RedirectIssue.invalidTarget,
    r'/deployment\api': RedirectIssue.invalidTarget,
    'https://[': RedirectIssue.invalidTarget,
    null: RedirectIssue.invalidTarget,
    '': RedirectIssue.invalidTarget,
  };
  var caseIndex = 0;
  for (final entry in rejected.entries) {
    test(
      'unsafe redirect case ${caseIndex++} sends no second request',
      () async {
        final adapter = FakeServerAdapter((_, _) => redirect(entry.key));
        await expectLater(
          transport(adapter).getJson(['api', 'health']),
          throwsA(
            isA<RedirectException>()
                .having((e) => e.issue, 'issue', entry.value)
                .having(
                  (e) => e.recoveryMessage,
                  'recovery',
                  'Enter the final deployment root.',
                ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      },
    );
  }

  for (final root in [
    'https://example.test/a%2Fb/',
    'http://[2001:db8::7]:8080/reader/',
  ]) {
    test('same origin redirect preserves encoded/IPv6 root $root', () async {
      final adapter = FakeServerAdapter((options, index) {
        if (index == 0) return redirect('${root}api/final');
        expect(options.uri.toString(), '${root}api/final');
        return jsonBody();
      });
      await transport(adapter, root).getJson(['api', 'health']);
      expect(adapter.requests, hasLength(2));
    });
  }

  test('cover follows same policy and disposes redirect body', () async {
    var closed = false;
    final adapter = FakeServerAdapter(
      (_, index) => index == 0
          ? ResponseBody.fromBytes(
              [1],
              307,
              headers: {
                'location': ['/deployment/covers/final'],
              },
              onClose: () => closed = true,
            )
          : ResponseBody.fromBytes([2, 3], 200),
    );
    expect(
      (await transport(adapter).getBytes('/covers/start', maxBytes: 2)).body,
      [2, 3],
    );
    expect(closed, isTrue);
    expect(adapter.requests, hasLength(2));
  });

  for (final locations in <List<String>>[
    [],
    ['/deployment/a', '/deployment/b'],
  ]) {
    test(
      'invalid Location cardinality ${locations.length} never follows',
      () async {
        final adapter = FakeServerAdapter(
          (_, _) =>
              ResponseBody.fromBytes([], 302, headers: {'location': locations}),
        );
        await expectLater(
          transport(adapter).getJson(['api', 'health']),
          throwsA(
            isA<RedirectException>().having(
              (e) => e.issue,
              'issue',
              RedirectIssue.invalidTarget,
            ),
          ),
        );
        expect(adapter.requests, hasLength(1));
      },
    );
  }
}
