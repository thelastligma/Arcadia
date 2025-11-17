#!/bin/bash
set -euo pipefail

echo "=== Arcadia local macOS builder & installer ==="

# assume running inside project root that contains package.json
ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

echo "Installing dependencies..."
npm install

ICON_PNG="assets/icon.png"
if [ -f "$ICON_PNG" ]; then
  if command -v sips >/dev/null 2>&1; then
    W=$(sips -g pixelWidth "$ICON_PNG" | awk '/pixelWidth/ {print $2}')
    H=$(sips -g pixelHeight "$ICON_PNG" | awk '/pixelHeight/ {print $2}')
    echo "Icon size: ${W}x${H}"
    if [ "$W" -lt 512 ] || [ "$H" -lt 512 ]; then
      echo "ERROR: assets/icon.png must be at least 512x512. Please replace it."
      exit 1
    fi
  else
    echo "Note: 'sips' not available; cannot verify icon dimensions."
  fi
else
  echo "Warning: assets/icon.png not found; build may use default icon."
fi

# Generate .icns if on macOS
if command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
  echo "Generating .icns from assets/icon.png..."
  rm -rf build/icons.iconset || true
  mkdir -p build/icons.iconset
  sips -z 16 16     "$ICON_PNG" --out build/icons.iconset/icon_16x16.png
  sips -z 32 32     "$ICON_PNG" --out build/icons.iconset/icon_16x16@2x.png
  sips -z 32 32     "$ICON_PNG" --out build/icons.iconset/icon_32x32.png
  sips -z 64 64     "$ICON_PNG" --out build/icons.iconset/icon_32x32@2x.png
  sips -z 128 128   "$ICON_PNG" --out build/icons.iconset/icon_128x128.png
  sips -z 256 256   "$ICON_PNG" --out build/icons.iconset/icon_128x128@2x.png
  sips -z 256 256   "$ICON_PNG" --out build/icons.iconset/icon_256x256.png
  sips -z 512 512   "$ICON_PNG" --out build/icons.iconset/icon_256x256@2x.png
  sips -z 512 512   "$ICON_PNG" --out build/icons.iconset/icon_512x512.png
  sips -z 1024 1024 "$ICON_PNG" --out build/icons.iconset/icon_512x512@2x.png
  iconutil -c icns build/icons.iconset -o assets/icon.icns
  echo "Generated assets/icon.icns"
else
  echo "Skipping .icns generation (requires macOS 'iconutil' and 'sips')."
fi

echo "Building macOS application (dmg + app)..."
npx electron-builder --mac

APP_PATH=$(find dist -name "*.app" | head -n 1 || true)
DMG_PATH=$(find dist -name "*.dmg" | head -n 1 || true)

if [ -z "$APP_PATH" ]; then
  echo "ERROR: build failed — no .app produced."
  exit 1
fi

echo "Copying app to /Applications..."
APP_NAME=$(basename "$APP_PATH")
sudo rm -rf "/Applications/$APP_NAME" 2>/dev/null || true
sudo cp -R "$APP_PATH" "/Applications/$APP_NAME"
sudo xattr -cr "/Applications/$APP_NAME" || true

echo "Refreshing Launchpad..."
killall Dock || true

echo "Build complete."
echo "Installed: /Applications/$APP_NAME"
if [ -n "$DMG_PATH" ]; then
  echo "DMG created at: $DMG_PATH"
fi
