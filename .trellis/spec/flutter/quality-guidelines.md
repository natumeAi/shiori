---
name: flutter-quality-guidelines
description: Approved dependencies, lints, formatting, code generation, Dart language usage, forbidden patterns
paths:
  - pubspec.yaml
  - analysis_options.yaml
  - build.yaml
  - l10n.yaml
---

# Quality Guidelines

> `dart format` + `flutter analyze` + `flutter test` must be clean before
> any task is reported done.

---

## Approved Dependencies

Snapshot verified against `pubspec.yaml`, `pubspec.lock` and the resolved
packages' cached `LICENSE` files through S3 Phase A. Hosted direct constraints are `^`
the resolved version shown here; SDK packages use `sdk: flutter`. Update this
table with the lockfile when changing dependencies; this is not a latest-version
claim. The SDK pin is Flutter 3.47.7 / Dart 3.13.5.

| Package | Resolved version | Licence | Reason / boundary |
| --- | --- | --- | --- |
| `flutter`, `flutter_localizations` | SDK (lockfile `0.0.0`) | BSD-3-Clause | Widgets/engine and SDK localization delegates |
| `flutter_riverpod` | 3.4.3 | MIT | App/provider state; excluded from reader core |
| `riverpod_annotation` | 4.0.7 | MIT | Generated provider declarations |
| `go_router` | 17.5.0 | BSD-3-Clause | Product routing (pin below) |
| `dio` | 5.11.1 | MIT | HTTP transport, outside the offline reader core |
| `freezed_annotation` | 3.1.0 | MIT | Immutable API/diagnostic records |
| `json_annotation` | 4.12.0 | BSD-3-Clause | Checked JSON model boundary |
| `logging` | 1.3.0 | BSD-3-Clause | Structured application logging |
| `intl` | 0.20.3 | BSD-3-Clause | Localization |
| `path_provider` | 2.1.6 | BSD-3-Clause | Injectable Application Support/Documents directories |
| `sqlite3` | 3.8.0 | MIT | Isolated diagnostic SQLite self-check; product storage and iPhone packaging proof remain pending |
| `crypto` | 3.0.7 | BSD-3-Clause | SHA-256 for streamed publication bytes |
| `archive` | 4.5.2 | MIT | EPUB ZIP access via app-owned raw-directory index with metadata bounds, last-wins duplicates, exact length/CRC-32 checks, bounded native decode and file-backed open |
| `xml` | 7.0.1 | MIT | XHTML/HTML4 entity table only; strict XML parser is project code |
| `html` | 0.15.7 | MIT | HTML5 tree builder for HTML media and XHTML fallback |
| `csslib` | 1.0.2 | BSD-3-Clause | CSS parsing; cascade/reader overrides are project code |
| `flutter_svg` | 2.3.0 | MIT | Static SVG compiled to `ui.Picture` during preparation; partial constructs surfaced |
| `flutter_test` (dev) | SDK (lockfile `0.0.0`) | BSD-3-Clause | Unit/widget test engine |
| `flutter_lints` (dev) | 6.0.0 | BSD-3-Clause | Analysis baseline |
| `build_runner` (dev) | 2.16.2 | BSD-3-Clause | Generated source orchestration |
| `riverpod_generator` (dev) | 4.0.9 | MIT | Provider generation |
| `go_router_builder` (dev) | 4.5.2 | BSD-3-Clause | Typed route generation |
| `freezed` (dev) | 4.0.3 | MIT | Immutable record/union generation |
| `json_serializable` (dev) | 6.15.2 | BSD-3-Clause | Checked JSON encoding/decoding generation |
| `mocktail` (dev) | 1.0.5 | MIT | Test doubles |

Reader-related resolved transitives (not new direct imports):

