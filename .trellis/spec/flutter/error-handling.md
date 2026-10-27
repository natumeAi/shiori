---
name: flutter-error-handling
description: sealed AppException, guardDio mapping, showing errors in UI, logging with package:logging
paths:
  - lib/core/errors/**
  - lib/core/logging/**
  - lib/core/network/**
  - lib/features/*/data/*_repository.dart
  - lib/main.dart
---

# Error Handling and Logging

> Recoverable failures are typed `AppException`s. Cancellation is separate
> control flow and must be consumed before publishing UI state. Never log raw
> transport exceptions, body text or endpoint metadata.

---

## Session transport boundary

### Scope / Trigger

Runtime deployments contain private endpoint/path/library information. All
session reads use `SessionTransport`; repository DTO parsing uses `guardDio`.
Only introduce an exception subtype when recovery, UI or retry differs.

### Signatures

```dart
Future<T> guardDio<T>(Future<T> Function() request, {RedactedRequestLog? log});
NetworkException([Object? cause]);
UnauthorizedException([Object? cause]);
ServerException(int? statusCode, [Object? cause, Object? code]);
ParseException([Object? cause]);
TlsException([Object? cause]);
RedirectException(RedirectIssue issue); // recoveryMessage: enter final root
RequestCancelled(); // core/network/request_cancelled.dart; NOT AppException
```

### Contracts

- `RequestCancelled` deliberately does not extend `AppException`. It carries
  no private cause. Session retirement cancels all requests; a final active
  check rejects completed/decoded responses from a retired transport too.
- The activation/controller owner must catch cancellation and check captured
  server key/generation before publishing. Never turn cancellation into
  `AsyncError`, call `errorMessage`, show a snackbar, or retry it. The activation
  coordinator consumes it; session-scoped library owners reject late results.
- Retry remains `retryNetworkErrors`: only `NetworkException`, at most three
  retries after 200/400/800 ms. Do not unwrap/retry dependent ProviderExceptions.
- TLS remains fail-closed. Never bypass certificates or infer LAN permission
  denial from a generic socket failure. TLS recovery and redirect root-entry
  feedback are separate from transient connection troubleshooting.
- JSON endpoints reject non-JSON media types, HTML, invalid JSON/UTF-8 and
  error envelopes without keeping body text as a message/cause. Missing media
  type is tolerated only when the bytes decode as JSON. DTO shape and service/
  schema validation remain repository-owned. Present Content-Type must have
  exactly one value; empty/duplicate values are typed parse failures.
- `ServerException.code` preserves opaque top-level `code` or nested
  `error.code`, including unknown values; it is never a displayed/logged
  message. HTTP error-envelope inspection is capped at 64 KiB. A non-JSON or
  oversized error body keeps the HTTP failure status and no code.

### Validation & Error Matrix

| Evidence | Result | Automatic retry |
| --- | --- | --- |
| Dio `cancel`, disposed session | `RequestCancelled` control flow | Never |
| Dio `badCertificate`, direct/wrapped `HandshakeException` | `TlsException` | Never |
| Dio connect/send/receive/transform timeout, connection error | `NetworkException` | Bounded |
| Dio `unknown` except known TLS/format causes | `NetworkException` | Bounded |
| Direct receiving `SocketException`, `HttpException`, `TimeoutException` | `NetworkException` | Bounded |
| HTTP 401/403 | `UnauthorizedException` regardless of body | Never |
| Unapproved HTTP terminal status, including default 304/206/412/416 | `ServerException(status)` | Never |
| JSON `{error: ...}`, even on HTTP 200 | `ServerException(status, null, code)` | Never |
| HTML/non-JSON, malformed JSON/UTF-8, checked JSON/cast error | `ParseException` | Never |
| Cover emitted bytes exceed caller limit | `ParseException` | Never |
| Invalid/outside/looping/sixth redirect | `RedirectException(issue)`; enter final deployment root | Never |

### Good / Base / Bad Cases

- Base: health JSON 200 reaches its repository unchanged for typed decoding.
- Good: snapshot caller explicitly allows bodyless 304 and owns cache recovery.
- Bad: login HTML at 200 is a parse failure; 401 login HTML is unauthorized.

### Tests Required

Fake `HttpClientAdapter` tests assert actual options and every Dio error type,
direct/wrapped TLS and receiving errors, status precedence, unknown codes,
HTML/error fixtures, bounded chunks and disposal before headers/during body.
Capture whole `LogRecord`s and assert safe messages and null error/stack fields.

### Wrong vs Correct

Wrong: map cancellation/certificates to `NetworkException`, or log a raw Dio
exception with `requestOptions.path`. Correct: use the matrix above and fixed
`ServerRoute` log templates; consume cancellation at its owner.

---

## Showing Errors in the UI

Load errors: the controller's `build` throws, the screen gets `AsyncError`
and renders the shared `ErrorView` with a retry button. This applies to current
recoverable failures, never `RequestCancelled`. Connection actions preserve the
selected session and expose typed `ServerActivationFailure` feedback through
`features/servers/presentation/server_feedback.dart`: localized TLS, access,
final-root-entry and network troubleshooting messages. A socket failure does
not prove LAN permission denial. The shared `errorMessage` helper remains the
generic load-error fallback; connection feedback uses `activationFailureMessage`.

```dart
body: bookmarks.when(
  data: (items) => BookmarkListView(bookmarks: items),
  error: (error, _) => ErrorView(
    error: error,
    onRetry: () => ref.invalidate(bookmarkListControllerProvider),
  ),
  loading: () => const Center(child: CircularProgressIndicator()),
),
```

Mutation errors: catch at the call site and show a snackbar. Check
`context.mounted` after the `await`.

```dart
onPressed: () async {
  try {
    await ref.read(bookmarkListControllerProvider.notifier).delete(id);
  } on AppException catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(errorMessage(context, e))));
  }
},
```

Message mapping lives in one place:

```dart
// lib/core/errors/error_messages.dart
import 'package:flutter_riverpod/misc.dart'; // ProviderException lives here

String errorMessage(BuildContext context, Object error) {
  final l10n = context.l10n;
  return switch (_unwrap(error)) {
    NetworkException() => l10n.errorNetwork,
    UnauthorizedException() => l10n.errorUnauthorized,
    ServerException() || ParseException() => l10n.errorServer,
    _ => l10n.errorUnexpected,
  };
}

/// Riverpod 3 wraps errors from dependent providers in ProviderException,
/// once per level of the dependency chain.
Object _unwrap(Object error) => switch (error) {
  ProviderException(:final exception) => _unwrap(exception),
  _ => error,
};
```

`ProviderException` and `Override` are exported by
`package:flutter_riverpod/misc.dart`, not by `flutter_riverpod.dart`.

Never show `error.toString()`, status codes, or stack traces to the user.

---

## Logging

`package:logging`, configured once in `lib/core/logging/logging.dart` and
called first thing in `main()`:

```dart
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart'; // also provides PlatformDispatcher
import 'package:logging/logging.dart';

void setupLogging() {
  Logger.root.level = kReleaseMode ? Level.INFO : Level.ALL;
  Logger.root.onRecord.listen((record) {
    developer.log(
      record.message,
      time: record.time,
      level: record.level.value,
      name: record.loggerName,
      error: record.error,
      stackTrace: record.stackTrace,
    );
  });
  FlutterError.onError = (details) {
    Logger('Flutter').severe(details.exceptionAsString(), details.exception, details.stack);
    FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    Logger('Platform').severe('Uncaught error', error, stack);
    return true;
  };
}
```

- One logger per class or file: `final _log = Logger('BookmarkRepository');`
- Levels: `fine` for safe debug metadata, `info` for app lifecycle
  events, `warning` for handled failures (network errors), `severe` for bugs
  and unexpected states (parse errors, uncaught exceptions).
- `RedactingInterceptor` replaces `LogInterceptor`. Each HTTP hop records only
  `GET api/books/{id} status=200 elapsedMs=12` (or another fixed `ServerRoute`
  template); elapsed time is through response headers, not full body transfer.
  Failures without headers use `status=-`. `guardDio` uses the same form and
  shared metadata to avoid repeating a hop's record. Without metadata it uses
  `GET {route}`; it never guesses a template from a path.
- Network logs attach neither exceptions nor stack traces: `LogRecord.error`
  and `.stackTrace` must be null. Causes can retain private Dio/DTO information
  for typed internal inspection; never serialize/log them or `error.toString()`.
  Direct JSON format failures discard `FormatException.source` entirely.
- Never log scheme, host, port, deployment prefix, actual resource path/book ID,
  query, headers, bodies, opaque server codes, tokens or library content.
  Cancellation produces no failure log. Callers do not log handled failures again.

---

## Forbidden

- `print` / `debugPrint` for diagnostics (use a `Logger`).
- Empty `catch` blocks, or `catch (e)` that swallows without logging or rethrowing.
- Catching `Object` / `Exception` broadly in widgets. Catch `AppException`.
- Returning `null` to signal failure from a repository.
