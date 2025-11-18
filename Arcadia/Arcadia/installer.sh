
#!/usr/bin/env bash
set -euo pipefail

# Non-interactive installer that clones the Arcadia repo, builds the mac app,
# and installs the resulting .app into /Applications.

REPO_URL="https://github.com/thelastligma/Arcadia.git"

TMPDIR="$(mktemp -d /tmp/arcadia-build.XXXXXX)"
echo "Cloning $REPO_URL to $TMPDIR/arcadia..."
git clone --depth=1 "$REPO_URL" "$TMPDIR/arcadia"

cd "$TMPDIR/arcadia"

# Locate package.json (repo root or subfolder)
if [ ! -f package.json ]; then
    SUB_PKG_PATH=$(find . -maxdepth 5 -type f -iname "package.json" -print | head -n 1 || true)
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

# Icon generation removed

echo "Building macOS app with npm run build:mac..."
npm run build:mac

APP_PATH=$(find dist -name "*.app" | head -n 1 || true)
if [ -z "$APP_PATH" ]; then
    echo "ERROR: build failed, no .app found in dist/." >&2
    exit 1
fi

APP_NAME=$(basename "$APP_PATH")
echo "Installing $APP_NAME to /Applications..."
sudo rm -rf "/Applications/$APP_NAME" 2>/dev/null || true
sudo cp -R "$APP_PATH" "/Applications/$APP_NAME"
sudo xattr -cr "/Applications/$APP_NAME" || true

echo "Installed: /Applications/$APP_NAME"

echo "Cleaning up temporary clone: $TMPDIR"
rm -rf "$TMPDIR"

echo "Done."
