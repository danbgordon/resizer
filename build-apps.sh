#!/bin/bash
# ============================================================
# Window Resizer — App Builder
# ============================================================
# Run this script on any Mac to generate a Window Resizer .app
# that resizes any application's window to preset dimensions.
#
# Usage:  chmod +x build-apps.sh && ./build-apps.sh
# Output: ~/Applications/Window Resizer.app
# ============================================================

set -e

APP_DIR="$HOME/Applications"
APP_NAME="Window Resizer"
CONFIG_DIR="$HOME/.config/window-resizer"
CONFIG_FILE="$CONFIG_DIR/sizes.conf"

mkdir -p "$APP_DIR"

# ----------------------------------------------------------
# Create default config file if it doesn't exist
# ----------------------------------------------------------
if [ ! -f "$CONFIG_FILE" ]; then
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << 'CONFIG'
# Window Resizer — custom sizes
# Format: width,height (one per line)
# Lines starting with # are ignored, blank lines are skipped
#
# These dimensions set the full window size. When a supported
# browser (Chrome, Safari) is the target, viewport options are
# also offered automatically.
1280,1024
1920,1080
CONFIG
    echo "  Created default config: $CONFIG_FILE"
fi

echo "Building $APP_NAME..."
echo ""

# ----------------------------------------------------------
# Generate the AppleScript
# ----------------------------------------------------------
cat > /tmp/window_resizer.applescript << 'APPLESCRIPT'
-- ============================================================
-- Window Resizer
-- Resizes the frontmost window to a preset size.
-- Sizes are loaded from ~/.config/window-resizer/sizes.conf
-- ============================================================

on loadSizes()
    set configPath to (POSIX path of (path to home folder)) & ".config/window-resizer/sizes.conf"
    try
        set fileContents to read POSIX file configPath as «class utf8»
    on error
        -- Config missing; use built-in defaults
        return {{targetWidth:1280, targetHeight:1024}, {targetWidth:1920, targetHeight:1080}}
    end try

    set sizeList to {}
    set configLines to every paragraph of fileContents
    repeat with aLine in configLines
        set trimmed to aLine as text
        if trimmed is not "" and trimmed does not start with "#" then
            set AppleScript's text item delimiters to ","
            set parts to text items of trimmed
            set AppleScript's text item delimiters to ""
            if (count of parts) ≥ 2 then
                try
                    set w to (item 1 of parts) as integer
                    set h to (item 2 of parts) as integer
                    set end of sizeList to {targetWidth:w, targetHeight:h}
                end try
            end if
        end if
    end repeat

    if (count of sizeList) is 0 then
        return {{targetWidth:1280, targetHeight:1024}, {targetWidth:1920, targetHeight:1080}}
    end if
    return sizeList
end loadSizes

on isBrowser(appName)
    return appName is "Google Chrome" or appName is "Google Chrome Canary" or appName is "Safari" or appName is "Chromium" or appName is "Brave Browser" or appName is "Microsoft Edge" or appName is "Arc"
end isBrowser

on isChromium(appName)
    return appName is "Google Chrome" or appName is "Google Chrome Canary" or appName is "Chromium" or appName is "Brave Browser" or appName is "Microsoft Edge" or appName is "Arc"
end isChromium

on buildOptionList(sizes, showViewport)
    set opts to {}
    if showViewport then
        repeat with s in sizes
            set w to targetWidth of s
            set h to targetHeight of s
            set end of opts to (w as text) & " × " & (h as text) & " (window)"
        end repeat
        repeat with s in sizes
            set w to targetWidth of s
            set h to targetHeight of s
            set end of opts to (w as text) & " × " & (h as text) & " (viewport)"
        end repeat
    else
        repeat with s in sizes
            set w to targetWidth of s
            set h to targetHeight of s
            set end of opts to (w as text) & " × " & (h as text)
        end repeat
    end if
    return opts
end buildOptionList

on parseSelection(chosenSize)
    -- Parse "1280 × 1024", "1280 × 1024 (window)", or "1280 × 1024 (viewport)"
    set isViewport to chosenSize contains "(viewport)"

    -- Strip the mode suffix if present
    set cleanSize to chosenSize
    if chosenSize contains " (window)" then
        set cleanSize to text 1 thru ((offset of " (window)" in chosenSize) - 1) of chosenSize
    else if chosenSize contains " (viewport)" then
        set cleanSize to text 1 thru ((offset of " (viewport)" in chosenSize) - 1) of chosenSize
    end if

    -- Parse "1280 × 1024" (note: × is Unicode, not x)
    set AppleScript's text item delimiters to " × "
    set parts to text items of cleanSize
    set AppleScript's text item delimiters to ""

    set w to (item 1 of parts) as integer
    set h to (item 2 of parts) as integer

    return {targetWidth:w, targetHeight:h, isViewport:isViewport}
end parseSelection

on resizeWindow(appName, targetWidth, targetHeight)
    try
        tell application appName
            activate
            delay 0.3
            set bounds of front window to {0, 25, targetWidth, targetHeight + 25}
        end tell
    on error errMsg
        display dialog "Could not resize " & appName & ":" & return & return & errMsg buttons {"OK"} default button "OK"
    end try
