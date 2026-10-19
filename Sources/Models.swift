import AppKit
import Carbon.HIToolbox

/// A rectangle expressed as fractions (0…1) of a screen's visible frame, measured from the top-left corner.
struct FractionRect: Codable, Equatable {
    var x: Double
    var y: Double
    var w: Double
    var h: Double

    /// Returns a copy with every component clamped so the rectangle stays inside the unit square.
    var clamped: FractionRect {
        func unit(_ v: Double) -> Double { v.isFinite ? min(max(v, 0), 1) : 0 }
        let cx = min(unit(x), 0.99), cy = min(unit(y), 0.99)
        return FractionRect(x: cx, y: cy,
                            w: min(max(unit(w), 0.01), 1 - cx),
                            h: min(max(unit(h), 0.01), 1 - cy))
    }
}

/// A named, user-editable window placement.
struct Preset: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var rect: FractionRect

    static let maxCount = 9

    static let defaults: [Preset] = [
        Preset(name: "Left Half", rect: .init(x: 0, y: 0, w: 0.5, h: 1)),
        Preset(name: "Right Half", rect: .init(x: 0.5, y: 0, w: 0.5, h: 1)),
        Preset(name: "Left Two Thirds", rect: .init(x: 0, y: 0, w: 2.0 / 3, h: 1)),
        Preset(name: "Right Third", rect: .init(x: 2.0 / 3, y: 0, w: 1.0 / 3, h: 1)),
        Preset(name: "Top Half", rect: .init(x: 0, y: 0, w: 1, h: 0.5)),
        Preset(name: "Bottom Half", rect: .init(x: 0, y: 0.5, w: 1, h: 0.5)),
        Preset(name: "Centered Large", rect: .init(x: 0.1, y: 0.075, w: 0.8, h: 0.85)),
        Preset(name: "Centered Small", rect: .init(x: 0.25, y: 0.2, w: 0.5, h: 0.6)),
        Preset(name: "Maximize", rect: .init(x: 0, y: 0, w: 1, h: 1)),
    ]
}

/// UserDefaults keys and default values shared by `@AppStorage` and the services.
enum Prefs {
    static let columns = "gridColumns"
    static let rows = "gridRows"
    static let gap = "edgeGap"
    static let presets = "presetsJSON"
    static let hotKeyCode = "hotKeyCode"
    static let hotKeyMods = "hotKeyModifiers"
    static let hotKeyDisplay = "hotKeyDisplay"

    static func register() {
        UserDefaults.standard.register(defaults: [
            columns: 6, rows: 4, gap: 0.0,
            hotKeyCode: kVK_ANSI_G,
            hotKeyMods: controlKey | optionKey,
            hotKeyDisplay: "⌃⌥G",
        ])
    }

    static var gridColumns: Int { min(max(UserDefaults.standard.integer(forKey: columns), 1), 12) }
    static var gridRows: Int { min(max(UserDefaults.standard.integer(forKey: rows), 1), 12) }
    static var edgeGap: Double { max(UserDefaults.standard.double(forKey: gap), 0) }
}

/// Observable app-wide state: presets, permission status and hotkey status.
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var presets: [Preset] {
        didSet {
            presets = Array(presets.prefix(Preset.maxCount)).map { var p = $0; p.rect = p.rect.clamped; return p }
            if let data = try? JSONEncoder().encode(presets) {
                UserDefaults.standard.set(data, forKey: Prefs.presets)
            }
        }
    }
    @Published var isTrusted = AccessibilityService.isTrusted
    @Published var hotKeyError: String?
    @Published var hotKeyDisplay = UserDefaults.standard.string(forKey: Prefs.hotKeyDisplay) ?? "⌃⌥G"

    private var timer: Timer?

    private init() {
        if let data = UserDefaults.standard.data(forKey: Prefs.presets),
           let decoded = try? JSONDecoder().decode([Preset].self, from: data) {
            presets = decoded.map { var p = $0; p.rect = p.rect.clamped; return p }
        } else {
            presets = Preset.defaults
        }
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            let trusted = AccessibilityService.isTrusted
            if self?.isTrusted != trusted { self?.isTrusted = trusted }
        }
    }
}
