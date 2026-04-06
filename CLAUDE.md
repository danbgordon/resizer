# Resizer

## Project Summary

A native macOS AppleScript app that resizes any application's window to exact pixel dimensions. Works with any app, and offers viewport-accurate sizing for supported browsers (Chrome, Safari, Edge, Arc, Brave, Chromium). Sizes are loaded from a user-editable config file.

Built as a safe, zero-dependency alternative to Chrome extensions (which have a history of malware issues — e.g., the original Resizer extension).

Target audience: Fleet (fleetdm.com) team members who need to record their screen at specific dimensions.

## What Exists

- **`build-apps.sh`** — Shell script that uses `osacompile` to generate a single `Resizer.app` in `~/Applications`. Also creates a default config file at `~/.config/resizer/sizes.conf` if one doesn't exist.
- **`README.md`** — Setup guide covering usage, custom sizes, deployment options, and troubleshooting.

## Key Technical Details

- Single compiled AppleScript app (`.app` bundle via `osacompile`, ad-hoc codesigned)
- Auto-detects the previously-active app using `lsappinfo visibleProcessList` (skips Finder, Dock, Spotlight, Launchpad)
- Sizes loaded from `~/.config/resizer/sizes.conf` (CSV format: `width,height`), falls back to built-in defaults
- Window resize uses `tell application X to set bounds of front window` (triggers per-app Automation permission)
- Viewport resize (browsers only): two-pass technique — set initial bounds, measure viewport via JavaScript, adjust to compensate for browser UI chrome
  - Chromium browsers: `using terms from application "Google Chrome"` + `execute javascript`
  - Safari: `do JavaScript` in front document
- Window bounds use `{x, y, x+width, y+height}` format; y-offset of 25 accounts for macOS menu bar
- Apps must be built to `~/Applications` (not Desktop) — macOS blocks `osacompile` apps from running on Desktop
- Chrome viewport mode requires: View → Developer → Allow JavaScript from Apple Events

## Potential Next Steps

- Custom icon for the .app file (currently uses the default Script Editor icon)
- Package as a `.pkg` installer for MDM deployment
- Create a PPPC profile (`.mobileconfig`) for Fleet/MDM to pre-approve the Automation permission
- Keyboard shortcut integration (e.g., via Automator or Shortcuts)
