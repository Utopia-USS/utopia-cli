# Utopia CLI Rebuild Plan

Document version: 1.0 · Branch: `feat/rebuild-utopia-cli` · Author: Claude

This document describes the plan to rebuild the existing `utopia_cli` MVP into
a kebab-case, marketplace-ready Flutter scaffolder built on Mason, with
first-class integration with the Utopia Claude Code skills marketplace.

---

## 1. Goals

1. **Marketing-grade CLI surface.** Single short command (`utopia`), legible
   help, branded output. Today: `utopia_arch_cli --name X --org Y`. Goal:
   `utopia create flutter_app my_app --org io.utopiasoft`.
2. **Scaffold a working Utopia Flutter app** with utopia_arch + utopia_hooks
   wired up, plus a runnable sample feature using the Screen/State/View pattern.
3. **Claude Code skills integration baked in.** Generated projects ship with
   a `.claude/` directory referencing `Utopia-USS/utopia-flutter-skills` so a
   user can hit `/utopia-hooks` immediately after `flutter run`.
4. **Marketplace-ready presentation.** Pub.dev metadata complete, README that
   sells the workflow, in-CLI marketing touch points (welcome message, README
   footer credit) without being annoying.
5. **Pragmatic defaults.** Bricks shipped in-repo (atomic versioning),
   optional `.utopia.yaml` project config, no `$HOME` clutter.

## 2. Non-goals (this PR)

- Publishing to pub.dev — manual step after review.
- `utopia migrate bloc` and `utopia add state` — dropped from scope
  during review. BLoC migration lives in the
  `utopia-hooks-migrate-bloc` Claude Code skill (invoked via
  `/utopia-hooks-migrate-bloc:migrate`). "State" scaffolding is too
  context-dependent (global vs widget-local) to bake into a CLI brick;
  `/utopia-hooks` in the skill handles it instead.
- Custom CI for the CLI itself (skill repo has its own).
- Marketing assets outside the CLI (blog, demo GIFs, social previews).
- Renaming the GitHub repo from `utopia_cli` to `utopia-cli` — a separate
  GitHub admin action; flagged in the open questions.

---

## 3. Architecture

### 3.1 Naming

| Surface | Value | Why |
|---|---|---|
| Pub package name | `utopia_cli` | pub.dev requires snake_case |
| Executable name | `utopia` | The marketing surface; short, brandable |
| GitHub repo | `utopia-cli` (target) | Kebab matches docs/marketing |
| Old executable | `utopia_arch_cli` | Kept as a deprecated alias for one minor |
| Brick name | `utopia_flutter_app` | Snake — Mason convention |

Dart packages must use snake_case (pubspec spec), so we cannot rename the
*package* itself to kebab. We compensate by renaming the executable and the
repo.

### 3.2 Code layout

```
utopia_cli/
├── bin/
│   └── utopia.dart                    # entrypoint (was utopia_arch_cli.dart)
├── lib/
│   ├── utopia_cli.dart                # public re-exports for tests
│   └── src/
│       ├── command_runner.dart        # UtopiaCommandRunner
│       ├── version.dart               # generated, holds packageVersion
│       ├── strings.dart               # ALL marketing copy lives here
│       ├── config/
│       │   └── utopia_config.dart     # .utopia.yaml loader (optional)
│       ├── commands/
│       │   ├── commands.dart
│       │   ├── create/
│       │   │   ├── create_command.dart
│       │   │   ├── create_subcommand.dart
│       │   │   ├── flutter_app_command.dart
│       │   │   └── flutter_package_command.dart
│       │   └── update_command.dart
│       └── generators/
│           └── brick_locator.dart     # finds in-repo bricks reliably
├── bricks/
│   ├── utopia_flutter_app/            # main scaffold (renamed from utopia_template)
│   │   ├── brick.yaml
│   │   ├── README.md
│   │   └── __brick__/                 # see §5
│   └── utopia_flutter_package/        # simple Dart/Flutter package
│       ├── brick.yaml
│       └── __brick__/
├── test/
│   ├── command_runner_test.dart
│   ├── commands/
│   │   ├── create_flutter_app_test.dart
│   │   └── update_command_test.dart
│   └── generators/
│       └── brick_locator_test.dart
├── CHANGELOG.md
├── LICENSE                            # MIT, kept
├── README.md                          # rewritten
├── analysis_options.yaml              # was missing for CLI itself
├── dart_test.yaml
└── pubspec.yaml
```

