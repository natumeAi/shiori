# Implementation plan: S3

Status: completed, 2026-10-27; owner-confirmed device acceptance closes Phase F.
See [closeout and AC mapping](research/s3-closeout.md). The checklist below is
the original execution plan, retained as planning history; its unchecked boxes
are superseded by the phase evidence and final acceptance report.
The parent remains the integration owner; S4 conditions remain open.

## Entry conditions and work ownership

- S1 archived build/storage foundation and merged S2 source model are present.
- Read parent scope, S2 carry-forward and this child's three planning artifacts.
  S2's conditional GO is not full performance acceptance.
- Both context manifests contain real spec/research entries. They are context
  manifests, not executable checklists or a replacement for this file.
- The base manifests stay below the 131072-byte artifact/context cap. Before
  a dispatch, curate for that phase rather than appending every guide. Read
  the Flutter index and testing guide before coding/tests; Phase E additionally
  reads routing/widget guides. The check agent reads directory/state rules
  on demand. Recalculate injected bytes after any manifest/artifact change.
- The base manifests are curated for Phase A, which adds no providers,
  models, repositories or Dio code: `implement.jsonl` omits
  `state-management.md` and `check.jsonl` omits `data-layer.md`. An agent
  reads an omitted spec directly if its phase work touches it. Before the
  first Phase B dispatch, add both back (session/retry and repository/
  endpoint rules), re-curate other entries to stay under the cap and re-run
  the injection check so `implement.md` stays inlined.
- Main session coordinates, reviews, updates specs and records outcomes.
  Implementation/check work defaults to the Trellis agents after activation;
  load the relevant phase instructions then. No implementation/check agent is
  dispatched by this planning turn.
- The first dispatch targets this child, never the whole parent. Each dispatch
  starts with the actual active-task path and a bounded phase/file ownership
  assignment; preserve other agents' and the user's changes.
- Treat this as one deliverable with ordered internal phases. No extra nested
  tasks are needed unless independently deliverable work actually emerges.

## Phase A: lock contracts and prove technical prerequisites

Owner: storage/network/reader foundation, no product screens yet.

- [ ] Recheck clean/dirty state, reference HEAD and declared task dependencies.
  Read affected Flutter specs; preserve unrelated work.
- [ ] Add synthetic health/snapshot/detail/error/file response fixtures from
  the pinned source; include duplicate/nullability/304/prefix cases.
- [ ] Resolve a compatible `sqlite3` release and promote `crypto` to a direct
  dependency without changing SDK/codegen pins. Record actual versions,
  licences and lockfile diff; verify an isolated temporary DB transaction,
  reopen, migration rollback and future-version refusal on Windows.
- [ ] Hosted iOS SQLite gate, before Phase B: add the smallest self-check
  reachable from an existing entry point (preferably the probe's diagnostic
  export; diagnostics may depend on `core/storage`, never the reverse) that
  opens, commits, reopens and refuses a future schema under Application
  Support. First check whether the resolved package can link system SQLite
  instead of bundling its own library. Build through the existing workflow,
  inspect the IPA's packaged native library, then the user signs/installs it
  through the selected S1 route and runs the check. The push to
  `ios-build/**` needs the user's explicit authorization in chat. A failure
  stops S3 for a storage-driver plan revision.
- [ ] Confirm the archive implementation actually resolved from the lockfile.
  Prove directory-before-expansion limits, real emitted-byte bounds, stored/
  deflate CRC/truncation and duplicate behavior using generated small limits.
  Reuse existing chunked/limited APIs when their tests establish the contract.
- [ ] Fix the known duplicate-name divergence: index entries from the raw
  central-directory headers so the last occurrence wins like the reference,
  count every physical entry and bypass the decoder's eager symlink read.
  Add generated duplicate-name fixtures through `tool/oracle`; existing
  vectors must stay unchanged. Record the intentional S2 behavior change.
- [ ] Add a file-backed archive open beside the in-memory one. With a
  generated near-limit archive, prove lazy entry reads, shared file handles
  released by `close()` and host worker resident memory that does not grow
  with archive size; record the measured ceiling in the design budget.
- [ ] Prototype the worker/source-resource adapter with generated fixtures;
  prove cancel/exit/error handling and no lazy decompression on the root.
- [ ] If an existing dependency cannot meet the bounded import contract,
  research the smallest compatible alternative and revise affected design
  before integrating downloads. Never substitute whole-file UI-thread work.
- [ ] Record local feasibility and the hosted/device SQLite result separately.

