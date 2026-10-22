# Bootstrap Task: Fill Project Development Guidelines

**You (the AI) are running this task. The developer does not read this file.**

The developer just ran `trellis init` on this project for the first time.
`.trellis/` now exists with empty spec scaffolding, and this bootstrap task
exists under `.trellis/tasks/`. When they want to work on it, they should start
this task from a session that provides Trellis session identity.

**Your job**: help them populate `.trellis/spec/` with the team's real
coding conventions. Every future AI session — this project's
`trellis-implement` and `trellis-check` sub-agents — auto-loads spec files
listed in per-task jsonl manifests. Empty spec = sub-agents write generic
code. Real spec = sub-agents match the team's actual patterns.

Don't dump instructions. Open with a short greeting, figure out if the repo
has any existing convention docs (CLAUDE.md, .cursorrules, etc.), and drive
the rest conversationally.

---

## Status (update the checkboxes as you complete each item)

- [x] Restructure spec for Flutter (backend/frontend layers replaced by `flutter/`)
- [x] Decide conventions with the developer (state, layout, routing, data, testing)
- [x] Fill flutter guidelines
- [x] Add code examples (prescriptive examples; no feature code exists yet)
- [ ] Developer review of the filled spec

Decisions (2026-10-22): feature-first layout, Riverpod 3 + codegen, go_router +
go_router_builder, remote API via dio, freezed + json_serializable, unit +
key-screen widget tests with mocktail, ARB + gen-l10n.
Defaults chosen by the AI, open to change: sealed `AppException` + `guardDio`
error mapping, `package:logging`, `zh` as template locale, generated files
committed, package imports only, global Riverpod retry for network errors only.
Still open: auth, API field casing, pagination/error-body format.

---

## Spec files to populate

The project is a single Flutter app, so `trellis init`'s fullstack
backend/frontend layers were replaced by one `flutter/` layer. Each file
carries `paths:` frontmatter so it is injected when matching files are touched.

### Flutter guidelines

| File | What to document |
|------|------------------|
| `.trellis/spec/flutter/index.md` | Scope, pre-dev checklist, quality check commands, index |
| `.trellis/spec/flutter/directory-structure.md` | `lib/` layout, file naming, where things go |
| `.trellis/spec/flutter/widget-guidelines.md` | Widget composition, theming, localization, accessibility |
| `.trellis/spec/flutter/state-management.md` | State library, providers, what state lives where |
| `.trellis/spec/flutter/routing.md` | Router setup, route definitions, navigation |
| `.trellis/spec/flutter/data-layer.md` | Models, serialization, repositories, storage, networking |
| `.trellis/spec/flutter/error-handling.md` | Error types, propagation, user-facing errors, logging |
| `.trellis/spec/flutter/testing.md` | Unit / widget / integration tests, mocks, fixtures |
| `.trellis/spec/flutter/quality-guidelines.md` | Lints, formatting, language features, codegen, forbidden patterns |

The codebase is still the `flutter create` template, so these record agreed
decisions rather than extracted patterns. Examples must use the real
`lib/` paths the directory-structure spec defines.


### Thinking guides (already populated)

`.trellis/spec/guides/` contains general thinking guides pre-filled with
best practices. Customize only if something clearly doesn't fit this project.

---

## How to fill the spec

### Step 1: Import from existing convention files first (preferred)

Search the repo for existing convention docs. If any exist, read them and
extract the relevant rules into the matching `.trellis/spec/` files —
usually much faster than documenting from scratch.

| File / Directory | Tool |
|------|------|
| `CLAUDE.md` / `CLAUDE.local.md` | Claude Code |
| `AGENTS.md` | Codex / Claude Code / agent-compatible tools |
| `.cursorrules` | Cursor |
| `.cursor/rules/*.mdc` | Cursor (rules directory) |
| `.windsurfrules` | Windsurf |
| `.clinerules` | Cline |
| `.roomodes` | Roo Code |
| `.github/copilot-instructions.md` | GitHub Copilot |
| `.vscode/settings.json` → `github.copilot.chat.codeGeneration.instructions` | VS Code Copilot |
| `CONVENTIONS.md` / `.aider.conf.yml` | aider |
| `CONTRIBUTING.md` | General project conventions |
| `.editorconfig` | Editor formatting rules |

### Step 2: Analyze the codebase for anything not covered by existing docs

Scan real code to discover patterns. Before writing each spec file:
- Find 2-3 real examples of each pattern in the codebase.
- Reference real file paths (not hypothetical ones).
- Document anti-patterns the team clearly avoids.

### Step 3: Document reality, not ideals

**Critical**: write what the code *actually does*, not what it should do.
Sub-agents match the spec, so aspirational patterns that don't exist in the
codebase will cause sub-agents to write code that looks out of place.

If the team has known tech debt, document the current state — improvement
is a separate conversation, not a bootstrap concern.

---

## Quick explainer of the runtime (share when they ask "why do we need spec at all")

- Every AI coding task spawns two sub-agents: `trellis-implement` (writes
  code) and `trellis-check` (verifies quality).
- Each task has `implement.jsonl` / `check.jsonl` manifests listing which
  spec files to load.
- The platform hook auto-injects those spec files + the task's `prd.md`
  into every sub-agent prompt, so the sub-agent codes/reviews per team
  conventions without anyone pasting them manually.
- Source of truth: `.trellis/spec/`. That's why filling it well now pays
  off forever.

---

## Completion

When the developer confirms the checklist items above are done with real
examples (not placeholders), guide them to run:

```bash
python ./.trellis/scripts/task.py finish
python ./.trellis/scripts/task.py archive 00-bootstrap-guidelines
```

After archive, every new developer who joins this project will get a
`00-join-<slug>` onboarding task instead of this bootstrap task.

---

## Suggested opening line

"Welcome to Trellis! Your init just set me up to help you fill the project
spec — a one-time setup so every future AI session follows the team's
conventions instead of writing generic code. Before we start, do you have
any existing convention docs (CLAUDE.md, .cursorrules, CONTRIBUTING.md,
etc.) I can pull from, or should I scan the codebase from scratch?"
