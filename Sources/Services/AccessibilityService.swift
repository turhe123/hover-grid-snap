import AppKit
import ApplicationServices

/// Wraps the Accessibility (AXUIElement) API: permission checks and moving/resizing the focused window.
enum AccessibilityService {
    private static var hasPrompted = false

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Asks macOS for trust. The first call shows the system prompt; later calls open System Settings directly.
    static func requestAccess() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) { return }
        if hasPrompted { openPrivacyPane() }
        hasPrompted = true
    }

    static func openPrivacyPane() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// The process id of the frontmost application, ignoring HoverGridSnap itself.
    static func frontmostPID() -> pid_t? {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else { return nil }
        return app.processIdentifier
    }

    /// Places the focused window of `pid` at a fractional rectangle of `screen`. Beeps when that is impossible.
    static func apply(_ fraction: FractionRect, pid: pid_t?, screen: NSScreen?) {
        guard isTrusted, let pid, let screen,
              let window = focusedWindow(of: pid), !isFullScreen(window) else {
            NSSound.beep()
            return
        }
        let visible = ScreenGeometry.usableFrame(of: screen)
        let target = ScreenGeometry.frame(for: fraction, in: visible)
        move(window, to: target, within: visible)
    }

    private static func focusedWindow(of pid: pid_t) -> AXUIElement? {
        let app = AXUIElementCreateApplication(pid)
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXUIElementGetTypeID() else { return nil }
        return unsafeBitCast(ref, to: AXUIElement.self)
    }

    private static func isFullScreen(_ window: AXUIElement) -> Bool {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, "AXFullScreen" as CFString, &ref) == .success else { return false }
        return (ref as? Bool) ?? false
    }

    /// Size → position → size (for apps that animate), then re-position if the window refused the size.
    private static func move(_ window: AXUIElement, to target: CGRect, within visible: CGRect) {
        let axTarget = ScreenGeometry.flip(target)
        setSize(window, axTarget.size)
        setPosition(window, axTarget.origin)
        setSize(window, axTarget.size)

        guard let actual = size(of: window), actual != axTarget.size else { return }
        // Keep the top-left anchored but pull the window back inside the visible frame.
        var x = min(target.minX, visible.maxX - actual.width)
        x = max(x, visible.minX)
        var y = target.maxY - actual.height
        y = max(y, visible.minY)
        let fixed = CGRect(x: x, y: y, width: actual.width, height: actual.height)
        setPosition(window, ScreenGeometry.flip(fixed).origin)
    }

    private static func setSize(_ window: AXUIElement, _ size: CGSize) {
        var value = size
        if let ax = AXValueCreate(.cgSize, &value) {
            AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, ax)
        }
    }

    private static func setPosition(_ window: AXUIElement, _ point: CGPoint) {
        var value = point
        if let ax = AXValueCreate(.cgPoint, &value) {
            AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, ax)
        }
    }

    private static func size(of window: AXUIElement) -> CGSize? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &ref) == .success,
              let ref, CFGetTypeID(ref) == AXValueGetTypeID() else { return nil }
        var size = CGSize.zero
        return AXValueGetValue(unsafeBitCast(ref, to: AXValue.self), .cgSize, &size) ? size : nil
    }
}

/// Coordinate math in points: fractional rects, gaps, and AppKit (bottom-left) ↔ AX (top-left) flipping.
enum ScreenGeometry {
    static func screenUnderMouse() -> NSScreen? {
        let mouse = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
    }

    /// The screen's visible frame (menu bar and Dock excluded), inset by the configured edge gap.
    static func usableFrame(of screen: NSScreen) -> CGRect {
        let vf = screen.visibleFrame
        let gap = min(Prefs.edgeGap, Double(min(vf.width, vf.height)) / 4)
        return vf.insetBy(dx: gap, dy: gap)
    }

    /// Converts a top-left-origin fraction into an AppKit rect within `visible`.
    static func frame(for f: FractionRect, in visible: CGRect) -> CGRect {
        let r = f.clamped
        let width = visible.width * r.w, height = visible.height * r.h
        return CGRect(x: (visible.minX + visible.width * r.x).rounded(),
                      y: (visible.maxY - visible.height * r.y - height).rounded(),
                      width: width.rounded(), height: height.rounded())
    }

    /// Flips a rect between AppKit and Accessibility coordinates using the primary screen height.
    static func flip(_ rect: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
