# A0 scene and process-font admission policy

Status: executable provisional policy, 2026-10-27. These modules are not yet
connected to the production preparer/renderer. A3 owns that integration and its
lifetime tests; A5 owns the physical-device resource/performance decision.

## Owners and finite limits

`engine/layout/scene_resource_budget.dart` owns whole-plan logical reservations.
`reserve` checks every requested class and depth before changing any counters.
`reserveUnit` adds one unit and its one/two real source constituents atomically;
blank slots add no source charge. Four units permit three presented units plus
one preparation reserve, up to eight real source-page constituents. This count
must be the same ownership decision as the surface pool, not a second cache or
permission to allocate another four units. Share one ledger across warm work,
required preparation, and replacement/zoom generations. Retain every old charge
until its allocations are destroyed and canceled physical work has drained.

| Logical resource | Inclusive provisional aggregate limit | A3 charge definition |
| --- | --- | --- |
| Reading units / real source pages | 4 / 8 | Pending and retained units; every spread constituent, no blank source |
| Source payload bytes / source nodes | 32 MiB / 100,000 | Every simultaneously owned input serialization and source/style/geometry payload; node count includes nonpainted identity nodes |
| Paragraphs / shaping UTF-16 code units | 8,192 / 4,194,304 | Retained plus pending paragraphs and all shaping input, including SVG text and foreignObject |
| Vector payload bytes / operations | 16 MiB / 100,000 | Path/scene payload and every expanded path/paint operation; referenced subtree instances cannot hide work |
| References / gradient stops | 4,096 / 4,096 | Expanded graph edges and all retained stops, including repeated referenced uses |
| Temporary RGBA8 pixels / bytes | 8,388,608 / 32 MiB | Sum of simultaneous physical pixel areas, including scale, padded filter regions and intermediates |
| Source / reference / layer nesting | 64 / 32 / 8 | Maximum actual traversal/compositing stack per candidate, checked independently |
| Process font input bytes / faces | 64 MiB / 32 | Pending + successfully registered + uncertain native outcomes, across all books |

These are initial engineering limits, not measured iPhone-safe ceilings. Source
bytes describe known owned string/typed-array payload (UTF-16 strings count two
bytes/code unit), not an invented exact VM heap size. Nodes bound object-count
overhead separately. A3 must document its actual payload estimator and include
source/style/geometry strings and buffers; counting only the raw XHTML size is
insufficient. Paragraph/vector counts constrain work and ownership; native
shaping allocations and GPU/driver overhead remain separately measured.

The existing `ReaderResourceBudget.shared` remains the sole shared **128 MiB**
encoded preload owner. Existing retained picture/image starting bounds remain
**16 MiB / 48 MiB**. Scene/font counters do not replace, reset or add capacity to
those owners. A font's encoded source buffer is counted by the encoded owner
while live; the process-font number records a separate non-unloadable lifetime,
not an additional retained copy of that Dart buffer. A raster that becomes the
retained surface transfers into its image owner without a period in which neither
owner charges it; retained and temporary overlap must both remain visible.

`reserveLayer(width,height,buffers,depth)` uses division before multiplication to
refuse oversized dimensions safely. It charges all simultaneous RGBA8 buffers;
other pixel formats require explicit actual-byte reservations. For a whole filter
graph, reserve its complete known peak plan before its first image. Never create
some primitives and publish the remaining partial image after refusal. A3 can
serialize preparation to fit temporary capacity; it cannot drop required content
or weaken capability completeness. Cancel optional prewarm first, retain the
accepted page/proof, and return a typed failure if the required candidate cannot
fit. A later required-fixture cap failure remains an open gate for review.

## Host fixture basis and exclusions

The current `test/fixtures/reader/fixed_layout/corpus.json` has 52 synthetic cases
at authored 320 x 240. A raw XML scan on 2026-10-27 found maximum source UTF-8
size 1,616 bytes, 30 elements, element depth 8, 2 gradient stops, and 491 UTF-16
text/tail code units (including stylesheet text). These raw XML counts are not
the final inert source graph or shaped layout counts. The focused corpus test
uses the actual `SourceParser` projection and admits eight copies of every case's
serialized source/node/text payload; all pass. It proves current fixture headroom
for these logical counters, not the resource demand of eight fully rendered pages.
The much larger provisional graph/paragraph/vector limits leave room for real
sections but are not empirically calibrated from this small synthetic corpus.

The native hard-feature peer measured the following in its first host raster run:

| Case | Owned RGBA8 images incl final surface | Known image payload |
| --- | --- | --- |
| sRGB filter graph | 9 at 320 x 240 | 2,764,800 bytes |
| linearRGB filter graph | 11 at 320 x 240 | 3,379,200 bytes |
| SVG shaped text / foreignObject | 2 / 1 paragraphs | Native paragraph bytes unmeasured |
| Packaged fixture font | 1 SFNT face | 171,676 source bytes |

At scale 3 the linear graph would have 7,603,200 owned pixels / 30,412,800
RGBA8 bytes, below the provisional layer cap. This is arithmetic headroom, not
a measured scale-3 native run or permission for another graph at that peak.
The harness's blur/saveLayer scratch is additional and unmeasured. Its luminance
mask uses up to four nested saveLayers, plus an outer nested-case group. A3 must
bound/count the real layer nesting/regions and intermediate graph; A5 must record
peak device RSS/native/GPU effects. Do not infer total memory from these bytes.

The font fixture digest is
`79e851404657dac2106b3d22ad256d47824a9a5765458edb72c9102a45816d95`.
Thirty-two such distinct faces would charge 5,493,632 input bytes, under the
64 MiB byte bound; the face-count bound would refuse the next face. Larger fonts
can instead hit the byte bound. These two independent bounds deliberately remain
finite before repeated book changes. This host test does not establish WOFF/
WOFF2 support, font collection selection, engine font memory, or iPhone fidelity.
Consult the separate native spike for actual registration/rendering results.

