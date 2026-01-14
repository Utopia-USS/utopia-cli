# How to Update Template in Utopia Arch CLI

When you update the `utopia-flutter-template` repository on GitHub, you need to update it in the CLI package as well.

## Steps to Update Template

### 1. Update Template from GitHub

Run the setup script to fetch the latest version:

```bash
./scripts/setup_template.sh
```

This will:
- Clone the latest version from GitHub
- Copy files to `bricks/utopia_template/__brick__/`
- Replace `DART_PACKAGE_NAME` with `{{package_name}}`
- Clean up temporary files

### 2. Test Locally

Test that the updated template works:

```bash
# Test the CLI locally
dart run bin/utopia_arch_cli.dart --name test_app --org io.test

# Or test as global tool
dart pub global activate --source path .
utopia_arch_cli --name test_app --org io.test
```

### 3. Update Version

Increment the version in `pubspec.yaml`:

```yaml
version: 0.1.0-dev.X  # Increment the version number
```

### 4. Update CHANGELOG

Add an entry to `CHANGELOG.md`:

```markdown
## [0.1.0-dev.X] - YYYY-MM-DD

### Updated
- Updated template from utopia-flutter-template repository
```

### 5. Test Publication

```bash
dart pub publish --dry-run
```

### 6. Publish

```bash
dart pub publish
```

## Quick Update Command

For a quick update, you can run:

```bash
# 1. Update template
./scripts/setup_template.sh

# 2. Test locally (optional but recommended)
dart run bin/utopia_arch_cli.dart --name test_app --org io.test

# 3. Update version in pubspec.yaml (manually)
# 4. Update CHANGELOG.md (manually)
# 5. Publish
dart pub publish --dry-run
dart pub publish
```

## Notes

- Always test locally before publishing
- Make sure template files are properly templated (DART_PACKAGE_NAME → {{package_name}})
- Check that all new files from template are included
- Verify that .gitignore excludes unnecessary files
