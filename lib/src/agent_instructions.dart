const agentInstructionsFileName = 'AGENTS.md';

const agentInstructionsMarkdown = '''
# Utopia Agent Workflow

This project uses Utopia conventions for Flutter code:

- Screens live under `lib/screen/<feature>/`.
- Each feature is split into Screen, State, and View files.
- Views stay pure and receive data through constructor arguments.
- State files own hooks and actions.
- Cross-feature services are injected through `utopia_hooks` providers.

## Inspect

Use the CLI before making structural changes:

```bash
utopia describe -o -
```

For routes only:

```bash
utopia describe --routes-only -o -
```

## Generate

Use the CLI to scaffold new screens:

```bash
utopia add screen profile --json
```

The JSON result tells you which files were written and whether route
registration still needs a manual edit.

## Validate

Run repo-wide validation:

```bash
utopia doctor --fail-on=warning --human -o -
```

For per-edit checks:

```bash
utopia doctor --file lib/screen/profile/state/profile_state.dart -o -
```

Keep machine-readable JSON on stdout. Human summaries, when enabled, go
to stderr.

## Claude Code

Claude Code skills are optional. To enable them, run:

```bash
utopia init skills
```

That writes `.claude/settings.json` and enables the Utopia skills
marketplace for Claude Code. Codex and shell/CI agents can use the CLI
commands above without Claude Code.
''';
