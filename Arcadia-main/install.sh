#!/bin/bash

# Arcadia Installer Script
# Usage: curl -fsSL https://raw.githubusercontent.com/thelastligma/Arcadia/main/install.sh | bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Arcadia Installer v1.0         ║${NC}"
echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo ""

# Detect OS
OS="$(uname -s)"
case "${OS}" in
    Linux*)     PLATFORM=linux;;
    Darwin*)    PLATFORM=mac;;
    *)          PLATFORM="UNKNOWN";;
esac

echo -e "${GREEN}✓${NC} Detected platform: ${PLATFORM}"

if [ "${PLATFORM}" = "UNKNOWN" ]; then
    echo -e "${RED}✗${NC} Unsupported operating system: ${OS}"
    echo -e "${YELLOW}ℹ${NC} Arcadia currently supports Linux and macOS only."
    exit 1
fi

# Check for required dependencies
echo ""
echo -e "${BLUE}Checking dependencies...${NC}"

# Check for Node.js
if ! command -v node &> /dev/null; then
    echo -e "${RED}✗${NC} Node.js is not installed."
    echo -e "${YELLOW}ℹ${NC} Please install Node.js from https://nodejs.org/"
    exit 1
else
    NODE_VERSION=$(node -v)
    echo -e "${GREEN}✓${NC} Node.js ${NODE_VERSION} found"
fi

# Check for npm
if ! command -v npm &> /dev/null; then
    echo -e "${RED}✗${NC} npm is not installed."
    echo -e "${YELLOW}ℹ${NC} Please install npm (usually comes with Node.js)"
    exit 1
else
    NPM_VERSION=$(npm -v)
    echo -e "${GREEN}✓${NC} npm ${NPM_VERSION} found"
fi

# Check for git
if ! command -v git &> /dev/null; then
    echo -e "${RED}✗${NC} git is not installed."
    echo -e "${YELLOW}ℹ${NC} Please install git from https://git-scm.com/"
    exit 1
else
    GIT_VERSION=$(git --version | cut -d' ' -f3)
    echo -e "${GREEN}✓${NC} git ${GIT_VERSION} found"
fi

# Set installation directory
INSTALL_DIR="$HOME/.arcadia"

echo ""
echo -e "${BLUE}Installation directory: ${INSTALL_DIR}${NC}"

# Remove old installation if exists
if [ -d "${INSTALL_DIR}" ]; then
    echo -e "${YELLOW}⚠${NC} Previous installation found. Removing..."
    rm -rf "${INSTALL_DIR}"
fi

# Clone repository
echo ""
echo -e "${BLUE}Cloning Arcadia repository...${NC}"
git clone --depth 1 https://github.com/thelastligma/Arcadia.git "${INSTALL_DIR}"

if [ $? -ne 0 ]; then
    echo -e "${RED}✗${NC} Failed to clone repository"
    exit 1
fi

echo -e "${GREEN}✓${NC} Repository cloned successfully"

# Navigate to installation directory
cd "${INSTALL_DIR}"

# Install dependencies
echo ""
echo -e "${BLUE}Installing dependencies...${NC}"
npm install

if [ $? -ne 0 ]; then
    echo -e "${RED}✗${NC} Failed to install dependencies"
    exit 1
fi

echo -e "${GREEN}✓${NC} Dependencies installed successfully"

# Create launcher script
LAUNCHER_PATH="$HOME/.local/bin/arcadia"
mkdir -p "$HOME/.local/bin"

echo ""
echo -e "${BLUE}Creating launcher script...${NC}"

cat > "${LAUNCHER_PATH}" << 'EOF'
#!/bin/bash
cd "$HOME/.arcadia"
npm start
EOF

chmod +x "${LAUNCHER_PATH}"

echo -e "${GREEN}✓${NC} Launcher created at ${LAUNCHER_PATH}"

# Add to PATH if not already there
if [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    echo ""
    echo -e "${YELLOW}⚠${NC} Adding ${HOME}/.local/bin to PATH..."
    
    # Detect shell and add to appropriate config file
    if [ -n "$ZSH_VERSION" ]; then
        SHELL_CONFIG="$HOME/.zshrc"
    elif [ -n "$BASH_VERSION" ]; then
        SHELL_CONFIG="$HOME/.bashrc"
    else
        SHELL_CONFIG="$HOME/.profile"
    fi
    
    echo 'export PATH="$HOME/.local/bin:$PATH"' >> "${SHELL_CONFIG}"
    echo -e "${GREEN}✓${NC} PATH updated in ${SHELL_CONFIG}"
    echo -e "${YELLOW}ℹ${NC} Please restart your terminal or run: source ${SHELL_CONFIG}"
fi

# Create desktop entry for Linux
if [ "${PLATFORM}" = "linux" ]; then
    echo ""
    echo -e "${BLUE}Creating desktop entry...${NC}"
    
    DESKTOP_FILE="$HOME/.local/share/applications/arcadia.desktop"
    mkdir -p "$HOME/.local/share/applications"
    
    cat > "${DESKTOP_FILE}" << EOF
[Desktop Entry]
Name=Arcadia
Comment=Arcadia Script Executor
Exec=$HOME/.local/bin/arcadia
Terminal=false
Type=Application
Categories=Development;Utility;
EOF
    
    echo -e "${GREEN}✓${NC} Desktop entry created"
fi

# Create .app wrapper for macOS
if [ "${PLATFORM}" = "mac" ]; then
    echo ""
    echo -e "${BLUE}Creating macOS application...${NC}"
    
    APP_DIR="/Applications/Arcadia.app"
    
    if [ -d "${APP_DIR}" ]; then
        rm -rf "${APP_DIR}"
    fi
    
    mkdir -p "${APP_DIR}/Contents/MacOS"
    mkdir -p "${APP_DIR}/Contents/Resources"
    
    cat > "${APP_DIR}/Contents/MacOS/Arcadia" << 'EOF'
#!/bin/bash
cd "$HOME/.arcadia"
npm start
EOF
    
    chmod +x "${APP_DIR}/Contents/MacOS/Arcadia"
    
    cat > "${APP_DIR}/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Arcadia</string>
    <key>CFBundleIdentifier</key>
    <string>com.arcadia.app</string>
    <key>CFBundleName</key>
    <string>Arcadia</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
</dict>
</plist>
EOF
    
    echo -e "${GREEN}✓${NC} macOS application created at ${APP_DIR}"
fi

# Installation complete
echo ""
echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   Installation Complete! 🎉        ║${NC}"
echo -e "${GREEN}╔════════════════════════════════════╗${NC}"
echo ""
echo -e "${BLUE}To start Arcadia:${NC}"
echo -e "  • Run: ${GREEN}arcadia${NC} in your terminal"

if [ "${PLATFORM}" = "mac" ]; then
    echo -e "  • Or open ${GREEN}Arcadia${NC} from Applications"
elif [ "${PLATFORM}" = "linux" ]; then
    echo -e "  • Or search for ${GREEN}Arcadia${NC} in your application menu"
fi

echo ""
echo -e "${YELLOW}Note:${NC} If 'arcadia' command is not found, restart your terminal or run:"
echo -e "  ${GREEN}source ~/.$(basename $SHELL)rc${NC}"
echo ""
echo -e "${BLUE}Repository location:${NC} ${INSTALL_DIR}"
echo -e "${BLUE}To uninstall:${NC} rm -rf ${INSTALL_DIR} && rm ${LAUNCHER_PATH}"
echo ""
echo -e "${GREEN}Thank you for installing Arcadia!${NC}"
