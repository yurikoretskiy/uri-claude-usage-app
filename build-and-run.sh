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

# Copy bundled resources
cp -f .build/debug/ClaudeUsage_ClaudeUsage.bundle/claude-logo.png "$APP_DIR/Resources/" 2>/dev/null || \
cp -f ClaudeUsage/Resources/claude-logo.png "$APP_DIR/Resources/" 2>/dev/null || true

# Info.plist for no-dock-icon menu bar app
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

echo "Launching..."
open .build/debug/ClaudeUsage.app