### 3.3 Dependencies (`pubspec.yaml`)

| Package | Purpose | Note |
|---|---|---|
| `args` | CommandRunner | Already used |
| `mason` | Brick generation | Already used; bump if needed |
| `mason_logger` | Branded log output | New — replaces `print()` calls |
| `path` | Path joining | Already used |
| `pub_updater` | `utopia update` self-update | New |
| `yaml` | `.utopia.yaml` reader | New |
| `meta` | `@visibleForTesting` | New |
| `dart_mcp` | MCP server exposure | New (added in 0.2.0-dev.3) |
| `test` (dev) | unit tests | Already used |

Avoid: `cli_completion` (over-budget for MVP), `pana` (lint tooling, not
needed at runtime).

### 3.4 Architectural decisions and rationale

| Decision | Rationale |
|---|---|
| `args`-based `CommandRunner` | Standard, predictable for Dart CLI users; supports subcommands cleanly. |
| Bricks shipped **in-repo** under `bricks/` | Atomic versioning — brick + CLI release together; no surprise version skew. |
| Brick resolution via `Platform.script` + `package_config` fallback | Robust across `dart run`, `dart pub global activate`, and `dart compile exe`. Existing CLI's multi-strategy approach is preserved but refactored into `BrickLocator`. |
| Replace `print()` with `mason_logger` (`Logger`) | Colored output, progress spinners, verbose mode. |
| Marketing strings centralized in `lib/src/strings.dart` | User can iterate copy without hunting through code. |
| `.utopia.yaml` is optional, read once at startup | Fills in defaults for `--org`, `--lints`, future per-project settings. No files are written by the CLI to bare `$HOME` (use `$XDG_CONFIG_HOME` if state ever needs to be persisted). |
| `.claude/` generated, not symlinked | Project owns its config; users can edit per-project. |
| Sample "counter" feature in generated app | Demonstrates Screen/State/View, gives a `flutter run`-ready experience. |
| Keep `utopia_arch_cli` as deprecated alias for one minor | Documented upgrade path, zero churn for the 1 commit MVP. |

---

## 4. Command Specification

### 4.1 Top-level

```
utopia [global-flags] <command> [<subcommand>] [args]
```

Global flags:
- `--version`, `-v` — print version (also: `utopia --version`)
- `--verbose` — enable verbose logging
- `--help`, `-h` — show usage

Examples:
```
utopia --version
utopia --help
utopia create flutter_app my_app
```

### 4.2 `utopia create flutter_app <name>` — **P0**

Generate a new Flutter app project from the `utopia_flutter_app` brick.

**Positional args:**
- `<name>` (required) — project name. Must be a valid Dart package name
  (snake_case, no `-`).

**Flags:**
| Flag | Alias | Default | Notes |
|---|---|---|---|
| `--org` | `-o` | `io.utopiasoft` | Reverse-domain org identifier |
| `--description` | | `A Utopia Flutter project.` | App description |
| `--platforms` | `-p` | `android,ios` | Flutter platforms to enable |
| `--output-directory` | `-d` | `.` | Where to create the project dir |
| `--application-id` | | `<org>.<name>` | iOS bundle / Android app id |
| `--no-skills` | | `false` | Skip generating `.claude/` skills config |
| `--no-pub-get` | | `false` | Skip running `flutter pub get` |
| `--no-git` | | `false` | Skip `git init` |

**Examples:**
```
utopia create flutter_app my_app
utopia create flutter_app my_app --org io.acme
utopia create flutter_app my_app -d ~/projects --no-skills
```

