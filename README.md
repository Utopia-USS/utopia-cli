# Utopia CLI 🦄

A command-line scaffolder for Flutter projects built on
[`utopia_arch`](https://pub.dev/packages/utopia_arch) +
[`utopia_hooks`](https://pub.dev/packages/utopia_hooks), with first-class
[Claude Code skills](https://github.com/Utopia-USS/utopia-flutter-skills)
integration baked into every generated project.

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
flutter run
```

You now have a runnable Flutter app with a sample Screen/State/View
feature and Claude Code skills pre-registered. Open Claude Code from the
project and try `/utopia-hooks` to scaffold your next screen.

## Commands

| Command | Status | What it does |
|---|---|---|
| `utopia create flutter_app <name>` | ✓ | Scaffold a Utopia Flutter app. |
| `utopia create flutter_package <name>` | ✓ | Scaffold a Utopia Flutter package. |
| `utopia update` | ✓ | Self-update from pub.dev. |
| `utopia --version` | ✓ | Print the CLI version. |
| `utopia add screen <name>` | ✓ | Scaffold a Screen/State/View triad in an existing project. |
| `utopia add state <name>` | planned | Scaffold a global state hook. |
| `utopia migrate bloc` | planned | Migrate `flutter_bloc` code to `utopia_hooks`. |

Planned commands appear in `--help` but exit with a "coming soon" notice
for now.

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
```

After scaffolding, the CLI prints a snippet you can paste into
`lib/app/app_routing.dart` to register the new route.

The brick is vendored from
[`Utopia-USS/utopia-mason`](https://github.com/Utopia-USS/utopia-mason)'s
`screen` brick and shipped in-repo for atomic versioning.

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

## `.utopia.yaml` (optional)

You can ship sensible defaults per-project. The CLI walks up from the
current directory looking for `.utopia.yaml`:

```yaml
org: io.utopiasoft
platforms: android,ios
skills: true
lints: utopia_lints
```

When present, these values are used as defaults for the matching `create`
flags. Nothing is written to `$HOME`.

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
