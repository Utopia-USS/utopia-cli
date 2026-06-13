# Contributing to Utopia CLI

## Local development

```bash
git clone https://github.com/Utopia-USS/utopia-cli
cd utopia-cli
dart pub get
```

Run the CLI locally:

```bash
dart run bin/utopia.dart create flutter_app smoke_test -d /tmp
```

Run the test suite:

```bash
dart test
```

Lint:

```bash
dart analyze
dart format --line-length=120 .
```

## Repository layout

```
utopia_cli/
├── bin/                              # executables
│   ├── utopia.dart                   # main entrypoint
│   └── utopia_arch_cli.dart          # deprecated shim (remove in 0.3.0)
├── lib/
│   ├── utopia_cli.dart               # public re-exports (tests only)
│   └── src/
│       ├── command_runner.dart
│       ├── version.dart              # synced from pubspec.yaml
│       ├── strings.dart              # all user-facing copy
│       ├── config/
│       │   └── utopia_config.dart    # .utopia.yaml reader
│       ├── commands/
│       │   ├── create/
│       │   ├── update_command.dart
│       │   └── stub_commands.dart    # Phase-2 placeholders
│       └── generators/
│           └── brick_locator.dart
├── bricks/                           # in-repo Mason bricks
│   ├── utopia_flutter_app/
│   └── utopia_flutter_package/
├── test/
└── tool/
    └── sync_version.dart             # regen lib/src/version.dart
```

## Editing a brick

Bricks live under `bricks/<name>/__brick__/`. Edit files directly;
the next `dart run bin/utopia.dart create ...` picks them up.
No `mason get` is required because the CLI uses `Brick.path(...)`.

Files with Mustache-style placeholders (`{{var}}`, `{{#var}}…{{/var}}`)
follow the standard Mason syntax. Variables are declared in the brick's
`brick.yaml`.

## Bumping the version

1. Bump `version:` in `pubspec.yaml`.
2. Update `CHANGELOG.md`.
3. Regenerate `lib/src/version.dart`:
   ```bash
   dart run tool/sync_version.dart
   ```
4. Commit, tag `vX.Y.Z`, push.

## Publishing to pub.dev

(Done by maintainers only.)

```bash
dart pub publish --dry-run
dart pub publish
```

## Marketing copy

All user-facing strings live in [`lib/src/strings.dart`](lib/src/strings.dart).
Edit copy there; reviewers can see all changes in one diff.

## Adding a new `create` subcommand

1. Add a brick under `bricks/<name>/`.
2. Add a `CreateSubCommand` subclass under
   `lib/src/commands/create/<name>_command.dart` that points at the
   brick and provides `buildVars()`.
3. Register the new command in
   `lib/src/commands/create/create_command.dart`.
4. Add a test under `test/commands/`.

## License

BSD 2-Clause. By contributing you agree to release your changes under
the same license. See [`LICENSE`](LICENSE).
