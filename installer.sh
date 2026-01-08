#!/bin/bash
set -euo pipefail
clear

REPO="thelastligma/Arcadia"
TAG="Releases"

echo "🚀 Arcadia Installer"
echo "===================="

ARCH=$(uname -m)
case "$ARCH" in
  arm64|aarch64)
    ARCH_KEY="arm64"
    echo "Detected: Apple Silicon ($ARCH)"
    ;;
  x86_64|amd64)
    ARCH_KEY="x86_64"
    echo "Detected: Intel ($ARCH)"
    ;;
  *)
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# ---- MANUAL ASSET NAME (adjust if needed) ----
ASSET_NAME="Arcadia-${ARCH_KEY}.zip"
DOWNLOAD_URL="https://github.com/$REPO/releases/download/$TAG/$ASSET_NAME"

echo "🔗 Downloading: $DOWNLOAD_URL"

TMP_ZIP="/tmp/Arcadia_${ARCH_KEY}.zip"

curl -fL "$DOWNLOAD_URL" -o "$TMP_ZIP" || {
  echo "❌ Download failed."
  echo "Make sure this file exists:"
  echo "  $ASSET_NAME"
  exit 1
}

echo "📂 Extracting..."
rm -rf /tmp/Arcadia_Extract
mkdir -p /tmp/Arcadia_Extract
unzip -q "$TMP_ZIP" -d /tmp/Arcadia_Extract

APP_SRC=$(find /tmp/Arcadia_Extract -name "Arcadia.app" -type d | head -n1)
[ -z "$APP_SRC" ] && { echo "❌ Arcadia.app not found"; exit 1; }

if [ -d "/Applications/Arcadia.app" ]; then
  echo "♻️ Removing existing installation..."
  rm -rf /Applications/Arcadia.app
fi

echo "💾 Installing..."
if [ -w /Applications ]; then
  mv "$APP_SRC" /Applications/Arcadia.app
else
  sudo mv "$APP_SRC" /Applications/Arcadia.app
fi

echo "🛡️ Removing quarantine flags..."
xattr -rd com.apple.quarantine /Applications/Arcadia.app 2>/dev/null || true

rm -f "$TMP_ZIP"
rm -rf /tmp/Arcadia_Extract

echo ""
echo "✅ Arcadia installed successfully!"
open -a /Applications/Arcadia.app