## Font lifecycle and failure contract

`ProcessFontBudget.shared` is the product process owner. Injectable fresh owners
are for isolated tests; never create one per registry, book or server activation.
`load(bytes, face:, register:, cancellation:)` hashes immutable admitted bytes and
coalesces the SHA-256 plus canonical face descriptor before native registration.
Archive path, book identity and CSS family aliases are not registration identity.
Callers must normalize collection index/weight/style/variation descriptors; the
string is opaque to the policy. The registered engine alias is content-derived.

Pending admission consumes both bytes and a face synchronously before `register`
runs, including when `register` reenters. After success it moves to permanent
registered accounting; no close/reset/unload method exists. `bytes`/`faces` equal
pending + registered + uncertain, with separate public counters and lifetime peaks.

Cancellation before admission starts no work. Cancellation afterward completes
only that caller with `ProcessFontLoadCanceled`; shared native registration keeps
running and stays charged even when every book waiter leaves. A late successful
registration remains permanent. A late failure is consumed so abandoned waiters
do not generate unhandled asynchronous errors.

Only `ProcessFontRegistrationRejected` authorizes releasing a failed pending
reservation. An adapter may throw it only when no engine registration occurred.
A generic synchronous/asynchronous native error is uncertain: its bytes/face
remain charged and its failed attempt is cached, so close/retry cannot silently
register the same uncertain face again. A3 must validate formats before this
boundary and document whether the platform adapter can certify rejection.

Exhaustion throws `SceneAdmissionException` with
`SceneAdmissionFailure.processFontExhausted` before starting another registration.
Do not swallow it into FontRegistry's ordinary missing-font fallback for required
fixed content. Preserve the accepted reader state and expose recovery explaining
that closing/retrying does not unload engine fonts. A user-initiated app restart
may be needed; never automatically restart or silently substitute required fonts.

## A3 integration handoff (read-only boundary review)

1. `layout/font_registry.dart`: inject the shared process owner; replace
   per-instance `_loaded` registration identity with the process alias and keep
   CSS family mapping separate. Its broad catch currently turns all errors into
   fallback records: typed exhaustion/canceled/required failures must propagate
   appropriately. Retain the existing individual 32 MiB pre-read check. Format
   validation/native SFNT/WOFF support remains a separate renderer gate.
2. `pagination/section_preparer.dart`: it creates FontRegistry by default and
   loads fonts before paragraphs. Reserve scene payload/work before allocation,
   preserve no-work-in-motion guards, and transfer scene/resource owners to the
   prepared result only on complete success. Count partially constructed native
   objects until disposal, including canceled awaited work.
3. `surface/page_surface_pool.dart`: current picture size admission occurs after
   recording. A3 needs a conservative pre-record reservation plus actual-size
   reconciliation; decoded-image admission likewise must precede decode. Keep
   current/old replacement and pending owners live through teardown. Integrate
   reading-unit counts once, with all constituents sharing the same unit owner.
4. `surface/prepared_reader_session.dart`: `_warming` coalesces warm work only;
   direct `prepare` can race it. Coalesce a full identity/generation/target plan,
   suppress optional warm while motion is admitted, and give each consumer an
   independent reference. Releasing one canceled waiter cannot destroy another
   consumer's prepared unit. A fresh generation cannot publish old warm results.
5. Publication worker/session integration: preserve the encoded shared budget and
   independent immutable-file lease; worker reopen cannot revoke a live reader's
   adapter. Add reader worker reservation/drain ownership before using downloaded
   scenes. This policy ledger itself does not acquire file/worker ownership.

Suggested separate A3 review scopes: process-font adapter/typed propagation;
scene/surface preallocation with constituent ownership; preparation/session and
worker lifetime/coalescing. Those seams interact: each scope needs a shared
identity/ownership contract before parallel product edits.

## Focused validation

Owned paths: `scene_resource_budget.dart`, `process_font_budget.dart`, and their
matching two layout tests. No production FontRegistry/preparer/pool was changed.

On 2026-10-27, all 21 focused tests passed. Coverage includes every resource's
inclusive boundary, atomic multi-class failure, independent depths, 4-unit/8-page
ownership, blank constituent behavior, old/new overlap, exact-once release,
layer dimension overflow, immutable snapshots, corpus projection admission,
concurrent pending font dedup/exhaustion, confirmed rejection/retry, uncertain
native failure, caller cancellation and no font work in motion callbacks.

The local `.bat` SDK wrappers waited without starting Dart and were canceled.
The equivalent installed SDK entry points ran successfully:

```powershell
$dart = 'D:/DevTools/flutter/bin/cache/dart-sdk/bin/dart.exe'
$owned = @(
  'lib/features/reader/engine/layout/scene_resource_budget.dart',
  'lib/features/reader/engine/layout/process_font_budget.dart',
  'test/features/reader/engine/layout/scene_resource_budget_test.dart',
  'test/features/reader/engine/layout/process_font_budget_test.dart'
)
& $dart format --set-exit-if-changed @owned
& $dart analyze @owned
& $dart 'D:/DevTools/flutter/bin/cache/flutter_tools.snapshot' test `
  test/features/reader/engine/layout/scene_resource_budget_test.dart `
  test/features/reader/engine/layout/process_font_budget_test.dart --reporter expanded
```

Final format: four files, zero changes. Final analyzer: no issues. Test runner:
21 passed. The Flutter test needed automatic sandbox escalation for its existing
SDK cache lockfile; no source outside the workspace was edited. Full codegen/
analysis/test and required oracle/device gates remain the main session's broader
S4a validation responsibility.
