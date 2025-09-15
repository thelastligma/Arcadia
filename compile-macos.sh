#!/bin/zsh
set -euo pipefail

# Ensure dependencies are installed
if [ ! -d "node_modules" ]; then
  echo "Installing dependencies..."
  npm install
fi

# Package for macOS
echo "Packaging for macOS..."
npx electron-packager . ArcadiaUI --platform=darwin --arch=x64 --asar.compression=zstd --overwrite --icon=assets/icon.icns

echo "Done. Check the generated ArcadiaUI-darwin-x64 folder."
