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
Future<void> ServerActivationSerializer.waitForIdle();
bool SessionPublicationGuard.isCurrent(ServerSession captured);
bool publish(ServerSession captured, void Function() synchronousPublication);
void Function() onRetire(ServerSession captured, void Function() cancel);
```

`serverSelectionStoreProvider` binds to `SqliteServerSelectionStore` by default.
It is keep-alive; its lazy resolver reads `sqliteStoreProvider.future` inside
port calls so open failures become typed selection errors. The underlying
keep-alive provider owns worker disposal; tests can still override the port.
`candidateSnapshotValidatorProvider` defaults to Phase C's unconditional
LibrarySnapshotValidator and remains overridable in tests. Validation errors
are thrown by `validate`, not provider construction, so the coordinator can
classify them without a dependency ProviderException wrapper.
`candidateTransportFactoryProvider` creates temporary transports;
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
- `serverActivationSerializerProvider` is keep-alive and container-scoped,
  independent of controller lifetime. Register the section before notifying
  `committing`, re-check candidate ownership after that synchronous notification
  and before calling the store, and release it in `finally` on every outcome.
  A replacement build awaits this shared section before reading active selection:
  it restores B after a successful retired commit, or A after rollback. A rebuild
  before dispatch cancels B entirely. No compensation write or store API change.
- Admission awaits the controller's actual restoration future, then the shared
  serializer. Reentrant provider `.future` reads inside state notifications may
  still expose retained data; they cannot authorize a candidate to bypass restore.
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
| Rebuild during dispatched commit | Restore waits, then publishes the durable selection (B on success, A on failure) |
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
Real temporary-directory SQLite tests also exercise the production binding,
container disposal/reopen without HTTP, atomic commit failure preserving active
work and both snapshots, A -> B -> A retention, and typed future-schema/open
refusal with byte-identical retained files. Generations restart in a new scope;
they are not expected to increase across process/container lifetimes.
Reproduce synchronous invalidation plus immediate restore from `validating` and
`committing` listeners, including a queued replacement candidate. Gate an actual
production SQLite adapter commit, rebuild while pending, and release success or
the worker's rollback fault. Assert durable active key equals the published key,
the guard owns that generation, and previous rows/snapshots survive.

### Wrong vs Correct

Wrong: watch the restored session's transport in the coordinator build; retiring
it then rebuilds its owner. Correct: watch the dynamic factory and let ordinary
session consumers watch the family. Wrong: publish after an await using a
previous `isCurrent` check. Correct: check inside `publish` immediately before
the synchronous write and use `onRetire` to stop pending work.
Wrong: keep commit serialization only on the notifier, or check ownership only
before publishing. Correct: share the commit barrier across rebuilds, check after
synchronous notifications before dispatch, and restore after outstanding commits.

---

## Session library and image lifecycle

### Scope / Trigger

Library data and cover work capture the current immutable ServerSession.
Consumers pass the selected session to generated families; candidate activation
must not start or invalidate the selected session's library providers.

### Signatures

```dart
librarySnapshotRepositoryProvider(ServerSession session); // keep-alive
librarySnapshotControllerProvider(ServerSession session); // auto-dispose Notifier
bookRepositoryProvider(ServerSession session); // keep-alive, guarded
bookDetailProvider(ServerSession session, BookKey key); // auto-dispose Future
coverLoaderProvider(ServerSession session); // keep-alive, onRetire cleanup
Future<void> LibrarySnapshotController.refresh();
```

### Contracts

- The snapshot controller is a synchronous Notifier of LibrarySnapshotState,
  initially empty, then receives the repository's stale/refreshing/fresh/error
  states. It subscribes before starting load and cancels its subscription on
  disposal. Every state assignment checks ref.mounted and the captured session
  guard. The repository independently guards stream and persistence admission.
- Snapshot requests coalesce in the repository. Both automatic initial load and
  explicit refresh read durable cache first. Keep-alive repository ownership
  preserves shared work/data between listeners; a replacement controller can
  resubscribe and starts revalidation. The auto-dispose controller does not
  dispose a shared session repository when leaving a view.
- Snapshot failures are state.error alongside stale data, rather than provider
  failures. The repository alone runs retryNetworkErrors for HTTP network
  failures; successful provider states never trigger a second Riverpod retry.
  Retirement interrupts retry waits and completes pending callers silently.
- BookRepository guards detail admission/results itself. bookDetail adds a
  per-view LibrarySessionScope; view disposal/retirement returns null silently.
  BookDetailResult.unavailable is the separate HTTP 404 result. Other errors
  propagate through AsyncValue and the root bounded network retry policy.
- CoverLoader owns encoded bytes, decoded pixel reservations/LRU and active
  leases. Its keep-alive provider retains reuse across views in one session;
  onRetire synchronously clears owned cache state even while the provider is
  retained. Provider disposal does the same. Native late decodes dispose their
  resources when they finish. Never depend solely on auto-dispose for retirement.
- SessionCoverImage uses the loader's decoded cache, with a lease until the
  image stream is actually disposed, including its last keep-alive handle.
  Image.errorBuilder consumes typed
  placeholder reasons. Retired streams discard results without an image error.
- LibrarySessionScope removes settled cancellation waiters; do not accumulate
  one callback on a never-completing retirement Future per completed request.
  Synchronous repository listeners may dispose owners; cancel immediately and
  defer stream close to a microtask to avoid closing during event dispatch.

### Validation & Error Matrix

| Transition | Observable state |
| --- | --- |
| Relaunch + valid stored snapshot | stale/refreshing data before HTTP |
| Successful refresh / matching 304 | fresh data |
| Refresh fails | stale data + error; selected session unchanged |
| First A -> B -> later A | first A can no longer publish/write |
| Detail retired | null, never AsyncError(RequestCancelled) |
| Cover retired/provider disposed | owned byte/image caches cleared; silent late result |

### Good / Base / Bad Cases

Base: a selected-session controller loads its repository once and watches state.
Good: the same active session shares covers between views and clears on retirement.
Bad: checking only ServerKey when first A and later A have different generations.

### Tests Required

Use selected guards, generated families, recording adapters and completers.
Assert stale/fresh controller state, real SQLite reopen/persistence, silent detail
cancellation, A -> B -> A late success/error, retry interruption, synchronous
listener retirement/disposal, cover provider cleanup and lease release. Disable
Riverpod retries in tests; inject retry waiting at the snapshot repository seam.

### Wrong vs Correct

Wrong: throw refresh failures from build and hide retained data. Correct: publish
LibrarySnapshotState(snapshot: cached, stale: true, error: typedFailure).
Wrong: release a cover lease immediately after decode or on last-listener
removal while a TickerMode handle retains the image. Correct: release it from
ImageStreamCompleter.onDisposed so admission accounts for those pixels too.

## Preparation controller and session worker (D5)

### Scope / Trigger

Use the generated preparation family for explicit book preparation/cancel/retry.
State is handwritten orchestration infrastructure, separate from checked HTTP
DTOs. No screen or reader-progress behavior is implied by ready.

### Signatures

```dart
prepareBookServiceProvider(ServerSession session); // keep-alive
sessionPublicationWorkerProvider(ServerSession session); // keep-alive lazy owner
preparationControllerProvider(ServerSession session, BookKey key); // auto-dispose
publicationContentChangesProvider(ServerSession session); // StreamProvider
PreparationState PreparationController.build(ServerSession session, BookKey key);
Future<void> PreparationController.prepare({bool refresh = false});
void PreparationController.cancel();
```

### Contracts

- Build returns PreparationIdle and subscribes to byte progress; it starts no
  request. Explicit prepare yields Preparing -> Ready(PreparedBook) or
  Failed(PrepareBookException). Received/total are nullable until known.
- Controller methods consume cancellation and typed failure into state, so
  Riverpod provider retries do not multiply preparation attempts. Retry is an
  explicit prepare; refresh supersedes existing work and bypasses validators.
- Capture a view lifetime and operation generation in every async method. Check
  ref.mounted, lifetime, operation and session immediately before assignment.
  Preparing/ready/progress listeners may synchronously cancel or dispose.
- Cancel returns idle immediately, cancels shared book work and releases its
  ready book. Disposal does the same without assigning state. Retirement
  revokes the view and returns idle; late success/error cannot replace it.
- Controller releases the old ready owner when beginning another prepare. S4
  must acquire/verify an independent file lease before relying on it after that
  transition. A summary remains detached; its file/resource owners do not.
- SessionPublicationWorker closes on guard retirement, including a late spawn,
  even if keep-alive providers still have listeners. It is declared outside
  reader/data. Do not depend on view auto-disposal for session cleanup.
- Content changes are guarded synchronous broadcast events and contain full
  old/new identities; subscribe before prepare. StreamProvider adapts these
  events, not replay/durability. Revalidate saved identity on every S4 open.
- PrepareBookQueue persists across service/provider lifetimes. Logical cancel
  finishes promptly; physical worker operations drain before the next staged
  import. Provider invalidation cannot admit overlapping staged files.

### Validation & Error Matrix

| Transition | State / ownership |
| --- | --- |
| Build | idle, zero HTTP |
| Prepare / chunk receipt | preparing, admitted byte count and nullable total |
| Validated publish / usable 304 | ready, matching summary and file lease |
| Recoverable failure | failed with sanitized typed reason |
| Cancel / retirement | idle; no cancellation AsyncError or retry |
| Dispose / stale callback | no assignment, owned lease released |

### Good / Base / Bad Cases

Base: idle until the UI explicitly prepares. Good: a retained old-session family
is idle after activation changes. Bad: a late first-A result cannot update a
later-A view merely because their BookKeys compare equal.

### Tests Required

Keep family listeners alive with real providers/fake HTTP, real SQLite and
worker. Assert byte updates, ready/failed/cancel/retry, duplicate coalescing,
refresh supersession, disposal, retirement during download and actual import,
A -> B -> A, lease/staging accounting and no late content/state event.

### Wrong vs Correct

Wrong: store RequestCancelled in AsyncError or check only serverKey. Correct:
consume cancellation, check session generation plus view/operation lifetime and
release abandoned results. Wrong: hold the worker's staged handle across rename.
Correct: drain/detach before publication; S4 reopens the leased immutable path.

## Forbidden

- Hand-written providers (`final xProvider = Provider(...)`). Use codegen.
- Legacy providers from `package:flutter_riverpod/legacy.dart`
  (`StateProvider`, `StateNotifierProvider`, `ChangeNotifierProvider`).
- Experimental APIs (`Mutation`, offline `persist`) until they are stable.
- Global mutable singletons or service locators (`get_it`). Inject via providers.
- `setState` for data that comes from the API. `setState` is only for
  ephemeral UI state inside a `ConsumerStatefulWidget` / `StatefulWidget`.
- Calling Dio from a controller or widget. Go through the repository.
