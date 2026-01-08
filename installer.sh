#!/bin/bash

clear

REPO="thelastigma/Arcadia"

# 1. Determine the latest version tag from GitHub
# This captures "Arcadia-v1.0.0-arm64" from your release
LATEST_TAG=$(curl -fsSLI -o /dev/null -w '%{url_effective}' https://github.com/$REPO/releases/latest | sed 's|.*/tag/||')
echo "Latest tag determined to be: $LATEST_TAG"

# Extract just the version number (e.g., 1.0.0) for the filenames
# This removes "Arcadia-v" and everything after the version number
VER_NUM=$(echo "$LATEST_TAG" | sed -n 's/.*v\([0-9.]*\).*/\1/p')
echo "Version number parsed as: $VER_NUM"
echo ""

# 2. Detect Architecture and set the specific ZIP name from your screenshot
ARCH=$(uname -m)
if [[ "$ARCH" == "arm64" ]]; then
  # Matches: Arcadia-1.0.0-arm64-mac.zip
  FILE_NAME="Arcadia-${VER_NUM}-arm64-mac.zip"
  echo "Detected: Apple Silicon ($ARCH)"
elif [[ "$ARCH" == "x86_64" ]]; then
  # Matches: Arcadia-1.0.0-mac.zip
  FILE_NAME="Arcadia-${VER_NUM}-mac.zip"
  echo "Detected: Intel ($ARCH)"
else
  echo "❌ Unsupported architecture: $ARCH"
  exit 1
fi

# 3. Construct URL and Temp Paths
Arcadia_URL="https://github.com/$REPO/releases/download/$LATEST_TAG/$FILE_NAME"
TMP_ZIP="/tmp/Arcadia_Install.zip"

# 4. Cleanup old installation
if [ -d "/Applications/Arcadia.app" ]; then
  echo "Arcadia is already installed. Updating..."
  rm -rf /Applications/Arcadia.app
fi

# 5. Download
echo "Downloading $FILE_NAME..."
curl -fsSL "$Arcadia_URL" -o "$TMP_ZIP" || {
  echo "❌ Failed to download. Ensure the file $FILE_NAME exists in the $LATEST_TAG release."
  exit 1
}

# 6. Unzip and Locate App
echo "Unzipping..."
unzip -o -q "$TMP_ZIP" -d /tmp/Arcadia_Extract

# Find the .app bundle (handles nested folders automatically)
APP_SRC=$(find /tmp/Arcadia_Extract -name "Arcadia.app" -type d | head -n1)

if [ -z "$APP_SRC" ]; then
  echo "❌ Error: Could not find Arcadia.app in the downloaded archive."
  exit 1
fi

# 7. Install to Applications
echo "Installing to /Applications..."
mv "$APP_SRC" "/Applications/Arcadia.app" || {
  echo "❌ Failed to move to Applications. Try running with sudo."
  exit 1
}

# 8. Security Bypass (Quarantine)
# This prevents the "App is damaged" message common with GitHub downloads
xattr -rd com.apple.quarantine /Applications/Arcadia.app 2>/dev/null || true

# 9. Final Cleanup
rm "$TMP_ZIP"
rm -rf /tmp/Arcadia_Extract

echo ""
echo "✅ Arcadia installed successfully!"
open -a /Applications/Arcadia.app
