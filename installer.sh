#!/bin/bash
set -euo pipefail
clear

REPO="thelastligma/Arcadia"
TAG_NAME="Releases"

echo "🚀 Arcadia Installer"
echo "===================="

# 1. Detect Architecture
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

echo "🔎 Fetching release metadata..."

API_RESPONSE=$(curl -fsSL \
  -H "Accept: application/vnd.github+json" \
  -H "User-Agent: Arcadia-Installer" \
  "https://api.github.com/repos/$REPO/releases")

Arcadia_URL=$(echo "$API_RESPONSE" | python3 - "$ARCH_KEY" "$TAG_NAME" <<'PY'
import json, sys

arch = sys.argv[1]
tag = sys.argv[2]

data = json.load(sys.stdin)

for release in data:
    if release.get("tag_name") == tag:
        for asset in release.get("assets", []):
            name = asset.get("name", "").lower()
            if arch in name and name.endswith(".zip"):
                print(asset["browser_download_url"])
                sys.exit(0)

print("No matching asset found", file=sys.stderr)
sys.exit(1)
PY
)

FILE_NAME=$(basename "$Arcadia_URL")
TMP_ZIP="/tmp/Arcadia_${ARCH_KEY}.zip"

echo "🔗 Target URL: $Arcadia_URL"
echo "📦 Using asset: $FILE_NAME"

# Remove old install
if [ -d "/Applications/Arcadia.app" ]; then
  echo "♻️ Removing existing installation..."
  rm -rf /Applications/Arcadia.app
fi

# Download
echo "📥 Downloading..."
curl -fL "$Arcadia_URL" -o "$TMP_ZIP"

# Extract
echo "📂 Extracting..."
rm -rf /tmp/Arcadia_Extract
mkdir -p /tmp/Arcadia_Extract
unzip -q "$TMP_ZIP" -d /tmp/Arcadia_Extract

APP_SRC=$(find /tmp/Arcadia_Extract -name "Arcadia.app" -type d | head -n1)
[ -z "$APP_SRC" ] && { echo "❌ Arcadia.app not found"; exit 1; }

# Install
echo "💾 Installing..."
if [ -w /Applications ]; then
  mv "$APP_SRC" /Applications/Arcadia.app
else
  sudo mv "$APP_SRC" /Applications/Arcadia.app
fi

# Fix Gatekeeper
echo "🛡️ Removing quarantine flags..."
xattr -rd com.apple.quarantine /Applications/Arcadia.app 2>/dev/null || true

# Cleanup
rm -f "$TMP_ZIP"
rm -rf /tmp/Arcadia_Extract

echo ""
echo "✅ Arcadia installed successfully!"
open -a /Applications/Arcadia.app
