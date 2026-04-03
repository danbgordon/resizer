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

OUTPUT_DIR="$HOME/Applications/Chrome Resizer Apps"
rm -rf "$OUTPUT_DIR"
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
# 1b. Individual viewport size apps
# ----------------------------------------------------------
# These adjust the window so the *viewport* (web content area)
# matches the target dimensions, compensating for Chrome's
# tab bar, address bar, bookmarks bar, etc.

# --- Viewport 1280 x 1024 ---
cat > /tmp/chrome_viewport_1280x1024.applescript << 'APPLESCRIPT'
on run
    tell application "Google Chrome"
        activate
        delay 0.3
        set targetWidth to 1280
        set targetHeight to 1024

        -- First pass: set window to target size
        set bounds of front window to {0, 25, targetWidth, targetHeight + 25}
        delay 0.3

        -- Measure actual viewport via JavaScript
        try
            set jsResult to execute front window's active tab javascript "window.innerWidth + ',' + window.innerHeight"
        on error
            display dialog "Viewport mode requires:" & return & return & "1. Enable: Chrome → View → Developer → Allow JavaScript from Apple Events" & return & "2. A regular web page in the active tab (not a chrome:// page)" & return & return & "Falling back to window size." buttons {"OK"} default button "OK"
            display notification "Chrome resized to 1280 × 1024 (window)" with title "Chrome Resizer"
            return
        end try

        -- Parse the result and calculate chrome overhead
        set AppleScript's text item delimiters to ","
        set resultParts to text items of jsResult
        set actualVW to (item 1 of resultParts) as integer
        set actualVH to (item 2 of resultParts) as integer
        set AppleScript's text item delimiters to ""

        set deltaW to targetWidth - actualVW
        set deltaH to targetHeight - actualVH

        -- Second pass: adjust bounds to compensate
        set bounds of front window to {0, 25, targetWidth + deltaW, targetHeight + deltaH + 25}
    end tell

    display notification "Chrome viewport set to 1280 × 1024" with title "Chrome Resizer"
end run
APPLESCRIPT

osacompile -o "$OUTPUT_DIR/Chrome Viewport 1280×1024.app" /tmp/chrome_viewport_1280x1024.applescript
echo "  ✓ Chrome Viewport 1280×1024.app"

# --- Viewport 1920 x 1080 ---
cat > /tmp/chrome_viewport_1920x1080.applescript << 'APPLESCRIPT'
on run
    tell application "Google Chrome"
        activate
        delay 0.3
        set targetWidth to 1920
        set targetHeight to 1080

        -- First pass: set window to target size
        set bounds of front window to {0, 25, targetWidth, targetHeight + 25}
        delay 0.3

        -- Measure actual viewport via JavaScript
        try
            set jsResult to execute front window's active tab javascript "window.innerWidth + ',' + window.innerHeight"
        on error
            display dialog "Viewport mode requires:" & return & return & "1. Enable: Chrome → View → Developer → Allow JavaScript from Apple Events" & return & "2. A regular web page in the active tab (not a chrome:// page)" & return & return & "Falling back to window size." buttons {"OK"} default button "OK"
            display notification "Chrome resized to 1920 × 1080 (window)" with title "Chrome Resizer"
            return
        end try

        -- Parse the result and calculate chrome overhead
        set AppleScript's text item delimiters to ","
        set resultParts to text items of jsResult
        set actualVW to (item 1 of resultParts) as integer
        set actualVH to (item 2 of resultParts) as integer
        set AppleScript's text item delimiters to ""

        set deltaW to targetWidth - actualVW
        set deltaH to targetHeight - actualVH

        -- Second pass: adjust bounds to compensate
        set bounds of front window to {0, 25, targetWidth + deltaW, targetHeight + deltaH + 25}
    end tell

    display notification "Chrome viewport set to 1920 × 1080" with title "Chrome Resizer"
end run
APPLESCRIPT

osacompile -o "$OUTPUT_DIR/Chrome Viewport 1920×1080.app" /tmp/chrome_viewport_1920x1080.applescript
echo "  ✓ Chrome Viewport 1920×1080.app"

# ----------------------------------------------------------
# 2. Chooser app (one app, pick from a list)
# ----------------------------------------------------------

cat > /tmp/chrome_resizer_chooser.applescript << 'APPLESCRIPT'
on resizeChrome(targetWidth, targetHeight, useViewport)
    tell application "Google Chrome"
        activate
        delay 0.3
        set bounds of front window to {0, 25, targetWidth, targetHeight + 25}

        if useViewport then
            delay 0.3
            try
                set jsResult to execute front window's active tab javascript "window.innerWidth + ',' + window.innerHeight"
            on error
                display dialog "Viewport mode requires:" & return & return & "1. Enable: Chrome → View → Developer → Allow JavaScript from Apple Events" & return & "2. A regular web page in the active tab (not a chrome:// page)" & return & return & "Falling back to window size." buttons {"OK"} default button "OK"
                return
            end try

            set AppleScript's text item delimiters to ","
            set resultParts to text items of jsResult
            set actualVW to (item 1 of resultParts) as integer
            set actualVH to (item 2 of resultParts) as integer
            set AppleScript's text item delimiters to ""

            set deltaW to targetWidth - actualVW
            set deltaH to targetHeight - actualVH
            set bounds of front window to {0, 25, targetWidth + deltaW, targetHeight + deltaH + 25}
        end if
    end tell
