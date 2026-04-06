// Resizer — Native macOS window resizer
// Resizes any app's window to preset dimensions using the Accessibility API.
// Browsers also get viewport-accurate sizing via JavaScript measurement.
// Only requires Accessibility permission (one time, for all apps).

import Cocoa
import ApplicationServices

// MARK: - Config

struct SizeOption {
    let width: Int
    let height: Int
    let name: String?

    var displayTitle: String {
        if let name = name {
            return "\(width) \u{00d7} \(height) — \(name)"
        }
        return "\(width) \u{00d7} \(height)"
    }
}

let defaultSizes = [SizeOption(width: 1280, height: 1024, name: nil), SizeOption(width: 1920, height: 1080, name: nil)]
let configPath = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent(".config/resizer/sizes.conf").path

let browserNames: Set<String> = [
    "Google Chrome", "Google Chrome Canary", "Safari", "Chromium",
    "Brave Browser", "Microsoft Edge", "Arc"
]
let chromiumNames: Set<String> = [
    "Google Chrome", "Google Chrome Canary", "Chromium",
    "Brave Browser", "Microsoft Edge", "Arc"
]

func isBrowser(_ name: String) -> Bool { browserNames.contains(name) }
func isChromium(_ name: String) -> Bool { chromiumNames.contains(name) }

// MARK: - Config Loading

func loadSizes() -> [SizeOption] {
    guard let content = try? String(contentsOfFile: configPath, encoding: .utf8) else {
        return defaultSizes
    }
    var sizes: [SizeOption] = []
    for line in content.split(separator: "\n", omittingEmptySubsequences: false) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
        let parts = trimmed.split(separator: ",", maxSplits: 2)
        if parts.count >= 2,
           let w = Int(parts[0].trimmingCharacters(in: .whitespaces)),
           let h = Int(parts[1].trimmingCharacters(in: .whitespaces)) {
            let name = parts.count >= 3 ? parts[2].trimmingCharacters(in: .whitespaces) : nil
            sizes.append(SizeOption(width: w, height: h, name: name))
        }
    }
    return sizes.isEmpty ? defaultSizes : sizes
}

func ensureDefaultConfig() {
    let fm = FileManager.default
    if !fm.fileExists(atPath: configPath) {
        let dir = (configPath as NSString).deletingLastPathComponent
        try? fm.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let defaultContent = """
        # Resizer — custom sizes
        # Format: width,height or width,height,name (one per line)
        # Lines starting with # are ignored, blank lines are skipped
        #
        # These dimensions set the full window size. When a supported
        # browser (Chrome, Safari) is the target, viewport options are
        # also offered automatically.
        1280,1024
        1920,1080,Full HD
        """
        try? defaultContent.write(toFile: configPath, atomically: true, encoding: .utf8)
    }
}

// MARK: - Shell Helpers

func shell(_ command: String) -> String? {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", command]
    process.standardOutput = pipe
    process.standardError = FileHandle.nullDevice
    try? process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else { return nil }
    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
}

// MARK: - App Detection

func getPreviousApp() -> (name: String, pid: pid_t)? {
    // Get the app that was frontmost before us, skipping launchers
    let bundleID = Bundle.main.bundleIdentifier ?? "Resizer"
    let selfName = ProcessInfo.processInfo.processName

    let skipList = "Finder|Dock|Spotlight|Launchpad|Resizer|\(selfName)"
    let cmd = "lsappinfo visibleProcessList | grep -oE '\"[^\"]+\"' | tr -d '\"' | tr '_' ' ' | grep -vE \"^(\(skipList))$\" | head -n 1"

    guard let appName = shell(cmd), !appName.isEmpty else { return nil }

    // Get PID for this app
    let pidCmd = "lsappinfo info -only pid \"\(appName)\" 2>/dev/null | grep -oE '[0-9]+'"
    // lsappinfo uses underscores in app names
    let escapedName = appName.replacingOccurrences(of: " ", with: "_")
    let pidCmd2 = "lsappinfo info -only pid \"\(escapedName)\" 2>/dev/null | grep -oE '[0-9]+'"

    if let pidStr = shell(pidCmd2), let pid = Int32(pidStr) {
        return (appName, pid)
    }
    if let pidStr = shell(pidCmd), let pid = Int32(pidStr) {
        return (appName, pid)
    }

    // Fallback: use NSWorkspace to find PID by name
    for app in NSWorkspace.shared.runningApplications {
        if app.localizedName == appName {
            return (appName, app.processIdentifier)
        }
    }

    return nil
}

