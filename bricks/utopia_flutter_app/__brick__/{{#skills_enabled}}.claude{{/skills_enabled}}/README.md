# Claude Code skills

This project ships with [`utopia-skills`](https://github.com/Utopia-USS/utopia-skills)
pre-registered as a Claude Code marketplace.

## What's included

| Skill | Slash command | Purpose |
|---|---|---|
| `utopia-hooks` | `/utopia-hooks` | Scaffold a Screen/State/View triad following the Utopia pattern. |
| `utopia-hooks-migrate-bloc` | `/utopia-hooks-migrate-bloc:migrate` | Migrate legacy `flutter_bloc` code to `utopia_hooks`. |

## Using it

1. Install Claude Code (one-time, machine-wide):
   ```
   npm install -g @anthropic-ai/claude-code
   ```
2. From your project root, run:
   ```
   claude
   ```
3. In the Claude Code session, try:
   ```
   /utopia-hooks
   ```

If the marketplace did not auto-register on first run, register it manually:

```
/plugin marketplace add Utopia-USS/utopia-skills
/plugin enable utopia-hooks
```

## Disabling skills

Delete this `.claude/` directory. Skills are opt-in and have no effect on
the runtime behavior of your Flutter app.
