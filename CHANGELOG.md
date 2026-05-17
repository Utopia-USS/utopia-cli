# Changelog

All notable changes to this project will be documented in this file.

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
- Optional `.utopia.yaml` project config for default `org`, `platforms`,
  `skills`, and `lints` (read from CWD or any parent).
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
