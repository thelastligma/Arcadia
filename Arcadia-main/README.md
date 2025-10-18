# Arcadia UI

Simple Electron-based UI for opiumware script executor.

Repository: https://github.com/thelastligma/Arcadia

## 🚀 Quick Installation

### One-Line Install (macOS/Linux)

```bash
curl -fsSL https://raw.githubusercontent.com/thelastligma/Arcadia/main/install.sh | bash
```

This will automatically:
- Install dependencies
- Clone the repository
- Create a launcher command
- Set up the application

After installation, simply run `arcadia` in your terminal!

### Manual Installation

```bash
# Clone the repository
git clone https://github.com/thelastligma/Arcadia.git
cd Arcadia

# Install dependencies
npm install

# Run the application
npm start
```

## 📦 Building

### macOS
```bash
# Build for x64
npm run package:mac

# Build universal (x64 + ARM)
npm run build:mac
```

### Linux
```bash
npx electron-packager . ArcadiaUI --platform=linux --arch=x64 --asar.compression=zstd --overwrite
```

### Windows
```bash
npx electron-packager . ArcadiaUI --platform=win32 --arch=x64 --asar.compression=zstd --overwrite
```

## ⚙️ Features

- Modern, clean UI
- Script editor with syntax highlighting
- Execute scripts via OpiumwareScript protocol
- Kill Roblox process
- Always on top option
- Theme customization
- Auto-inject support
- File management (save/open scripts)

## 🔧 Development

The project uses:
- Electron for the desktop application
- Ace Editor for code editing
- Custom IPC for script execution

## 📝 Usage

1. Launch Arcadia
2. Write or load your script
3. Click "Execute" to run the script
4. Use settings to customize your experience

## 🤝 Contributing

Pull requests are welcome! For major changes, please open an issue first.

## 📄 License

MIT

