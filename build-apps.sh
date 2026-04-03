#!/bin/bash
# ============================================================
# Chrome Window Resizer — App Builder
# ============================================================
# Run this script on any Mac to generate .app files that
# resize Google Chrome to preset dimensions.
#
# Usage:  chmod +x build-apps.sh && ./build-apps.sh
# Output: A "Chrome Resizer Apps" folder on the Desktop
# ============================================================

set -e

OUTPUT_DIR="$HOME/Desktop/Chrome Resizer Apps"
mkdir -p "$OUTPUT_DIR"

echo "Building Chrome Resizer apps..."
echo ""

# ----------------------------------------------------------
# 1. Individual size apps (great for Dock placement)
# ----------------------------------------------------------

# --- 1280 x 1024 ---
cat > /tmp/chrome_1280x1024.applescript << 'APPLESCRIPT'
on run
    tell application "Google Chrome"
        activate
        delay 0.3
        set targetWidth to 1280
        set targetHeight to 1024
        set bounds of front window to {0, 25, targetWidth, targetHeight + 25}
    end tell
    
    display notification "Chrome resized to 1280 × 1024" with title "Chrome Resizer"
end run
APPLESCRIPT

osacompile -o "$OUTPUT_DIR/Chrome 1280×1024.app" /tmp/chrome_1280x1024.applescript
echo "  ✓ Chrome 1280×1024.app"

# --- 1920 x 1080 ---
cat > /tmp/chrome_1920x1080.applescript << 'APPLESCRIPT'
on run
    tell application "Google Chrome"
        activate
        delay 0.3
        set targetWidth to 1920
        set targetHeight to 1080
        set bounds of front window to {0, 25, targetWidth, targetHeight + 25}
    end tell
    
    display notification "Chrome resized to 1920 × 1080" with title "Chrome Resizer"
end run
APPLESCRIPT

osacompile -o "$OUTPUT_DIR/Chrome 1920×1080.app" /tmp/chrome_1920x1080.applescript
echo "  ✓ Chrome 1920×1080.app"

# ----------------------------------------------------------
# 2. Chooser app (one app, pick from a list)
# ----------------------------------------------------------

cat > /tmp/chrome_resizer_chooser.applescript << 'APPLESCRIPT'
on run
    set sizeOptions to {"1280 × 1024", "1920 × 1080"}
    
    set chosenSize to choose from list sizeOptions ¬
        with title "Chrome Window Resizer" ¬
        with prompt "Choose a window size for Chrome:" ¬
        default items {"1280 × 1024"}
    
    if chosenSize is false then return
    
    set chosenSize to item 1 of chosenSize
    
    if chosenSize is "1280 × 1024" then
        set targetWidth to 1280
        set targetHeight to 1024
    else if chosenSize is "1920 × 1080" then
        set targetWidth to 1920
        set targetHeight to 1080
    end if
    
    tell application "Google Chrome"
        activate
        delay 0.3
        set bounds of front window to {0, 25, targetWidth, targetHeight + 25}
    end tell
    
    display notification ("Chrome resized to " & chosenSize) with title "Chrome Resizer"
end run
APPLESCRIPT

osacompile -o "$OUTPUT_DIR/Chrome Resizer.app" /tmp/chrome_resizer_chooser.applescript
echo "  ✓ Chrome Resizer.app (chooser)"

# ----------------------------------------------------------
# 3. Menu bar helper (stays in menu bar, always accessible)
# ----------------------------------------------------------

cat > /tmp/chrome_resizer_menubar.applescript << 'APPLESCRIPT'
-- This version runs as a stay-open app with a menu bar presence.
-- Double-click to launch; it will prompt you to choose a size
-- each time you open it. Drag it to your Dock for easy access.

on run
    set sizeOptions to {"1280 × 1024", "1920 × 1080"}
    
    repeat
        set chosenSize to choose from list sizeOptions ¬
            with title "Chrome Window Resizer" ¬
            with prompt "Choose a window size for Chrome:" ¬
            default items {"1280 × 1024"} ¬
            cancel button name "Quit"
        
        if chosenSize is false then return
        
        set chosenSize to item 1 of chosenSize
        
        if chosenSize is "1280 × 1024" then
            set targetWidth to 1280
            set targetHeight to 1024
        else if chosenSize is "1920 × 1080" then
            set targetWidth to 1920
            set targetHeight to 1080
        end if
        
        tell application "Google Chrome"
            activate
            delay 0.3
            set bounds of front window to {0, 25, targetWidth, targetHeight + 25}
        end tell
        
        display notification ("Chrome resized to " & chosenSize) with title "Chrome Resizer"
        
        delay 1
    end repeat
end run
APPLESCRIPT

osacompile -o "$OUTPUT_DIR/Chrome Resizer (Repeat).app" /tmp/chrome_resizer_menubar.applescript
echo "  ✓ Chrome Resizer (Repeat).app"

# ----------------------------------------------------------
# Clean up temp files
# ----------------------------------------------------------
rm -f /tmp/chrome_1280x1024.applescript
rm -f /tmp/chrome_1920x1080.applescript
rm -f /tmp/chrome_resizer_chooser.applescript
rm -f /tmp/chrome_resizer_menubar.applescript

echo ""
echo "============================================================"
echo "  Done! Apps are in: $OUTPUT_DIR"
echo ""
echo "  What you get:"
echo "    • Chrome 1280×1024.app  — one-click resize to 1280×1024"
echo "    • Chrome 1920×1080.app  — one-click resize to 1920×1080"
echo "    • Chrome Resizer.app    — pick from a list each time"
echo "    • Chrome Resizer (Repeat).app — keeps prompting until quit"
echo ""
echo "  Drag any of these to the Dock for easy access."
echo "============================================================"
