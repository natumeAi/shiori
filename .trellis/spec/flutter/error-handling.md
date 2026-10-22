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

> Errors are typed exceptions, not result objects. Repositories convert every
> transport/parse failure into a sealed `AppException`; Riverpod carries it to
> the UI as `AsyncError`; the UI maps it to a localized message.

---

## Exception Types

```dart
// lib/core/errors/app_exception.dart
sealed class AppException implements Exception {
  const AppException([this.cause]);

  final Object? cause;
}

/// No connection, timeout, or other transport failure. Retried automatically.
final class NetworkException extends AppException {
  const NetworkException([super.cause]);
}

/// 401 / 403 from the API.
final class UnauthorizedException extends AppException {
  const UnauthorizedException([super.cause]);
}

/// Any other non-2xx response.
final class ServerException extends AppException {
  const ServerException(this.statusCode, [super.cause]);

  final int? statusCode;
}

/// The response body could not be decoded or did not match the expected
/// JSON shape. Not retried.
final class ParseException extends AppException {
  const ParseException([super.cause]);
}
```

Add a subtype only when the UI must react differently to it (e.g. a
`NotFoundException` for a "deleted" screen). Never throw `Exception('...')`
or strings.

---

## Mapping: `guardDio`

```dart
// lib/core/network/guard_dio.dart
final _log = Logger('Network');

Future<T> guardDio<T>(Future<T> Function() request) async {
  try {
    return await request();
  } on DioException catch (e, stack) {
    if (e.type == DioExceptionType.unknown && e.error is FormatException) {
      // Dio reports a body it cannot decode (malformed JSON, invalid UTF-8)
      // as `unknown`. That is a parse failure, not a transport one.
      _log.severe('Undecodable response body', e, stack);
      throw ParseException(e);
    }
    _log.warning('${e.requestOptions.method} ${e.requestOptions.path} failed', e, stack);
    throw switch (e.type) {
      DioExceptionType.badResponse => switch (e.response?.statusCode) {
        401 || 403 => UnauthorizedException(e),
        final code => ServerException(code, e),
      },
      _ => NetworkException(e),
    };
  } on CheckedFromJsonException catch (e, stack) {
    _log.severe('Unexpected JSON shape', e, stack);
    throw ParseException(e);
  } on TypeError catch (e, stack) {
    // Casts at the JSON boundary (`json as Map<String, Object?>`).
    _log.severe('Unexpected JSON shape', e, stack);
    throw ParseException(e);
  }
}
```

The error is logged once, here. Callers above the repository do not log it again.

---

## Showing Errors in the UI

Load errors: the controller's `build` throws, the screen gets `AsyncError`
and renders the shared `ErrorView` with a retry button.

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
- Levels: `fine` for debug detail (HTTP bodies), `info` for app lifecycle
  events, `warning` for handled failures (network errors), `severe` for bugs
  and unexpected states (parse errors, uncaught exceptions).
- Never log tokens, passwords, or personal data. `LogInterceptor` keeps
  `requestHeader: false` so `Authorization` is never printed.

---

## Forbidden

- `print` / `debugPrint` for diagnostics (use a `Logger`).
- Empty `catch` blocks, or `catch (e)` that swallows without logging or rethrowing.
- Catching `Object` / `Exception` broadly in widgets. Catch `AppException`.
- Returning `null` to signal failure from a repository.