| Package | Version | Licence | Reason |
| --- | --- | --- | --- |
| `vector_graphics` | 1.2.4 | BSD-3-Clause | SVG picture decoding/rendering |
| `vector_graphics_compiler` | 1.3.2 | BSD-3-Clause | SVG compilation; owns the audited XML upper bound |
| `vector_graphics_codec` | 1.1.13 | BSD-3-Clause | Vector binary format |
| `path_parsing` | 1.1.0 | MIT | SVG path parsing |
| `http` | 1.6.0 | BSD-3-Clause | SVG package loader dependency; not permission to fetch remote book resources |
| `petitparser` | 7.1.0 | MIT | XML package parser support |
| `posix` | 6.5.2 | MIT | Archive package platform support |
| `meta` | 1.19.0 | BSD-3-Clause | Shared annotations (updated in S2) |

`flutter_svg` and `path_parsing` are MIT, unlike the BSD-3-Clause
`vector_graphics` family; the S2 PRD's SVG licence row grouped them incorrectly.
Use resolved package licences when the planning notes disagree.

`tool/oracle/` is development-only Node tooling and never ships in the app.
Its exact versions/integrities are in `package.json` / `package-lock.json`:

| Package | Exact version / revision | Licence | Reason |
| --- | --- | --- | --- |
| `foliate-js` | `78914aef4466eb960965702401634c2cb348e9b1` (package `0.0.0`) | MIT | Browser reference EPUB/CFI behavior |
| `fflate` | 0.8.2 | MIT | Reference ZIP/UTF-8 and deterministic synthetic EPUBs |
| `esbuild` | 0.28.2 | MIT | Browser TypeScript bundle |
| `playwright` | 1.64.1 | Apache-2.0 | WebKit authority / Chromium cross-check |
| `playwright-core` (transitive) | 1.64.1 | Apache-2.0 | Browser transport |
| `@esbuild/*` (optional host binaries) | 0.28.2 | MIT | Host bundler executable |

Vendored owner-authorized lan-reader files have provenance but no declared
repository licence; do not label them MIT by association with Foliate.
Fixture Roboto attribution/licence is retained under
`tool/oracle/fixtures/styles/` (Apache-2.0). See `tool/oracle/README.md`.

Add packages with `flutter pub add <pkg>` / `flutter pub add dev:<pkg>`.
Anything outside this table needs a reason in the task's `prd.md` and a
row added here.

### Version Pins

These compatibility constraints are deliberate; re-check them when upgrading:

| Package | Held at | Why |
|---|---|---|
| `go_router` | `^17.5.0` (18.x exists) | go_router 18 moved to the standalone `package:material_ui`; it only recognizes `material_ui`'s `MaterialApp` and otherwise silently falls back to `NoTransitionPage` (no page transitions). The app, the `flutter create` template, gen-l10n output (`GlobalMaterialLocalizations` from `flutter_localizations`), and `flutter_test` finders (`find.byTooltip`) all still use the SDK's `package:flutter/material.dart`. go_router_builder 4.5.x is itself tested against `go_router ^17.3.0`. Upgrade together with a `material_ui` migration task. |
| `build_runner` | `2.16.x` (2.17 exists) | build_runner 2.17 needs `build ^5`; go_router_builder 4.5.x allows only `build <5`. Resolved by pub, not pinned in `pubspec.yaml`. |
| `xml` | `^7.0.1`, resolved 7.0.1 | The resolved `vector_graphics_compiler` 1.3.2 declares `>=6.3.0 <=7.0.1`; preserve this SVG-stack compatibility rather than assuming a bound on every historical SVG release. |

### Material Library

Import Material from the SDK: `package:flutter/material.dart`. Do not import
`package:material_ui/material_ui.dart` or `package:cupertino_ui/...`; mixing
them with the SDK library gives two incompatible `Theme` / `MaterialApp` /
`MaterialLocalizations` types. Moving to `material_ui` is a separate task
(see the `go_router` pin above).

---

## Lints and Analysis

Baseline is `package:flutter_lints/flutter.yaml`. `analysis_options.yaml`
excludes the native platform folders and generated files, and adds these
rules on top:

