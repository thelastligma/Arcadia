#!/bin/bash

# Arcadia Installer Script
# This script helps install Arcadia from the release archive

set -e

echo "🚀 Arcadia Installer"
echo "===================="

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This installer is for macOS only."
    exit 1
fi

# Determine the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Look for the .app bundle
APP_BUNDLE=$(find "$SCRIPT_DIR" -name "Arcadia.app" -type d | head -n1)

if [ -z "$APP_BUNDLE" ]; then
    echo "❌ Error: Could not find Arcadia.app in the current directory."
    echo "Make sure you've extracted the archive first."
    exit 1
fi

echo "Found Arcadia.app at: $APP_BUNDLE"

# Install to /Applications
INSTALL_PATH="/Applications/Arcadia.app"

echo "Installing to $INSTALL_PATH..."

# Remove existing installation if present
if [ -d "$INSTALL_PATH" ]; then
    echo "Removing existing Arcadia installation..."
    rm -rf "$INSTALL_PATH"
fi

# Copy the app bundle
cp -R "$APP_BUNDLE" "$INSTALL_PATH"

# Make it executable
chmod +x "$INSTALL_PATH/Contents/MacOS/Arcadia"

echo "✅ Arcadia has been installed successfully!"
echo "You can now launch it from /Applications or Spotlight."
echo ""
echo "Launch with: open /Applications/Arcadia.app"