// MARK: - Accessibility

func checkAccessibilityExternal() -> Bool {
    // AXIsProcessTrusted() may cache its result within a running process.
    // Use bundled ax_check binary for a fresh out-of-process check.
    let axCheckPath = Bundle.main.bundlePath + "/Contents/Resources/ax_check"
    let result = shell(axCheckPath)
    return result == "true"
}

func ensureAccessibility() -> Bool {
    if AXIsProcessTrusted() { return true }

    // Show explanation before the system prompt
    let alert = NSAlert()
    alert.messageText = "Accessibility Permission Required"
    alert.informativeText = "Resizer needs Accessibility access to resize windows.\n\nClick OK to open System Settings and grant access. Resizer will automatically resize your window once permission is granted."
    alert.alertStyle = .informational
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    NSApp.activate(ignoringOtherApps: true)
    if alert.runModal() == .alertSecondButtonReturn { return false }

    // Trigger the system prompt
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    AXIsProcessTrustedWithOptions(options)

    // Poll until granted — use bundled binary for fresh check each iteration
    while !checkAccessibilityExternal() {
        RunLoop.current.run(until: Date(timeIntervalSinceNow: 1.0))
    }
    return true
}

// MARK: - Window Management (Accessibility API)

func getWindowElement(pid: pid_t) -> AXUIElement? {
    let appElement = AXUIElementCreateApplication(pid)
    var windowsRef: CFTypeRef?
    let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsRef)
    guard result == .success, let windows = windowsRef as? [AXUIElement], let firstWindow = windows.first else {
        return nil
    }
    return firstWindow
}

func getWindowPosition(_ window: AXUIElement) -> CGPoint? {
    var posRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef) == .success,
          let posValue = posRef else { return nil }
    var point = CGPoint.zero
    AXValueGetValue(posValue as! AXValue, .cgPoint, &point)
    return point
}

func getWindowSize(_ window: AXUIElement) -> CGSize? {
    var sizeRef: CFTypeRef?
    guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef) == .success,
          let sizeValue = sizeRef else { return nil }
    var size = CGSize.zero
    AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
    return size
}

func setWindowPosition(_ window: AXUIElement, _ point: CGPoint) {
    var p = point
    if let value = AXValueCreate(.cgPoint, &p) {
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, value)
    }
}

func setWindowSize(_ window: AXUIElement, _ size: CGSize) {
    var s = size
    if let value = AXValueCreate(.cgSize, &s) {
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, value)
    }
}

// MARK: - Screen Clamping

func clampToScreen(position: CGPoint, size: CGSize) -> CGPoint {
    // Find which screen contains the window's top-left corner
    // NSScreen coordinates: origin at bottom-left of main screen, y increases upward
    // AXUIElement coordinates: origin at top-left of main screen, y increases downward
    // We need to convert between the two coordinate systems

    let mainScreenHeight = NSScreen.screens.first?.frame.height ?? 0

    // Convert AX position (top-left origin) to NS position (bottom-left origin)
    let nsY = mainScreenHeight - position.y - size.height

    var bestScreen = NSScreen.screens.first!
    for screen in NSScreen.screens {
        let frame = screen.frame
        // Check if window's top-left corner (in NS coords) is on this screen
        let windowTopNS = mainScreenHeight - position.y
        if position.x >= frame.minX && position.x < frame.maxX &&
           windowTopNS > frame.minY && windowTopNS <= frame.maxY {
            bestScreen = screen
            break
        }
    }

    let visibleFrame = bestScreen.visibleFrame
    // Convert visible frame to AX coordinates
    let screenTopAX = mainScreenHeight - visibleFrame.maxY
    let screenBottomAX = mainScreenHeight - visibleFrame.minY
    let screenLeftAX = visibleFrame.minX
    let screenRightAX = visibleFrame.maxX

    var newX = position.x
    var newY = position.y

    if newX + size.width > screenRightAX {
        newX = screenRightAX - size.width
    }
    if newY + size.height > screenBottomAX {
        newY = screenBottomAX - size.height
    }
    if newX < screenLeftAX { newX = screenLeftAX }
    if newY < screenTopAX { newY = screenTopAX }

    return CGPoint(x: newX, y: newY)
}

// MARK: - Resize

