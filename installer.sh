#!/bin/bash

# Arcadia Installer
set -e

REPO="thelastigma/Arcadia"
# This URL will redirect us to the actual download link
LATEST_RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"

echo "🚀 Arcadia Installer"
echo "===================="

# 1. Architecture Detection
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    echo "Detected: Apple Silicon ($ARCH)"
    # We look for the file that ends exactly with arm64-mac.zip
    SEARCH_PATTERN="arm64-mac\.zip"
else
    echo "Detected: Intel ($ARCH)"
    # We look for the file that ends with mac.zip but DOES NOT contain arm64
    SEARCH_PATTERN="mac\.zip"
fi

# 2. Get the specific download URL from GitHub API
echo "📥 Fetching download link..."
RELEASE_DATA=$(curl -s "$LATEST_RELEASE_URL")

# Extract the URL. If Intel, we exclude 'arm64' lines to avoid picking the wrong zip.
if [[ "$ARCH" == "arm64" ]]; then
    DOWNLOAD_URL=$(echo "$RELEASE_DATA" | grep "browser_download_url" | grep "$SEARCH_PATTERN" | cut -d '"' -f 4 | head -n 1)
else
    DOWNLOAD_URL=$(echo "$RELEASE_DATA" | grep "browser_download_url" | grep "$SEARCH_PATTERN" | grep -v "arm64" | cut -d '"' -f 4 | head -n 1)
fi

# Safety check
if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Error: Could not find the zip file on GitHub."
    echo "Please ensure the file on GitHub is named exactly 'Arcadia-v1.0.0-arm64-mac.zip' or similar."
    exit 1
fi

# 3. Download
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT
ZIP_FILE="$TEMP_DIR/arcadia.zip"

echo "📦 Downloading Arcadia..."
curl -L -# -o "$ZIP_FILE" "$DOWNLOAD_URL"

# 4. Extraction
echo "📂 Extracting..."
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

# 5. Finding and Moving the App
# This finds Arcadia.app even if it's inside a folder in the zip
APP_PATH=$(find "$TEMP_DIR" -name "Arcadia.app" -type d -maxdepth 3 | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "❌ Error: Arcadia.app not found inside the zip."
    exit 1
fi

echo "💾 Installing to /Applications..."
# Use sudo only if we don't have permission to write to /Applications
if [ -w "/Applications" ]; then
    rm -rf "/Applications/Arcadia.app"
    cp -R "$APP_PATH" "/Applications/"
else
    echo "Please enter your Mac password to finish installation:"
    sudo rm -rf "/Applications/Arcadia.app"
    sudo cp -R "$APP_PATH" "/Applications/"
fi

# 6. Final Polish
echo "🛡️  Clearing system quarantine..."
# This stops the "App is damaged" message for non-App Store apps
xattr -rd com.apple.quarantine "/Applications/Arcadia.app" 2>/dev/null || true

echo "✅ Done! Launching Arcadia..."
open "/Applications/Arcadia.app"
