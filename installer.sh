#!/bin/bash
set -euo pipefail
clear

REPO="thelastligma/Arcadia"

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

# 2. Fetch latest release (NOT tag-based)
API_URL="https://api.github.com/repos/$REPO/releases/latest"
echo "🔎 Fetching release metadata..."

Arcadia_URL=$(curl -fsSL "$API_URL" | python3 - "$ARCH_KEY" <<'PY'
import json, sys

arch = sys.argv[1].lower()

try:
    data = json.load(sys.stdin)
except Exception as e:
    print("❌ Failed to parse GitHub API response", file=sys.stderr)
    sys.exit(1)

assets = data.get("assets", [])
if not assets:
    print("❌ No assets found in release", file=sys.stderr)
    sys.exit(1)

for asset in assets:
    name = asset.get("name", "").lower()
    if arch in name and name.endswith(".zip"):
        print(asset["browser_download_url"])
        sys.exit(0)

print(f"❌ No asset matching architecture '{arch}'", file=sys.stderr)
sys.exit(1)
PY
)

FILE_NAME=$(basename "$Arcadia_URL")
TMP_ZIP="/tmp/Arcadia_${ARCH_KEY}.zip"

echo "🔗 Target URL: $Arcadia_URL"
echo "📦 Using asset: $FILE_NAME"

# 3. Remove old install
if [ -d "/Applications/Arcadia.app" ]; then
  echo "♻️  Removing existing installation..."
  rm -rf /Applications/Arcadia.app
fi

# 4. Download
echo "📥 Downloading..."
curl -fL "$Arcadia_URL" -o "$TMP_ZIP"

# 5. Extract
echo "📂 Extracting..."
rm -rf /tmp/Arcadia_Extract
mkdir -p /tmp/Arcadia_Extract
unzip -q "$TMP_ZIP" -d /tmp/Arcadia_Extract

# 6. Find app
APP_SRC=$(find /tmp/Arcadia_Extract -name "Arcadia.app" -type d | head -n1)
if [ -z "$APP_SRC" ]; then
  echo "❌ Arcadia.app not found in archive"
  exit 1
fi

# 7. Install
echo "💾 Installing..."
if [ -w /Applications ]; then
  mv "$APP_SRC" /Applications/Arcadia.app
else
  sudo mv "$APP_SRC" /Applications/Arcadia.app
fi

# 8. Fix Gatekeeper
echo "🛡️  Removing quarantine flags..."
xattr -rd com.apple.quarantine /Applications/Arcadia.app 2>/dev/null || true

# 9. Cleanup
rm -f "$TMP_ZIP"
rm -rf /tmp/Arcadia_Extract

echo ""
echo "✅ Arcadia installed successfully!"
open -a /Applications/Arcadia.app