Exit: the storage driver and import boundary can satisfy the proposed design
without changing product behavior beyond the recorded duplicate-name fix; the
hosted SQLite gate has passed on the iPhone; duplicate resolution and the
file-backed open are proven. Dependency pin adjustments need evidence;
scope/compatibility changes require renewed plan review.

## Phase B: durable configuration and session transport

Own `core/config`, `core/network`, `core/storage`, servers data, their tests.

- [ ] Add endpoint normalization/root-resource resolver and `BookKey` identity.
  Verify canonical round trips, IPv6, encoded prefixes and safe cover joining.
- [ ] Extend `AppDirectories` with Caches; implement serialized SQLite owner,
  schema v1/migrations and typed asynchronous store commands.
- [ ] Implement candidate health + initial snapshot validation, transactional
  active selection, activation serial/generation and stale-publication guards.
- [ ] Bind Dio, cancellation and image requests to immutable sessions. Retain
  only approved read retries; map cancellation/TLS/shape/storage errors
  correctly, preserve unknown error codes and sanitize logging.
- [ ] Test simultaneous candidates, canceled attempt, commit failure, relaunch,
  and A -> B -> A delayed responses. Verify no whole-server deletion.
- [ ] Update data-layer/error/directory/state specs for intentional departures
  from compile-time configuration and no-persistence scaffold guidance.

Exit: S3-AC1 through AC3 and storage migration portions of AC6/AC8 pass locally.

## Phase C: typed snapshot and basic book data

Own `features/library/data` and fixture/controller tests.

- [ ] Implement Health, SnapshotBook, SnapshotFolder, ShelfRef, RecentEntry,
  LibrarySnapshot and full Book DTOs; use explicit server timestamp conversion.
- [ ] Implement normalized snapshot indexes and full detail retrieval, with
  required nullable field checks and tolerated additive fields.
- [ ] Persist snapshot/validator atomically; handle cached stale state and
  200/304/missing-cache unconditional recovery without infinite retries.
- [ ] Add scoped cover fetching, bounded bytes/decode cache and fallback.
  Verify no use of storage paths, filename URLs or independent image clients.
- [ ] Prove `/books` root-only semantics do not accidentally replace the
  all-book snapshot; do not add unused mutation/statistics wrappers.

Exit: S3-AC4, API portions of AC5 and GET-only inventory pass.

## Phase D: bounded files and worker handoff

Own cache/file repository, reader pure-data worker/seams and tests. Keep
product reader controls, activity and turn instrumentation out of this phase.

- [ ] Stream to task-owned temp files; actual length limits, SHA-256 and
  cancellation; per-book operation token/coalescing and forced-refresh order.
- [ ] Implement 200/304/no-validator and unconditional recovery policy;
  refuse to publish partial range or error/login responses.
- [ ] Apply proven bounded, file-backed archive entry access, source
  parsing/resource discovery and canonical indexing in the worker. Keep
  node/UTF-16/CFI behavior.
- [ ] Preserve package/per-item fixed-layout and mixed-layout metadata plus
  viewport/source/resource facts. Implement the layout-facts value:
  per-section mode, package-level progression/language facts and
  style-derived facts only for sections actually styled (others
  `notInspected`). No layout class fails import and no whole-book
  `detectBookLayout` pass runs; the S2 probe keeps its `requireSupported()`
  refusal unchanged.
- [ ] Expose typed publication/source/resource/close operations and leased
  identity; implement preloaded adapter needed for S4 without importing
  diagnostic presentation or allocating a whole-book resource mirror.
- [ ] Enforce cache/staging/worker budgets, pinning, generation invalidation,
  resource disposal and clear recovery for unsupported/corrupt content.
- [ ] Implement rename-before-DB-publication and crash reconciliation.
  Inject failures at each boundary and verify old-head preservation, orphan
  cleanup, disk-full handling and cache-only eviction.
- [ ] Run existing synthetic EPUB/source/CFI/canonical tests. Include archive
  duplicate/path/symlink/CRC cases and work canceled during resource discovery.
- [ ] Add source-handoff cases for simple/complex fixed and mixed publications,
  including per-item overrides and valid fixed first pages, plus
  RTL-progression, RTL-language and vertical fixtures that prepare with their
  facts recorded; distinguish them from corrupt/invalid sources without
  claiming rendering acceptance.
- [ ] Document exact S4 migration/lease/content-change contracts and update
  reader/data/testing specs after behavior is verified.

Exit: S3-AC5 through AC8 plus zero-write/identity checks pass locally.

## Phase E: minimal product UI and iPhone build selection

Own servers/library presentation, app routing, ARB, plist, CI target selection.

- [ ] Add connection/edit form, list/folder navigation, refresh/retry/change
  entry and book preparation/cancel/ready states. Use typed routes.
