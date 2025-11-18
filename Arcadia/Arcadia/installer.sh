#!/usr/bin/env bash
set -euo pipefail

show_help() {
  cat <<'EOF'
Arcadia macOS builder & installer

Usage: installer.sh [--install] [--no-build] [--help]

Options:
  --install     After building, copy the produced .app into /Applications (requires sudo).
  --no-build    Skip building; attempt to locate an existing `dist/*.app` and (optionally) install it.
  --help        Show this help and exit.

Notes:
  - This script is intended to run on macOS.
  - It will run `npm install` and then `npx electron-builder --mac` by default.
  - By default it will NOT auto-copy the app to /Applications. Use `--install` to enable that.
EOF
}

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT_DIR"

INSTALL=0
NO_BUILD=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --install) INSTALL=1; shift ;;
    --no-build) NO_BUILD=1; shift ;;
    -h|--help) show_help; exit 0 ;;
    *) echo "Unknown option: $1" >&2; show_help; exit 2 ;;
  esac
done

if [ "$(uname -s)" != "Darwin" ]; then
  echo "ERROR: This installer script is intended to run on macOS (Darwin)." >&2
  exit 1
fi

if [ ! -f package.json ]; then
  echo "ERROR: package.json not found in: $ROOT_DIR" >&2
  exit 1
fi

if [ "$NO_BUILD" -eq 0 ]; then
  echo "Installing npm dependencies (local)..."
  if command -v npm >/dev/null 2>&1; then
    npm install
  else
    echo "ERROR: npm is not installed or not in PATH." >&2
    exit 1
  fi

  ICON_PNG="assets/icon.png"
  if [ -f "$ICON_PNG" ]; then
    if command -v sips >/dev/null 2>&1; then
      W=$(sips -g pixelWidth "$ICON_PNG" | awk '/pixelWidth/ {print $2}')
      H=$(sips -g pixelHeight "$ICON_PNG" | awk '/pixelHeight/ {print $2}')
      echo "Icon size: ${W}x${H}"
      if [ "$W" -lt 512 ] || [ "$H" -lt 512 ]; then
        echo "ERROR: assets/icon.png must be at least 512x512. Please replace it." >&2
        exit 1
      fi
    else
      echo "Note: 'sips' not available; cannot verify icon dimensions." 
    fi
  else
    echo "Warning: assets/icon.png not found; build may use default icon." 
  fi

  if command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1 && [ -f "$ICON_PNG" ]; then
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
    echo "Skipping .icns generation (requires macOS 'iconutil' and 'sips' and an icon)."
  fi

  echo "Building macOS application (dmg + app) via npx electron-builder --mac..."
  if command -v npx >/dev/null 2>&1; then
    npx electron-builder --mac
  else
    echo "ERROR: npx is not available. Ensure Node.js/npm are installed." >&2
    exit 1
  fi
else
  echo "Skipping build step (user requested --no-build)."
fi

APP_PATH=$(find dist -name "*.app" | head -n 1 || true)
DMG_PATH=$(find dist -name "*.dmg" | head -n 1 || true)

if [ -z "$APP_PATH" ]; then
  echo "ERROR: build/lookup failed — no .app produced or found in 'dist/'." >&2
  exit 1
fi

echo "Found built app: $APP_PATH"

if [ "$INSTALL" -eq 1 ]; then
  APP_NAME=$(basename "$APP_PATH")
  echo "Preparing to copy $APP_NAME to /Applications (requires sudo)..."
  sudo rm -rf "/Applications/$APP_NAME" 2>/dev/null || true
  sudo cp -R "$APP_PATH" "/Applications/$APP_NAME"
  sudo xattr -cr "/Applications/$APP_NAME" || true
  echo "Installed: /Applications/$APP_NAME"
  echo "Refreshing Launchpad..."
  killall Dock || true
else
  echo "Build complete. App is at: $APP_PATH"
  if [ -n "$DMG_PATH" ]; then
    echo "DMG created at: $DMG_PATH"
  fi
  echo "To copy the app into /Applications, re-run with: ./installer.sh --install"
fi

echo "Done."
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
