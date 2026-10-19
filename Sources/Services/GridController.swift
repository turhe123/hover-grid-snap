import AppKit
import SwiftUI

/// Borderless panel that can become key (for Escape) without activating HoverGridSnap.
final class GridPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Owns the floating grid panel and the click-through preview overlay, and applies the chosen frame.
final class GridController {
    static let shared = GridController()

    private var panel: GridPanel?
    private var overlay: NSWindow?
    private var monitors: [Any] = []
    private var targetPID: pid_t?
    private var targetScreen: NSScreen?

    var isVisible: Bool { panel?.isVisible ?? false }

    private init() {
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.close() }
    }

    func toggle() { isVisible ? close() : show() }

    func show() {
        guard AccessibilityService.isTrusted else {
            NSSound.beep()
            AccessibilityService.requestAccess()
            return
        }
        close()
        targetPID = AccessibilityService.frontmostPID()
        targetScreen = ScreenGeometry.screenUnderMouse()
        guard let screen = targetScreen else { NSSound.beep(); return }

        let view = GridView(columns: Prefs.gridColumns, rows: Prefs.gridRows,
                            presets: AppState.shared.presets,
                            onPreview: { [weak self] in self?.preview($0) },
                            onCommit: { [weak self] in self?.commit($0) },
                            onClose: { [weak self] in self?.close() })
        let hosting = NSHostingView(rootView: view)
        let size = hosting.fittingSize

        let panel = GridPanel(contentRect: CGRect(origin: .zero, size: size),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = hosting

        // Centre under the pointer, clamped to the visible frame.
        let mouse = NSEvent.mouseLocation, vf = screen.visibleFrame
        let x = min(max(mouse.x - size.width / 2, vf.minX), vf.maxX - size.width)
        let y = min(max(mouse.y - size.height / 2, vf.minY), vf.maxY - size.height)
        panel.setFrameOrigin(CGPoint(x: x, y: y))
        panel.makeKeyAndOrderFront(nil)
        self.panel = panel
        installMonitors()
    }

    func close() {
        monitors.forEach(NSEvent.removeMonitor)
        monitors.removeAll()
        panel?.orderOut(nil)
        panel = nil
        overlay?.orderOut(nil)
    }

    private func installMonitors() {
        if let esc = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] event in
            guard event.keyCode == 53 else { return event }
            self?.close()
            return nil
        }) { monitors.append(esc) }
        if let outside = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown],
                                                           handler: { [weak self] _ in self?.close() }) {
            monitors.append(outside)
        }
    }

    private func commit(_ fraction: FractionRect) {
        let pid = targetPID, screen = targetScreen
        close()
        AccessibilityService.apply(fraction, pid: pid, screen: screen)
    }

    /// Shows (or hides, when nil) a translucent rectangle where the window will land.
    private func preview(_ fraction: FractionRect?) {
        guard let fraction, let screen = targetScreen else { overlay?.orderOut(nil); return }
        let frame = ScreenGeometry.frame(for: fraction, in: ScreenGeometry.usableFrame(of: screen))
        let window = overlay ?? makeOverlay()
        window.setFrame(frame, display: true)
        window.orderFront(nil)
    }

    private func makeOverlay() -> NSWindow {
        let window = NSWindow(contentRect: .zero, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.level = .floating
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        window.contentView = NSHostingView(rootView: PreviewShape())
        overlay = window
        return window
    }
}

/// The translucent accent-coloured rectangle shown inside the overlay window.
private struct PreviewShape: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.accentColor.opacity(0.25))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.accentColor, lineWidth: 3))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
