---
name: flutter-state-management
description: Riverpod 3 with riverpod_generator - provider kinds, ref usage, notifier patterns
paths:
  - lib/features/**
  - lib/app/**
  - lib/core/network/**
---

# State Management

> Riverpod 3 (`flutter_riverpod` + `riverpod_annotation`), providers declared
> only through `riverpod_generator` (`@riverpod` / `@Riverpod(...)`).

---

## Provider Kinds

| What | Declare as | Lives in |
|---|---|---|
| Dependencies (Dio, repositories, router) | functional, `@Riverpod(keepAlive: true)` | same file as the class it provides |
| Screen data loaded from the API | `@riverpod class XController extends _$XController` with `Future<T> build()` | `presentation/<name>_controller.dart` |
| Parameterized data (detail by id) | same, with parameters on `build` | `presentation/<name>_controller.dart` |
| Derived / computed values | functional `@riverpod` | next to the provider it derives from |
| Ephemeral UI state (text input, tab index, expanded) | **not a provider**: widget-local state | the widget |

Generated names: `BookmarkListController` -> `bookmarkListControllerProvider`,
`bookmarkRepository(Ref ref)` -> `bookmarkRepositoryProvider`.

---

## Examples

Dependency provider (colocated with the class):

```dart
// lib/features/bookmarks/data/bookmark_repository.dart
part 'bookmark_repository.g.dart';

@Riverpod(keepAlive: true)
BookmarkRepository bookmarkRepository(Ref ref) =>
    BookmarkRepository(ref.watch(dioProvider));
```

Screen controller (AsyncNotifier):

```dart
// lib/features/bookmarks/presentation/bookmark_list_controller.dart
part 'bookmark_list_controller.g.dart';

@riverpod
class BookmarkListController extends _$BookmarkListController {
  @override
  Future<List<Bookmark>> build() =>
      ref.watch(bookmarkRepositoryProvider).fetchBookmarks();

  Future<void> delete(String id) async {
    await ref.read(bookmarkRepositoryProvider).deleteBookmark(id);
    if (!ref.mounted) return;
    ref.invalidateSelf();
  }
}
```

Parameterized (family):

```dart
@riverpod
class BookmarkDetailController extends _$BookmarkDetailController {
  @override
  Future<Bookmark> build(String id) =>
      ref.watch(bookmarkRepositoryProvider).fetchBookmark(id);
}
// usage: ref.watch(bookmarkDetailControllerProvider(id))
```

---

## Rules for `ref`

- `ref.watch` inside `build` (widget or provider). Never inside callbacks.
- `ref.read` inside callbacks (`onPressed`, notifier methods). Never in `build`.
- `ref.listen` inside a widget's `build` for one-off side effects reacting to
  state changes (snackbar, navigation). Never trigger side effects from `build` directly.
- After every `await` in a notifier method, check `if (!ref.mounted) return;`
  before touching `state` or `ref`. Using a disposed ref throws in Riverpod 3.

---

## Mutations (writes)

- Writes are methods on the controller that owns the affected data
  (`delete`, `rename`, `create`).
- After a successful write, either `ref.invalidateSelf()` (refetch) or set
  `state = AsyncData(updated)` when the server response contains the new value.
- Mutation methods let `AppException` propagate. The calling widget catches it
  and shows a snackbar (see [Error Handling](./error-handling.md)). Do not
  stash mutation errors in `state`; that would replace the loaded data with an error screen.

---

## Retry

Riverpod 3 retries failed providers automatically. The root `ProviderScope`
in `main.dart` sets `retry: retryNetworkErrors` (`core/network/retry_policy.dart`)
so only `NetworkException` is retried (max 3, exponential backoff). Server and
parse errors fail immediately. Tests disable retry (see [Testing](./testing.md)).

```dart
// lib/core/network/retry_policy.dart
Duration? retryNetworkErrors(int retryCount, Object error) {
  if (retryCount >= 3 || error is! NetworkException) return null;
  return Duration(milliseconds: 200 * (1 << retryCount));
}
```

A `ProviderException` (the provider failed because a dependency failed) is
not unwrapped and not retried, matching Riverpod's default policy: the failing
dependency retries itself, and its dependents rebuild once it recovers.
Unwrapping it would retry every provider in the chain.

---

## Forbidden

- Hand-written providers (`final xProvider = Provider(...)`). Use codegen.
- Legacy providers from `package:flutter_riverpod/legacy.dart`
  (`StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider`).
- Experimental APIs (`Mutation`, offline `persist`) until they are stable.
- Global mutable singletons or service locators (`get_it`). Inject via providers.
- `setState` for data that comes from the API. `setState` is only for
  ephemeral UI state inside a `ConsumerStatefulWidget` / `StatefulWidget`.
- Calling Dio from a controller or widget. Go through the repository.
