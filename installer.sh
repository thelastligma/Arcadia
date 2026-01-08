#!/bin/bash

clear

REPO="thelastigma/Arcadia"
TAG="Releases"
VERSION="1.0.0"

echo "🚀 Arcadia Installer"
echo "===================="

# 1. Detect Architecture
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  FILE_NAME="Arcadia-${VERSION}-arm64-mac.zip"
  echo "Detected: Apple Silicon ($ARCH)"
elif [[ "$ARCH" == "x86_64" ]]; then
  FILE_NAME="Arcadia-${VERSION}-mac.zip"
  echo "Detected: Intel ($ARCH)"
else
  echo "❌ Unsupported architecture: $ARCH"
  exit 1
fi

# 2. Construct the direct URL
# This bypasses the "latest" redirect which was causing your 404
Arcadia_URL="https://github.com/$REPO/releases/download/$TAG/$FILE_NAME"
TMP_ZIP="/tmp/Arcadia_Install.zip"

echo "🔗 Target URL: $Arcadia_URL"

# 3. Cleanup old installation
if [ -d "/Applications/Arcadia.app" ]; then
  echo "Updating existing installation..."
  rm -rf /Applications/Arcadia.app
fi

# 4. Download
echo "📥 Downloading $FILE_NAME..."
curl -fsSL "$Arcadia_URL" -o "$TMP_ZIP" || {
  echo ""
  echo "❌ Error 404: File not found on GitHub."
  echo "Please verify that '$FILE_NAME' is uploaded to the '$TAG' release."
  exit 1
}

# 5. Unzip
echo "📂 Extracting..."
rm -rf /tmp/Arcadia_Extract
mkdir -p /tmp/Arcadia_Extract
unzip -o -q "$TMP_ZIP" -d /tmp/Arcadia_Extract

# 6. Locate .app bundle
APP_SRC=$(find /tmp/Arcadia_Extract -name "Arcadia.app" -type d | head -n1)

if [ -z "$APP_SRC" ]; then
  echo "❌ Error: Could not find Arcadia.app inside the zip."
  exit 1
fi

# 7. Install
echo "💾 Moving to Applications..."
if [ -w "/Applications" ]; then
    mv "$APP_SRC" "/Applications/Arcadia.app"
else
    sudo mv "$APP_SRC" "/Applications/Arcadia.app"
fi

# 8. Fix macOS "Damaged App" error
echo "🛡️  Removing quarantine flags..."
xattr -rd com.apple.quarantine /Applications/Arcadia.app 2>/dev/null || true

# 9. Cleanup
rm "$TMP_ZIP"
rm -rf /tmp/Arcadia_Extract

echo ""
echo "✅ Arcadia installed successfully!"
open -a /Applications/Arcadia.app
