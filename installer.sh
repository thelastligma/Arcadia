#!/bin/bash

set -euo pipefail
clear

REPO="thelastligma/Arcadia"
TAG="Releases"

echo "🚀 Arcadia Installer"
echo "===================="

# 1. Detect Architecture
ARCH=$(uname -m)
case "$ARCH" in
  arm64|aarch64)
    ARCH_KEY="silicon"
    echo "Detected: Apple Silicon ($ARCH)"
    ;;
  x86_64|amd64)
    ARCH_KEY="intel"
    echo "Detected: Intel ($ARCH)"
    ;;
  *)
    echo "❌ Unsupported architecture: $ARCH"
    exit 1
    ;;
esac

# 2. Resolve the correct asset from the tagged release
API_URL="https://api.github.com/repos/$REPO/releases/tags/$TAG"
echo "🔎 Fetching release metadata..."

Arcadia_URL=$(curl -fsSL "$API_URL" | python3 - "$ARCH_KEY" <<'PY'
import json, sys
arch_key = sys.argv[1].lower()
try:
    data = json.load(sys.stdin)
except json.JSONDecodeError as e:
    print(f"Error: Invalid JSON from API", file=sys.stderr)
    sys.exit(1)

for asset in data.get("assets", []):
    name = asset.get("name", "").lower()
    if arch_key in name and name.endswith(".zip"):
        url = asset.get("browser_download_url", "")
        if url:
            print(url)
            sys.exit(0)
sys.exit(1)
PY
) || {
  echo "❌ No release asset found for architecture '$ARCH_KEY' in tag '$TAG'."
  exit 1
}

FILE_NAME=$(basename "$Arcadia_URL")
TMP_ZIP="/tmp/Arcadia_Install_${ARCH_KEY}.zip"
echo "🔗 Target URL: $Arcadia_URL"
echo "📦 Using asset: $FILE_NAME"

# 3. Cleanup old installation
if [ -d "/Applications/Arcadia.app" ]; then
  echo "Updating existing installation..."
  rm -rf /Applications/Arcadia.app
fi

# 4. Download
echo "📥 Downloading $FILE_NAME..."
curl -fL "$Arcadia_URL" -o "$TMP_ZIP" || {
  echo ""
  echo "❌ Download failed. Please verify that '$FILE_NAME' is still attached to the '$TAG' release."
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
