#!/bin/bash

clear

REPO="thelastigma/Arcadia"

# 1. Get the latest version tag (e.g., v1.0.0)
LATEST_VER=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/$REPO/releases/latest | sed 's|.*/tag/||')
echo "Latest version determined to be: $LATEST_VER"
echo ""

# 2. Detect Architecture and set the specific ZIP name
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  # Matches: Arcadia-1.0.0-arm64-mac.zip
  FILE_NAME="Arcadia-${LATEST_VER#v}-arm64-mac.zip"
  echo "Detected architecture: Apple Silicon (arm64)"
elif [[ "$ARCH" == "x86_64" ]]; then
  # Matches: Arcadia-1.0.0-mac.zip
  FILE_NAME="Arcadia-${LATEST_VER#v}-mac.zip"
  echo "Detected architecture: Intel (x86_64)"
else
  echo "Unsupported architecture: $ARCH"
  exit 1
fi

# 3. Construct the Download URL
# Based on your screenshot, the URL pattern is: releases/download/v1.0.0/FILENAME
Arcadia_URL="https://github.com/$REPO/releases/download/$LATEST_VER/$FILE_NAME"
TMP_ZIP="/tmp/Arcadia_Install.zip"

# 4. Clean up old installation
if [ -d "/Applications/Arcadia.app" ]; then
  echo "Arcadia is already installed."
  echo "Updating / Reinstalling Arcadia..."
  rm -rf /Applications/Arcadia.app
fi

# 5. Clean up temporary files
echo "Cleaning up temporary files..."
rm -rf "$TMP_ZIP" /tmp/Arcadia.app

# 6. Download
echo "Downloading Arcadia..."
curl -fsSL "$Arcadia_URL" -o "$TMP_ZIP" || {
  echo "❌ Failed to download Arcadia. Ensure the filename $FILE_NAME exists in the release."
  exit 1
}

# 7. Unzip
echo "Unzipping Arcadia..."
# Unzip to /tmp first to handle the move logic
unzip -o -q "$TMP_ZIP" -d /tmp || {
  echo "❌ Failed to unzip Arcadia"
  exit 1
}

# 8. Locate and Install
# Using 'find' ensures we grab the .app even if the zip structure changes slightly
APP_SRC=$(find /tmp -name "Arcadia.app" -type d -maxdepth 2 | head -n1)

if [ -z "$APP_SRC" ]; then
  echo "❌ Error: Could not find Arcadia.app in the downloaded archive."
  exit 1
fi

echo "Installing Arcadia..."
mv "$APP_SRC" "/Applications/Arcadia.app" || {
  echo "❌ Failed to move Arcadia to Applications"
  exit 1
}

# 9. Security & Cleanup
echo "Applying security fixes..."
xattr -rd com.apple.quarantine /Applications/Arcadia.app 2>/dev/null || true

rm "$TMP_ZIP"

echo ""
echo "✅ Arcadia installed successfully!"
echo "You can now find Arcadia in your Applications folder."

# 10. Launch
open -a /Applications/Arcadia.app
