# Utopia Template Brick

This brick contains the template for creating Flutter projects based on utopia_arch.

## Setup Instructions

To populate this brick with the actual template:

1. Clone the utopia-flutter-template repository:
   ```bash
   git clone https://github.com/Utopia-USS/utopia-flutter-template.git temp_template
   ```

2. Copy all files from the template to `__brick__/` directory:
   ```bash
   cp -r temp_template/* __brick__/
   ```

3. Replace all occurrences of `DART_PACKAGE_NAME` with `{{package_name}}` in the template files:
   ```bash
   find __brick__ -type f -exec sed -i '' 's/DART_PACKAGE_NAME/{{package_name}}/g' {} +
   ```

4. Clean up:
   ```bash
   rm -rf temp_template
   ```

## Variables

- `{{project_name}}` - Project name
- `{{org_name}}` - Organization name
- `{{package_name}}` - Full package name (org_name.project_name)
- `{{platforms}}` - Platforms to support
- `{{dart_package_name}}` - Same as package_name (for backward compatibility)

## Note

The `__brick__` directory should contain the actual template files from utopia-flutter-template repository.
