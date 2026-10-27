import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shiori/app/router.dart';
import 'package:shiori/core/errors/app_exception.dart';
import 'package:shiori/features/servers/presentation/server_activation_controller.dart';

import '../../../app/product_ui_test_support.dart';

void main() {
  for (final (input, message) in [
    ('example.test', l10n.serverUrlScheme),
    ('https:///', l10n.serverUrlHost),
    ('https://user:secret@example.test', l10n.serverUrlCredentials),
    ('https://example.test/?x=1', l10n.serverUrlQuery),
    ('https://example.test/#x', l10n.serverUrlFragment),
    ('https://example.test/%xx', l10n.serverUrlEscape),
    (r'https://example.test/\x', l10n.serverUrlBackslash),
    ('https://example.test:65536', l10n.serverUrlPort),
    ('https://[fe80::1%25en0]', l10n.serverUrlZone),
    ('https://[broken]/', l10n.serverUrlInvalid),
  ]) {
    testWidgets(
      'invalid address has localized feedback and no request: $input',
      (tester) async {
        final h = ProductUiHarness();
        await h.pump(tester);
        await tester.enterText(find.byType(TextFormField), input);
        await tester.tap(find.text(l10n.serverConnect));
        await tester.pumpAndSettle();
        expect(find.text(message), findsOneWidget);
        expect(h.candidates, isEmpty);
        expect(h.store.commits, isEmpty);
      },
    );
  }

  final failureCases =
      <(String, ResponseBody Function(RequestOptions), String)>[
        (
          'timeout',
          (o) => throw DioException(
            requestOptions: o,
            type: DioExceptionType.connectionTimeout,
          ),
          l10n.serverConnectionFailed,
        ),
        (
          'offline',
          (o) => throw DioException.connectionError(
            requestOptions: o,
            reason: 'synthetic',
          ),
          l10n.serverConnectionFailed,
        ),
        (
          'TLS',
          (o) => throw DioException(
            requestOptions: o,
            type: DioExceptionType.badCertificate,
          ),
          l10n.serverTlsFailed,
        ),
        // Discarded-body HTTP cases are adapter-tested in the controller suite.
        // Inject their typed boundary errors here to test the localized UI.
        (
          'HTML',
          (_) => throw const ParseException(),
          l10n.serverUnexpectedResponse,
        ),
        (
          '401',
          (_) => throw const UnauthorizedException(),
          l10n.serverAccessDenied,
        ),
        (
          '403',
          (_) => throw const UnauthorizedException(),
          l10n.serverAccessDenied,
        ),
        (
          'wrong service',
          (_) => jsonBody(fixture('health_wrong_service.json')),
          l10n.serverWrongService,
        ),
        (
          'unconfigured',
          (_) => jsonBody(fixture('health_database_unconfigured.json')),
          l10n.serverLibraryUnconfigured,
        ),
        (
          'unavailable',
          (_) => jsonBody(fixture('health_database_error.json'), 500),
          l10n.serverLibraryUnavailable,
        ),
        (
          'schema',
          (o) => jsonBody(
            fixture(
              o.uri.path.endsWith('/health')
                  ? 'health_ok.json'
                  : 'snapshot_invalid_schema_version.json',
            ),
          ),
          l10n.serverUnsupportedVersion,
        ),
        (
          'redirect',
          (_) => throw const RedirectException(RedirectIssue.outsideDeployment),
          l10n.serverFinalAddress,
        ),
      ];
  for (final (name, response, message) in failureCases) {
    testWidgets('failed switch retains visible previous server: $name', (
      tester,
    ) async {
      final h = ProductUiHarness();
      await h.seed();
      await h.pump(tester);
      final old = h.session;
      h.snapshotFailure = switch (name) {
        'HTML' => const ParseException(),
        '401' || '403' => const UnauthorizedException(),
        'redirect' => const RedirectException(RedirectIssue.outsideDeployment),
        _ => null,
      };
      if (h.snapshotFailure == null) h.candidateResponse = response;
      await tester.tap(find.byTooltip(l10n.serverChangeTitle));
      await tester.pumpAndSettle();
      await h.connect(tester);
      await tester.pump(Duration.zero);
      await tester.pump(Duration.zero);
      await tester.pumpAndSettle();
      expect(find.text(message), findsOneWidget);
      expect(
        find.text(l10n.serverCurrent(old.endpoint.normalizedText)),
        findsOneWidget,
      );
      expect(h.session, same(old));
      expect(h.store.commits, hasLength(1));
      expect(h.activeAdapters.single.closed, isFalse);
      h.container.read(routerProvider).pop();
      await tester.pumpAndSettle();
      expect(find.text(l10n.libraryTitle), findsOneWidget);
    });
  }

  for (final back in [false, true]) {
    testWidgets('cancel validation ignores late result (back: $back)', (
      tester,
    ) async {
      final h = ProductUiHarness();
      await h.seed();
      await h.pump(tester);
      final old = h.session;
      final late = Completer<ResponseBody>();
      h.candidateResponse = (_) => late.future;
      await tester.tap(find.byTooltip(l10n.serverChangeTitle));
      await tester.pumpAndSettle();
      await h.connect(tester);
      await tester.pump();
      await tester.pump();
      expect(find.text(l10n.commonCancel), findsOneWidget);
      if (back) {
        h.container.read(routerProvider).pop();
        await tester.pumpAndSettle();
      } else {
        await tester.tap(find.text(l10n.commonCancel));
        await tester.pumpAndSettle();
        expect(find.text(l10n.serverConnect), findsOneWidget);
      }
      late.complete(jsonBody(fixture('health_ok.json')));
      await tester.pumpAndSettle();
      expect(h.candidates.single.closed, isTrue);
      expect(h.session, same(old));
      expect(
        h.container
            .read(serverActivationControllerProvider)
            .requireValue
            .failure,
        isNull,
      );
      expect(h.store.commits, hasLength(1));
    });
  }
}
