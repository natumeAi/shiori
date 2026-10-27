# S3 Phase B3: candidate activation against a selection-store port

Implemented on Windows, 2026-10-26, in `D:/Projects/shiori-b3`, branch
`s3/b3-activation`, based on `d2ef82b`. Direct implementation; no sub-agents,
staging, commits, pushes, branch changes, other-checkout access or live HTTP.
This is host evidence with in-memory storage, not SQLite/device acceptance.

## Store interface and values

`lib/core/config/server_selection_store.dart` declares exactly five methods:

```dart
Future<StoredServer?> readServer(ServerKey key);
Future<ServerKey?> readActiveServer();
Future<void> commitActivation({
  required ServerEndpoint endpoint,
  required ServerKey key,
  required ValidatedSnapshot snapshot,
});
Future<ValidatedSnapshot?> readCurrentSnapshot(ServerKey key);
Future<void> touchLastUsed(ServerKey key);
```

The associated plain immutable values are separate core/config files:

- `StoredServer`: `canonicalEndpoint: String`, `createdAt: DateTime`,
  `lastUsedAt: DateTime`. Timestamps are local metadata represented in UTC.
- `ValidatedSnapshot`: exact `payloadText: String`, `schemaVersion: int`,
  optional opaque `etag: String?`, `revision: int`, `fetchedAt: DateTime`.
  It performs no DTO decoding, validator normalization or revision comparison.
- `SelectionStorageException(SelectionStorageIssue)`: `unavailable`,
  `invalidSelection`, `newerSchema`; contains no SQL, payload or driver cause.

The SQLite adapter must verify key/endpoint identity and transactionally upsert
endpoint, snapshot and active selection. Preserve an existing creation time,
update last-use time, and roll back the entire operation on failure. It must
map storage failures to the typed boundary and preserve unknown/newer schemas.
No namespace deletion, cache mutation, reader-state or reset API is exposed.
The interface was not widened and B1a/B1b handwritten APIs were not changed.

## Health and snapshot validation

`ServerHealth` is a Freezed DTO with generated checked JSON conversions for
three required strings. `HealthRepository.validate()` requires `status=ok`,
`service=epub-reader-server`, `database=ok`; additive fields are ignored.
Wrong service, unconfigured DB, failed DB health and malformed health have
separate `HealthIssue` values. Missing/null/wrong-type fields are malformed.

The failed-DB fixture is the real HTTP 500 error envelope. The repository maps
health HTTP 500 to `databaseFailed`; `database:"error"` is not invented as a
valid wire state. An intermediary's identical 500 cannot establish which
server component failed; the classification is health-stage failure feedback.

`CandidateSnapshotValidator.validate(SessionTransport)` is injected. Phase C
must implement an unconditional `GET api/library/snapshot` on that candidate
transport, with no validators and only 200 allowed. It validates the complete
schema and joins, returns the plain validated value, or throws
`SnapshotValidationException(incompatible | malformed)`. Tests use a fake that
exercises the real unconditional GET or supplies controlled validation futures.
No snapshot DTO or production validator is implemented in B3.

## State machine and commit boundary

`ServerActivationController` is a generated keep-alive AsyncNotifier.

```text
AsyncLoading (restoring)
  -> AsyncData(session: null)             unconfigured
  -> AsyncData(session: restoredSession)  selected
  -> AsyncError(typed storage error)      preserve storage; recover explicitly

unconfigured | selected(previous)
  -> validating(previous)
  -> committing(previous)
  -> selected(new session)
  -> idle(previous, typed feedback)       on failure
```

Each admitted candidate owns a serial, lifetime token, temporary session,
transport and cancellation completer. Validate health before snapshot. A newer
validation cancels/supersedes the earlier one; ownership checks after awaits
discard stale results. Cancellation races the validator future, so a fake or
future worker that ignores transport disposal cannot hold the activation call.
Abandoned success/error completions remain consumed, with no feedback/retry.
Candidate work never reads or invalidates active session families.

**Linearization:** the supplied port cannot undo a transaction already
dispatched. Commit and session publication therefore form one noncancelable
serial section. New requests wait for that section to finish; only the latest
queued request starts afterwards. Cancel during commit cancels queued admission,
while the already dispatched transaction completes. This prevents a durable
selection from being silently discarded while UI remains on an older server.
No conditional commit, compensation transaction or rollback API was added.

On commit failure the prior session, transport, pending work and snapshots
remain current. On success: revoke publication, cancel registered old work,
dispose/invalidate old transport, create a new generation, then publish the
new session. The candidate transport is always disposed rather than promoted.
App/UI composition later registers controller/worker/route/image cleanup.

Relaunch reads active key and server row, re-parses the canonical endpoint,
verifies exact canonical text and key, and creates a fresh session without
health/snapshot traffic. Missing/malformed/noncanonical/mismatched rows fail
recoverably without clearing them. The active transport is created through a
dynamic family-reading factory: watching the retired family directly from
coordinator build would rebuild its activation owner during a server switch.