- [ ] Keep stale data marked, old selection on candidate failure and route
  stack reset on activation. Check safe-area, keyboard, semantics, enlarged
  text and system light/dark without doing S5/S6 parity work.
- [ ] Add honest local-network explanation/troubleshooting; do not claim a
  socket error proves permission denial. Add the iOS purpose string.
- [ ] Add allowlisted `probe|app` build mode, default probe. App mode targets
  `lib/main.dart`, one default-layer IPA, with explicit provenance/artifact
  names and the existing workflow's monotonically increasing build number.
  Keep the existing probe/cametal artifacts and bundle identity intact.
- [ ] Maintain the recorded S4 synthetic-assets-before-release item. S3's
  engineering build is not a release acceptance or a second diagnostic project.
- [ ] Test key screens and route-switch races; check script syntax and fixture
  privacy. Review native diff and package provenance when CI runs.

Exit: S3-AC9 and all local code gates; device AC10 still requires actual evidence.

## Phase F: independent check, device evidence and handoff

- [ ] Run the final required gate once after fixes; independent check reviews
  the entire S3 diff and all acceptance mappings, not just the last phase.
- [ ] Review manifest/spec drift and ensure reference/NAS write inventory is empty.
- [ ] Prepare the concrete diff/build instructions before requesting any
  public push authorization still required by the parent. Do not assume this
  planning request grants a push.
- [ ] Build the app IPA through the existing hosted route, re-confirm the
  SQLite integration proven in Phase A and record any iOS generated diff.
  Retain SDK/identity checks and free-usage constraints.
- [ ] User-operated sign/install/update: on iPhone test initial connection,
  LAN permission denial then re-enable/retry, library/cover load, book
  preparation (including a near-limit synthetic archive without memory
  termination), transient network failure, endpoint change, relaunch and
  update retention. Use disposable/synthetic data for repeatable checks.
- [ ] Record a prefixed and/or plain HTTP deployment only if available; label
  unsupported live combinations unverified. Host fixtures remain separate.
- [ ] Keep private endpoint/screenshots/books/diagnostics in ignored
  `local-evidence/s3/`. Commit only redacted counts/results and reproducible
  synthetic fixture descriptions.
- [ ] Supply S4 handoff with API signatures, schema/migration ownership,
  content-change/lease lifetimes and retained S2 conditions.
- [ ] Do not mark the child completed with AC10 missing. Report local-ready
  status and the exact external/device step still pending.
- [ ] On actual completion, follow the loaded finish-work workflow; this
  planning turn does not commit, archive or start a task.

## Validation commands

Planning-only validation (run now):

```powershell
python .trellis/scripts/task.py validate .trellis/tasks/10-26-runtime-server-library
git diff --check
git status --short
```

Implementation gate (run after code changes, not during planning):

```powershell
dart run build_runner build
dart format --set-exit-if-changed lib test tool/reader tool/diag tool/ci
flutter analyze
flutter test
dart run tool/ci/check_reader_fixtures.dart
```

Include newly created integration/tool directories when applicable. Run
`bash -n tool/ci/build_ios_unsigned.sh` with Git Bash after script changes;
Windows syntax checks do not prove macOS builds. New focused tests use fake
Dio adapters/mocks and temporary directories/DBs, never a real NAS. Network
prefix/redirect/304 tests assert actual request options and streamed response
handling, not mocked repository outputs alone.

Parser changes must pass the existing authoritative generated fixture tests.
Regenerate oracle outputs only if fixture sources deliberately change, using
`tool/oracle/README.md`; record why and inspect diffs. Do not bless altered
expected vectors to conceal source/CFI drift. Optional private-book tests
remain local and are never a public CI prerequisite.

## Review and rollback hotspots

- Endpoint resolver and activation coordinator: a lost prefix or missing
  generation guard can target the wrong deployment.
- `guardDio`/`retry_policy`: cancellation must not become a retry storm;
  fail-closed certificate behavior remains unchanged.
- SQLite migrations and cache publisher: preserve old state and reconcile
  filesystem/DB split commits; never clear the whole app root to recover.
- Archive/worker/resource seams: preserve source oracle and existing probe;
  avoid hidden root-isolate decompression or duplicated retained book memory.
  The duplicate-name index and file-backed open are shared with the probe;
  existing vectors must not move.
- CI target selection: preserve default probe, fixed identity, build counter
  and default product layer; no accidental alternate-layer product artifact.
- Stop and revise the plan if passing requires dropping supported content,
  changing the parent scope/thresholds, backend mutation or paid infrastructure.
