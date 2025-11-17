#!/bin/bash
set -e
echo "======================================="
echo " Arcadia macOS Installer"
echo "======================================="
REPO_URL="https://github.com/thelastligma/Arcadia.git"
BUILD_DIR="/tmp/arcadia-build.$RANDOM"
echo "➡️  Creating temp build folder: $BUILD_DIR"
mkdir -p "$BUILD_DIR"
echo "➡️  Cloning Arcadia repo..."
git clone "$REPO_URL" "$BUILD_DIR"
cd "$BUILD_DIR"
echo "➡️  Installing npm dependencies..."
npm install
echo "➡️  Building macOS app..."
npm run build:mac || { echo "❌ Build failed."; exit 1; }
APP_PATH="$BUILD_DIR/dist/mac-arm64/Arcadia.app"
if [ ! -d "$APP_PATH" ]; then
    echo "❌ Build succeeded, but .app was not found!"
    exit 1
fi
echo "➡️  Moving Arcadia.app to /Applications..."
sudo rm -rf /Applications/Arcadia.app 2>/dev/null
sudo cp -R "$APP_PATH" /Applications/
echo "➡️  Building DMG..."
npm run dist || echo "⚠️ DMG build failed — app install still succeeded."
echo "======================================="
echo " ✅ Installation Complete!"
echo "======================================="
