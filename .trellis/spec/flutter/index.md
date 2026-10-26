# Flutter App Guidelines

> Conventions for the `shiori` Flutter app (single package, Dart 3.13 / Flutter 3.47).

---

## Scope

This layer covers `lib/`, `test/`, `integration_test/`, dependency/analysis
configuration, reader fixtures and `tool/{oracle,reader,diag,ci}/`. Native
folders are largely Flutter-generated; `ios/Runner/AppDelegate.swift` also
owns the explicit diagnostic presentation channel. See Diagnostics before
changing that boundary.

The scaffold conventions coexist with S1 diagnostic storage/capture and S2's
implemented reader core. Reader data/engine models, local controller and
proof/navigation results have their own contracts; do not force them into
HTTP repositories or providers. Keep these specs aligned with actual code.

---

## Stack at a Glance

| Concern | Decision | Guide |
|---|---|---|
| Layout | Feature-first; reader adds reusable `data/` and `engine/` layers | [Directory Structure](./directory-structure.md) |
| State | Riverpod 3 + codegen for app state; reader-local numeric motion | [State Management](./state-management.md), [Reader Engine](./reader-engine.md) |
| Routing | `go_router` + `go_router_builder` typed routes | [Routing](./routing.md) |
| Data | Remote HTTP API via `dio`; models with `freezed` + `json_serializable` | [Data Layer](./data-layer.md) |
| Errors | Sealed `AppException`, mapped in `guardDio`, surfaced via `AsyncValue` | [Error Handling](./error-handling.md) |
| Logging | `package:logging` -> `dart:developer` | [Error Handling](./error-handling.md) |
| UI text | ARB + gen-l10n, template locale `zh` | [Widget Guidelines](./widget-guidelines.md) |
| Tests | Unit (repositories, controllers) + widget (key screens), `mocktail` | [Testing](./testing.md) |
| Reader | Pure Dart EPUB/CFI/canonical v1, native layout, proven anchors, bounded retained surfaces | [Reader Engine](./reader-engine.md) |
| Diagnostics | S1 synthetic and S2 reader records, independent analyzer, explicit evidence levels | [Diagnostics](./diagnostics.md) |

The scaffold task set all of this up: dependencies, `lib/app`, `lib/core`,
`lib/l10n`, test helpers, and a placeholder `features/home`. Feature tasks
start writing feature code directly. Current dependency versions, licences and
compatibility constraints are in [Quality Guidelines](./quality-guidelines.md).

---

## Pre-Development Checklist

Before writing code in this layer:

- [ ] Read [Directory Structure](./directory-structure.md) to place new files
- [ ] Read the guide matching the change (widgets, state, routing, data)
- [ ] Check `pubspec.yaml` before adding a dependency; prefer packages already in use
- [ ] If the change adds a screen, check [Routing](./routing.md)
- [ ] For reader core changes, read [Reader Engine](./reader-engine.md); for
  probe/export/native evidence, also read [Diagnostics](./diagnostics.md)

---

## Quality Check

Run before reporting a task complete:

```bash
dart run build_runner build
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

All must pass for code changes. Reader/tool changes extend the format scope to
`tool/reader tool/diag tool/ci` and require relevant vector/export parity checks.
Documentation-only spec updates use source/path/diff review without rerunning
code generation, formatting, analysis or tests. See the Definition of Done in
[Quality Guidelines](./quality-guidelines.md).

---

## Guidelines Index

| Guide | Description | Status |
|-------|-------------|--------|
| [Directory Structure](./directory-structure.md) | Reader data/engine layers, probe/tool layout, fixture/private evidence locations and import boundaries | Filled |
| [Reader Engine](./reader-engine.md) | EPUB projection, CFI/UTF-16 and canonical v1, native layout/conservation, anchor proof/reflow, motion and surface ownership | Filled (S2; product persistence/activity deferred) |
| [Widget Guidelines](./widget-guidelines.md) | Widget types, composition, theming, localization, accessibility | Filled |
| [State Management](./state-management.md) | Provider kinds, `ref` rules, mutations, retry | Filled |
| [Routing](./routing.md) | Typed routes, router provider, navigation | Filled |
| [Data Layer](./data-layer.md) | Models, JSON config, repositories, Dio and env config | Filled (auth, API casing TBD) |
| [Error Handling](./error-handling.md) | `AppException`, `guardDio`, UI error display, logging | Filled |
| [Testing](./testing.md) | Unit/widget helpers, oracle and export regeneration, private-input switches, injected clocks/frames and host-evidence limits | Filled |
| [Quality Guidelines](./quality-guidelines.md) | Resolved dependency/licence tables, pins, fixture/privacy guard, product asset carry-forward and build quality gates | Filled |
| [Diagnostics](./diagnostics.md) | S1 and reader-feasibility schemas, correctness/resources, presentation channel/evidence levels and independent analyzer | Filled (native/device results pending) |

---

**Language**: All documentation should be written in **English**.