end resizeChrome

on run
    set sizeOptions to {"1280 × 1024 (window)", "1920 × 1080 (window)", "1280 × 1024 (viewport)", "1920 × 1080 (viewport)"}

    set chosenSize to choose from list sizeOptions ¬
        with title "Chrome Window Resizer" ¬
        with prompt "Choose a size and mode for Chrome:" ¬
        default items {"1280 × 1024 (window)"}

    if chosenSize is false then return

    set chosenSize to item 1 of chosenSize

    if chosenSize is "1280 × 1024 (window)" then
        resizeChrome(1280, 1024, false)
    else if chosenSize is "1920 × 1080 (window)" then
        resizeChrome(1920, 1080, false)
    else if chosenSize is "1280 × 1024 (viewport)" then
        resizeChrome(1280, 1024, true)
    else if chosenSize is "1920 × 1080 (viewport)" then
        resizeChrome(1920, 1080, true)
    end if

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

on resizeChrome(targetWidth, targetHeight, useViewport)
    tell application "Google Chrome"
        activate
        delay 0.3
        set bounds of front window to {0, 25, targetWidth, targetHeight + 25}

        if useViewport then
            delay 0.3
            try
                set jsResult to execute front window's active tab javascript "window.innerWidth + ',' + window.innerHeight"
            on error
                display dialog "Viewport mode requires:" & return & return & "1. Enable: Chrome → View → Developer → Allow JavaScript from Apple Events" & return & "2. A regular web page in the active tab (not a chrome:// page)" & return & return & "Falling back to window size." buttons {"OK"} default button "OK"
                return
            end try

            set AppleScript's text item delimiters to ","
            set resultParts to text items of jsResult
            set actualVW to (item 1 of resultParts) as integer
            set actualVH to (item 2 of resultParts) as integer
            set AppleScript's text item delimiters to ""

            set deltaW to targetWidth - actualVW
            set deltaH to targetHeight - actualVH
            set bounds of front window to {0, 25, targetWidth + deltaW, targetHeight + deltaH + 25}
        end if
    end tell
end resizeChrome

on run
    set sizeOptions to {"1280 × 1024 (window)", "1920 × 1080 (window)", "1280 × 1024 (viewport)", "1920 × 1080 (viewport)"}

    repeat
        set chosenSize to choose from list sizeOptions ¬
            with title "Chrome Window Resizer" ¬
            with prompt "Choose a size and mode for Chrome:" ¬
            default items {"1280 × 1024 (window)"} ¬
            cancel button name "Quit"

        if chosenSize is false then return

        set chosenSize to item 1 of chosenSize

        if chosenSize is "1280 × 1024 (window)" then
            resizeChrome(1280, 1024, false)
        else if chosenSize is "1920 × 1080 (window)" then
            resizeChrome(1920, 1080, false)
        else if chosenSize is "1280 × 1024 (viewport)" then
            resizeChrome(1280, 1024, true)
        else if chosenSize is "1920 × 1080 (viewport)" then
            resizeChrome(1920, 1080, true)
        end if

        display notification ("Chrome resized to " & chosenSize) with title "Chrome Resizer"

        delay 1
    end repeat
end run
APPLESCRIPT

osacompile -o "$OUTPUT_DIR/Chrome Resizer (Repeat).app" /tmp/chrome_resizer_menubar.applescript
echo "  ✓ Chrome Resizer (Repeat).app"

# ----------------------------------------------------------
# Re-sign all apps (ad-hoc) so macOS doesn't reject them
# ----------------------------------------------------------
for app in "$OUTPUT_DIR"/*.app; do
    codesign --force --sign - "$app"
done
echo ""
echo "  All apps re-signed."

# ----------------------------------------------------------
# Clean up temp files
# ----------------------------------------------------------
rm -f /tmp/chrome_1280x1024.applescript
rm -f /tmp/chrome_1920x1080.applescript
rm -f /tmp/chrome_viewport_1280x1024.applescript
rm -f /tmp/chrome_viewport_1920x1080.applescript
rm -f /tmp/chrome_resizer_chooser.applescript
rm -f /tmp/chrome_resizer_menubar.applescript

echo ""
echo "============================================================"
echo "  Done! Apps are in: $OUTPUT_DIR"
echo ""
echo "  What you get:"
echo "    • Chrome 1280×1024.app           — one-click resize window to 1280×1024"
echo "    • Chrome 1920×1080.app           — one-click resize window to 1920×1080"
echo "    • Chrome Viewport 1280×1024.app  — one-click resize viewport to 1280×1024"
echo "    • Chrome Viewport 1920×1080.app  — one-click resize viewport to 1920×1080"
echo "    • Chrome Resizer.app             — pick size and mode from a list"
echo "    • Chrome Resizer (Repeat).app    — keeps prompting until quit"
echo ""
echo "  Drag any of these to the Dock for easy access."
echo "============================================================"
