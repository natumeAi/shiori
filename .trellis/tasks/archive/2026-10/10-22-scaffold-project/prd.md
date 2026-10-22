# Scaffold Flutter project per spec

## Goal

Make the codebase match `.trellis/spec/flutter/` so the first feature task can
write feature code directly, without first setting up dependencies, app wiring,
error handling, logging, localization, or test helpers.

## Requirements

- **R1 Dependencies**: add every package in the "Approved Dependencies" table of
  `quality-guidelines.md` (runtime + dev) and set `flutter: generate: true` in
  `pubspec.yaml`. Let pub pick the latest mutually compatible versions.
- **R2 Project config**:
  - `analysis_options.yaml`: keep `flutter_lints` and the existing native-folder
    excludes; add the generated-file excludes and the three extra lint rules from
    `quality-guidelines.md`.
  - `build.yaml`: json_serializable `checked: true`, `explicit_to_json: true`.
  - `l10n.yaml`: exactly as in `widget-guidelines.md`.
  - `config/dev.json`: `{"API_BASE_URL": "https://api.example.com"}`
    (dev server given by the developer; no trailing slash because repository
    paths start with `/`).
- **R3 `lib/app/`**: `app.dart` (`ShioriApp`, `MaterialApp.router`), `routes.dart`,
  `router.dart` (`routerProvider`), `theme.dart` (`AppTheme.light` / `.dark`).
- **R4 `lib/core/`**: `config/env.dart`, `errors/app_exception.dart`,
  `errors/error_messages.dart`, `logging/logging.dart`, `network/dio_provider.dart`,
  `network/guard_dio.dart`, `network/retry_policy.dart`, `widgets/error_view.dart`.
- **R5 `lib/l10n/`**: `app_zh.arb` (template) with the keys the scaffold uses,
  `l10n.dart` (export + `context.l10n`), generated `app_localizations*.dart`.
- **R6 Placeholder home**: `lib/features/home/presentation/home_screen.dart`
  routed at `/` via `HomeRoute`, showing a localized title and welcome text.
  No repository, no API call.
- **R7 `lib/main.dart`**: only `setupLogging()` and
  `runApp(ProviderScope(retry: retryNetworkErrors, child: ShioriApp()))`.
  All template counter code removed.
- **R8 Tests**: delete `test/widget_test.dart`; add `test/helpers/pump_app.dart`,
  `test/helpers/mocks.dart`, and tests for `guardDio` (every mapping branch),
  `retryNetworkErrors`, `errorMessage` (every branch), `HomeScreen`, and an app
  smoke test that pumps `ShioriApp` and finds the home title.

## Out of Scope

Real features, authentication, actual API endpoints, native platform folders,
`riverpod_lint`, CI, locales other than `zh`.

## Acceptance Criteria

- [x] `dart run build_runner build` succeeds, and a second run produces no changes
- [x] `dart format --set-exit-if-changed lib test` passes
- [x] `flutter analyze` reports no issues
- [x] `flutter test` passes
- [x] No template leftovers (`MyHomePage`, `_counter`, `Flutter Demo`) remain
- [x] Every file listed in `directory-structure.md` for `app/`, `core/`, `l10n/` exists
- [x] If an API turned out different from what the spec shows (package
      versions, generated names, syntax), the spec is corrected in this task

## Notes

- The dev API is plain HTTP. Android (cleartext), iOS (ATS), and macOS
  (network client entitlement) block or restrict it by default. The scaffold
  makes no requests, so platform config is left to the first task that calls
  the API; this is recorded in data-layer.md "Not Decided Yet".
- Plan reviewed and approved by the developer on 2026-10-22.
