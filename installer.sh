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
    SEARCH_PATTERN="Arcadia-.*-arm64-mac\.zip"
else
    SEARCH_PATTERN="Arcadia-.*-mac\.zip"
fi

# 2. Robust URL Extraction
# We use 'tr' and 'sed' to ensure we grab the clean URL from the JSON
echo "📥 Fetching latest release info..."
RELEASE_JSON=$(curl -s "$RELEASE_URL")
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -oE "https://github.com/[^\"]+$SEARCH_PATTERN" | grep -v "Source code" | head -n1)

# Fallback check: if the first grep fails, Intel might be named simply "mac.zip"
if [[ -z "$DOWNLOAD_URL" && "$ARCH" == "x86_64" ]]; then
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -oE "https://github.com/[^\"]+mac\.zip" | grep -v "arm64" | head -n1)
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Error: Could not find compatible .zip for $ARCH."
    exit 1
fi

# 3. Secure Temp Space
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT
ZIP_FILE="$TEMP_DIR/download.zip"

# 4. Download and Unzip
echo "📦 Downloading: $(basename "$DOWNLOAD_URL")"
curl -L -# -o "$ZIP_FILE" "$DOWNLOAD_URL"

echo "📂 Extracting..."
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

# 5. Locate Bundle
APP_BUNDLE=$(find "$TEMP_DIR" -name "Arcadia.app" -type d -maxdepth 3 | head -n1)
if [ -z "$APP_BUNDLE" ]; then
    echo "❌ Error: Arcadia.app not found in zip."
    exit 1
fi

# 6. Smart Install (Handles Permissions)
INSTALL_PATH="/Applications/Arcadia.app"
echo "💾 Installing to /Applications..."

# If we don't have write access, ask for sudo
if [ ! -w "/Applications" ]; then
    echo "Password required to install to /Applications:"
    sudo rm -rf "$INSTALL_PATH"
    sudo cp -R "$APP_BUNDLE" "$INSTALL_PATH"
    sudo chown -R $(whoami):admin "$INSTALL_PATH"
else
    rm -rf "$INSTALL_PATH"
    cp -R "$APP_BUNDLE" "$INSTALL_PATH"
fi

# 7. Bypass "App is Damaged" / Quarantine (Crucial for GitHub downloads)
echo "🛡️  Adjusting permissions..."
xattr -rd com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true

echo "✅ Success!"
open "$INSTALL_PATH"
