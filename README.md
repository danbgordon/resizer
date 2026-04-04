# Window Resizer — Setup Guide

## What This Does

A single macOS app that resizes any application's window to exact pixel dimensions. Works with any app — and when a browser (Chrome, Safari, Edge, Arc, Brave) is the target, it also offers viewport-accurate sizing. No extensions, no dependencies — just native macOS AppleScript.

Sizes are loaded from a simple config file that you can edit to add your own presets.

## Quick Start

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
4. **Window Resizer.app** will appear in `~/Applications`
5. Drag it to your **Dock**

## How to Use

1. Click on the window you want to resize (making it the active app)
2. Click **Window Resizer** in your Dock
3. The app auto-detects what you were just using and shows: **"Resize: Google Chrome"**
4. Pick a size from the list
5. Done — the window resizes and the app exits

If the target is a browser, viewport options are also shown (e.g., "1280 × 1024 (viewport)").

## Custom Sizes

Sizes are stored in `~/.config/window-resizer/sizes.conf`. The build script creates a default config with two sizes (1280×1024 and 1920×1080). Edit this file to add your own:

```
# Window Resizer — custom sizes
# Format: width,height (one per line)
# Lines starting with # are ignored, blank lines are skipped
1280,1024
1920,1080
1440,900
3840,2160
```

Changes take effect the next time you launch the app — no rebuild needed.

## Window vs Viewport Mode

- **Window mode** sets the full window frame (including title bar, tabs, address bar) to the target dimensions. Available for any app.
- **Viewport mode** sets the web content area to the exact target dimensions, automatically compensating for the browser's UI chrome. Only available when a supported browser is the target.

Supported browsers for viewport mode: Google Chrome, Chrome Canary, Chromium, Brave, Microsoft Edge, Arc, Safari.

> **Chrome viewport setup:** Go to **View → Developer → Allow JavaScript from Apple Events** (one-time setting). Viewport mode also requires a regular web page in the active tab — not a `chrome://` internal page. If JavaScript access isn't available, the app falls back to window mode with a helpful message.

## First-Time Permission

The first time you resize a particular app, macOS will ask:

> "Window Resizer" wants to control "[App Name]." Allow?

Click **OK**. This is macOS's standard Automation permission — it only asks once per target app. If it gets blocked, go to **System Settings → Privacy & Security → Automation** and enable it.

## Company-Wide Deployment

### Option A: Share the Build Script (Simplest)

1. Distribute `build-apps.sh` (via Slack, email, shared drive, etc.)
2. Each person runs the terminal commands above
3. Done — the app and default config are created locally

### Option B: Pre-Build and Distribute

1. Run `build-apps.sh` on your own Mac
2. Zip the app:
   ```
   cd ~/Applications
   zip -r "Window Resizer.zip" "Window Resizer.app"
   ```
3. Share the .zip via your internal file sharing
4. Each person unzips, moves to `~/Applications`, and drags to Dock

> **Note:** Pre-built .app files may trigger Gatekeeper warnings. Right-click → Open the first time to bypass.

### Option C: MDM Deployment (Fleet, Jamf, etc.)

1. Pre-build the app
2. Package into a `.pkg` installer targeting `/Applications/`
3. Deploy via MDM
4. Pre-approve the Automation permission via a PPPC profile for each target app (e.g., `com.google.Chrome`)

## How It Works

**Window Resizer.app** is a compiled AppleScript that:

1. Detects the previously-active app using `lsappinfo` (skips Finder, Dock, and other launchers)
2. Reads sizes from `~/.config/window-resizer/sizes.conf` (falls back to built-in defaults if missing)
3. If the target is a browser, adds viewport options to the list
4. Presents a `choose from list` dialog
5. Resizes the target app's front window using `set bounds`
6. For viewport mode: measures the actual viewport via JavaScript, calculates the UI chrome overhead, and adjusts the window to compensate

The `y` offset of `25` in the bounds accounts for the macOS menu bar. Dimensions are the full window frame — the viewport (web content area) will be slightly smaller in window mode.

## Troubleshooting

**"App is damaged and can't be opened"**
→ Right-click the app → Open → click "Open" in the dialog. This is Gatekeeper; it only happens once.

**"Window Resizer wants to control [app]" keeps appearing**
→ Go to System Settings → Privacy & Security → Automation → enable Window Resizer for that app.

**Wrong app detected**
→ Make sure you click on the target window before launching Window Resizer. If you launched from Finder, the app skips Finder and detects the next most recent app.

**Window doesn't fit on my screen**
→ 1920×1080 requires at least a 1920px-wide display. On a smaller screen, the window will be clipped. Add a smaller preset to your config file.

**Viewport mode isn't offered**
→ Viewport mode only appears when the target app is a supported browser (Chrome, Safari, Edge, Arc, Brave, Chromium).
