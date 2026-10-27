---
name: flutter-widget-guidelines
description: Screen and widget structure, theming, localization with gen-l10n, accessibility
paths:
  - lib/features/*/presentation/**
  - lib/core/widgets/**
  - lib/app/app.dart
  - lib/app/theme.dart
  - lib/l10n/**
  - l10n.yaml
---

# Widget Guidelines

> Material 3, small composable widget classes, every visible string from
> ARB files, every color and text style from the theme.

---

## Choosing the Widget Type

| Widget needs... | Use |
|---|---|
| Providers (screens, widgets that read state) | `ConsumerWidget` |
| Providers + controllers to dispose (`TextEditingController`, `AnimationController`, `ScrollController`, `FocusNode`) | `ConsumerStatefulWidget` |
| Only constructor data | `StatelessWidget` |
| Only local ephemeral state, no providers | `StatefulWidget` |

Leaf widgets take plain data through their constructor instead of reading
providers. This keeps them reusable and testable without a `ProviderScope`.

---

## Screen Shape

```dart
// lib/features/bookmarks/presentation/bookmark_list_screen.dart
class BookmarkListScreen extends ConsumerWidget {
  const BookmarkListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarkListControllerProvider);
    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.bookmarksTitle)),
      body: bookmarks.when(
        data: (items) => items.isEmpty
            ? const _EmptyState()
            : BookmarkListView(bookmarks: items),
        error: (error, _) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(bookmarkListControllerProvider),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
```

- Every screen handles all three `AsyncValue` states. `when` keeps showing the
  previous data while refreshing.
- Screens own the `Scaffold`; widgets under `widgets/` never create one.

---

## Composition Rules

- Extract a sub-tree into a widget **class** (private `_Name` if file-local),
  not a `Widget _buildHeader()` method. Classes get their own element, rebuild
  independently, and can be `const`.
- Add `const` constructors with `super.key` to every widget; instantiate with
  `const` wherever possible.
- Space children with `Column(spacing: 8, ...)` / `Row(spacing: ...)`, not
  interleaved `SizedBox`es.
- No side effects in `build` (no fetching, no navigation, no `setState`).
  React to state changes with `ref.listen`.
- After any `await` in a callback, check `if (!context.mounted) return;`
  before using `context`.

---

## Theming

- `lib/app/theme.dart` defines `AppTheme.light` / `AppTheme.dark` from one
  seed color with `ColorScheme.fromSeed`. Material 3 only.
- Widgets read `Theme.of(context).colorScheme.*` and `Theme.of(context).textTheme.*`.
- Hardcoded `Colors.*`, `Color(0x...)`, and inline `TextStyle(fontSize: ...)`
  are only allowed in `theme.dart`. Adjust a theme style with
  `textTheme.titleMedium?.copyWith(...)` when needed.

---

## Localization

Setup (`l10n.yaml` at project root, `flutter: generate: true` in pubspec):

```yaml
arb-dir: lib/l10n
template-arb-file: app_zh.arb
output-localization-file: app_localizations.dart
nullable-getter: false
```

Generated files land in `lib/l10n/` (gen-l10n no longer uses a synthetic
package). `lib/l10n/l10n.dart` re-exports them and adds the accessor:

```dart
import 'package:flutter/widgets.dart';
import 'package:shiori/l10n/app_localizations.dart';

export 'package:shiori/l10n/app_localizations.dart';

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
```

`MaterialApp.router` uses `AppLocalizations.localizationsDelegates` and
`AppLocalizations.supportedLocales`.

Rules:

- Every user-visible string goes through `context.l10n`. This includes
  tooltips, semantics labels, snackbars, and dialog buttons.
- `app_zh.arb` is the template; add the key there first, then to every other
  `app_<locale>.arb`.
- Keys are lowerCamelCase, prefixed by feature: `bookmarksTitle`,
  `bookmarksEmptyMessage`, `settingsThemeLabel`. Shared keys use `common*`
  (`commonRetry`), error messages use `error*` (`errorNetwork`).
- Use placeholders and ICU plurals for dynamic text, never string concatenation:

```json
"bookmarksCount": "{count, plural, =0{没有书签} other{{count} 个书签}}",
"@bookmarksCount": {
  "placeholders": { "count": { "type": "int" } }
}
```

---

## Accessibility

- `IconButton` always has a localized `tooltip`.
- Meaningful images/icons get `semanticLabel`; decorative ones are excluded
  (`excludeFromSemantics: true` / `ExcludeSemantics`).
- Tap targets are at least 48x48 (Material defaults already satisfy this;
  do not shrink them with `visualDensity` or tight `SizedBox`es).
- Never convey state with color alone; pair it with an icon or text.
- Layouts must survive 200% text scale: no fixed heights around text.

## Minimal server and library UI

- Keep endpoint form controllers local. Validate with `ServerEndpoint.parse`
  before calling activation, and localize every issue without sending traffic.
- Candidate feedback accompanies the selected server. Keep the selected
  address visible on failure; disable edits while validating/committing.
  Offer cancel during validation and block back navigation during commit.
- Abandoning a form cancels candidate work. Route disposal may happen during
  a widget build, so defer its provider notification to a microtask; controller
  cancellation must tolerate an already disposed provider.
- Use scrollable safe areas for setup and content. Book rows use an expanded
  text column rather than fixed tile heights, with session-owned covers and
  localized image semantics plus placeholders for missing/failed images.
- Render `LibrarySnapshotState.error` alongside retained content. Show a
  stale label whenever a cached snapshot is displayed; refresh/retry must keep
  that content visible until a fresh result arrives. Empty and missing-ID
  states are distinct from load errors.
- Product feedback maps typed failures to ordinary localized copy and never
  displays raw exceptions. Network evidence groups timeout/unreachability;
  unexpected-response copy may suggest a login/proxy page without asserting
  its presence. LAN help explains Settings access without detecting denial.
