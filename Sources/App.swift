import SwiftUI
import AppKit

/// Entry point: a menu-bar-only app exposing presets, the grid, settings and support.
@main
struct HoverGridSnapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState.shared

    init() { Prefs.register() }

    var body: some Scene {
        MenuBarExtra("HoverGridSnap", systemImage: "square.grid.3x3") {
            MenuContent().environmentObject(state)
        }
    }
}

/// Configures the accessory activation policy and wires the global hotkey to the grid.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        HotKeyManager.shared.onPress = { GridController.shared.toggle() }
        HotKeyManager.shared.registerFromDefaults()
        if !AccessibilityService.isTrusted { AccessibilityService.requestAccess() }
    }
}

/// The MenuBarExtra menu. Shows only the permission item while Accessibility access is missing.
struct MenuContent: View {
    @EnvironmentObject var state: AppState

    var body: some View {
        if state.isTrusted {
            ForEach(Array(state.presets.enumerated()), id: \.element.id) { index, preset in
                Button(preset.name) {
                    AccessibilityService.apply(preset.rect, pid: AccessibilityService.frontmostPID(),
                                               screen: ScreenGeometry.screenUnderMouse())
                }
                .keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: [])
            }
            Divider()
            Button("Show Grid    \(state.hotKeyDisplay)") {
                // Let the menu close before the panel grabs key focus.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { GridController.shared.show() }
            }
        } else {
            Button("⚠️ Grant Accessibility Access…") { AccessibilityService.requestAccess() }
        }
        Divider()
        Button("Settings…") { SettingsWindowController.shared.show() }
            .keyboardShortcut(",")
        Button("Support / Donate ❤️") { openDonation() }
        Divider()
        Button("Quit HoverGridSnap") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}

func openDonation() {
    NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
}

/// Hosts the SwiftUI settings view in a regular window, activating the app so it comes to front.
final class SettingsWindowController {
    static let shared = SettingsWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView().environmentObject(AppState.shared))
            let window = NSWindow(contentViewController: hosting)
            window.title = "HoverGridSnap Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.isReleasedWhenClosed = false
            window.center()
            self.window = window
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