**Output (golden path):**
```
🦄 Utopia CLI v0.2.0

Creating Flutter app: my_app
  Org:         io.utopiasoft
  Platforms:   android,ios
  Skills:      Utopia-USS/utopia-flutter-skills (enabled)

✓ Created project structure         (32 files)
✓ Initialized git
✓ Installed dependencies            (flutter pub get)
✓ Configured Claude Code skills

Done in 11.3s.

→ cd my_app
→ flutter run

Next:
  • Try the sample counter feature at lib/screen/counter/
  • Open Claude Code and run /utopia-hooks to scaffold your next screen
  • Read DEVELOPMENT.md for the Screen/State/View pattern overview

Built with ❤︎ by Utopia · https://utopiasoft.io
```

### 4.3 `utopia create flutter_package <name>` — **P1**

Generate a Flutter package (re-usable library, no app shell).

**Positional args:** `<name>` (required).

**Flags:**
- `--description` (default: `A Utopia Flutter package.`)
- `--output-directory` (default: `.`)
- `--no-skills`, `--no-pub-get`, `--no-git` (same semantics as `flutter_app`)

**Examples:**
```
utopia create flutter_package my_widgets
```

Generated layout: minimal `lib/`, `test/`, `example/`, `analysis_options.yaml`
pointing at `utopia_lints`.

### 4.4 `utopia update` — **P1**

Self-update via `pub_updater`.

```
utopia update
```

Behavior:
- Checks pub.dev for `utopia_cli` latest version.
- If newer, runs `dart pub global activate utopia_cli <latest>`.
- Honors `--force` to re-install the current version.

### 4.5 `utopia --version` — **P0**

Prints `utopia_cli vX.Y.Z`. Version sourced from `lib/src/version.dart` —
generated at release time from `pubspec.yaml`.

### 4.6 Roadmap

| Command | Status | Notes |
|---|---|---|
| `utopia add screen <name>` | ✓ implemented | `bricks/screen/` vendored from `Utopia-USS/utopia-mason`. |
| `utopia mcp` | ✓ implemented | MCP server over stdio. |
| `utopia init skills` | planned | Writes `.claude/` into an existing project. |

**Dropped from scope** during PR review:

- `utopia migrate bloc` — handled by the `utopia-hooks-migrate-bloc`
  Claude Code skill (`/utopia-hooks-migrate-bloc:migrate`); no CLI
  surface needed.
- `utopia add state` — "state" is overloaded (global vs widget-local)
  and not a clean single-template problem; `/utopia-hooks` in the skill
  handles it with context.

---

## 5. Brick structure — `bricks/utopia_flutter_app/__brick__/`

Based on the existing `utopia-flutter-template` and the existing brick in
`utopia_cli`, with three additions:

1. A working **counter** sample feature wired up to the router.
2. A `.claude/` directory pre-configured with the skills marketplace.
3. A `DEVELOPMENT.md` doc that explains the Screen/State/View pattern with
   a link to the upstream `utopia_hooks` skill.

```
__brick__/
├── .gitignore.tmpl                    # leading dot files use .tmpl suffix
├── .fvmrc
├── .metadata
├── README.md                          # branded, with "Generated by Utopia CLI" footer
├── DEVELOPMENT.md                     # NEW — Screen/State/View intro + skill CTA
├── analysis_options.yaml              # include: package:utopia_lints/lints.yaml
├── pubspec.yaml                       # {{package_name}} substitution
├── .claude/
│   ├── settings.json                  # NEW — registers skills marketplace
│   └── README.md                      # NEW — explains the skills setup
├── lib/
│   ├── main.dart
│   ├── app/
│   │   ├── app.dart
│   │   ├── app_config.dart
│   │   ├── app_injector.dart
│   │   ├── app_localizations.dart
│   │   ├── app_reporter.dart
│   │   ├── app_routing.dart           # MODIFIED — adds Counter route
│   │   ├── state/
│   │   │   ├── firebase/firebase_state.dart
│   │   │   ├── initialization/initialization_state.dart
│   │   │   └── precache/image_precache_state.dart
│   │   └── widget/app_global_error_dialog.dart
│   ├── common/
│   │   ├── constant/{app_colors,app_icons,app_images,app_text,app_theme}.dart
│   │   └── widget/
│   │       ├── button/app_button.dart
│   │       ├── field/{app_field_layout.dart,app_field_theme.dart,datetime/...,text/...}
│   │       └── loader/app_loader.dart
│   ├── screen/
│   │   ├── splash/splash_screen.dart
│   │   └── counter/                   # NEW
│   │       ├── counter_screen.dart
│   │       ├── state/counter_state.dart
│   │       └── view/counter_view.dart
│   └── util/
│       ├── extension/context_extensions.dart
│       └── widget/cross_fade_overlay.dart
```

