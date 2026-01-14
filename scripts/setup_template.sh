#!/bin/bash

# Script to setup the utopia_template brick with files from utopia-flutter-template repository

set -e

BRICK_DIR="bricks/utopia_template"
TEMPLATE_DIR="$BRICK_DIR/__brick__"
TEMP_DIR="temp_utopia_template"

echo "🚀 Setting up Utopia template brick..."

# Check if template directory exists
if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "❌ Error: $TEMPLATE_DIR does not exist"
    exit 1
fi

# Clone the template repository
echo "📥 Cloning utopia-flutter-template repository..."
if [ -d "$TEMP_DIR" ]; then
    echo "⚠️  Removing existing temp directory..."
    rm -rf "$TEMP_DIR"
fi

git clone https://github.com/Utopia-USS/utopia-flutter-template.git "$TEMP_DIR"

# Copy files to brick directory
echo "📋 Copying files to brick directory..."
cp -r "$TEMP_DIR"/* "$TEMPLATE_DIR/"

# Remove .git directory if it was copied
if [ -d "$TEMPLATE_DIR/.git" ]; then
    rm -rf "$TEMPLATE_DIR/.git"
fi

# Replace DART_PACKAGE_NAME with {{package_name}} in all files
echo "🔄 Replacing DART_PACKAGE_NAME with {{package_name}}..."
find "$TEMPLATE_DIR" -type f \( -name "*.dart" -o -name "*.yaml" -o -name "*.yml" -o -name "*.md" -o -name "*.json" -o -name "*.gradle" -o -name "*.xml" -o -name "*.plist" -o -name "*.xcconfig" \) -exec sed -i '' 's/DART_PACKAGE_NAME/{{package_name}}/g' {} +

# Clean up
echo "🧹 Cleaning up..."
rm -rf "$TEMP_DIR"

echo "✅ Template setup complete!"
echo ""
echo "📝 Next steps:"
echo "   1. Review the template files in $TEMPLATE_DIR"
echo "   2. Test the brick: mason make utopia_template"
echo "   3. Update any additional placeholders if needed"
