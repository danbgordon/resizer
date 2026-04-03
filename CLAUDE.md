# Chrome Window Resizer

## Project Summary

A set of native macOS AppleScript apps that resize Google Chrome windows to exact pixel dimensions. Built as a safe, zero-dependency alternative to Chrome extensions (which have a history of malware issues — e.g., the original Window Resizer extension).

Target audience: Fleet (fleetdm.com) team members who need to record their screen at specific dimensions.

## What Exists

- **`build-apps.sh`** — Shell script that uses `osacompile` to generate .app bundles on macOS. Builds four apps:
  - `Chrome 1280×1024.app` — one-click resize
  - `Chrome 1920×1080.app` — one-click resize
  - `Chrome Resizer.app` — dropdown picker
  - `Chrome Resizer (Repeat).app` — persistent picker that stays open
- **`README.md`** — Setup guide covering individual setup, company distribution (share script, pre-build .apps, or MDM deployment), adding new sizes, troubleshooting, and PPPC profile guidance for MDM.

## Key Technical Details

- Apps are compiled AppleScript (`.app` bundles via `osacompile`)
- Window bounds use `{x, y, x+width, y+height}` format; y-offset of 25 accounts for macOS menu bar
- Stated dimensions are the full Chrome window frame (tabs, address bar included), not the viewport
- First run triggers a macOS Automation permission prompt ("wants to control Google Chrome") — can be pre-approved via PPPC configuration profile in MDM
- Gatekeeper may block pre-built .apps from unidentified developers — right-click → Open bypasses this once

## Potential Next Steps

- Add more preset sizes
- Custom icon for the .app files (currently uses the default Script Editor icon)
- Package as a `.pkg` installer for MDM deployment
- Create a PPPC profile (`.mobileconfig`) for Fleet/MDM to pre-approve the Automation permission
- Support for other browsers (Brave, Arc, Edge, etc.)
- Consider a single menu-bar app using a status item instead of separate .app files
