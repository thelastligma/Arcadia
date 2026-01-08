#!/bin/bash

# Arcadia Installer
# Downloads from GitHub and installs to /Applications, then opens the app

set -e

REPO="thelastigma/Arcadia"
RELEASE_URL="https://api.github.com/repos/$REPO/releases/latest"

echo "🚀 Arcadia Installer"
echo "===================="
echo ""

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ Error: This installer is for macOS only."
    exit 1
fi

# Detect CPU architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
    ARCH_NAME="Apple Silicon (M1/M2/M3/M4)"
    # Matches the specific file in your screenshot
    SEARCH_PATTERN="Arcadia-.*-arm64-mac\.zip"
elif [[ "$ARCH" == "x86_64" ]]; then
    ARCH_NAME="Intel"
    # Matches the Intel file while avoiding the arm64 one
    SEARCH_PATTERN="Arcadia-.*-mac\.zip"
else
    echo "❌ Error: Unsupported architecture: $ARCH"
    exit 1
fi

echo "Detected macOS: $ARCH_NAME"
echo ""

# Fetch the latest release info
echo "📥 Fetching latest release info from GitHub..."
RELEASE_JSON=$(curl -s "$RELEASE_URL")

# Extract download URL
if [[ "$ARCH" == "arm64" ]]; then
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o "https://github.com/[^\"]*$SEARCH_PATTERN" | head -n1)
else
    # For Intel, we specifically exclude arm64 to avoid picking up the wrong zip
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o "https://github.com/[^\"]*$SEARCH_PATTERN" | grep -v "arm64" | head -n1)
fi

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Error: Could not find compatible .zip file in the latest release."
    exit 1
fi

echo "Found download: $(basename "$DOWNLOAD_URL")"
echo ""

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

DOWNLOAD_FILENAME=$(basename "$DOWNLOAD_URL")
ZIP_FILE="$TEMP_DIR/$DOWNLOAD_FILENAME"

# Download the archive
echo "📦 Downloading Arcadia..."
curl -L -o "$ZIP_FILE" "$DOWNLOAD_URL"

# Extract
echo "📂 Extracting..."
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

# Find the app bundle (looking deeper in case of nested folders)
APP_BUNDLE=$(find "$TEMP_DIR" -name "Arcadia.app" -type d -maxdepth 3 | head -n1)

if [ -z "$APP_BUNDLE" ]; then
    echo "❌ Error: Could not find Arcadia.app in the archive."
    exit 1
fi

# Install to /Applications
INSTALL_PATH="/Applications/Arcadia.app"
echo "💾 Installing to /Applications..."

# Remove existing installation if present (requires sudo if /Apps is protected)
if [ -d "$INSTALL_PATH" ]; then
    rm -rf "$INSTALL_PATH"
fi

cp -R "$APP_BUNDLE" "$INSTALL_PATH"

echo "✅ Installation complete!"
echo "🚀 Launching Arcadia..."
open "$INSTALL_PATH"
