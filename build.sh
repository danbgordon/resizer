#!/bin/bash
# ============================================================
# Resizer — Build Script
# ============================================================
# Compiles resizer.swift into a native macOS .app bundle.
#
# Usage:  chmod +x build.sh && ./build.sh
# Output: ~/Applications/Resizer.app
# ============================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_DIR="$HOME/Applications"
APP_NAME="Resizer"
APP_PATH="$APP_DIR/$APP_NAME.app"
BUNDLE_ID="com.danbgordon.resizer"

echo "Building $APP_NAME..."
echo ""

# ----------------------------------------------------------
# Compile Swift
# ----------------------------------------------------------
echo "  Compiling main binary..."
swiftc "$SCRIPT_DIR/resizer.swift" \
    -o /tmp/resizer \
    -framework Cocoa \
    -framework ApplicationServices \
    -O 2>/dev/null

echo "  Compiling ax_check helper..."
cat > /tmp/ax_check.swift << 'SWIFT'
import ApplicationServices
print(AXIsProcessTrusted())
SWIFT
swiftc /tmp/ax_check.swift -o /tmp/ax_check -framework ApplicationServices -O 2>/dev/null

# ----------------------------------------------------------
# Create .app bundle
# ----------------------------------------------------------
echo "  Creating app bundle..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

cp /tmp/resizer "$APP_PATH/Contents/MacOS/resizer"
chmod +x "$APP_PATH/Contents/MacOS/resizer"

cp /tmp/ax_check "$APP_PATH/Contents/Resources/ax_check"
chmod +x "$APP_PATH/Contents/Resources/ax_check"

cat > "$APP_PATH/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>resizer</string>
    <key>CFBundleVersion</key>
    <string>1.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
</dict>
</plist>
PLIST

# ----------------------------------------------------------
# Codesign
# ----------------------------------------------------------
echo "  Signing..."
codesign --force --sign - "$APP_PATH"

# ----------------------------------------------------------
# Clean up
# ----------------------------------------------------------
rm -f /tmp/resizer /tmp/ax_check /tmp/ax_check.swift

# Reset flags since rebuild changes codesign (which resets macOS permissions)
defaults delete com.danbgordon.resizer 2>/dev/null || true

echo "  Done!"
echo ""
echo "============================================================"
echo "  App:  $APP_PATH"
echo ""
echo "  Drag to your Dock for easy access."
echo "  Config: ~/.config/resizer/sizes.conf (created on first launch)"
echo "============================================================"
