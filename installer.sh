#!/bin/bash

# Arcadia Installer
set -e

REPO="thelastigma/Arcadia"
RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"

echo "🚀 Arcadia Installer"
echo "===================="

# 1. Architecture Detection
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    SEARCH_PATTERN="arm64-mac\.zip"
else
    SEARCH_PATTERN="mac\.zip"
fi

echo "Detected macOS: $ARCH"

# 2. Robust URL Extraction
echo "📥 Fetching latest release info..."
# This fetches the JSON, finds the line with the zip, and strips the quotes/whitespace
DOWNLOAD_URL=$(curl -s "$RELEASE_URL" | grep "browser_download_url" | grep "$SEARCH_PATTERN" | cut -d '"' -f 4 | head -n 1)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Error: Could not find a zip matching '$SEARCH_PATTERN' in the latest release."
    echo "Check: https://github.com/$REPO/releases"
    exit 1
fi

echo "Found download: $(basename "$DOWNLOAD_URL")"

# 3. Create Temp Space
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT
ZIP_FILE="$TEMP_DIR/arcadia.zip"

# 4. Download and Extract
echo "📦 Downloading..."
curl -L -# -o "$ZIP_FILE" "$DOWNLOAD_URL"

echo "📂 Extracting..."
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

# 5. Find Arcadia.app
APP_BUNDLE=$(find "$TEMP_DIR" -name "Arcadia.app" -type d | head -n1)

if [ -z "$APP_BUNDLE" ]; then
    echo "❌ Error: Could not find Arcadia.app in the downloaded archive."
    exit 1
fi

# 6. Install
INSTALL_PATH="/Applications/Arcadia.app"
echo "💾 Installing to /Applications..."

if [ -d "$INSTALL_PATH" ]; then
    rm -rf "$INSTALL_PATH"
fi

cp -R "$APP_BUNDLE" "$INSTALL_PATH"

# 7. Strip Quarantine (Prevents "App is damaged" error)
xattr -rd com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true

echo "✅ Success! Arcadia is installed."
open "$INSTALL_PATH"