end resizeWindow

on resizeViewport(appName, targetWidth, targetHeight)
    -- First pass: set window to target size
    tell application appName
        activate
        delay 0.3
        set bounds of front window to {0, 25, targetWidth, targetHeight + 25}
    end tell
    delay 0.3

    -- Measure viewport via JavaScript (browser-specific)
    set jsCode to "window.innerWidth + ',' + window.innerHeight"
    set jsResult to ""
    try
        if my isChromium(appName) then
            using terms from application "Google Chrome"
                tell application appName
                    set jsResult to execute front window's active tab javascript jsCode
                end tell
            end using terms from
        else if appName is "Safari" then
            tell application "Safari"
                set jsResult to do JavaScript jsCode in front document
            end tell
        else
            display notification (appName & " resized to " & targetWidth & " × " & targetHeight & " (window)") with title "Window Resizer"
            return
        end if
    on error
        display dialog "Viewport mode requires:" & return & return & "1. A regular web page in the active tab (not a browser internal page)" & return & "2. For Chrome: enable View → Developer → Allow JavaScript from Apple Events" & return & return & "Falling back to window size." buttons {"OK"} default button "OK"
        display notification (appName & " resized to " & targetWidth & " × " & targetHeight & " (window)") with title "Window Resizer"
        return
    end try

    -- Parse viewport dimensions and calculate chrome overhead
    set AppleScript's text item delimiters to ","
    set resultParts to text items of jsResult
    set actualVW to (item 1 of resultParts) as integer
    set actualVH to (item 2 of resultParts) as integer
    set AppleScript's text item delimiters to ""

    set deltaW to targetWidth - actualVW
    set deltaH to targetHeight - actualVH

    -- Second pass: adjust bounds to compensate
    tell application appName
        set bounds of front window to {0, 25, targetWidth + deltaW, targetHeight + deltaH + 25}
    end tell

    display notification (appName & " viewport set to " & targetWidth & " × " & targetHeight) with title "Window Resizer"
end resizeViewport

on getPreviousApp()
    -- Get the app that was frontmost before us, using lsappinfo's activation order.
    -- Skips Finder and other launcher apps since the user may have launched us from there.
    set shellScript to "skip='Finder|Dock|Spotlight|Launchpad|Window Resizer'; first=true; for asn in $(lsappinfo visibleProcessList | grep -oE 'ASN:[^ ]+' | sed 's/\"[^\"]*\"//; s/-:$//'); do if $first; then first=false; continue; fi; name=$(lsappinfo info -only name \"$asn\" 2>/dev/null | awk -F'=\"' '{print $2}' | sed 's/\"$//'); if [ -n \"$name\" ] && ! echo \"$name\" | grep -qE \"^($skip)$\"; then echo \"$name\"; exit 0; fi; done"
    try
        set targetName to do shell script shellScript
    on error
        set targetName to ""
    end try
    return targetName
end getPreviousApp

on run
    set sizes to my loadSizes()

    -- Auto-detect the app that was active before us
    set targetApp to my getPreviousApp()
    if targetApp is "" then
        display dialog "No target window found. Click on a window first, then launch Window Resizer." buttons {"OK"} default button "OK"
        return
    end if

    -- Build size options (include viewport if target is a browser)
    set browserTarget to my isBrowser(targetApp)
    set opts to my buildOptionList(sizes, browserTarget)

    set chosenSize to choose from list opts ¬
        with title "Window Resizer" ¬
        with prompt "Resize: " & targetApp ¬
        default items {item 1 of opts}

    if chosenSize is false then return
    set chosenSize to item 1 of chosenSize

    -- Parse and execute
    set sizeInfo to my parseSelection(chosenSize)
    set w to targetWidth of sizeInfo
    set h to targetHeight of sizeInfo

    if isViewport of sizeInfo then
        my resizeViewport(targetApp, w, h)
    else
        my resizeWindow(targetApp, w, h)
        display notification (targetApp & " resized to " & w & " × " & h) with title "Window Resizer"
    end if
end run
APPLESCRIPT

# ----------------------------------------------------------
# Compile and sign
# ----------------------------------------------------------
rm -rf "$APP_DIR/$APP_NAME.app"
osacompile -o "$APP_DIR/$APP_NAME.app" /tmp/window_resizer.applescript

# Set a proper bundle identifier so macOS can track permissions correctly
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.fleetdm.window-resizer" "$APP_DIR/$APP_NAME.app/Contents/Info.plist"

codesign --force --sign - "$APP_DIR/$APP_NAME.app"
echo "  ✓ $APP_NAME.app"

# ----------------------------------------------------------
# Clean up temp file
# ----------------------------------------------------------
rm -f /tmp/window_resizer.applescript

echo ""
echo "============================================================"
echo "  Done!"
echo ""
echo "  App:    $APP_DIR/$APP_NAME.app"
echo "  Config: $CONFIG_FILE"
echo ""
echo "  The app resizes the frontmost window to a preset size."
echo "  Edit the config file to add your own custom sizes."
echo "  Drag the app to the Dock for easy access."
echo "============================================================"
