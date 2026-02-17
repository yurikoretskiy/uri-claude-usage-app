#!/bin/bash
set -e

cd "$(dirname "$0")"

echo "Building..."
swift build

echo "Creating app bundle..."
APP_DIR=".build/debug/ClaudeUsage.app/Contents"
mkdir -p "$APP_DIR/MacOS"
mkdir -p "$APP_DIR/Resources"
cp .build/debug/ClaudeUsage "$APP_DIR/MacOS/ClaudeUsage"
cp -f ClaudeUsage/Resources/claude-logo.png "$APP_DIR/Resources/"

cat > "$APP_DIR/Info.plist" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>ClaudeUsage</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.ClaudeUsage</string>
    <key>CFBundleName</key>
    <string>Claude Usage</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
</dict>
</plist>
PLIST

echo "Installing to /Applications..."
rm -rf "/Applications/Claude Usage.app"
cp -R .build/debug/ClaudeUsage.app "/Applications/Claude Usage.app"

echo ""
echo "Installed to /Applications/Claude Usage.app"
echo "You can now:"
echo "  - Open it from Spotlight (Cmd+Space, type 'Claude Usage')"
echo "  - Open it from Launchpad"
echo "  - Run: open '/Applications/Claude Usage.app'"
echo ""
echo "Launching now..."
open "/Applications/Claude Usage.app"
