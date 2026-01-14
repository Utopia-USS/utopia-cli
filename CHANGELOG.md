# Changelog

All notable changes to this project will be documented in this file.

## [0.1.0-dev.6] - 2026-01-14

### Updated
- Updated template from utopia-flutter-template repository

## [0.1.0-dev.5] - 2026-01-14

### Fixed
- Fixed filename reference: changed `up-localizations.dart` to `app_localizations.dart` in documentation and logs

## [0.1.0-dev.4] - 2026-01-14

### Changed
- Removed automatic `build_runner build` execution
- Users must now manually update `app_localizations.dart` with doc id and sheet id before running code generation
- Updated documentation to reflect manual code generation step

## [0.1.0-dev.3] - 2026-01-14

### Fixed
- Fixed brick path resolution for globally installed packages
- Improved brick discovery logic to check multiple possible locations in pub cache

## [0.1.0-dev.2] - 2026-01-14

### Changed
- Updated README.md to reflect automated setup process
- Removed manual "Next Steps" section as all steps are now automated

## [0.1.0-dev.1] - 2026-01-14

### Added
- Initial pre-release
- Create Flutter projects based on utopia_arch
- Support for custom project name and organization
- Platform selection (android, ios)
- FVM integration
- Automatic Flutter project structure creation
- Automatic git initialization
- Automatic dependency installation
- Template application with Utopia architecture