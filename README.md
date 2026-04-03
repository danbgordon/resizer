# Chrome Window Resizer — Setup Guide

## What This Does

This toolkit creates small macOS apps that resize your Google Chrome window to exact pixel dimensions with a single click. No Chrome extensions, no third-party dependencies, no security concerns — just native macOS AppleScript.

## Quick Start (Individual Setup)

1. Open **Terminal** (Applications → Utilities → Terminal)
2. Navigate to wherever you saved these files:
   ```
   cd ~/Downloads/chrome-resizer
   ```
3. Make the script executable and run it:
   ```
   chmod +x build-apps.sh
   ./build-apps.sh
   ```
4. A folder called **"Chrome Resizer Apps"** will appear on your Desktop
5. Drag whichever app(s) you want into your **Dock**

That's it. Click the app in your Dock, Chrome resizes.

## What Gets Built

| App | Behavior |
|-----|----------|
| **Chrome 1280×1024.app** | One click → Chrome resizes to 1280×1024 |
| **Chrome 1920×1080.app** | One click → Chrome resizes to 1920×1080 |
| **Chrome Resizer.app** | Presents a dropdown to pick a size |
| **Chrome Resizer (Repeat).app** | Same dropdown, but stays open so you can resize multiple times |

**Recommended for most people:** Drag the individual size apps (1280×1024 and 1920×1080) to your Dock. One click, done.

## First-Time Permission

The first time you run one of these apps, macOS will ask:

> "Chrome [app name]" wants to control "Google Chrome." Allow?

Click **OK**. This is macOS's standard automation permission — it only asks once. If it gets blocked, go to **System Settings → Privacy & Security → Automation** and enable it there.

## Company-Wide Deployment

### Option A: Share the Build Script (Simplest)

1. Distribute the `build-apps.sh` file (via Slack, email, shared drive, etc.)
2. Have each person run the two terminal commands above
3. Done — apps are built locally on their machine

### Option B: Pre-Build and Distribute the .app Files

1. Run `build-apps.sh` on your own Mac
2. Zip the "Chrome Resizer Apps" folder:
   ```
   cd ~/Desktop
   zip -r "Chrome Resizer Apps.zip" "Chrome Resizer Apps"
   ```
3. Share the .zip via your internal file sharing
4. Each person unzips and drags to their Dock

> **Note:** Pre-built .app files may trigger Gatekeeper warnings ("app is from an unidentified developer"). Each person will need to right-click → Open the first time, then click "Open" in the dialog. After that it works normally.

### Option C: MDM Deployment (Fleet, Jamf, etc.)

If you want to push these out silently:

1. Pre-build the apps as above
2. Package them into a `.pkg` installer targeting `/Applications/Utilities/Chrome Resizers/`
3. Deploy via your MDM tool
4. You'll also need to pre-approve the Automation (Accessibility) permission via a PPPC profile:
   - **App:** `/Applications/Utilities/Chrome Resizers/Chrome 1280×1024.app`
   - **Receiver:** `com.google.Chrome`
   - **Permission:** `AppleEvents` → `Allow`
   - Repeat for each .app

This avoids the "wants to control Google Chrome" prompt entirely.

## Adding New Sizes

To add a new size, edit `build-apps.sh`:

1. Copy one of the individual app blocks (e.g., the 1280×1024 section)
2. Change the dimensions and filename
3. Add the new size to the chooser app's `sizeOptions` list and `if/else` block
4. Re-run the script

Example — adding 1440×900:

```bash
cat > /tmp/chrome_1440x900.applescript << 'APPLESCRIPT'
on run
    tell application "Google Chrome"
        activate
        delay 0.3
        set targetWidth to 1440
        set targetHeight to 900
        set bounds of front window to {0, 25, targetWidth, targetHeight + 25}
    end tell
    display notification "Chrome resized to 1440 × 900" with title "Chrome Resizer"
end run
APPLESCRIPT

osacompile -o "$OUTPUT_DIR/Chrome 1440×900.app" /tmp/chrome_1440x900.applescript
```

## How It Works

Each `.app` is a compiled AppleScript that:

1. Activates Google Chrome (brings it to the front)
2. Sets the `bounds` of the front window to `{x, y, x+width, y+height}`
3. The `y` offset of `25` accounts for the macOS menu bar
4. Shows a confirmation notification

The window dimensions include Chrome's full window frame — tabs, address bar, and all. This means the **viewport** (the web content area) will be slightly smaller than the stated dimensions, which is typically what you want when recording the full browser window.

## Troubleshooting

**"App is damaged and can't be opened"**
→ Right-click the app → Open → click "Open" in the dialog. This is Gatekeeper; it only happens once.

**"Chrome Resizer wants to control Google Chrome" keeps appearing**
→ Go to System Settings → Privacy & Security → Automation → make sure the app is allowed to control Chrome.

**Window doesn't fit on my screen**
→ 1920×1080 requires at least a 1920px-wide display. On a smaller screen (like a 13" MacBook), the window will be clipped. Consider adding a smaller preset.

**I use Chrome Canary / Chromium / Brave**
→ Change `"Google Chrome"` in the AppleScript to `"Google Chrome Canary"`, `"Chromium"`, or `"Brave Browser"`.
