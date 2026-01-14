# Setup Instructions

## Prerequisites

- Dart SDK >= 3.0.0
- Git (for cloning the template repository)

## Initial Setup

1. **Install dependencies:**
   ```bash
   dart pub get
   ```

2. **Setup the template brick:**
   
   The template brick needs to be populated with files from the utopia-flutter-template repository.
   
   **Option A: Using the setup script (recommended)**
   ```bash
   chmod +x scripts/setup_template.sh
   ./scripts/setup_template.sh
   ```
   
   **Option B: Manual setup**
   
   See `scripts/setup_template.md` for detailed manual instructions.

3. **Verify the setup:**
   ```bash
   # Check that the brick directory has files
   ls -la bricks/utopia_template/__brick__/
   ```

## Testing Locally

1. **Test the CLI locally:**
   ```bash
   dart run bin/utopia_arch_cli.dart --name test_app --org io.test
   ```

2. **Test as a global tool (local):**
   ```bash
   dart pub global activate --source path .
   utopia_arch_cli --name test_app --org io.test
   ```

## Development

### Project Structure

```
utopia_arch_cli/
├── bin/
│   └── utopia_arch_cli.dart     # Main CLI entry point
├── bricks/
│   └── utopia_template/          # Mason brick template
│       ├── brick.yaml            # Brick configuration
│       └── __brick__/            # Template files (populated by setup script)
├── scripts/
│   ├── setup_template.sh         # Script to populate template
│   └── setup_template.md         # Manual setup instructions
├── sources/                      # Documentation and planning
├── pubspec.yaml
└── README.md
```

### Making Changes

1. **Update CLI logic:** Edit `bin/utopia_arch_cli.dart`
2. **Update template:** Edit files in `bricks/utopia_template/__brick__/`
3. **Update brick config:** Edit `bricks/utopia_template/brick.yaml`

### Testing Changes

After making changes, test locally:

```bash
# Run directly
dart run bin/utopia_arch_cli.dart --name test_app --org io.test

# Or activate and test
dart pub global activate --source path .
utopia_arch_cli --name test_app --org io.test
```

## Publishing

Before publishing:

1. **Ensure template is populated:**
   ```bash
   ls -la bricks/utopia_template/__brick__/
   ```
   The `__brick__` directory should contain template files.

2. **Test thoroughly:**
   - Test local execution
   - Test global activation
   - Test on different platforms if possible

3. **Check package:**
   ```bash
   dart pub publish --dry-run
   ```

4. **Publish:**
   ```bash
   dart pub publish
   ```

## Troubleshooting

### Brick not found error

If you get "Brick not found" error:

1. Make sure you ran the setup script:
   ```bash
   ./scripts/setup_template.sh
   ```

2. Verify the brick directory exists:
   ```bash
   ls -la bricks/utopia_template/__brick__/
   ```

3. Check that files were copied correctly

### Template files missing

If the `__brick__` directory is empty or only has `.gitkeep`:

1. Run the setup script again
2. Or follow manual setup instructions in `scripts/setup_template.md`

### Dependencies not found

If you get import errors:

1. Run `dart pub get`
2. Make sure you're using Dart SDK >= 3.0.0