### 5.1 Brick variables

Defined in `brick.yaml`:

| Var | Type | Default | Source |
|---|---|---|---|
| `project_name` | string | `my_app` | CLI `<name>` positional |
| `org_name` | string | `io.utopiasoft` | CLI `--org` |
| `package_name` | string | `{{project_name}}` | derived |
| `description` | string | `A Utopia Flutter project.` | CLI `--description` |
| `platforms` | string | `android,ios` | CLI `--platforms` |
| `application_id` | string | `{{org_name}}.{{project_name}}` | derived if not passed |
| `skills_enabled` | bool | `true` | inverse of `--no-skills` |
| `year` | string | runtime | for `LICENSE` |

### 5.2 Counter feature (sample)

The counter is the "Hello, World" of the Screen/State/View pattern. It is
small enough to read at a glance, complete enough to copy.

**`counter_state.dart`** — class `CounterState` produced by a hook
`useCounterState()` that exposes `(int count, VoidCallback increment)`.

**`counter_view.dart`** — pure widget that takes a `CounterState` and renders
the count plus a FloatingActionButton.

**`counter_screen.dart`** — the `HookWidget` that calls `useCounterState()`
and passes it to `CounterView`.

**`app_routing.dart`** — adds `/counter` route, opens it from the splash CTA.

This gives users a `flutter run`-ready project that demonstrates the entire
pattern in three small files.

### 5.3 `.claude/settings.json` (generated)

```json
{
  "$schema": "https://raw.githubusercontent.com/anthropics/claude-code/main/schemas/settings.schema.json",
  "permissions": {},
  "marketplaces": [
    {
      "source": "github:Utopia-USS/utopia-flutter-skills"
    }
  ],
  "enabledPlugins": [
    "utopia-hooks"
  ]
}
```

> Note: the exact schema for `marketplaces` / `enabledPlugins` in
> `.claude/settings.json` is **flagged as an open question** (see §11) —
> if the consumer schema differs, we fall back to a `CLAUDE.md` snippet
> documenting `/plugin marketplace add Utopia-USS/utopia-flutter-skills`
> as the manual step.

### 5.4 `analysis_options.yaml` (generated)

Keeps the existing template's choice:
```yaml
include: package:utopia_lints/lints.yaml
analyzer:
  exclude:
    - "**/*.g.dart"
    - "**/*.freezed.dart"
formatter:
  page_width: 120
```

If `utopia_lints` is not resolvable at generation time (e.g., not yet
published to pub.dev), the CLI falls back to `flutter_lints` and prints
a warning. Decided at brick-render time via a `lints_pack` var (default:
`utopia_lints`, override via `--lints`).

---

## 6. Generated project structure (what users get)

Tree after `utopia create flutter_app my_app`:

```
my_app/
├── .claude/
│   ├── settings.json                  # marketplace registered
│   └── README.md                      # skill quick-reference
├── .git/                              # initialized + first commit staged
├── .fvmrc
├── .gitignore
├── DEVELOPMENT.md                     # Screen/State/View overview
├── README.md                          # with Utopia CLI footer
├── analysis_options.yaml
├── android/                           # from flutter create
├── ios/                               # from flutter create
├── lib/
│   ├── main.dart
│   ├── app/...                        # see §5
│   ├── common/...
│   ├── screen/
│   │   ├── splash/splash_screen.dart
│   │   └── counter/
│   │       ├── counter_screen.dart
│   │       ├── state/counter_state.dart
│   │       └── view/counter_view.dart
│   └── util/...
├── pubspec.yaml
└── pubspec.lock                       # after pub get
```

