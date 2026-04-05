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

on getScreenFrames()
    -- Get screen frames once at launch (avoids repeated Swift cold-starts).
    -- Returns pipe-delimited string: "x,y,w,h|x,y,w,h|..."
    return do shell script "swift -e '
import AppKit
let mainHeight = NSScreen.screens[0].frame.height
var lines: [String] = []
for screen in NSScreen.screens {
    let f = screen.frame
    let topY = mainHeight - f.origin.y - f.height
    lines.append(\"\\(Int(f.origin.x)),\\(Int(topY)),\\(Int(f.width)),\\(Int(f.height))\")
}
print(lines.joined(separator: \"|\"))
'"
end getScreenFrames

on clampToScreen(winX, winY, newWidth, newHeight, screenData)
    -- Find which screen the window is on and adjust position to stay on it.
    set AppleScript's text item delimiters to "|"
    set screenLines to text items of screenData
    set AppleScript's text item delimiters to ""

    -- Find which screen contains the window's top-left corner
    set bestX to 0
    set bestY to 0
    set bestW to 9999
    set bestH to 9999
    repeat with aLine in screenLines
        set AppleScript's text item delimiters to ","
        set parts to text items of aLine
        set AppleScript's text item delimiters to ""
        set sX to (item 1 of parts) as integer
        set sY to (item 2 of parts) as integer
        set sW to (item 3 of parts) as integer
        set sH to (item 4 of parts) as integer
        if winX ≥ sX and winX < (sX + sW) and winY ≥ sY and winY < (sY + sH) then
            set bestX to sX
            set bestY to sY
            set bestW to sW
            set bestH to sH
            exit repeat
        end if
    end repeat

    set newX to winX
    set newY to winY
    if (newX + newWidth) > (bestX + bestW) then
        set newX to (bestX + bestW) - newWidth
    end if
    if (newY + newHeight) > (bestY + bestH) then
        set newY to (bestY + bestH) - newHeight
    end if
    if newX < bestX then set newX to bestX
    if newY < bestY then set newY to bestY

    return {newX, newY}
end clampToScreen

on resizeWindow(appName, targetWidth, targetHeight, screenFrames)
    try
        -- Try direct app scripting first (works for most apps)
        tell application appName
            activate
            set {x1, y1, x2, y2} to bounds of front window
        end tell
        set {newX, newY} to my clampToScreen(x1, y1, targetWidth, targetHeight, screenFrames)
        tell application appName
            set bounds of front window to {newX, newY, newX + targetWidth, newY + targetHeight}
        end tell
    on error
        -- Fallback: use System Events (for Electron apps, etc.)
        -- First check if we have Accessibility permission; prompt if not
        -- Check Accessibility without prompting first
        set axCheckPath to POSIX path of (path to me) & "Contents/Resources/ax_check"
        set axPromptPath to POSIX path of (path to me) & "Contents/Resources/ax_prompt"
        set axTrusted to do shell script quoted form of axCheckPath
        if axTrusted is "false" then
            tell me to activate
            display dialog "Window Resizer needs Accessibility access to resize " & appName & "." & return & return & "Click OK to open System Settings and grant access. Window Resizer will automatically resize " & appName & " once permission is granted." buttons {"OK"} default button "OK"
            do shell script quoted form of axPromptPath
            -- Poll until permission is granted (uses bundled binary, no Automation prompts)
            repeat
                delay 1
                set axCheck to do shell script quoted form of axCheckPath
                if axCheck is "true" then exit repeat
            end repeat
            -- Permission granted — activate the target app and fall through to resize
            tell application appName to activate
            delay 0.2
        end if
        try
            tell application appName to activate
            tell application "System Events"
                tell application process appName
                    set {x1, y1} to position of window 1
                end tell
            end tell
            set {newX, newY} to my clampToScreen(x1, y1, targetWidth, targetHeight, screenFrames)
            tell application "System Events"
                tell application process appName
                    set position of window 1 to {newX, newY}
                    set size of window 1 to {targetWidth, targetHeight}
                end tell
            end tell
        on error errMsg
            display dialog "Could not resize " & appName & ":" & return & return & errMsg buttons {"OK"} default button "OK"
        end try
    end try
end resizeWindow

on resizeViewport(appName, targetWidth, targetHeight, screenFrames)
    -- First pass: set window to target size on the same screen
    tell application appName
        activate
        set {x1, y1, x2, y2} to bounds of front window
    end tell
    set {newX, newY} to my clampToScreen(x1, y1, targetWidth, targetHeight, screenFrames)
    tell application appName
        set bounds of front window to {newX, newY, newX + targetWidth, newY + targetHeight}
    end tell
    delay 0.1

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

    -- Second pass: adjust bounds to compensate, staying on same screen
    set adjW to targetWidth + deltaW
    set adjH to targetHeight + deltaH
    tell application appName
        set {x1, y1, x2, y2} to bounds of front window
    end tell
    set {newX, newY} to my clampToScreen(x1, y1, adjW, adjH, screenFrames)
    tell application appName
        set bounds of front window to {newX, newY, newX + adjW, newY + adjH}
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
    set screenFrames to my getScreenFrames()

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
        my resizeViewport(targetApp, w, h, screenFrames)
    else
        my resizeWindow(targetApp, w, h, screenFrames)
        display notification (targetApp & " resized to " & w & " × " & h) with title "Window Resizer"
    end if
end run
APPLESCRIPT

# ----------------------------------------------------------
# Build AX check helper (instant binary, no swift cold-start)
# ----------------------------------------------------------
cat > /tmp/ax_check.swift << 'SWIFT'
import Cocoa
print(AXIsProcessTrusted())
SWIFT
swiftc /tmp/ax_check.swift -o /tmp/ax_check 2>/dev/null

cat > /tmp/ax_prompt.swift << 'SWIFT'
import Cocoa
let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
_ = AXIsProcessTrustedWithOptions(opts)
SWIFT
swiftc /tmp/ax_prompt.swift -o /tmp/ax_prompt 2>/dev/null

# ----------------------------------------------------------
# Compile and sign
# ----------------------------------------------------------
rm -rf "$APP_DIR/$APP_NAME.app"
osacompile -o "$APP_DIR/$APP_NAME.app" /tmp/window_resizer.applescript

# Bundle the helper binaries inside the app
cp /tmp/ax_check "$APP_DIR/$APP_NAME.app/Contents/Resources/ax_check"
cp /tmp/ax_prompt "$APP_DIR/$APP_NAME.app/Contents/Resources/ax_prompt"
chmod +x "$APP_DIR/$APP_NAME.app/Contents/Resources/ax_check"
chmod +x "$APP_DIR/$APP_NAME.app/Contents/Resources/ax_prompt"

# Set a proper bundle identifier so macOS can track permissions correctly
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string com.fleetdm.window-resizer" "$APP_DIR/$APP_NAME.app/Contents/Info.plist"

codesign --force --sign - "$APP_DIR/$APP_NAME.app"
echo "  ✓ $APP_NAME.app"

# ----------------------------------------------------------
# Clean up temp files
# ----------------------------------------------------------
rm -f /tmp/window_resizer.applescript /tmp/ax_check /tmp/ax_check.swift /tmp/ax_prompt /tmp/ax_prompt.swift

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
