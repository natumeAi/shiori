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

| Purpose | Packages |
|---|---|
| State | `flutter_riverpod`, `riverpod_annotation` (dev: `riverpod_generator`) |
| Routing | `go_router` (dev: `go_router_builder`) |
| HTTP | `dio` |
| Models | `freezed_annotation`, `json_annotation` (dev: `freezed`, `json_serializable`) |
| Localization | `flutter_localizations` (sdk), `intl` |
| Logging | `logging` |
| App directories | `path_provider` (Application Support for private probe state; Documents for user exports) |
| EPUB source (reader `data/` layer, pure Dart) | `archive` 4.5.2 (ZIP container, MIT); `html` 0.15.7 (HTML5 tree builder for the reference HTML fallback, MIT); `xml` 7.1.0 (HTML4/XHTML entity table only, MIT; the strict XML parser is project code) |
| Codegen | dev: `build_runner` |
| Testing | dev: `flutter_test` (sdk), `mocktail` |

Add packages with `flutter pub add <pkg>` / `flutter pub add dev:<pkg>`.
Anything outside this table needs a reason in the task's `prd.md` and a
row added here.

### Version Pins

Every other package in the table above resolves to its latest version. These
are held back on purpose; re-check them when upgrading:

| Package | Held at | Why |
|---|---|---|
| `go_router` | `^17.5.0` (18.x exists) | go_router 18 moved to the standalone `package:material_ui`; it only recognizes `material_ui`'s `MaterialApp` and otherwise silently falls back to `NoTransitionPage` (no page transitions). The app, the `flutter create` template, gen-l10n output (`GlobalMaterialLocalizations` from `flutter_localizations`), and `flutter_test` finders (`find.byTooltip`) all still use the SDK's `package:flutter/material.dart`. go_router_builder 4.5.x is itself tested against `go_router ^17.3.0`. Upgrade together with a `material_ui` migration task. |
| `build_runner` | `2.16.x` (2.17 exists) | build_runner 2.17 needs `build ^5`; go_router_builder 4.5.x allows only `build <5`. Resolved by pub, not pinned in `pubspec.yaml`. |

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
  Supply both, plus SDK/framework/engine defines, to the probe build. Keep the
  fixed source identifier `io.github.natumeai.shiori` across probe/product
  builds. A new workflow/counter must not regress the installed build number.
- Validate iphoneos, bundle identifier/version, arm64 executable and both
  Flutter/App framework binaries before packaging `Payload/Runner.app` into
  `shiori-probe-<BUILD_ID>.ipa`. Save provenance, checksum and native status/diff.
  Save newly generated, nonignored iOS file contents in `ios-untracked.zip`;
  status/diff alone cannot recover them after the hosted runner is removed.
  A source push and device signing are separate user-operated review boundaries.
- Windows validation is **only** `bash -n tool/ci/build_ios_unsigned.sh` using
  Git Bash. `plutil`, `lipo`, hosted compilation, signing and device behavior
  remain unverified until exercised on their actual platforms.