## Session publication guards

`SessionPublicationGuard` is a pure core/config helper, injected through a
generated keep-alive provider. Generations increase within its container
lifetime, including coordinator invalidation; candidates also receive unique
temporary generations but are never current. A process restart has a new
runtime ownership scope. Generations are not persisted or globally ordered.

- `isCurrent(session)` compares key and generation via `ServerSession` equality.
- `publish(session, synchronousCallback)` checks immediately before writing;
  no await is allowed between this check and the write. The coordinator uses it.
- `onRetire(session, cancel)` registers pending work and returns an unregister
  function. A stale registration cancels immediately. Callbacks must be
  synchronous, idempotent and nonthrowing. Completed work unregisters itself.
- Retirement revokes current ownership before invoking cleanup callbacks.
  Old first-A and B results cannot publish into a later activation of A.

## Test coverage and results

| New test file | Passed |
| --- | ---: |
| `test/features/servers/data/health_repository_test.dart` | 25 |
| `test/features/servers/presentation/server_activation_controller_test.dart` | 13 |
| `test/features/servers/presentation/server_activation_failures_test.dart` | 16 |
| `test/features/servers/presentation/server_activation_races_test.dart` | 12 |
| `test/core/config/session_publication_guard_test.dart` | 4 |
| Total | 70 |

Coverage includes all five health fixtures; checked missing/null/type failures;
HTML/malformed payloads; invalid roots with zero client creation; TLS, 401/403,
timeouts, redirect and HTTP status distinctions; incompatible/malformed
snapshot; simultaneous supersession; cancel during health and snapshot;
four delayed A-health/snapshot x B-health/snapshot combinations; active A -> B
-> A guarded HTTP/cover/file/worker publication; ignored cancellation and late
errors; commit failure; one commit in flight; latest queued admission; cancel
while committing; restore/no selection/corrupt row/future schema; switch after
restore; cancel during restoration; active transport preservation and retirement;
container disposal; guard unregister and duplicate callback registrations.
Every harness rejects unexpected store commands and asserts no such command
was called; successful switches retain both server records and snapshots.

Initial focused compilation failed on two tests missing Riverpod extension
imports; corrected. An intermediate analyze found five style infos; corrected.
Final verification:

| Command | Result |
| --- | --- |
| `flutter pub get --offline` | PASS; no pubspec/lock diff; no fallback needed |
| `dart run build_runner build` | PASS; new checked DTO and providers generated |
| `dart format` on all 24 changed/new Dart files | PASS |
| `dart format --output=none --set-exit-if-changed` on the same files | PASS; 24 files, no changes |
| `flutter analyze --no-pub` | PASS; no issues |
| `flutter test test/features/servers test/core/config/session_publication_guard_test.dart --no-pub --reporter expanded` | PASS; 70 passed, no skips |
| `flutter test --no-pub --reporter expanded` | PASS; 1472 passed, 4 skipped |
| `git diff --check` | PASS |

The full suite skips three existing private-local-book tests because local
EPUBs/vectors are absent in this worktree, plus the existing native CFI export
test because `SHIORI_NATIVE_CFI_OUT` is unset. Logs are ignored local output:
`build/phase-b3-focused.log`, `build/phase-b3-flutter-test.log`.

## Spec notes and later integration

Updated only `state-management.md`: lifecycle, serial commit admission,
generation/publication/cleanup rules, dynamic family ownership, feedback and
required tests. Placement notes for the parallel spec owner:

- Directory: pure selection-store/value/error/guard types belong in
  `core/config/`; candidate contracts/health/composition ports in
  `features/servers/data/`; generated activation controller in presentation.
- Data layer: plain validated payload values are not HTTP DTOs. Health uses
  checked Freezed; Phase C supplies snapshot validation. The SQLite adapter
  implements the five-method port; composition overrides the store/validator
  providers, whose defaults intentionally throw until wired.
- Feature health/snapshot/storage contract exceptions stay outside the sealed
  core `AppException` library. The controller maps them, and existing transport
  exceptions, to safe `ServerActivationFailure` feedback alongside selected data.
  Phase E maps these typed kinds to localized connection UI. No raw exception
  rendering or automatic candidate retry is introduced.
- Required Flutter/codegen commands rewrote 30 existing generated files with
  LF endings. Their content was verified against HEAD and original CRLF
  checkout bytes restored (verified against indexed file sizes). Final Git
  status has no changes under storage, B1a/B1b, diagnostics, app, native plugin
  files or dependencies. No handwritten storage files or shared evidence were
  edited.

Remaining integration work belongs to later slices: SQLite adapter/composition,
Phase C validator/DTOs, Phase E UI and actual caller cleanup registrations.
No B3 implementation blocker remains; this slice makes no device/LAN/SQLite
transaction or completed S3 product acceptance claim.
