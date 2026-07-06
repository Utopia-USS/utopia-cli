# Changelog

All notable changes to this project will be documented in this file.

## 0.2.1 - 2026-07-07

- Docs: generalize the reference-project labels in `doc/describe_schema.md`
  and related code comments to the anonymized `repo-A`..`repo-D` convention.

## 0.2.0 - 2026-07-03

First release of `utopia_cli` on pub.dev. This package replaces
[`utopia_arch_cli`](https://pub.dev/packages/utopia_arch_cli) (published
only as `0.1.0-dev.x`); see the migration note below.

### Scaffolding

- `utopia create flutter_app <name>` - scaffolds a Flutter app built on
  the Utopia stack (`utopia_arch` + `utopia_hooks`), including a sample
  `Counter` Screen/State/View feature and pre-configured Claude Code
  skills (opt out with `--no-skills`).
- `utopia create flutter_package <name>` - Flutter package scaffolder.
- `utopia add screen <name>` - generates a Screen/State/View triad at
  `lib/screen/<name>/` and prints the exact routing snippet to paste.
  `--json` emits a machine-readable result for agents.
- Mason bricks ship in-repo under `bricks/`, so brick and CLI always
  release together.

### Project inspection (JSON-first)

- `utopia describe` - emits project structure as versioned JSON
  (`schema_version: 1`, documented in `doc/describe_schema.md`):
  workspace shape (single package or Melos monorepo), screens
  classified by kind, routing strategy, global states, services, and
  foreign-framework artifacts. `--routes-only` for a cheap routes view.
- `utopia doctor` - repo-wide audit with tag-based check selection
  (`--check`, `--skip`, `--strict`), conditional activation (framework
  checks run only when that framework is in the pubspec), structured
  findings (`rule_id`, `severity`, `package`, `file`, `line`, `fix`),
  and a `--fail-on` CI gate. `--human` prints a digest to stderr
  alongside the JSON.
- `utopia hooks analyze` - per-file utopia_hooks rule analysis for
  editor hooks and CI (single file, explicit paths, changed files, or
  `--all`).
- All relative paths in JSON output are posix-style on every platform,
  Windows included - one deterministic contract for agents.

### Agent integration

- `utopia init skills` - writes `.claude/` settings registering the
  [`Utopia-USS/utopia-flutter-skills`](https://github.com/Utopia-USS/utopia-flutter-skills)
  marketplace and enabling the `utopia-hooks` plugin.
- `utopia init agents` - writes `AGENTS.md` with the provider-neutral
  CLI workflow: inspect with `describe`, generate with
  `add screen --json`, validate with `doctor`.
- `utopia mcp` - Model Context Protocol server over stdio exposing the
  operational tools: `describe`, `describe_routes`, `doctor`,
  `analyze_hooks_files`, `analyze_hooks_changed`. Generators stay on
  the CLI surface by design.

### Maintenance

- `utopia bump` - bumps all `utopia_*` dependencies in `pubspec.yaml`
  to the latest pub.dev versions with minimal-diff edits; `--dry-run`
  to preview.
- `utopia update` - self-update via pub.dev.

### Migrating from utopia_arch_cli

```diff
- dart pub global activate utopia_arch_cli
- utopia_arch_cli --name my_app --org io.utopiasoft
+ dart pub global activate utopia_cli
+ utopia create flutter_app my_app --org io.utopiasoft
```

The old `utopia_arch_cli` executable still works as a deprecated shim
in 0.2.0 and will be removed in 0.3.0.
