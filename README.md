<img src="https://raw.githubusercontent.com/Utopia-USS/utopia-cli/main/docs/header.png" width="190" alt="Utopia CLI"/>

# Utopia CLI 👾

A command-line scaffolder for Flutter projects built on
[`utopia_arch`](https://pub.dev/packages/utopia_arch) +
[`utopia_hooks`](https://pub.dev/packages/utopia_hooks), with optional
Claude Code skills and JSON-first workflows for Codex, shell, and CI agents.

## Install

```bash
dart pub global activate utopia_cli
```

Make sure `$HOME/.pub-cache/bin` is on your `PATH`. Verify:

```bash
utopia --version
```

## Quick start

```bash
utopia create flutter_app my_app --org io.utopiasoft
cd my_app
dart run build_runner build --delete-conflicting-outputs
flutter run
```

You now have a runnable Flutter app with a sample Screen/State/View
feature and Claude Code skills pre-registered. Codex and shell agents can
use the CLI directly; run `utopia init agents` in existing projects to
write a provider-neutral `AGENTS.md`.

## Commands

| Command | Status | What it does |
|---|---|---|
| `utopia create flutter_app <name>` | ✓ | Scaffold a Utopia Flutter app. |
| `utopia create flutter_package <name>` | ✓ | Scaffold a Utopia Flutter package. |
| `utopia add screen <name>` | ✓ | Scaffold a Screen/State/View triad in an existing project. |
| `utopia init agents` | ✓ | Write provider-neutral AGENTS.md instructions for Codex, shell, and CI agents. |
| `utopia init skills` | ✓ | Register the skills marketplace in an existing project. |
| `utopia describe` | ✓ | Emit project structure (screens, routes, states, services, deps) as JSON for agents. |
| `utopia hooks analyze` | ✓ | Fast utopia_hooks convention analysis for changed files, one file, or the whole project. |
| `utopia doctor` | ✓ | Repo-wide audit (setup, conventions, artifacts, imports, structure) with tag-filtered checks. |
| `utopia mcp` | ✓ | Boot MCP server exposing `describe`, `describe_routes`, `doctor`, and hooks analysis for AI agents. |
| `utopia bump` | ✓ | Bump all `utopia_*` deps in pubspec.yaml to latest pub.dev versions. |
| `utopia update` | ✓ | Self-update from pub.dev. |
| `utopia --version` | ✓ | Print the CLI version. |

### `utopia add screen`

Scaffolds three files at `lib/screen/<name>/`:

```
lib/screen/<name>/
├── <name>_screen.dart           # HookWidget — wires state into view
├── state/<name>_state.dart      # value class + use<Name>State() hook
└── view/<name>_view.dart        # pure StatelessWidget
```

```
utopia add screen <name> [options]

Options:
  -r, --route             Route path served by this screen (default: /<name>)
  -d, --output-directory  Parent directory (default: lib/screen)
      --json              Emit a machine-readable summary to stdout
```

After scaffolding, the CLI prints a snippet you can paste into
`lib/app/app_routing.dart` to register the new route.

The brick is vendored from
[`Utopia-USS/utopia-mason`](https://github.com/Utopia-USS/utopia-mason)'s
`screen` brick and shipped in-repo for atomic versioning.

### `utopia hooks analyze`

Fast convention analysis for `utopia_hooks` projects. This is the canonical
CLI implementation of the Screen/State/View quality rules that AI-agent
adapters and CI can share.

```
utopia hooks analyze [paths...] [options]

Options:
  -C, --project-root  Project (or workspace) root. Defaults to CWD.
  -f, --file          File(s) to analyze. Repeat or comma-separate. Positional paths are also accepted.
      --changed       Analyze changed git files. Default when no target is supplied.
      --all           Analyze every Dart file under the project root.
      --format        human | json. Default: human.
  -o, --output        JSON output file. "-" writes to stdout.
      --fail-on       error | warning | info | never. Default: warning.
```

Use `utopia hooks analyze --hook-json` from agent hook adapters,
`utopia hooks analyze --file <path>` for manual one-file validation,
`utopia hooks analyze lib/a.dart lib/b.dart` for batch path validation,
`utopia hooks analyze` for changed-file validation, and
`utopia hooks analyze --all --format=json` for CI-style scans.

### `utopia init agents`

Writes `AGENTS.md` into the current directory with the canonical CLI
workflow for provider-neutral agents: inspect with `describe`, generate
with `add screen --json`, and validate with `doctor`.

This command does not write `.claude/`; Claude Code skills are configured
separately with `utopia init skills`.

```
utopia init agents [options]

Options:
  -d, --output-directory  Project root (default: ".")
  -f, --force             Overwrite an existing AGENTS.md
```

### `utopia init skills`

Writes `.claude/settings.json` + `.claude/README.md` into the current
directory, pre-registering the
[`Utopia-USS/utopia-flutter-skills`](https://github.com/Utopia-USS/utopia-flutter-skills)
marketplace and enabling the `utopia-hooks` plugin by default.

Intended for projects created with `--no-skills`, or any existing
Flutter project that wants to opt in.

```
utopia init skills [options]

Options:
  -d, --output-directory  Project root (default: ".")
  -f, --force             Overwrite an existing .claude/settings.json
```

### `utopia describe`

Emit project structure as JSON. Output schema is versioned
(`schema_version: 1`) and documented in [`doc/describe_schema.md`](doc/describe_schema.md);
downstream tooling (skills, MCP) pins to it.

```
utopia describe [options]

Options:
  -C, --project-root  Project (or workspace) root. Defaults to CWD.
  -o, --output        Output file. Defaults to `-` (stdout).
      --[no-]pretty   Pretty-print JSON. Default on.
      --routes-only   Only the routes view (useful for piping).
```

Detects monorepo workspaces (Melos), screen kinds (routed / sheet /
dialog / non_routed_page / subscreen_fragment / bare_screen /
auto_route_page), routing strategy, global states, services, and
foreign-framework artefacts. Discovery notes flag unresolved
references rather than silently skipping them.

### `utopia doctor`

Repo-wide audit. Complements the per-file `quality_check.sh`
PostToolUse hook in the `utopia-hooks` skill - that fires on every
edit; doctor catches drift across the whole project on demand and in
CI.

```
utopia doctor [options]

Options:
  -C, --project-root  Project (or workspace) root. Defaults to CWD.
  -o, --output        Output file. Defaults to `-` (stdout).
      --check=...     Run only these tags / sub-tags / rule IDs.
      --skip=...      Exclude these tags / sub-tags / rule IDs.
  -f, --file          Run shared per-file hooks analysis for these Dart files.
      --strict        Bypass activation gates; run all checks.
      --[no-]pretty   Pretty-print JSON. Default on.
      --human         Also print a human-readable summary to stderr.
      --fail-on       error | warning | info | never. Default: error.
```

Tag taxonomy (used by `--check` / `--skip`):

| Tag | Covers |
|---|---|
| `setup` | pubspec coherence, `utopia_lints` extension, `.claude/` settings, plugin enablement |
| `conventions` | per-file utopia_hooks rules scanned repo-wide |
| `artifacts` | foreign framework patterns. Sub-tags: `artifacts:bloc`, `artifacts:riverpod`, `artifacts:provider`, `artifacts:mobx`, `artifacts:getx`, `artifacts:stateful` |
| `imports` | banned direct imports (`package:flutter_hooks/`) |
| `structure` | cross-file invariants (orphan state files, etc.) |

Default behaviour: `artifacts:bloc` runs only if `flutter_bloc` is in
the pubspec; same for `:riverpod`, `:provider`, `:mobx`, `:getx`.
`setup` and `conventions` run on any project that declares
`utopia_arch` or `utopia_hooks`. `--strict` overrides all gates.
Use `doctor --file <paths> -o -` when an editor hook or agent wants the
same per-file rule set as `utopia hooks analyze` under the doctor JSON
contract.

Each finding carries `rule_id`, `severity`, `message`, an optional
`file`/`line` location, and `package` - the name of the package the
finding belongs to (matching describe's `packages[].name`; `null` for
project-root-level findings), so monorepo agents don't have to infer
the package from path prefixes. All `file` paths in JSON output are
project-root-relative and always use forward slashes, on Windows too.

### `utopia mcp` - MCP server for AI agents

Exposes operational tools as a [Model Context Protocol](https://modelcontextprotocol.io)
server over stdio. Scoped intentionally: only tools that earn their
keep on the MCP-vs-Bash test - i.e. called multiple times per session
with structured output the agent reasons over.

```
utopia mcp
```

Tools registered:

| Tool | Wraps | Why MCP vs Bash |
|---|---|---|
| `describe` | `utopia describe` | Structured JSON output, called repeatedly across a refactor session |
| `describe_routes` | `utopia describe --routes-only` | Same; subset for cheap path enumeration |
| `doctor` | `utopia doctor` | Structured findings array agents reason over (`{file, line, rule_id, severity}`) |
| `analyze_hooks_files` | `utopia hooks analyze --file` | Per-edit utopia_hooks analysis gate with structured findings |
| `analyze_hooks_changed` | `utopia hooks analyze` | Changed-file analysis gate for Codex/agent validation before final response |

Generators (`utopia create *`, `utopia add screen`, `utopia init
skills`) are **not** exposed via MCP - they're one-shot, return only
"done"/"error", and gain nothing from the MCP transport. Agents
should invoke them via Bash.

### Agent workflow without Claude Code

Codex and shell/CI agents do not need the Claude Code skills plugin. Use
the deterministic CLI surfaces directly:

```bash
utopia describe -o -
utopia add screen profile --json
utopia doctor --fail-on=warning --human -o -
```

Keep JSON on stdout for machine parsing. Human summaries, when enabled,
go to stderr.

Example: register in your Claude Code config:

```json
{
  "mcpServers": {
    "utopia": { "command": "utopia", "args": ["mcp"] }
  }
}
```

### `utopia create flutter_app`

```
utopia create flutter_app <name> [options]

Options:
  -o, --org              Org in reverse-domain notation
                         (default: io.utopiasoft)
  -p, --platforms        Comma-separated Flutter platforms
                         (default: android,ios)
  -d, --output-directory Where to create the project (default: .)
      --application-id   iOS bundle / Android app id
                         (default: <org>.<name>)
      --description      Project description
                         (default: "A Utopia Flutter project.")
      --[no-]skills      Generate .claude/ skills config (default: on)
      --[no-]pub-get     Run `flutter pub get` after generation
      --[no-]git         Initialize a git repo
```

### `utopia update`

Checks pub.dev for a newer release and runs
`dart pub global activate utopia_cli <latest>` when one is available.

## What you get from `flutter_app`

```
my_app/
├── .claude/                   # Claude Code skills pre-registered
│   ├── settings.json
│   └── README.md
├── lib/
│   ├── app/                   # routing, theming, top-level providers
│   ├── common/                # shared widgets and constants
│   ├── screen/
│   │   ├── splash/
│   │   └── counter/           # sample Screen/State/View
│   │       ├── counter_screen.dart
│   │       ├── state/counter_state.dart
│   │       └── view/counter_view.dart
│   └── util/
├── DEVELOPMENT.md             # Screen/State/View overview
├── README.md
└── pubspec.yaml
```

The counter feature demonstrates the Utopia pattern in three small
files — copy it as the starting point for your own screens.

## `.utopia.yaml`

The repository contains an experimental config loader, but released
commands do not currently read `.utopia.yaml`. Prefer explicit flags for
now; this surface is intentionally not documented as active until a
command has tests proving it consumes the config.

## Migrating from `utopia_arch_cli`

The `utopia_arch_cli` executable (versions `0.1.0-dev.*`) has been
renamed to `utopia`. The old executable still works in `0.2.0` and prints
a deprecation notice; it will be removed in `0.3.0`.

| Old | New |
|---|---|
| `utopia_arch_cli --name my_app --org io.utopiasoft` | `utopia create flutter_app my_app --org io.utopiasoft` |
| `dart pub global activate utopia_arch_cli` | `dart pub global activate utopia_cli` |

Generated project structure is unchanged apart from the new sample
counter feature and `.claude/` directory.

## Contributing

See [`CONTRIBUTING.md`](CONTRIBUTING.md). The bricks ship in-repo under
`bricks/` — when you edit a brick, the next `dart run bin/utopia.dart …`
picks it up immediately (no `mason get` required).

## License

BSD 2-Clause. See [`LICENSE`](LICENSE).
