# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- **`utopia describe`** - emits project structure as versioned JSON
  (`schema_version: 1`). One tool call replaces many file reads when
  agents need to know what's in the project. Detects:
  - Workspace shape (single package vs Melos monorepo, with package
    glob expansion)
  - Screens classified by kind (`routed_screen`, `sheet`, `dialog`,
    `non_routed_page`, `subscreen_fragment`, `bare_screen`,
    `auto_route_page`)
  - Multiple states / views per screen (real apps have 0, 1, 2, or 4)
  - Routing strategy (`static_const_aggregator`, `auto_route`,
    `go_router`, `imperative_only`)
  - Global states with cross-package origin tracking
  - Services + injector registration kind
  - Foreign-framework artefacts (bloc / cubit / riverpod / provider /
    mobx / get_x / stateful_widget / direct flutter_hooks imports)
  - Discovery notes for parse-time issues (cross-file references,
    computed paths, multiple `@RoutePage` per file)
  - Flags: `-C <root>`, `-o <file>`, `--pretty` / `--no-pretty`,
    `--routes-only`
  - Schema doc at `doc/describe_schema.md` - public API contract
- **`utopia doctor`** - repo-wide audit complementing the
  `quality_check.sh` PostToolUse hook in the `utopia-hooks` skill.
  - Tag-based check selection: `--check=setup,artifacts:bloc`,
    `--skip=structure`, `--strict` (bypass activation gates)
  - Smart conditional activation: `artifacts:bloc` only runs if
    `flutter_bloc` is in pubspec; setup / conventions gate on
    `utopia_arch` OR `utopia_hooks` presence (revised from
    hooks-only after the brick was found to not declare hooks
    directly, which would have silenced the check)
  - MVP check set across 5 tags:
    - `setup`: lints_not_extended, utopia_hooks_plugin_not_enabled,
      claude_settings_missing
    - `conventions`: state_has_navigator, state_has_buildcontext,
      view_uses_hooks, screen_extends_stateful
    - `artifacts`: bloc, riverpod, provider, mobx, getx,
      stateful_widget
    - `imports`: flutter_hooks_direct
    - `structure`: orphan_state
  - Structured `{rule_id, tag, sub_tag, severity, package, file,
    line, message, fix}` findings array + summary counts; `package`
    names the owning package (describe `packages[].name`, null for
    project-root findings) so monorepo agents don't infer it from
    path prefixes
  - Non-zero exit code on `error`-severity findings (CI gate)
  - `--human` flag prints a digest to stderr alongside JSON
- All relative paths in JSON outputs (describe, doctor, hooks analyze,
  `add screen --json`) are posix-style (forward slashes) on every
  platform, Windows included - one deterministic contract for agents
- CI runs the full analyze + test job on Windows as well as Linux, and
  dogfoods the real `doctor` binary end to end (gate passes on
  warnings at default `--fail-on=error`, fails at `--fail-on=warning`)

### Removed

