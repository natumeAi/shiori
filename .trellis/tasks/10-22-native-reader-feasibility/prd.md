# Native reader feasibility

## Goal

Prove, before any broad UI work, that a pure Dart/Flutter reader can
(1) reproduce the reference reader's source positions and statistics
coordinates exactly, (2) lay out ordinary novel EPUBs natively without losing
content, and (3) turn pages on the iPhone 14 Pro Max within the proposed
120 Hz engineering gate — and record honestly which presentation evidence the
Windows + iPhone setup can produce.

Parent: `../10-22-flutter-lan-reader-parity` (stage S2). This child owns the
early part of parent AC4 and the feasibility evidence for AC3, AC5, AC8 and
AC10. It does not deliver the product reader; S4 does.

## Background

S1 (`../archive/2026-10/10-22-ios-free-device-bootstrap`) proved the free
build → 全能签 signing → install → update → Files-app export loop, and measured
a synthetic moving surface near 120 Hz with engine timing only. Physical
presentation stayed unverified and was handed to S2.

New S2 entry facts are in `research/s2-entry-evidence.md`. The most important:
in the pinned engine the product presentation path is `FlutterMetalLayer`,
whose drawables do not implement `addPresentedHandler:`/`presentedTime`, so
Apple drawable presentation times exist only on a diagnostic variant that
disables that layer.

## Accepted Decisions

- **Presentation spike (user decision, 2026-10-22):** a time-boxed,
  diagnostic-only native iOS hook in `ios/Runner` is allowed. It is installed
  only by the diagnostic entry point; the reader itself stays pure Dart. If it
  yields no usable data, the result is recorded as unverified with evidence.
- **Execution mode (user decision, 2026-10-22):** the executor runs all local
  phases continuously, committing once per phase on a local branch, and stops
  only when a phase gate fails or the device step is reached. Every push still
  needs the user's confirmation in chat.
- **Oracle:** reference behavior is captured by shiori-owned tooling that runs
  the pinned foliate-js and vendored lan-reader logic in real browser engines.
  The lan-reader checkout is never modified.
- **Real books** reach the phone through the Files app into the app's
  Documents folder. They never enter the repository, CI, artifacts or exports.
- **App identity, build route and signing** are unchanged from S1.

## Requirements

| ID | Requirement |
| --- | --- |
| N1 | Provide reproducible oracle tooling that executes the pinned reference parsing, inert projection, CFI and canonical-text behavior in WebKit (primary) and Chromium (cross-check), and emits versioned vectors. Synthetic fixture vectors are committed; vectors for the four local books stay local. Record engine versions and every cross-engine difference. |
| N2 | Build a Dart EPUB/source model that preserves OPF itemrefs, spine order including `linear="no"`, TOC structure, namespaces, node identity and kinds, UTF-8 decoding as the reference does, XHTML-with-HTML-fallback parsing and the reference inert-content projection. |
| N3 | Implement CFI parsing, serialization, comparison and resolution with the pinned Foliate semantics (paths, indirection, escapes, text-chunk slots, UTF-16 offsets, ranges, element anchors). |
| N4 | Implement canonical text normalization v1 (code-point filter, FNV-1a64 signature, canonical↔UTF-16 mapping) with a generated, pinned Unicode table. |
| N5 | Prototype native layout with Flutter text and paint APIs: a documented CSS subset and style matrix, the reference reader-setting overrides, raster images, the SVG-wrapper fast path, general static SVG either rendered or surfaced as unsupported, and a page map carrying source ranges, candidate canonical intervals and image anchors. No content may be lost, duplicated or reordered. |
| N6 | Export a visible-page anchor with the reference policy and prove restoration: CFI → native page with round trip and foreground visibility, including after settings reflow. A failed proof keeps the previously accepted anchor. |
| N7 | Detect fixed-layout, vertical-writing and RTL publications before reading and explain them recoverably without changing any position. |
| N8 | Port the reference gesture, animation, input-queue, generation and turn-acceptance rules into a reader-local controller with prepared previous/current/next surfaces. No parsing, layout, decode, pagination or storage work runs in pointer or ticker callbacks. |
| N9 | Extend the diagnostic entry point with a reader feasibility mode: open bundled synthetic fixtures and user-placed EPUBs, run reproducible scripted scenarios and manual turns, capture bounded engine timing plus reader pipeline, layout-cost and cache/memory data, and export JSON that contains no book text. Provide an offline analyzer that recomputes every aggregate from raw samples. |
| N10 | Run the time-boxed presentation spike: native inventory (layer class, Metal-layer flag, Low Power Mode, thermal state, max FPS); layer-commit cadence on the product path; drawable `presentedTime` on a CAMetalLayer diagnostic variant. Label each result with its evidence level. |
| N11 | Produce a feasibility report with independent rows and a GO / NO-GO recommendation for S4. A failed gate returns to review with evidence; it never silently narrows scope, lowers the frame target or introduces a WebView. |

