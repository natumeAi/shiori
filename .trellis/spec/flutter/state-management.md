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

## Runtime server activation and publication

### Scope / Trigger

Use `serverActivationControllerProvider` for the app's one active deployment.
It is a generated keep-alive AsyncNotifier. Its selection stays alive across
connection-form navigation; widgets call `cancelCandidate()` when abandoning
validation. Composition ports live in servers/data; pure selection values and
the five-method store port live in core/config with no provider dependencies.

### Signatures

```dart
Future<ServerActivationState> ServerActivationController.build();
Future<void> activate(String deploymentRoot);
void cancelCandidate();
bool SessionPublicationGuard.isCurrent(ServerSession captured);
bool publish(ServerSession captured, void Function() synchronousPublication);
void Function() onRetire(ServerSession captured, void Function() cancel);
```

Override `serverSelectionStoreProvider` with the SQLite adapter and
`candidateSnapshotValidatorProvider` with Phase C's unconditional snapshot
validator. `candidateTransportFactoryProvider` creates temporary transports;
active requests share `sessionTransportProvider(session)`. The generated
`activeSessionTransportFactoryProvider` reads that family dynamically: the
coordinator must not watch a family it will invalidate while switching.

### Contracts

- `AsyncLoading` is restoring. `AsyncData` with `session == null` is
  unconfigured; with a session it is selected. Candidate `phase` is
  `validating -> committing -> idle`, preserving the selected session.
- Health precedes an unconditional validated snapshot. Each admitted candidate
  has a serial, lifetime token, temporary session, transport and cancellation
  signal. Candidates never read or invalidate active-session families.
- A newer validation supersedes the older one. Cancellation races the
  validator future as well as disposing transport, so even a validator that
  ignores cancellation cannot hold the caller or publish a late error.
- Commit endpoint/snapshot/active key together. The five-method port has no
  rollback-after-dispatch command: commit and session publication form one
  noncancelable serial section. Requests received during it wait; only the
  newest queued request is admitted afterwards. Cancel during commit cancels
  queued admission; the dispatched transaction still finishes.
- After successful commit, invalidate the guard, synchronously cancel registered
  work, dispose/invalidate the old transport family, create a fresh generation,
  then publish the new immutable session through the guard. Cleanup callbacks
  are synchronous, idempotent and nonthrowing. Unregister completed work.
- Generations increase within the guard's provider-container lifetime, including
  across coordinator invalidation. Temporary generations are never current.
  Relaunch re-parses and verifies the persisted canonical endpoint and key,
  creates a fresh activation, and makes no network request. A generation is
  runtime ownership, never durable storage identity or a global revision.
- HTTP, cover, file, controller and worker callbacks capture the whole session
  and call `guard.publish(captured, () { ... })` immediately before any write.
  There must be no await between the check and publication. Equal server keys
  alone cannot distinguish first A from later A in A -> B -> A.
- This connection action deliberately returns typed feedback alongside selected
  data (`ServerActivationFailure`); it does not replace active data with
  `AsyncError`. It has no automatic retry. A subsequent explicit action retries.
  Restore storage errors use `AsyncError` and preserve storage for recovery.

### Validation & Error Matrix

| Condition | Result |
| --- | --- |
| Invalid root | Typed endpoint issue, zero client creation |
| Wrong service / DB unconfigured / health HTTP 500 / malformed health | Distinct failure kinds, no snapshot or commit |
| TLS / 401 or 403 / connection or timeout / unsafe redirect / other HTTP | Distinct transport-derived feedback |
| Snapshot incompatible / malformed | Distinct failure kinds, no commit |
| Commit storage failure | Typed storage feedback; previous session/work remain current |
| Missing, noncanonical or key-mismatched restored row | `SelectionStorageException(invalidSelection)`, no reset/traffic |
| Cancellation, supersession, late result, disposed owner | Silent completion; no error publication or retry |

Feature contract/storage exceptions remain outside the sealed core
`AppException` library. The coordinator maps them to safe typed feedback;
connection UI must handle this feedback rather than pass it to generic raw
exception text rendering. Transport `AppException`s retain their existing API.

### Good / Base / Bad Cases

Base: unconfigured -> validate A -> transaction -> selected A.
Good: selected A -> failed B keeps A's transport, snapshot and pending work.
Bad: a delayed first-A result checking only `ServerKey` overwrites later A.

### Tests Required

Fake Dio adapters and completers cover all health fixtures, checked DTO fields,
failure classification, simultaneous candidates, cancel at health/snapshot,
ignored cancellation, commit serialization/failure, queued admission/cancel,
restore with/without/corrupt selection, switching after restore, disposal and
A -> B -> A. Assert both final state and actual commit/request counts; retain
both servers' records and reject every unknown store command, including delete.

### Wrong vs Correct

Wrong: watch the restored session's transport in the coordinator build; retiring
it then rebuilds its owner. Correct: watch the dynamic factory and let ordinary
session consumers watch the family. Wrong: publish after an await using a
previous `isCurrent` check. Correct: check inside `publish` immediately before
the synchronous write and use `onRetire` to stop pending work.

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