Runs out of the box: `cd my_app && flutter run` shows splash → counter.

---

## 7. Marketing touch points (concrete strings)

All copy lives in `lib/src/strings.dart` as `const`. Sample below — final
copy iterable in one file.

### 7.1 Welcome banner (every command)
```
🦄 Utopia CLI v{version}
```

### 7.2 Post-create success block
```
Done in {duration}s.

→ cd {project_name}
→ flutter run

Next:
  • Try the sample counter feature at lib/screen/counter/
  • Open Claude Code and run /utopia-hooks to scaffold your next screen
  • Read DEVELOPMENT.md for the Screen/State/View pattern overview

Built with ❤︎ by Utopia · https://utopiasoft.io
```

### 7.3 Generated `README.md` footer (in project)
```
---
Generated by [Utopia CLI](https://github.com/Utopia-USS/utopia-cli) 🦄 ·
Powered by [utopia_hooks](https://pub.dev/packages/utopia_hooks) +
[utopia_arch](https://pub.dev/packages/utopia_arch)
```

### 7.4 Generated `DEVELOPMENT.md` (excerpt)
```
# Development guide

This project follows the Utopia **Screen / State / View** pattern.
See lib/screen/counter/ for a complete example.

For AI-assisted scaffolding, this project ships with the
[utopia-flutter-skills](https://github.com/Utopia-USS/utopia-flutter-skills)
marketplace pre-registered for Claude Code:

  • `/utopia-hooks` — scaffold a new Screen/State/View triad
  • `/utopia-hooks-migrate-bloc` — migrate legacy BLoC code

If you're new to Claude Code:
  npm install -g @anthropic-ai/claude-code
  cd {project_name}
  claude
```

### 7.5 `utopia update` available message
```
Update available! 0.2.0 → 0.3.0
Changelog: https://github.com/Utopia-USS/utopia-cli/releases/tag/v0.3.0
Run `utopia update` to install.
```

### 7.6 Constraints on copy

- No marketing speak in errors. Errors stay short and actionable.
- Emoji budget: 1 unicorn 🦄 (banner) + checkmarks ✓ + arrows →. No emoji
  party.
- All hardcoded URLs in one place: `lib/src/strings.dart`.

---

## 8. Migration from utopia_cli MVP

Existing state:
- Pub.dev: `utopia_arch_cli` 0.1.0-dev.6 — pre-release, no stable versions.
- GitHub: 1 commit, 0 stars, no PRs.
- Generated projects: format is essentially `utopia-flutter-template` —
  fully compatible with new CLI output (no breaking change to generated
  code shape).

What to **remove**:
- `bin/utopia_arch_cli.dart` — becomes a thin shim that prints "renamed
  to `utopia`" and forwards to the new entrypoint (one minor version).
- `scripts/setup_template.sh` — its function (pulling `utopia-flutter-template`
  contents into the brick) moves to a `tool/sync_template.dart` script that
  the maintainer runs locally. Not user-facing.
- `UPDATE_TEMPLATE.md`, `PUBLISHING.md`, `SETUP.md` — consolidated into
  `CONTRIBUTING.md`.

What to **keep**:
- `LICENSE` (MIT).
- `bricks/utopia_template/__brick__/lib/` — moved verbatim to
  `bricks/utopia_flutter_app/__brick__/lib/` and edited only to add the
  counter feature and `.claude/` directory.

User upgrade path (documented in CHANGELOG.md):
```
# Old (0.1.0-dev.x)
dart pub global activate utopia_arch_cli
utopia_arch_cli --name my_app --org io.utopiasoft

# New (0.2.0+)
dart pub global activate utopia_cli
utopia create flutter_app my_app --org io.utopiasoft

# Transitional (0.2.0): old executable name still works, prints a
# deprecation notice and forwards. Removed in 0.3.0.
```

---

## 9. Testing strategy

Scoped for MVP:

### 9.1 Unit tests (`test/`)

- `command_runner_test.dart`
  - Parses `--version` and prints version
  - Parses `--help` and shows top-level usage
  - Unknown command exits with `ExitCode.usage`
