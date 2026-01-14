# Utopia Arch CLI

A CLI tool for creating Flutter projects based on [utopia_arch](https://pub.dev/packages/utopia_arch).

## Installation

```bash
dart pub global activate utopia_arch_cli
```

Make sure you have the Dart SDK in your PATH.

> **Note:** For development setup, see [SETUP.md](SETUP.md)

## Usage

```bash
utopia_arch_cli --name <project_name> --org <organization>
```

### Options

- `--name` / `-n` (required): Project name (must not contain '-' character)
- `--org` / `-o` (required): Organization name in reverse domain notation (e.g., "io.utopiasoft")
- `--platforms` / `-p` (optional): Platforms to support (default: "android,ios")
- `--output` / `-d` (optional): Output directory (default: current directory)
- `--help` / `-h`: Show help message

### Examples

```bash
# Create a project in the current directory
utopia_arch_cli --name my_app --org io.utopiasoft

# Create a project with specific platforms
utopia_arch_cli -n my_app -o io.utopiasoft -p android,ios

# Create a project in a specific directory
utopia_arch_cli -n my_app -o io.utopiasoft -d ~/projects
```

## Requirements

- Dart SDK >= 3.0.0
- FVM (Flutter Version Manager) - [Install](https://fvm.app/documentation/getting-started)
- Flutter SDK (will be installed by FVM)

## What's Included

When you create a project with `utopia_arch_cli`, everything is set up automatically:

- ✅ Complete Flutter project structure (android/, ios/, web/, etc.)
- ✅ Git repository initialized
- ✅ Dependencies installed (`pub get`)
- ✅ All files staged with `git add`

## Next Steps

After creating a project, you need to:

1. **Update localization configuration:**
   - Open `app_localizations.dart` in your project
   - Add your Google Sheets `doc id` and `sheet id`
   
2. **Run code generation:**
   ```bash
   fvm dart run build_runner build
   ```
   (or `dart run build_runner build` if not using FVM)

Then your project is ready to use!

## Features

- ✅ Creates complete Flutter project structure (android/, ios/, web/, etc.)
- ✅ Applies Utopia template with utopia_arch architecture
- ✅ Automatically initializes git repository
- ✅ Configures FVM if .fvmrc is present in template
- ✅ Sets up proper project structure with all necessary dependencies
- ✅ No need to run `flutter create` manually - everything is automated!

## License

See LICENSE file for details.
