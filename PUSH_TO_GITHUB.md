# How to Push to GitHub

Since git command-line tools need to be installed, here are your options:

## Option 1: Install Git Command Line Tools
When the popup appears, click "Install" to install Xcode Command Line Tools.
Then run:
```bash
cd /Users/ikramullaj/Downloads/Arcadia-main
git init
git add .
git commit -m "Removed inject button, added installer and workflows"
git branch -M main
git remote add origin https://github.com/thelastligma/Arcadia.git
git push -u origin main
```

## Option 2: Use GitHub Desktop
1. Download GitHub Desktop from https://desktop.github.com
2. Open GitHub Desktop
3. Click "Add" → "Add Existing Repository"
4. Select the folder: /Users/ikramullaj/Downloads/Arcadia-main
5. Click "Publish repository" or "Push origin"

## Option 3: Use VS Code
1. Open this folder in VS Code
2. Click the Source Control icon (left sidebar)
3. Click "Initialize Repository"
4. Stage all changes (+ icon)
5. Enter commit message: "Removed inject button, added installer and workflows"
6. Click the checkmark to commit
7. Click "Publish Branch" and select your GitHub repository

## What's Included:
✅ install.sh - Working installer script
✅ .github/workflows/ - Automatic build system
✅ Updated README.md - Installation instructions
✅ Removed inject button from UI
✅ Kept Auto Inject in settings

## After Pushing:
Users can install with:
```bash
curl -fsSL https://raw.githubusercontent.com/thelastligma/Arcadia/main/install.sh | bash
```

## Create a Release:
Once pushed, create a release to trigger automatic builds:
```bash
git tag v1.0.0
git push origin v1.0.0
```