Dependency justification (candidates; the executor verifies versions and
compatibility, records the outcome here and in the approved-dependency table):
a pure-Dart ZIP reader (EPUB container), an XML parser (namespace-aware XHTML
and OPF), an HTML5 parser (reference HTML fallback), a CSS parser (packaged
styles), and a Flutter SVG renderer (non-wrapper static SVG). Node tooling
under `tool/oracle/` (foliate-js at the pinned tarball, fflate 0.8.2, a
bundler and Playwright) is development-only and never ships in the app.

### Phase A tooling selected

Exact development-only dependencies verified from the npm registry and installed
package metadata on 2026-10-22: `fflate 0.8.2` (MIT, matches the reference ZIP and
UTF-8 implementation), `foliate-js` commit
`78914aef4466eb960965702401634c2cb348e9b1` (MIT), `esbuild 0.28.2` (MIT, browser
bundle), and `playwright 1.64.1` (Apache-2.0, WebKit primary and Chromium
cross-check). The committed npm lockfile pins their integrity. No Dart runtime
dependency is added in Phase A. Full versions, provenance and transitive package
licences are in `tool/oracle/README.md`.

## Acceptance Criteria

- **NC1 (N1):** Running the oracle twice on a clean checkout yields
  byte-identical committed vectors. WebKit and Chromium versions are recorded;
  every cross-engine difference is listed with the engine treated as
  authoritative. Vendored reference files match `a4bda23` byte for byte.
- **NC2 (N2–N4):** Dart output equals the WebKit oracle vectors for every
  synthetic fixture: node projection, section bases, CFI parse/serialize
  round trips, comparison order, CFI → node/offset resolution, canonical
  length, signature and mappings. Native-generated CFIs fed back into the
  oracle resolve to the same node/offset. The four local books pass the same
  comparison locally. Any mismatch blocks the phase.
- **NC3 (N5, N7):** For every fixture and local book under the default and at
  least two non-default reader settings, the conservation check passes: the
  concatenated page text equals the eligible source text in order, every
  image/SVG appears exactly once or is listed as surfaced-unsupported, and no
  page clips a line or image. The style matrix and unsupported-layout fixtures
  have recorded outcomes (supported / supported-with-difference /
  surfaced-unsupported); nothing is dropped silently. Unsupported fixtures
  never open as an empty successful read.
- **NC4 (N6):** For every page of every fixture, the exported anchor resolves
  back to the same page with the anchor visible. Oracle-generated CFIs land on
  a page where the anchor is visible. After a font-size or line-height change,
  the accepted anchor stays visible; an injected proof failure keeps the
  previous anchor.
- **NC5 (N8):** Ported reference state-machine tests pass (axis lock, commit
  thresholds, rebound, tap zones, curve, settlement, late neighbor, FIFO 1+8
  with overflow, rebase, cancellation, stale callback rejection, exactly one
  accepted destination per committed input, reduced motion, static fallback
  accounting).
- **NC6 (N9):** The local quality gate passes, the ordinary entry point is
  unchanged in behavior, the analyzer reproduces the app's aggregates from
  fixture exports, and an export contains no book text.
- **NC7 (N9, N11):** On the iPhone, each S2 scenario in `design.md` §8 runs
  three times with limiters declared off, on the default build. Results are
  reported against the parent's proposed gate (≥99% of motion frames within
  8.333 ms for UI and, separately, raster; no unexplained ≥50 ms stall; P95
  warm admitted input → first motion submission ≤ 16.7 ms; zero correctness
  failures; bounded resource trend over ≥100 alternating turns). Cold
  preparation, queue wait and static-fallback rate are reported separately.
- **NC8 (N10):** The report states, per mode, whether native data arrived and
  what it shows, at its evidence level: engine timing, layer-commit cadence,
  or system drawable presentation on the non-default path. Missing data is
  "unverified", with the reason. No row claims touch-to-photon latency.
- **NC9 (N11):** `feasibility-report.md` records every NC row independently
  and gives a GO / NO-GO for S4 with the specific gaps S4 must close.

NC1–NC6 are local and the executor can complete them. NC7–NC9 need the user's
device runs after a confirmed push.

## Out of Scope

- NAS connection, API models, downloads and caching (S3).
- Persisting positions, the activity outbox, visibility sampling/idle rules,
  reading-time capture and any write to real reading history (S4). S2 keeps
  accepted anchors in memory only.
- Product reader chrome, settings sheets, TOC UI, image viewer and the rest of
  UI01–UI14 (S4–S6). Probe controls only.
- Rendering fixed-layout, vertical or RTL publications.
- Modifying or deploying lan-reader; patching the Flutter engine; paid tools;
  a Mac; a high-speed camera; WebView or JavaScript in the app.
- Changing the app identifier, signing route or product `Info.plist` keys.

## Status

Planning artifacts prepared on 2026-10-22: this PRD, `design.md`,
`implement.md`, `research/s2-entry-evidence.md` and the context manifests.
Phase 0 baseline and Phase A oracle tooling/fixtures are implemented locally.
Phase A gates pass: reproducible vectors, reference drift check, both-engine
synthetic/local-book comparisons and the full Flutter quality gate. Reader
runtime implementation has not started; no device run has happened.