func resizeWindow(pid: pid_t, width: Int, height: Int) -> Bool {
    guard let window = getWindowElement(pid: pid) else {
        showError("Could not find a window to resize.")
        return false
    }
    guard let currentPos = getWindowPosition(window) else {
        showError("Could not read window position.")
        return false
    }

    let newSize = CGSize(width: width, height: height)
    let newPos = clampToScreen(position: currentPos, size: newSize)

    setWindowPosition(window, newPos)
    setWindowSize(window, newSize)
    return true
}

// MARK: - Viewport Resize (Browsers)

func runAppleScript(_ script: String) -> (output: String?, error: String?) {
    let process = Process()
    let outPipe = Pipe()
    let errPipe = Pipe()
    let inPipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
    process.arguments = ["-"]
    process.standardInput = inPipe
    process.standardOutput = outPipe
    process.standardError = errPipe
    try? process.run()
    inPipe.fileHandleForWriting.write(script.data(using: .utf8)!)
    inPipe.fileHandleForWriting.closeFile()
    process.waitUntilExit()
    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: outData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    let errStr = String(data: errData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    if process.terminationStatus != 0 { return (nil, errStr) }
    return (output, nil)
}

func executeJavaScript(appName: String, code: String) -> String? {
    let script: String
    if isChromium(appName) {
        script = """
        tell application "\(appName)"
            using terms from application "Google Chrome"
                execute front window's active tab javascript "\(code)"
            end using terms from
        end tell
        """
    } else if appName == "Safari" {
        script = """
        tell application "Safari"
            do JavaScript "\(code)" in front document
        end tell
        """
    } else {
        return nil
    }
    let result = runAppleScript(script)
    // Debug: write the script and any error to a temp file
    var debug = "=== Script ===\n\(script)\n"
    if let err = result.error { debug += "=== Error ===\n\(err)\n" }
    if let out = result.output { debug += "=== Output ===\n\(out)\n" }
    debug += "=== End ===\n"
    try? debug.write(toFile: "/tmp/resizer_debug.txt", atomically: true, encoding: .utf8)
    return result.output
}

func ensureViewportPermission(appName: String) -> Bool {
    // Check if we've already explained the Automation permission for this browser
    let flagName = "viewport-prompted-\(appName)"
    let alreadyPrompted = shell("defaults read com.danbgordon.resizer '\(flagName)' 2>/dev/null") != nil

    if !alreadyPrompted {
        let alert = NSAlert()
        alert.messageText = "Viewport Permission"
        alert.informativeText = "To set the exact viewport size, Resizer needs to run a small script inside \(appName) to measure the browser's toolbar height.\n\nThe next dialog will ask for permission to control \(appName) — this is only used to read the viewport dimensions."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Skip (use window size)")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn { return false }
        _ = shell("defaults write com.danbgordon.resizer '\(flagName)' -bool true")
    }
    return true
}

func resizeViewport(pid: pid_t, appName: String, width: Int, height: Int) -> Bool {
    // Explain and confirm BEFORE any resize so the user isn't confused
    if !ensureViewportPermission(appName: appName) {
        // User chose to skip viewport — just do window resize
        if resizeWindow(pid: pid, width: width, height: height) {
            sendNotification(title: "Resizer", message: "\(appName) resized to \(width) \u{00d7} \(height) (window)")
        }
        return true
    }

    // Test that JS execution works before resizing (triggers Automation prompt if needed)
    let testResult = executeJavaScript(appName: appName, code: "'test'")
    if testResult == nil {
        showError("Viewport mode requires:\n\n1. A regular web page in the active tab (not a browser internal page)\n2. For Chrome: enable View > Developer > Allow JavaScript from Apple Events\n\nFalling back to window size.")
        if resizeWindow(pid: pid, width: width, height: height) {
            sendNotification(title: "Resizer", message: "\(appName) resized to \(width) \u{00d7} \(height) (window)")
        }
        return true
    }

    // Reactivate target app (may have lost focus during permission dialogs)
    NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }?.activate()
    Thread.sleep(forTimeInterval: 0.2)

    // First pass: set window to target size
    guard resizeWindow(pid: pid, width: width, height: height) else { return false }
    Thread.sleep(forTimeInterval: 0.1)

    // Measure actual viewport
    let jsCode = "'' + window.innerWidth + ',' + window.innerHeight"
    guard let jsResult = executeJavaScript(appName: appName, code: jsCode) else {
        showError("Viewport mode requires:\n\n1. A regular web page in the active tab (not a browser internal page)\n2. For Chrome: enable View > Developer > Allow JavaScript from Apple Events\n\nFalling back to window size.")
        sendNotification(title: "Resizer", message: "\(appName) resized to \(width) x \(height) (window)")
        return true
    }

    let parts = jsResult.split(separator: ",")
    guard parts.count >= 2, let actualVW = Int(parts[0]), let actualVH = Int(parts[1]) else {
        sendNotification(title: "Resizer", message: "\(appName) resized to \(width) x \(height) (window)")
        return true
    }

    // Calculate chrome overhead and adjust
    let deltaW = width - actualVW
    let deltaH = height - actualVH
    let adjW = width + deltaW
    let adjH = height + deltaH

    guard resizeWindow(pid: pid, width: adjW, height: adjH) else { return false }
    sendNotification(title: "Resizer", message: "\(appName) viewport set to \(width) x \(height)")
    return true
}

