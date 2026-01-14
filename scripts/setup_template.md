# Setup Template Instructions

## Manual Setup

To populate the `bricks/utopia_template/__brick__` directory with the actual template:

### Option 1: Using the setup script (macOS/Linux)

```bash
chmod +x scripts/setup_template.sh
./scripts/setup_template.sh
```

### Option 2: Manual steps

1. **Clone the template repository:**
   ```bash
   git clone https://github.com/Utopia-USS/utopia-flutter-template.git temp_template
   ```

2. **Copy files to brick directory:**
   ```bash
   cp -r temp_template/* bricks/utopia_template/__brick__/
   ```

3. **Remove .git directory if copied:**
   ```bash
   rm -rf bricks/utopia_template/__brick__/.git
   ```

4. **Replace DART_PACKAGE_NAME with {{package_name}}:**
   
   On macOS:
   ```bash
   find bricks/utopia_template/__brick__ -type f \( -name "*.dart" -o -name "*.yaml" -o -name "*.yml" -o -name "*.md" -o -name "*.json" -o -name "*.gradle" -o -name "*.xml" -o -name "*.plist" -o -name "*.xcconfig" \) -exec sed -i '' 's/DART_PACKAGE_NAME/{{package_name}}/g' {} +
   ```
   
   On Linux:
   ```bash
   find bricks/utopia_template/__brick__ -type f \( -name "*.dart" -o -name "*.yaml" -o -name "*.yml" -o -name "*.md" -o -name "*.json" -o -name "*.gradle" -o -name "*.xml" -o -name "*.plist" -o -name "*.xcconfig" \) -exec sed -i 's/DART_PACKAGE_NAME/{{package_name}}/g' {} +
   ```

5. **Clean up:**
   ```bash
   rm -rf temp_template
   ```

## Additional Placeholders to Replace

After copying the template, you may need to replace additional placeholders:

- `DART_PACKAGE_NAME` → `{{package_name}}` (already done by script)
- Any other project-specific values that should be templated

## Testing the Brick

After setup, test the brick locally:

```bash
# Install mason CLI if not already installed
dart pub global activate mason_cli

# Test the brick
mason make utopia_template --project_name test_app --org_name io.test --package_name io.test.test_app
```

## Notes

- The `__brick__` directory should contain all files from the utopia-flutter-template repository
- Make sure to preserve the directory structure
- Exclude unnecessary files like `.git`, `.idea`, etc. (they should be in .gitignore)
