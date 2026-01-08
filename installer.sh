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
    DOWNLOAD_NAME="Arcadia-1.0.0-arm64-mac.zip"
    ARCH_NAME="Apple Silicon (M1/M2/M3)"
elif [[ "$ARCH" == "x86_64" ]]; then
    DOWNLOAD_NAME="Arcadia-1.0.0-mac.zip"
    ARCH_NAME="Intel"
else
    echo "❌ Error: Unsupported architecture: $ARCH"
    exit 1
fi

echo "Detected macOS: $ARCH_NAME"
echo ""

# Fetch the latest release info
echo "📥 Fetching latest release from GitHub..."
RELEASE_JSON=$(curl -s "$RELEASE_URL")

# Extract download URL
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o "\"browser_download_url\": \"[^\"]*$DOWNLOAD_NAME\"" | head -n1 | cut -d'"' -f4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ Error: Could not find $DOWNLOAD_NAME in the latest release."
    exit 1
fi

echo "Found download ✓"
echo ""

# Create temporary directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

ZIP_FILE="$TEMP_DIR/$DOWNLOAD_NAME"

# Download the archive
echo "📦 Downloading Arcadia..."
curl -L -o "$ZIP_FILE" "$DOWNLOAD_URL"

if [ ! -f "$ZIP_FILE" ]; then
    echo "❌ Error: Download failed."
    exit 1
fi

echo "Download complete ✓"
echo ""

# Extract
echo "📂 Extracting..."
unzip -q "$ZIP_FILE" -d "$TEMP_DIR"

# Find the app bundle
APP_BUNDLE=$(find "$TEMP_DIR" -name "Arcadia.app" -type d | head -n1)

if [ -z "$APP_BUNDLE" ]; then
    echo "❌ Error: Could not find Arcadia.app in the archive."
    exit 1
fi

echo "Extract complete ✓"
echo ""

# Install to /Applications
INSTALL_PATH="/Applications/Arcadia.app"

echo "💾 Installing to /Applications..."

# Remove existing installation if present
if [ -d "$INSTALL_PATH" ]; then
    rm -rf "$INSTALL_PATH"
fi

# Copy the app bundle
cp -R "$APP_BUNDLE" "$INSTALL_PATH"

# Make it executable
chmod +x "$INSTALL_PATH/Contents/MacOS/Arcadia"

echo "Installation complete ✓"
echo ""
echo "✅ Arcadia installed successfully!"
echo ""
echo "🚀 Launching Arcadia..."
sleep 1
open "$INSTALL_PATH"