- `commands/create_flutter_app_test.dart`
  - Invalid project name (`my-app`) → usage error
  - Invalid org name (`utopiasoft`) → usage error
  - Happy path with mocked `MasonGenerator` produces expected template vars
  - `--no-skills` omits `.claude/` from generator vars
- `commands/update_command_test.dart`
  - With mocked `PubUpdater`: prints "already up to date" path
  - With mocked `PubUpdater`: triggers `pub global activate` on new version
- `generators/brick_locator_test.dart`
  - Resolves brick path in dev (relative to script)
  - Resolves brick path in pub-cache layout (faked via temp dir)

### 9.2 Golden-file integration test (smoke)

`test/integration/create_smoke_test.dart`:
- Runs `dart run bin/utopia.dart create flutter_app smoke_test` in a temp
  dir.
- Asserts: directory exists, `pubspec.yaml` contains the package name,
  `.claude/settings.json` is present, `lib/screen/counter/counter_screen.dart`
  exists.
- Skipped on CI without `flutter` on PATH.

### 9.3 Manual smoke (release checklist)

`tool/smoke.sh`:
1. `dart pub global activate --source path .`
2. `utopia create flutter_app smoke_test -d /tmp`
3. `cd /tmp/smoke_test && flutter pub get && flutter analyze`
4. `flutter test`

---

## 10. Release process

1. Bump version in `pubspec.yaml` (target: `0.2.0` — first stable Utopia CLI
   release).
2. Regenerate `lib/src/version.dart` via `tool/sync_version.dart`.
3. Update `CHANGELOG.md`.
4. `dart pub publish --dry-run`.
5. Tag `v0.2.0` and push.
6. `dart pub publish`.
7. Optional: GitHub release with CHANGELOG body.

Pub.dev metadata (in `pubspec.yaml`):
```yaml
homepage: https://github.com/Utopia-USS/utopia-cli
repository: https://github.com/Utopia-USS/utopia-cli
issue_tracker: https://github.com/Utopia-USS/utopia-cli/issues
topics: [cli, flutter, scaffolding, utopia, hooks]
```

---

## 11. Open questions for human review

1. **Repo rename `utopia_cli` → `utopia-cli`.** Requires a GH admin action.
   GitHub auto-redirects, but pub.dev `repository:` URL will point at the
   new slug. Recommend doing this *before* the 0.2.0 publish.
2. **`.claude/settings.json` schema for marketplaces.** The exact field
   names (`marketplaces` vs `marketplaceUrls`, `enabledPlugins` vs
   `plugins`) need to be confirmed against the current Claude Code release.
   Plan A above. Plan B fallback: ship only `CLAUDE.md` with the manual
   `/plugin marketplace add ...` instruction; no `settings.json` written.
3. **`utopia_lints` availability on pub.dev.** Template imports it. If
   it's not yet published, fallback path: `flutter_lints` (built-in) with
   a TODO in the generated `analysis_options.yaml`. Default in plan:
   `utopia_lints` because the existing brick already references it.
4. **Brick name `utopia_flutter_app` vs `utopia_app`.** Recommendation:
   keep `utopia_flutter_app` for clarity. Trivial to rename later.
5. **Should `utopia create` default to `--no-skills=false` or prompt?** The
   plan defaults to **enabled** for marketing reasons. If we want a more
   conservative default, flip to `false` and surface a "wanna add it?"
   prompt.
6. **Deprecate `utopia_arch_cli` executable: one minor or two?** Plan
   above says "removed in 0.3.0". Could keep through 0.4.0 if we want
   extra runway — see Constraints in source brief.
7. **`flutter pub get` in CI test environments.** The smoke integration
   test depends on a network reachable Flutter SDK; CI may need
   `--offline` or to be marked `@Skip` based on env var.

---

## 12. Out of scope (explicit)

- Pub.dev publish (manual after review).
- CI setup for the CLI repo (does not exist today).
- Marketing assets (blog, demo GIF, social cards).
- Localization of CLI output.
- Windows-specific path edge cases beyond what `path` package handles.
