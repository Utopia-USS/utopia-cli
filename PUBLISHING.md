# Publishing Guide - Utopia CLI

This guide explains how to publish `utopia_arch_cli` to pub.dev so it can be used globally by anyone, just like Very Good Ventures' `very_good_cli`.

## Prerequisites

Before publishing, make sure you have:

1. **Dart SDK** installed and in your PATH
2. **pub.dev account** - Create one at https://pub.dev
3. **Verified email** on pub.dev account
4. **Access to publish** - Make sure you're logged in: `dart pub login`

## Pre-Publication Checklist

### 1. Verify Package Name Availability

Check if `utopia_arch_cli` is available on pub.dev:
- Visit: https://pub.dev/packages/utopia_arch_cli
- If it doesn't exist, the name is available!

### 2. Ensure Template is Populated

Make sure the template brick is fully populated:

```bash
# Check that __brick__ directory has files (not just .gitkeep)
ls -la bricks/utopia_template/__brick__/

# If empty, run setup script:
./scripts/setup_template.sh
```

### 3. Review pubspec.yaml

Ensure `pubspec.yaml` has all required fields:
- ✅ `name`: utopia_arch_cli
- ✅ `description`: Clear description
- ✅ `version`: Semantic version (0.1.0)
- ✅ `homepage`: GitHub repository URL
- ✅ `executables`: utopia_arch_cli:

### 4. Check Dependencies

Current dependencies:
- `args: ^2.4.0` ✅
- `mason: ^0.1.0-dev.50` ⚠️ (dev version - check if stable available)
- `path: ^1.8.3` ✅

**Note:** If `mason` has a stable version, consider using it instead of dev version.

### 5. Verify Files Structure

Required files:
- ✅ `bin/utopia_arch_cli.dart` - Main executable
- ✅ `bricks/utopia_template/` - Template brick
- ✅ `README.md` - Documentation
- ✅ `LICENSE` - License file
- ✅ `CHANGELOG.md` - Changelog

### 6. Test Locally

Before publishing, test everything:

```bash
# Install dependencies
dart pub get

# Test locally
dart run bin/utopia_arch_cli.dart --name test_app --org io.test

# Test as global tool (local)
dart pub global activate --source path .
utopia_arch_cli --name test_app --org io.test
```

## Publishing Steps

### Step 1: Login to pub.dev

```bash
dart pub login
```

Follow the instructions to authenticate.

### Step 2: Dry Run (Test Publication)

This validates your package without actually publishing:

```bash
dart pub publish --dry-run
```

**Fix any errors or warnings** before proceeding.

Common issues:
- Missing files (check .gitignore)
- Invalid pubspec.yaml format
- Missing documentation
- Files too large (pub.dev has size limits)

### Step 3: Actual Publication

Once dry-run passes:

```bash
dart pub publish
```

You'll be asked to confirm. Type `y` to proceed.

### Step 4: Verify Publication

After publishing:
1. Visit https://pub.dev/packages/utopia_arch_cli
2. Wait a few minutes for indexing
3. Verify package appears correctly

## Post-Publication

### Users Can Now Install Globally

After publication, users can install globally:

```bash
dart pub global activate utopia_arch_cli
```

Then use it:

```bash
utopia_arch_cli --name my_app --org io.utopiasoft
```

### Updating the Package

When you need to publish updates:

1. **Update version** in `pubspec.yaml`:
   ```yaml
   version: 0.1.1  # Increment version
   ```

2. **Update CHANGELOG.md** with changes

3. **Test locally**:
   ```bash
   dart pub publish --dry-run
   ```

4. **Publish**:
   ```bash
   dart pub publish
   ```

## Important Notes

### Package Size

- pub.dev has size limits
- Template files in `bricks/` will be included in package
- If package is too large, consider:
  - Removing unnecessary files
  - Using .gitignore to exclude files
  - Optimizing template

### Version Constraints

- Use semantic versioning: `MAJOR.MINOR.PATCH`
- Breaking changes: increment MAJOR
- New features: increment MINOR
- Bug fixes: increment PATCH

### Executables

The `executables` section in pubspec.yaml makes the CLI available globally:

```yaml
executables:
  utopia_arch_cli:
```

This allows users to run `utopia_arch_cli` after `dart pub global activate`.

## Troubleshooting

### "Package name already taken"

If `utopia_arch_cli` is taken, choose an alternative:
- `utopia_flutter_cli`
- `utopia_cli_tool`
- `utopia_arch_tool`

Update `name` in pubspec.yaml and re-run.

### "Package validation failed"

Check:
- All required files present
- pubspec.yaml is valid
- No syntax errors
- Files not too large

### "Authentication failed"

- Make sure you're logged in: `dart pub login`
- Verify email on pub.dev account
- Check credentials

## References

- [pub.dev Publishing Guide](https://dart.dev/tools/pub/publishing)
- [Package Scoring](https://pub.dev/help/scoring)
- [Very Good CLI Example](https://pub.dev/packages/very_good_cli)
