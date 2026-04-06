# Resizer

A native macOS app that resizes any application's window to exact pixel dimensions. Works with any app — and when a browser (Chrome, Safari, Edge, Arc, Brave) is the target, it also offers viewport-accurate sizing.

No extensions, no dependencies — just a lightweight native Swift app.

## Install

### Option A: Download the installer
1. Download `Resizer-1.0.pkg` from the [latest release](https://github.com/danbgordon/resizer/releases)
2. Double-click to install (installs to `/Applications`)
3. Drag **Resizer** to your **Dock** for easy access

### Option B: Build from source
```
git clone https://github.com/danbgordon/resizer.git
cd resizer
chmod +x build.sh
./build.sh
```

## First Launch

1. **Right-click → Open** the first time to bypass Gatekeeper
2. Grant **Accessibility** permission when prompted — this is the only permission needed for window resizing, and it works for all apps

## How to Use

1. Click on the window you want to resize
2. Launch **Resizer** from the Dock
3. Pick a size from the dropdown and click **Resize**
4. Done — the window resizes and the app exits

If the target is a browser, viewport options are also shown (e.g., "1280 × 1024 (viewport)").

## Custom Sizes

Sizes are stored in `~/.config/resizer/sizes.conf` (created automatically on first launch). Edit this file to add your own presets:

```
# Resizer — custom sizes
# Format: width,height or width,height,name (one per line)
# Lines starting with # are ignored, blank lines are skipped
1280,1024
1920,1080,Full HD
1440,900,Recording
3840,2160,4K
```

Changes take effect the next time you launch the app.

## Window vs Viewport Mode

- **Window mode** — sets the full window frame (including title bar, tabs, address bar) to the target dimensions. Available for any app.
- **Viewport mode** — sets the web content area to the exact target dimensions, automatically compensating for the browser's UI chrome. Only available for supported browsers.

Supported browsers for viewport mode: Google Chrome, Chrome Canary, Chromium, Brave, Microsoft Edge, Arc, Safari.

> **Chrome viewport setup:** Enable **View → Developer → Allow JavaScript from Apple Events** (one-time setting). Viewport mode also requires a regular web page in the active tab — not a `chrome://` internal page.

## Permissions

| Action | Permission | When prompted |
|--------|-----------|---------------|
| Resize any window | Accessibility | Once, on first launch |
| Browser viewport mode | Automation (per browser) | Once per browser, only if you use viewport mode |

Resizer explains each permission before macOS prompts you.

## Deployment (Fleet, Jamf, etc.)

1. Download or build `Resizer-1.0.pkg`
2. Deploy via MDM to `/Applications`
3. Optionally pre-approve Accessibility via a PPPC profile for `com.danbgordon.resizer`

## How It Works

**Resizer** is a native Swift app that:

1. Detects the previously-active app using `lsappinfo` (skips Finder, Dock, and other launchers)
2. Reads sizes from `~/.config/resizer/sizes.conf` (falls back to built-in defaults if missing)
3. Shows a size picker (with viewport options for browsers)
4. Resizes the window using the macOS Accessibility API (`AXUIElement`)
5. For viewport mode: measures the actual viewport via JavaScript, calculates the browser chrome overhead, and adjusts the window to compensate
6. Keeps the window on its current screen (multi-monitor aware)

## Troubleshooting

**"App is damaged and can't be opened"**
→ Right-click the app → Open → click "Open" in the dialog. This is Gatekeeper; it only happens once.

**Wrong app detected**
→ Make sure you click on the target window before launching Resizer. If you launched from Finder, the app skips Finder and detects the next most recent app.

**Window doesn't fit on my screen**
→ 1920×1080 requires at least a 1920px-wide display. Add a smaller preset to your config file.

**Viewport mode isn't offered**
→ Viewport mode only appears when the target app is a supported browser.

**Viewport falls back to window size**
→ Make sure the active tab has a regular web page (not `chrome://settings` or similar). For Chrome, enable View → Developer → Allow JavaScript from Apple Events.
