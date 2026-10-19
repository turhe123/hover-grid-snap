import AppKit
import Carbon.HIToolbox

/// Registers a single global hotkey through Carbon's `RegisterEventHotKey` (no extra permission needed).
final class HotKeyManager {
    static let shared = HotKeyManager()

    var onPress: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerInstalled = false

    /// Registers the hotkey stored in UserDefaults, publishing any failure to `AppState.hotKeyError`.
    func registerFromDefaults() {
        let defaults = UserDefaults.standard
        register(keyCode: UInt32(defaults.integer(forKey: Prefs.hotKeyCode)),
                 modifiers: UInt32(defaults.integer(forKey: Prefs.hotKeyMods)))
    }

    func register(keyCode: UInt32, modifiers: UInt32) {
        unregister()
        installHandlerIfNeeded()
        let id = EventHotKeyID(signature: OSType(0x4847_534E), id: 1) // "HGSN"
        let status = RegisterEventHotKey(keyCode, modifiers, id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status == noErr {
            AppState.shared.hotKeyError = nil
        } else {
            hotKeyRef = nil
            AppState.shared.hotKeyError = status == eventHotKeyExistsErr
                ? "This shortcut is already used by another app. Choose a different one."
                : "Could not register the shortcut (error \(status))."
        }
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let status = InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKeyManager.shared.onPress?() }
            return noErr
        }, 1, &spec, nil, nil)
        handlerInstalled = status == noErr
    }

    /// Converts AppKit modifier flags to Carbon modifier bits.
    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods = 0
        if flags.contains(.command) { mods |= cmdKey }
        if flags.contains(.option) { mods |= optionKey }
        if flags.contains(.control) { mods |= controlKey }
        if flags.contains(.shift) { mods |= shiftKey }
        return UInt32(mods)
    }

    /// Human-readable shortcut such as "⌃⌥G".
    static func display(for event: NSEvent) -> String {
        let flags = event.modifierFlags
        var s = ""
        if flags.contains(.control) { s += "⌃" }
        if flags.contains(.option) { s += "⌥" }
        if flags.contains(.shift) { s += "⇧" }
        if flags.contains(.command) { s += "⌘" }
        switch Int(event.keyCode) {
        case kVK_Space: s += "Space"
        case kVK_Return: s += "↩"
        case kVK_Tab: s += "⇥"
        default:
            let chars = event.charactersIgnoringModifiers?.uppercased() ?? ""
            s += chars.isEmpty || chars.unicodeScalars.contains(where: { $0.value >= 0xF700 })
                ? "Key \(event.keyCode)" : chars
        }
        return s
    }
}
