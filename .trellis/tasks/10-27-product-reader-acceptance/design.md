# Design: product reader composition and acceptance

Status: proposed, 2026-10-27. Exact reference UI settings/constants and
source anchors are in research/product-and-evidence-plan.md.

## Product ownership

Add lib/features/reader/presentation with one session-scoped controller and
typed reader route. It composes S4a's ReaderPublicationSession/prepared units
and S4b's accepted observation/checkpoint/activity ports. Riverpod owns coarse
loading/settings/delivery state; local numeric controllers own motion/view
transforms. Widgets never independently save positions.

Existing BookRoute preparation obtains source readiness. Transition acquires
the reader's independent pin and worker ownership before the old route may
release its PreparedBook. Capture activation, BookKey, full content identity,
reader/layout/view generation on all asynchronous work. Preserve the source
return context without depending on the later three-tab S5 shell.

Persist active-reader intent separately from an accepted checkpoint. Explicit
open sets intent; startup restores the selected server before opening once.
Explicit exit clears intent; failure does not erase checkpoint/events.
Expose active-book-deleted and reader-return/delivery refresh hooks for S5/S6.
Use an adjacent migration after S4b v3 if current generic app-state commands
cannot represent typed intent/settings safely; preserve all reader records.

## Controls and appearance

Port reference tokens rather than Material seed approximations. Chrome/
TOC/current-entry scrolling, source progress versus native page progress,
mutually exclusive panels, safe areas and center tap match UI09.

Settings: six font labels with actual iPhone fallbacks; four reader themes;
font default 18, 14..40 step 2; extra horizontal/vertical margins default 0,
0..48 step 6 on reference base 48/60; line height 1.6, 1.3..2.0 step 0.1;
letter spacing 0, 0..0.12 em step 0.02. Sanitize persisted values and use
500 ms debounce plus teardown flush. Verify reference baseline before porting
tokens. Native pagination differences do not relax UI/settings parity.

Theme repaint is separate from geometry generation where possible. Reflow
settings preserve the accepted content anchor through repagination; fixed
sections retain authored geometry/typography and omit reflow overrides.
App system theme and reader-selected theme remain independent.

## Gestures, view state and source proof

Reuse existing tap/drag/flick/rebound/queue constants. Each fixed page/spread
starts fitted without cropping. View state is keyed by content/unit/viewport
generation; inverse-transform image/text hits through authored clips/masks.
SVG text hits resolve to S4a's shaping cluster and its source range, never to
a ligature component.

Arbitration is explicit: active pinch/pan owns its pointers; enlarged single-
finger drag pans and cannot trigger page turns or edge turns; fit restores
normal turn zones. A reachable reset restores fit. Explicit TOC/page
navigation cancels the old gesture and initializes the new source view.
Panels/viewer block conflicting input and never leak a late pointer-up into
a page turn. No added double-tap/edge shortcut is implied for whole-page view.

Image viewer retains reference fit, zoom/pan/dismiss and 180 ms transitions;
reference image zoom uses 1..5, double-tap 2.5 and pan resistance 0.25.
These viewer constants do not automatically become whole-page behavior.
Whole-page scale limits must use S4a's measured resource policy and permit
useful text enlargement. Higher-resolution images prepare outside gestures.

During view changes, invalidate S4b text samples; after settling, re-prove
visible source and publish the stable view. Time eligibility follows S4b,
not generic pointer activity. An accepted view change is not completion.
Transient transform persistence is optional technical state; source position
restoration is mandatory. Never apply an old transform to another unit.

## Lifecycle, persistence and recovery

Separate three transitions. Panels disable conflicting gestures and time/text
eligibility as specified by S4b while retaining the live session/resources;
the image viewer blocks text sampling but retains eligible time and source
resources. Neither transition detaches the worker or releases the file pin.

OS suspension disables input/samples, cancels motion/view work, closes eligible
time and persists accepted state. Retain the independent file pin and source
identity; cancel/drain optional work and release disposable surfaces under the
budget policy. Foreground reacquires any discarded surfaces/adapters through
the shared owner, checks viewport/resources/content and re-proves the accepted
anchor before resuming. A real post-return accepted turn is required.

Final retirement (exit, server switch, content/session replacement or dispose)
invalidates all generations, drains/disposes S4a owners, detaches the worker
and releases the file pin in the defined order. Persist already accepted
state before teardown without relying on a process-termination callback.

Persist checkpoints and activity during reading rather than relying on exit.
Pending verified local progress wins server/web conflicts as approved;
invalid identity/CFI uses retry or explicit chapter-start recovery. No
conflict-choice UI is added. Content change/unavailable book retains pending
records and explains the actionable state; unsupported vertical/RTL and
required rendering failures are never a successful empty/partial book.

Localize all labels/errors/semantics; preserve visible reference geometry with
accessible hit areas and enlarged-text controls. Reduced motion retains the
same proof/cancellation semantics. Diagnostic export contains no unredacted
private payload in tracked artifacts.

Consume S4a's typed process-font-exhausted outcome without a retry loop or
pretending that closing the book frees registered fonts. Preserve accepted
state, explain the limit and provide a safe return; a user-initiated app
restart may be necessary. Never restart automatically or silently substitute
an authored font to report successful fixed-page fidelity. S4a's typed
WOFF/WOFF2 conversion failure (invalid or over-bound font data) is a required
rendering failure for the affected section, presented with the same honest
recovery and never a fallback-font success.

## Build and evidence boundary

C4 makes app/probe asset sets explicit and verifies packaged manifests, so
synthetic EPUBs do not ship in the product while probe fixtures remain.
Keep the fixed identifier and build provenance. Native diagnostics remain
explicit/inert unless activated; product path is FlutterMetalLayer. A HarfBuzz
library adopted through S4a A0b ships pinned, is listed in the build inventory,
and has its licence notice registered through `LicenseRegistry`. Where the
licence page is linked from in the app shell is S5's concern.

S4a owns early measurement repairs and feasibility; C5 closes all seven S2
conditions against the final product. Each result records build/engine/OS,
viewport/fonts/cache/scenario, power/refresh declarations, observed vsync,
raw timings, waits, overflows and omissions. Use three repeats and >=100
alternating turns, plus real lifecycle, complex/mixed, settings/viewer and
delivery-under-reading scenarios. UI/raster budgets, admitted submission,
stall classification, resource trend and physical presentation are separate.

A missing required physical-presentation result cannot be promoted to PASS
by software timings or screen recording. Record the limitation for review.
S4c owns reader acceptance; S7 still owns complete app/NAS integration.

## Rollback and delivery to S5

Reader route/controls can be reverted without deleting active intent,
checkpoints or outbox. Unknown future schema is refused with bytes retained.
Do not change signing identity or buy services to overcome a gate.
Deliver typed reader-return, active-intent and delivery-refresh interfaces,
paired UI ledger and remaining evidence limits to S5; do not implement its
shell/statistics screens here.

Cross-client evidence applies the user-approved 2026-10-27 occlusion exception:
native counts actual-visible text, and only reproduced reference covered-text
interval/count differences are documented with a separate fix handoff.
Canonical v1, time, completion and idempotency remain exact; no other parity
failure is waived and no existing NAS history is rewritten. Two later narrow
exceptions also apply. D6 (2026-10-28) covers edge characters that differ only
through reference integer snapping. D3 (2026-10-27) covers reproducible WebKit
raster defects in fixed-page comparisons, re-verified on the device's Safari.
Both are recorded per case in S4a/S4b evidence.
