# Flutter App Guidelines

> Conventions for the `shiori` Flutter app (single package, Dart 3.13 / Flutter 3.47).

---

## Scope

This layer covers everything under `lib/`, `test/`, `integration_test/`,
plus `pubspec.yaml` and `analysis_options.yaml`. Native platform folders
(`android/`, `ios/`, `web/`, `windows/`, `macos/`, `linux/`) are generated
by Flutter and are only touched when a plugin's setup requires it.

The codebase was still the `flutter create` template when these guidelines
were written, so most rules below are **agreed decisions**, not patterns
extracted from existing code. When real code diverges, update the spec in
the same task.

---

## Stack at a Glance

| Concern | Decision | Guide |
|---|---|---|
| Layout | Feature-first: `lib/{app,core,features/<feature>/{data,presentation},l10n}` | [Directory Structure](./directory-structure.md) |
| State | Riverpod 3 + `riverpod_generator` | [State Management](./state-management.md) |
| Routing | `go_router` + `go_router_builder` typed routes | [Routing](./routing.md) |
| Data | Remote HTTP API via `dio`; models with `freezed` + `json_serializable` | [Data Layer](./data-layer.md) |
| Errors | Sealed `AppException`, mapped in `guardDio`, surfaced via `AsyncValue` | [Error Handling](./error-handling.md) |
| Logging | `package:logging` -> `dart:developer` | [Error Handling](./error-handling.md) |
| UI text | ARB + gen-l10n, template locale `zh` | [Widget Guidelines](./widget-guidelines.md) |
| Tests | Unit (repositories, controllers) + widget (key screens), `mocktail` | [Testing](./testing.md) |

The scaffold task set all of this up: dependencies, `lib/app`, `lib/core`,
`lib/l10n`, test helpers, and a placeholder `features/home`. Feature tasks
start writing feature code directly. Two packages are held below their latest
version; see "Version Pins" in [Quality Guidelines](./quality-guidelines.md).

---

## Pre-Development Checklist

Before writing code in this layer:

- [ ] Read [Directory Structure](./directory-structure.md) to place new files
- [ ] Read the guide matching the change (widgets, state, routing, data)
- [ ] Check `pubspec.yaml` before adding a dependency; prefer packages already in use
- [ ] If the change adds a screen, check [Routing](./routing.md)

---

## Quality Check

Run before reporting a task complete:

```bash
dart run build_runner build
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

All must pass with zero issues. Full list in the Definition of Done in
[Quality Guidelines](./quality-guidelines.md).

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | `lib/` layout, file naming, import boundaries | Filled |
| [Widget Guidelines](./widget-guidelines.md) | Widget types, composition, theming, localization, accessibility | Filled |
| [State Management](./state-management.md) | Provider kinds, `ref` rules, mutations, retry | Filled |
| [Routing](./routing.md) | Typed routes, router provider, navigation | Filled |
| [Data Layer](./data-layer.md) | Models, JSON config, repositories, Dio and env config | Filled (auth, API casing TBD) |
| [Error Handling](./error-handling.md) | `AppException`, `guardDio`, UI error display, logging | Filled |
| [Testing](./testing.md) | Required tests, mocks, container and widget test helpers | Filled |
| [Quality Guidelines](./quality-guidelines.md) | Dependencies, lints, formatting, codegen, forbidden patterns, definition of done | Filled |

---

**Language**: All documentation should be written in **English**.
