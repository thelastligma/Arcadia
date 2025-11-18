#!/usr/bin/env bash
set -euo pipefail

# Non-interactive installer that clones the Arcadia repo, builds the mac app,
# and installs the resulting .app into /Applications (refreshes Launchpad).

# Default repo to clone; change if you want another source. No options are used.
REPO_URL="https://github.com/thelastligma/Arcadia.git"

TMPDIR="$(mktemp -d /tmp/arcadia-build.XXXXXX)"
echo "Cloning $REPO_URL to $TMPDIR/arcadia..."
git clone --depth=1 "$REPO_URL" "$TMPDIR/arcadia"

cd "$TMPDIR/arcadia"

# If package.json is not at repo root, try to find it in a nested folder (common when repo contains a subfolder)
if [ ! -f package.json ]; then
	SUB_PKG_PATH=$(find . -maxdepth 3 -type f -name package.json -print | head -n 1 || true)
	if [ -n "$SUB_PKG_PATH" ]; then
		SUBDIR=$(dirname "$SUB_PKG_PATH")
		echo "Found package.json in cloned repo at: $SUBDIR. Changing directory into it."
		cd "$SUBDIR"
	else
		echo "ERROR: package.json not found in cloned repo." >&2
		exit 1
	fi
fi

echo "Installing npm dependencies..."
if command -v npm >/dev/null 2>&1; then
	npm install
else
	echo "ERROR: npm not found in PATH." >&2
	exit 1
fi

# Generate .icns from assets/icon.png if possible so the mac build has a proper icon.
ICON_PNG="assets/icon.png"
ICON_ICNS="assets/icon.icns"
if [ -f "$ICON_PNG" ] && command -v iconutil >/dev/null 2>&1 && command -v sips >/dev/null 2>&1; then
	echo "Generating .icns from $ICON_PNG..."
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
	iconutil -c icns build/icons.iconset -o "$ICON_ICNS"
	echo "Generated $ICON_ICNS"
else
	echo "Skipping .icns generation (missing assets or macOS tools)."
fi

echo "Building macOS app with npm run build:mac..."
if command -v npm >/dev/null 2>&1; then
	npm run build:mac
else
	echo "ERROR: npm not found in PATH." >&2
	exit 1
fi

APP_PATH=$(find dist -name "*.app" | head -n 1 || true)
if [ -z "$APP_PATH" ]; then
	echo "ERROR: build failed, no .app found in dist/." >&2
	exit 1
fi

APP_NAME=$(basename "$APP_PATH")
echo "Installing $APP_NAME to /Applications (requires sudo)..."
sudo rm -rf "/Applications/$APP_NAME" 2>/dev/null || true
sudo cp -R "$APP_PATH" "/Applications/$APP_NAME"
sudo xattr -cr "/Applications/$APP_NAME" || true

echo "Refreshing Launchpad..."
killall Dock || true

echo "Installed: /Applications/$APP_NAME"

echo "Cleaning up temporary clone: $TMPDIR"
rm -rf "$TMPDIR"

echo "Done."