// MARK: - UI

func showChooser(appName: String, sizes: [SizeOption], showViewport: Bool) -> (width: Int, height: Int, isViewport: Bool)? {
    let alert = NSAlert()
    alert.messageText = "Resize: \(appName)"
    alert.informativeText = "Select a size:"
    alert.addButton(withTitle: "Resize")
    alert.addButton(withTitle: "Cancel")

    let popup = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 280, height: 28), pullsDown: false)
    for s in sizes {
        popup.addItem(withTitle: s.displayTitle)
    }

    // Stack popup + optional viewport checkbox vertically
    let container: NSView
    let viewportCheckbox: NSButton?

    if showViewport {
        let checkbox = NSButton(checkboxWithTitle: "Viewport size", target: nil, action: nil)
        checkbox.frame = NSRect(x: 2, y: 0, width: 280, height: 18)
        popup.frame = NSRect(x: 0, y: 24, width: 280, height: 28)
        let stack = NSView(frame: NSRect(x: 0, y: 0, width: 280, height: 52))
        stack.addSubview(popup)
        stack.addSubview(checkbox)
        container = stack
        viewportCheckbox = checkbox
    } else {
        container = popup
        viewportCheckbox = nil
    }

    alert.accessoryView = container

    NSApp.activate(ignoringOtherApps: true)
    let response = alert.runModal()
    guard response == .alertFirstButtonReturn else { return nil }

    let isViewport = viewportCheckbox?.state == .on
    let selectedIndex = popup.indexOfSelectedItem
    guard selectedIndex >= 0 && selectedIndex < sizes.count else { return nil }
    let s = sizes[selectedIndex]

    return (s.width, s.height, isViewport)
}

func showError(_ message: String) {
    let alert = NSAlert()
    alert.messageText = "Resizer"
    alert.informativeText = message
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    NSApp.activate(ignoringOtherApps: true)
    alert.runModal()
}

func sendNotification(title: String, message: String) {
    // Use osascript for notifications (no UserNotifications entitlement needed)
    let escaped = message.replacingOccurrences(of: "\"", with: "\\\"")
    _ = shell("osascript -e 'display notification \"\(escaped)\" with title \"\(title)\"'")
}

// MARK: - Main

// Initialize as a proper foreground GUI app
let app = NSApplication.shared
app.setActivationPolicy(.accessory)  // No dock icon, but can show dialogs
ensureDefaultConfig()

// Detect target app FIRST (before any dialogs change the activation order)
guard let target = getPreviousApp() else {
    showError("No target window found. Click on a window first, then launch Resizer.")
    exit(0)
}

// Check Accessibility
guard ensureAccessibility() else { exit(0) }

// Activate the target app so its window is ready
NSWorkspace.shared.runningApplications.first { $0.processIdentifier == target.pid }?.activate()
Thread.sleep(forTimeInterval: 0.2)

// Load sizes and show chooser
let sizes = loadSizes()
let showViewport = isBrowser(target.name)
guard let choice = showChooser(appName: target.name, sizes: sizes, showViewport: showViewport) else { exit(0) }

// Resize
if choice.isViewport {
    _ = resizeViewport(pid: target.pid, appName: target.name, width: choice.width, height: choice.height)
} else {
    if resizeWindow(pid: target.pid, width: choice.width, height: choice.height) {
        sendNotification(title: "Resizer", message: "\(target.name) resized to \(choice.width) \u{00d7} \(choice.height)")
    }
}
