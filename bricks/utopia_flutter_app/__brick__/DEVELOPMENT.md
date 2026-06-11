# {{project_name}} — development guide

This project follows the **Utopia Screen / State / View** pattern, backed
by [`utopia_arch`](https://pub.dev/packages/utopia_arch) and
[`utopia_hooks`](https://pub.dev/packages/utopia_hooks).

A complete example lives in `lib/screen/counter/` — read it first; it's
three small files.

## The pattern, in 60 seconds

Every screen is a triad:

```
lib/screen/<feature>/
├── <feature>_screen.dart   # HookWidget — calls hooks, owns nothing else
├── state/<feature>_state.dart   # value class + use<Feature>State() hook
└── view/<feature>_view.dart    # StatelessWidget — receives state, no hooks
```

Rules:

- **Screen** is a `HookWidget`. It runs hooks (e.g. `useCounterState()`),
  hands the resulting state to the view, and does nothing else.
- **State** is an immutable value class. Built by a top-level hook
  function `use<Feature>State()` that composes other hooks.
- **View** is a pure `StatelessWidget`. It takes the state as a
  constructor argument. It must not call hooks or read providers — that
  keeps it cheap to preview, test, and screenshot.

## Adding a new screen

You can either copy the counter and rename, or scaffold a fresh triad
with Claude Code:

```
claude
/utopia-hooks
```

The skill will ask for the screen name, generate the three files in the
right layout, and wire the route into `lib/app/app_routing.dart`.

## Code generation

This project uses `freezed`, `json_serializable`, and
`utopia_localization_generator`. Run the generator on demand:

```
dart run build_runner build --delete-conflicting-outputs
```

Or in watch mode during development:

```
dart run build_runner watch --delete-conflicting-outputs
```

If your team uses FVM, prefix with `fvm`.

## Localization

`lib/app/app_localizations.dart` is wired through
[`utopia_localization_utils`](https://pub.dev/packages/utopia_localization_utils).
Update the Google Sheets `docId` and `sheetId` constants there before
running the build.

## Linting

`analysis_options.yaml` includes
[`utopia_lints`](https://pub.dev/packages/utopia_lints). Run:

```
dart analyze
dart format --line-length=120 lib test
```

## Learn more

- Utopia hooks reference: <https://pub.dev/packages/utopia_hooks>
- Utopia arch reference: <https://pub.dev/packages/utopia_arch>
- Skills marketplace: <https://github.com/Utopia-USS/utopia-flutter-skills>
- Generator CLI: <https://github.com/Utopia-USS/utopia-cli>
