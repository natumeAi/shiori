# Implement: Scaffold Flutter project

Ordered checklist. Run the validation in each step before moving on.

## 1. Dependencies and config

- [ ] `flutter pub add flutter_localizations --sdk=flutter`
- [ ] `flutter pub add flutter_riverpod riverpod_annotation go_router dio freezed_annotation json_annotation logging intl`
- [ ] `flutter pub add dev:build_runner dev:riverpod_generator dev:go_router_builder dev:freezed dev:json_serializable dev:mocktail`
- [ ] Add `generate: true` under `flutter:` in `pubspec.yaml`
- [ ] Update `analysis_options.yaml`, create `build.yaml`, `l10n.yaml`, `config/dev.json`

Validate: `flutter pub get` succeeds.

## 2. Localization

- [ ] `lib/l10n/app_zh.arb` with the keys from design.md
- [ ] `lib/l10n/l10n.dart`
- [ ] `flutter gen-l10n`

Validate: `lib/l10n/app_localizations.dart` and `app_localizations_zh.dart` exist.

## 3. Core

- [ ] `core/config/env.dart`
- [ ] `core/errors/app_exception.dart`, `core/errors/error_messages.dart`
- [ ] `core/logging/logging.dart`
- [ ] `core/network/dio_provider.dart`, `guard_dio.dart`, `retry_policy.dart`
- [ ] `core/widgets/error_view.dart`

## 4. App and home

- [ ] `app/theme.dart`, `app/routes.dart`, `app/router.dart`, `app/app.dart`
- [ ] `features/home/presentation/home_screen.dart`
- [ ] Replace `lib/main.dart`

Validate: `dart run build_runner build` succeeds; `flutter analyze` is clean.

## 5. Tests

- [ ] Delete `test/widget_test.dart`
- [ ] `test/helpers/pump_app.dart`, `test/helpers/mocks.dart`
- [ ] `test/core/network/guard_dio_test.dart`
- [ ] `test/core/network/retry_policy_test.dart`
- [ ] `test/core/errors/error_messages_test.dart`
- [ ] `test/features/home/presentation/home_screen_test.dart`
- [ ] `test/app/app_test.dart`

Validate: `flutter test` passes.

## 6. Final gate (quality-guidelines.md Definition of Done)

```bash
dart run build_runner build
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

- [ ] Second `build_runner build` run produces no file changes
- [ ] `grep -r "MyHomePage\|_counter\|Flutter Demo" lib test` finds nothing
- [ ] Any spec example that did not compile as written is fixed in `.trellis/spec/flutter/`

## Rollback points

After each step the previous state is recoverable: template files via
`git checkout -- <file>` (they are in the index), new files by deletion.