- **`utopia mcp` command and the MCP server** - dropped after PR review
  identified that the server wrapped only one-shot generative tools
  (`create_flutter_app`, `create_flutter_package`, `add_screen`) which
  add zero value over invoking the CLI via Bash. MCP earns its keep
  only on high-frequency / structured-output operational tools (cf.
  VGV's `very_good test`). The current set fails on all five
  dimensions, so the wrapper is pure transport overhead. Slated for
  re-introduction scoped to `describe` + `doctor`.
- `dart_mcp` dependency from `pubspec.yaml`.
- `mcp` topic from `pubspec.yaml`.
- `lib/src/commands/mcp/` directory.
- `test/commands/mcp_command_test.dart`.

### Fixed (smoke-test + adversarial verification pass)

Nine issues found by running `describe`/`doctor` against four real Utopia
projects (habicy, jolly-phonics-apps, qbt-black-phone, madrosc-tlumu) and
two independent verification passes:

- `describe`: function-based dialogs/sheets (top-level `showXxx()` with no
  matching widget class, e.g. `showDeckUpsellDialog`) were dropped. Now
  detected as `kind: dialog`/`sheet`.
- `describe`: a screen-state hoisted into the providers map (registered
  global living under `lib/screen/.../state/`) is now included in
  `global_states`.
- `describe`: `provider` framework false negative - `Provider.of<>()` and
  `MultiProvider` patterns were not detected. Added.
- `describe`: pattern matching now skips comment lines (avoids matching a
  framework keyword inside a doc comment).
- `describe`: a parameterized (arg-taking) state hook in the conventional
  `state/` dir that isn't registered is now correctly treated as a helper,
  not a phantom global. No-arg conventional states (cross-package global
  pattern) are still included.
- `describe`: bad `-C <root>` path now emits a `project_root_not_found`
  error note + non-zero exit instead of a silently-empty result; a dir with
  no package emits `no_package_found`.
- `doctor` `conventions.state_has_buildcontext`: no longer false-positives
  on `BuildContext` mentioned in comments or in `extension X on BuildContext`
  declarations.
- `doctor` `structure.orphan_state`: rewritten from a fragile same-directory
  heuristic to "the state's hook is defined but never referenced anywhere in
  the package." Fixes false positives on cross-directory / cross-screen state
  usage; also catches dead hooks whose return type isn't `*State`.

### Added (Phase 4)

- **`utopia bump`** - atomically bump all `utopia_*` deps in
  `pubspec.yaml` to the latest pub.dev versions. Preserves indentation
  and surrounding lines (minimal-diff edits). `--dry-run` flag to
  preview. Useful for keeping the brick template in sync with monorepo
  releases and for downstream apps tracking utopia.
- **`utopia init skills` extension** - after writing `.claude/`,
  doctor-style hints are emitted if `utopia_arch` is missing from
  pubspec or `utopia_lints` is not extended. Does NOT mutate the
  pubspec automatically (YAML mutation is fragile; user knows their
  project better). Suggests running `utopia doctor` for the full
  audit.

### Re-added (scoped)

- **`utopia mcp` (scoped rebuild)** - MCP server is back, but
  scoped intentionally to the operational tools that earn their keep
  on the MCP-vs-Bash test. Tools exposed:
  - `describe` (wraps `utopia describe`) - structured JSON of project
    structure
  - `describe_routes` (wraps `utopia describe --routes-only`)
  - `doctor` (wraps `utopia doctor`) - findings array agents reason
    over iteratively
  - Generators (`create_*`, `add_screen`, `init_skills`) NOT exposed
    via MCP - documented in README as "use Bash".
- `dart_mcp` dep back in `pubspec.yaml` (^0.5.0).
- `mcp` topic back in `pubspec.yaml`.

### Planned (next)

- `utopia describe --diff <ref>` - emit what changed (new screens,
  global states, route renames) between two git refs.
- `init skills` extension: add `utopia_arch` + `utopia_hooks` deps
  and `analysis_options.yaml` (extends utopia_lints) if missing.
- `utopia bump` - atomic version bump for all `utopia_*` deps.

## [0.2.0-dev.6] - 2026-05-17

### Added

- `utopia init skills` — writes `.claude/settings.json` and
  `.claude/README.md` into the current directory, registering the
  `Utopia-USS/utopia-flutter-skills` marketplace and enabling the
  `utopia-hooks` plugin. Intended for projects created with
  `--no-skills`, or any existing Flutter project that wants to opt in.
  Flags: `--output-directory`/`-d` (default `.`), `--force`/`-f`
  (overwrite existing settings).
- New in-repo brick `bricks/skills/` (no template variables) backing
  the command.
- 3 new tests covering golden-path write, idempotency, and `--force`
  overwrite.

## [0.2.0-dev.5] - 2026-05-17

### Added

- **CI workflow** (`.github/workflows/ci.yml`) — on every push and PR
  runs `dart format` (strict), `dart analyze --fatal-infos`, `dart test`,
  and `dart pub publish --dry-run`. Verifies `lib/src/version.dart` is
  in sync with `pubspec.yaml`.

### Fixed

- **MCP `tools/list` returned empty** — tools are now registered in the
  `UtopiaMcpServer` constructor (matches `dart_mcp` 0.5.1 example
  pattern) instead of inside `initialize()`. Verified end-to-end:
  `tools/list` returns all three tools with full schemas, and
  `tools/call create_flutter_app` successfully scaffolds a project.

### Changed

- `process` package added to `dev_dependencies` (used by
  `update_command_test.dart`) — silences the only outstanding
  `dart pub publish --dry-run` warning.
- `dart mcp` no longer flagged as experimental.

## [0.2.0-dev.4] - 2026-05-17

### Removed

- `utopia migrate bloc` stub — out of scope for the CLI. BLoC migration
  lives in the `utopia-hooks-migrate-bloc` Claude Code skill; invoke it
  via `/utopia-hooks-migrate-bloc:migrate` after the skills marketplace
  is registered (it is, in any project created by `utopia create`).
- `utopia add state` stub — global vs widget-local state is not a
  single-template problem and the value of scaffolding either is low.
  Dropped from the roadmap.
- `lib/src/commands/stub_commands.dart` and `strings_helper.dart` —
  no longer needed.

### Changed

- `AddCommand` exposes only `add screen` now. Help and `invocation`
  copy updated accordingly.

## [0.2.0-dev.3] - 2026-05-17

### Added

- `utopia mcp` — boots a Model Context Protocol server over stdio,
  exposing the CLI surface as MCP tools for AI agents (Claude Code,
  Cursor, etc.). Tools registered:
  - `create_flutter_app(name, org?, platforms?, output_directory?, application_id?, description?, skills?, pub_get?, git?)`
  - `create_flutter_package(name, description?, output_directory?, skills?, pub_get?, git?)`
  - `add_screen(name, route?, output_directory?)`
- Each tool parses MCP arguments back into CLI flags and runs
  `UtopiaCommandRunner` — no second source of truth.
- Tests for `McpCommand` registration and factory injection.

### Changed

- `UtopiaCommandRunner` exposes a `disableUpdateCheck` constructor flag
  so embedders (e.g. the MCP server) can suppress pub.dev probing.

### Removed

- Legacy MVP docs: `SETUP.md`, `PUBLISHING.md`, `UPDATE_TEMPLATE.md`,
  and the `scripts/` directory. Content consolidated into
  [`CONTRIBUTING.md`](CONTRIBUTING.md).

## [0.2.0-dev.2] - 2026-05-17

### Added

- `utopia add screen <name>` — scaffolds a Screen/State/View triad at
  `lib/screen/<name>/`. Brick vendored from
  [`Utopia-USS/utopia-mason`](https://github.com/Utopia-USS/utopia-mason)
  as `bricks/screen/`. Flags: `--route` (default `/<name>`),
  `--output-directory` (default `lib/screen`).
- Post-generation hint printed with the exact `import` and `routes`
  snippet to paste into `lib/app/app_routing.dart`.

### Changed

- `add` command wiring refactored — `AddCommand` is now a real command
  with `AddScreenCommand` subcommand; `add state` remains a stub via a
  shared `StubSubcommand` helper.

## [0.2.0-dev.1] - 2026-05-17

### Breaking

- **Renamed executable**: `utopia_arch_cli` → `utopia`. The old executable
  is preserved as a deprecated shim in `0.2.0` and will be removed in
  `0.3.0`.
- **Renamed package**: pub.dev publish target moved from `utopia_arch_cli`
  to `utopia_cli`. Re-install with
  `dart pub global activate utopia_cli`.
- **New command surface**: `--name`/`--org` flags replaced by positional
  `<name>` and `--org` on `utopia create flutter_app`.

### Added

- `utopia create flutter_app <name>` — Flutter app scaffolder built on a
  shipped-in-repo Mason brick (`bricks/utopia_flutter_app/`).
- `utopia create flutter_package <name>` — Flutter package scaffolder.
- `utopia update` — self-update via `pub_updater`.
- `utopia --version` — prints CLI version (`utopia_cli vX.Y.Z`).
- `utopia add screen|state` and `utopia migrate bloc` — Phase-2 stub
  commands that appear in `--help` and exit with "coming soon".
- Sample `Counter` Screen/State/View feature in the generated app,
  demonstrating the Utopia pattern.
- `.claude/` directory generated in every new project, registering the
  [`Utopia-USS/utopia-flutter-skills`](https://github.com/Utopia-USS/utopia-flutter-skills)
  marketplace and enabling `utopia-hooks` by default. Opt out with
  `--no-skills`.
- `DEVELOPMENT.md` generated in every project with a Screen/State/View
  primer and skill CTA.
- "Generated by Utopia CLI" footer in generated READMEs.
- Experimental `.utopia.yaml` loader for future project defaults. Released
  commands do not currently consume it; use explicit flags.
- Branded `mason_logger`-powered output (progress spinners, colored
  errors, `--verbose` mode).
- Unit tests for the command runner, `flutter_app` validation,
  `BrickLocator`, and `update` command.

### Changed

- Bricks are now shipped **in-repo** under `bricks/` and resolved via a
  new `BrickLocator`. Atomic versioning: brick + CLI release together.
- License changed from MIT to **BSD-2-Clause** to align with the
  pub.dev-published Utopia packages (`utopia_lints`,
  `utopia_hooks_riverpod`).
- Brick directory renamed from `utopia_template` → `utopia_flutter_app`.

### Removed

- `print(...)` calls in favor of `mason_logger`.

### Migration from 0.1.0-dev.x

```diff
- dart pub global activate utopia_arch_cli
- utopia_arch_cli --name my_app --org io.utopiasoft

+ dart pub global activate utopia_cli
+ utopia create flutter_app my_app --org io.utopiasoft
```

Generated project structure is unchanged apart from the new
`lib/screen/counter/` sample and the optional `.claude/` directory.

---

## [0.1.0-dev.6] - 2026-01-14

(See git history for pre-rebuild MVP changelog.)