```yaml
analyzer:
  exclude:
    - build/**                # plus android/ ios/ web/ windows/ macos/ linux/
    - "**/*.g.dart"
    - "**/*.freezed.dart"

linter:
  rules:
    - always_use_package_imports
    - prefer_single_quotes
    - unawaited_futures
```

Do not silence a lint with `// ignore:` unless the line has a comment
explaining why; never use `// ignore_for_file:` in hand-written code.

---

## Formatting

- `dart format` with default settings (tall style, 80 columns). The
  formatter manages trailing commas; do not fight it.
- Run `dart format lib test` before finishing. CI-style check:
  `dart format --set-exit-if-changed lib test`.

---

## Code Generation

- Run `dart run build_runner build` after changing any `@riverpod`,
  `@freezed`, `@JsonSerializable`, or `@TypedGoRoute` code. Use
  `dart run build_runner watch` while iterating.
- gen-l10n runs automatically on `flutter pub get` / `flutter run` /
  `flutter test`; run `flutter gen-l10n` to force it.
- Generated files are committed. Never edit them; change the source and regenerate.
- A task is not done if `build_runner` output is stale (analyze will usually
  show missing `_$` members).

---

## Dart Language Usage

The project targets Dart 3.13; use modern syntax where it reads better:

- Dot shorthands when the type is clear from context (as the template does):
  `mainAxisAlignment: .center`, `colorScheme: .fromSeed(...)`.
- `switch` expressions and patterns over `if`/`else` chains, especially for
  sealed types (`AppException`, freezed unions, `AsyncValue`).
- `sealed` / `final` class modifiers for closed hierarchies;
  `abstract final class` for static-only holders (`Env`, `AppTheme`).
- Wildcard `_` for unused parameters: `(_, _) => null`.
- Records for small multi-value returns inside a file; use a freezed class
  if the value crosses a file boundary.

---

## Forbidden Patterns

| Pattern | Use instead |
|---|---|
| `dynamic`, `Map<String, dynamic>` | `Object?`, `Map<String, Object?>` |
| `!` on a value that can legitimately be null | handle the null case; `!` only where null is impossible or is a parse error inside `guardDio` |
| `print` / `debugPrint` | `Logger` (see error-handling.md) |
| Relative imports (`../`) | `package:shiori/...` (only exception: test files import `test/helpers/` relatively, e.g. `../../helpers/pump_app.dart`, because `test/` has no `package:` URI) |
| Hardcoded UI strings / colors | `context.l10n`, `Theme.of(context)` |
| `Navigator.push` / string routes | typed routes (see routing.md) |
| Hand-written or legacy Riverpod providers | `@riverpod` codegen |
| `BuildContext` used after `await` without `context.mounted` check | check `context.mounted` first |
| Unawaited futures | `await`, or `unawaited(...)` with a comment |
| Commented-out code, `TODO` without a task reference | delete it / `TODO(task-slug): ...` |

---

## Definition of Done

1. `dart run build_runner build` produces no changes.
2. `dart format --set-exit-if-changed lib test` passes.
3. `flutter analyze` reports no issues.
4. `flutter test` passes, including the new tests required by [Testing](./testing.md).
5. New UI strings exist in every `lib/l10n/app_*.arb`.

For reader/tool code, include `tool/reader tool/diag tool/ci` in the format
check and maintain oracle/export regeneration parity as described in
[Testing](./testing.md). A documentation-only spec pass uses source/path/diff
checks; it does not require code generation, formatting, analysis or test runs.

## Reader Fixture and Privacy Guard

`dart run tool/ci/check_reader_fixtures.dart` runs before the CI Flutter build,
after enforced-lockfile resolution. It enumerates Git tracked and nonignored
untracked files using NUL delimiters, including tracked files matching ignore
rules. Existing EPUBs outside `assets/reader_fixtures/` fail except the two exact
hashed Phase B fixtures `edge-html.epub` and `edge-xhtml.epub` in
`test/fixtures/reader/source_edge/`. That folder is not a general exemption.
This exact two-file exception extends design §10's assets-only guard wording;
the implementation validates both payloads against their separate manifest.

