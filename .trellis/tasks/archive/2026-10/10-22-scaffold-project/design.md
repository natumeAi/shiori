# Design: Scaffold Flutter project

The architecture is already defined in `.trellis/spec/flutter/`. This file
only records decisions specific to the scaffold that the spec leaves open.

## File Map

| File | Source of truth in spec |
|---|---|
| `lib/main.dart` | directory-structure.md, error-handling.md (Logging) |
| `lib/app/app.dart` | routing.md (Files), widget-guidelines.md (Localization) |
| `lib/app/routes.dart`, `lib/app/router.dart` | routing.md |
| `lib/app/theme.dart` | widget-guidelines.md (Theming); seed color `Colors.deepPurple` carried over from the template |
| `lib/core/config/env.dart` | data-layer.md (Dio and Config) |
| `lib/core/network/dio_provider.dart`, `guard_dio.dart` | data-layer.md, error-handling.md |
| `lib/core/network/retry_policy.dart` | state-management.md (Retry) |
| `lib/core/errors/*.dart` | error-handling.md |
| `lib/core/logging/logging.dart` | error-handling.md (Logging) |
| `lib/core/widgets/error_view.dart` | error-handling.md (Showing Errors) |
| `lib/l10n/*` | widget-guidelines.md (Localization) |
| `test/**` | testing.md |

## Scaffold-Specific Decisions

**Retry policy** (`retry_policy.dart`):

```dart
Duration? retryNetworkErrors(int retryCount, Object error) {
  if (retryCount >= 3 || error is! NetworkException) return null;
  return Duration(milliseconds: 200 * (1 << retryCount));
}
```

Changed during implementation: the original draft unwrapped `ProviderException`
before the check. Riverpod's own default policy never retries
`ProviderException` (the failing dependency retries itself; dependents rebuild
when it recovers), so unwrapping would retry every provider in the chain.
Recorded in state-management.md "Retry".

**ErrorView** (`core/widgets/error_view.dart`): `ErrorView({required Object error,
VoidCallback? onRetry})`. Centered icon + `errorMessage(context, error)` text +
`FilledButton` labelled `l10n.commonRetry` when `onRetry` is non-null.

**ARB keys** in `app_zh.arb`: `appTitle`, `homeTitle`, `homeWelcome`,
`commonRetry`, `errorNetwork`, `errorUnauthorized`, `errorServer`,
`errorUnexpected`. Each has an `@key` description.

**Home placeholder**: `HomeScreen` is a `StatelessWidget` (it reads no
providers yet) with `Scaffold` + `AppBar(title: l10n.homeTitle)` + centered
`l10n.homeWelcome`. It exists only so routing, theme, and l10n are exercised;
the first real feature replaces or extends it.

**`ShioriApp`** is a `ConsumerWidget` (watches `routerProvider`), uses
`onGenerateTitle` with `l10n.appTitle`, `theme`/`darkTheme` from `AppTheme`.

**Generated files** are committed (quality-guidelines.md), so `flutter analyze`
works on a fresh checkout after `flutter pub get`.

## Risks

- **Codegen version conflicts** (freezed / riverpod_generator / go_router_builder /
  json_serializable share `analyzer` / `source_gen`). Mitigation: add all
  packages in one `flutter pub add` call so pub solves them together; if it
  cannot, drop to the newest compatible versions and note the pin in
  quality-guidelines.md.
- **Spec examples not matching real APIs** (e.g. `ProviderException.exception`,
  `ProviderScope` being `const`). Mitigation: the analyzer is the referee;
  fix the code and the spec together.

## Rollback

There are no commits yet; the template versions of `pubspec.yaml`,
`analysis_options.yaml`, `lib/main.dart`, and `test/widget_test.dart` are in
the git index. `git checkout -- <file>` restores them, and new files/dirs can
simply be deleted.
