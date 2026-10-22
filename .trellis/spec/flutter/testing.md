---
name: flutter-testing
description: Unit tests for repositories and controllers, widget tests for key screens, mocktail, test helpers
paths:
  - test/**
  - integration_test/**
---

# Testing

> Required: unit tests for every repository and controller, widget tests for
> key screens. Mocks with `mocktail`. No real network in any test.

---

## What Must Be Tested

| Code | Test type | Minimum coverage |
|---|---|---|
| `*_repository.dart` | unit | each public method: success + each `AppException` it can raise |
| `*_controller.dart` | unit (`ProviderContainer.test`) | `build` success and error; each mutation method |
| Key screens (list, detail, forms) | widget | loading, data, empty, and error states; main interactions |
| `core/**` helpers (`guardDio`, `errorMessage`) | unit | every branch |
| Pure layout widgets | optional | |

Integration tests (`integration_test/`) and golden tests are not required yet.

---

## Layout

Tests mirror `lib/`: `lib/features/bookmarks/data/bookmark_repository.dart`
-> `test/features/bookmarks/data/bookmark_repository_test.dart`.

```text
test/
  helpers/
    mocks.dart              # shared mocktail mocks (MockDio, MockBookmarkRepository)
    pump_app.dart           # WidgetTester.pumpApp extension
    provider_exception.dart # providerException(error): a real Riverpod ProviderException
  fixtures/                 # JSON responses: bookmarks_list.json
  app/...                   # app smoke test (pumps ShioriApp)
  features/...              # mirrors lib/features
  core/...                  # mirrors lib/core
```

Test files import `lib/` code with `package:shiori/...` and helpers with a
relative path (`import '../../helpers/pump_app.dart';`); `test/` has no
`package:` URI, and `always_use_package_imports` only governs `lib/`.

`ProviderException`'s constructor is `@internal`. To test code that unwraps
it, use `providerException(error)` from `test/helpers/provider_exception.dart`,
which obtains one through the public `AsyncValue.requireValue` path.

---

## Repository Tests

Mock `Dio` and assert on returned models / thrown `AppException` types.

```dart
import '../../../helpers/mocks.dart'; // class MockDio extends Mock implements Dio {}

void main() {
  late MockDio dio;
  late BookmarkRepository repository;

  setUp(() {
    dio = MockDio();
    repository = BookmarkRepository(dio);
  });

  test('fetchBookmarks maps a connection error to NetworkException', () {
    when(() => dio.get<List<Object?>>(any(), queryParameters: any(named: 'queryParameters')))
        .thenThrow(DioException.connectionError(
          requestOptions: RequestOptions(path: '/bookmarks'),
          reason: 'offline',
        ));

    expect(repository.fetchBookmarks(), throwsA(isA<NetworkException>()));
  });
}
```

---

## Controller Tests

One fresh container per test; override the repository; keep a listener
alive on auto-dispose providers while awaiting.

```dart
test('build loads bookmarks', () async {
  final repository = MockBookmarkRepository();
  when(() => repository.fetchBookmarks()).thenAnswer((_) async => [bookmark]);

  final container = ProviderContainer.test(
    overrides: [bookmarkRepositoryProvider.overrideWith((ref) => repository)],
    retry: (_, _) => null,
  );
  container.listen(bookmarkListControllerProvider, (_, _) {});

  expect(await container.read(bookmarkListControllerProvider.future), [bookmark]);
});
```

- Always pass `retry: (_, _) => null` so a failing provider errors
  immediately instead of scheduling retry timers.
- Never share a container between tests.

---

## Widget Tests

Use the `pumpApp` helper so every screen gets a `ProviderScope`, the theme,
and localizations:

```dart
// test/helpers/pump_app.dart
import 'package:flutter_riverpod/misc.dart'; // Override is not in flutter_riverpod.dart

extension PumpApp on WidgetTester {
  Future<void> pumpApp(Widget widget, {List<Override> overrides = const []}) {
    return pumpWidget(
      ProviderScope(
        overrides: overrides,
        retry: (_, _) => null,
        child: MaterialApp(
          theme: AppTheme.light,
          locale: const Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: widget,
        ),
      ),
    );
  }
}
```

- Find text through the generated strings, not literals:
  `final l10n = lookupAppLocalizations(const Locale('zh'));` then
  `find.text(l10n.bookmarksTitle)`.
- Override the controller's repository (not the controller itself) so the
  real controller logic runs.
- For the loading state, return a `Completer().future` that never completes;
  for data/error, `await tester.pumpAndSettle()`.

---

## Commands

```bash
flutter test                                    # all
flutter test test/features/bookmarks            # one feature
flutter test --name "maps a connection error"   # one test
```

---

## Forbidden

- Real HTTP calls (no live `Dio`, no hitting dev servers).
- `mockito` / `@GenerateMocks`. Use `mocktail`.
- `sleep` / fixed `Future.delayed` waits. Use `pump`, `pumpAndSettle`, or completers.
- Asserting on `error.toString()`. Assert on exception types or l10n text.