- Asset and source-edge `manifest.json` files use `fixtureSchemaVersion: 1`
  and `fixtures` entries with `file`, `bytes`, `sha256`. Missing/malformed
  manifests, duplicates, extra/missing payloads and byte/hash drift fail.
- Payloads must be regular files. Asset metadata `manifest.json` and
  `.gitattributes` are excluded from the payload set. Guard errors report
  counts/classes, never discovered private book names or contents.
- Keep user EPUBs, their text/titles/filenames, private oracle vectors, NAS
  addresses and secrets out of committed artifacts. `build/oracle-local/`
  may contain full private text; `local-evidence/` holds personal device exports.
  Both are ignored. Do not promote their contents into task `evidence/`.
- S4 carry-forward: shared `pubspec.yaml` currently registers
  `assets/reader_fixtures/`, so product builds also carry the synthetic EPUBs.
  Separate/remove diagnostic fixture assets before a product build; merely
  selecting `lib/main.dart` does not exclude shared assets.

S3 Phase A added bounded ZIP directory admission, emitted-byte limits and a
worker-isolate protocol prototype. Before downloaded books are opened, S3
Phase D must still integrate the worker with the preloaded source/resource
adapter, cache/lease accounting and near-limit worker memory evidence. See
[Reader Engine](./reader-engine.md) for archive guarantees and font/session
resource limits.

## Unsigned iPhone CI and build identity

- Workflow: `.github/workflows/ios-unsigned.yml`; build/package command:
  `bash tool/ci/build_ios_unsigned.sh`. Only dispatch and `ios-build/**` push
  triggers; read-only contents permission, per-ref concurrency, 14-day artifacts.
- Use an explicit standard macOS label, selected Xcode path and SHA-pinned
  setup action. Current choice: `macos-15`, Xcode `26.3`, Flutter `3.47.7`
  stable. Re-verify against official runner-images docs before changing pins.
  No Apple signing credentials belong in CI. Keep setup-action caches disabled
  unless their nested actions are reviewed and pinned too.
- Require framework `abaf9c523780a608bd46686fd5e53740a07077f8` and engine
  `deb287481e3ce9468f3434937ced4240a70539ca`. A mismatch fails before build.
  Resolve the committed lockfile with `flutter pub get --enforce-lockfile`.
- `BUILD_NUMBER` is the positive CI run number and becomes `CFBundleVersion`.
  `BUILD_ID` is `<12-character commit>-<host>-<run number>` (`host=gha` here).
  Supply both as `--dart-define`s to the probe build; do not pass SDK,
  framework or engine defines: the Flutter tool injects `FLUTTER_VERSION` and
  the revisions itself and rejects them as defines (`diagnostics.md` §3,
  `tool/ci/build_ios_unsigned.sh`). Keep the
  fixed source identifier `io.github.natumeai.shiori` across probe/product
  builds. A new workflow/counter must not regress the installed build number.
- Validate iphoneos, bundle identifier/version, arm64 executable and both
  Flutter/App framework binaries before packaging `Payload/Runner.app` into
  `shiori-probe-<BUILD_ID>.ipa`. S2 also stages
  `shiori-probe-<BUILD_ID>-cametal.ipa` from the same single build: only the
  alternate copy receives `FLTUseFlutterMetalLayer=false`. Validate both
  bundles, preserve the source/default plist bytes, and record each variant's
  actual/effective flag and SHA-256 in provenance plus `sha256.txt`.
  Save native status/diff.
  Save newly generated, nonignored iOS file contents in `ios-untracked.zip`;
  status/diff alone cannot recover them after the hosted runner is removed.
  A source push and device signing are separate user-operated review boundaries.
- Windows validation is **only** `bash -n tool/ci/build_ios_unsigned.sh` using
  Git Bash. `plutil`, `lipo`, hosted compilation, signing and device behavior
  remain unverified until exercised on their actual platforms.
