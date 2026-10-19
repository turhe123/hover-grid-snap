import SwiftUI
import ServiceManagement

/// Settings window with a General tab (hotkey, grid size, gap, login) and a Presets tab.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings().tabItem { Label("General", systemImage: "gearshape") }
            PresetEditor().tabItem { Label("Presets", systemImage: "rectangle.split.3x1") }
        }
        .padding()
        .frame(width: 560, height: 440)
    }
}

/// Hotkey recorder, grid dimensions, edge gap, launch at login, permission status and support link.
private struct GeneralSettings: View {
    @EnvironmentObject var state: AppState
    @AppStorage(Prefs.columns) private var columns = 6
    @AppStorage(Prefs.rows) private var rows = 4
    @AppStorage(Prefs.gap) private var gap = 0.0
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?

    var body: some View {
        Form {
            Section("Shortcut") {
                HotKeyRecorder()
                if let error = state.hotKeyError {
                    Label(error, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.red)
                }
            }
            Section("Grid") {
                Stepper("Columns: \(columns)", value: $columns, in: 1...12)
                Stepper("Rows: \(rows)", value: $rows, in: 1...12)
                HStack {
                    Text("Edge gap")
                    Slider(value: $gap, in: 0...40, step: 1)
                    Text("\(Int(gap)) pt").monospacedDigit().frame(width: 44, alignment: .trailing)
                }
            }
            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                HStack {
                    Image(systemName: state.isTrusted ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundStyle(state.isTrusted ? .green : .orange)
                    Text(state.isTrusted ? "Accessibility access granted"
                                         : "Accessibility access is required to move windows.")
                    Spacer()
                    if !state.isTrusted {
                        Button("Open Privacy & Security") { AccessibilityService.openPrivacyPane() }
                    }
                }
            }
            HStack {
                Spacer()
                Button("Support / Donate ❤️") { openDonation() }.controlSize(.large)
            }
        }
        .formStyle(.grouped)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Could not update login item: \(error.localizedDescription)"
        }
        let actual = SMAppService.mainApp.status == .enabled
        if actual != launchAtLogin { launchAtLogin = actual }
    }
}

/// Click "Record", then press a key combination with at least one modifier. Esc cancels.
private struct HotKeyRecorder: View {
    @EnvironmentObject var state: AppState
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Text("Show grid")
            Spacer()
            Text(recording ? "Press shortcut…" : state.hotKeyDisplay)
                .monospaced()
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.primary.opacity(0.08)))
            Button(recording ? "Cancel" : "Record") { recording ? stop() : start() }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        HotKeyManager.shared.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil }
            let mods = HotKeyManager.carbonModifiers(event.modifierFlags)
            guard mods != 0 else { NSSound.beep(); return nil }
            let display = HotKeyManager.display(for: event)
            let defaults = UserDefaults.standard
            defaults.set(Int(event.keyCode), forKey: Prefs.hotKeyCode)
            defaults.set(Int(mods), forKey: Prefs.hotKeyMods)
            defaults.set(display, forKey: Prefs.hotKeyDisplay)
            state.hotKeyDisplay = display
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { HotKeyManager.shared.registerFromDefaults() }
        recording = false
    }
}

/// Table-style editor for up to nine named presets, each a fractional rectangle (clamped to 0…1).
private struct PresetEditor: View {
    @EnvironmentObject var state: AppState
    private let fraction = FloatingPointFormatStyle<Double>.number.precision(.fractionLength(0...3))

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fractions are relative to the screen's visible area, measured from the top-left.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 6) {
                    GridRow {
                        Text("Name"); Text("X"); Text("Y"); Text("Width"); Text("Height"); Text("")
                    }
                    .font(.caption.bold()).foregroundStyle(.secondary)
                    ForEach($state.presets) { $preset in
                        GridRow {
                            TextField("Name", text: $preset.name).frame(minWidth: 160)
                            TextField("X", value: $preset.rect.x, format: fraction).frame(width: 60)
                            TextField("Y", value: $preset.rect.y, format: fraction).frame(width: 60)
                            TextField("W", value: $preset.rect.w, format: fraction).frame(width: 60)
                            TextField("H", value: $preset.rect.h, format: fraction).frame(width: 60)
                            Button {
                                state.presets.removeAll { $0.id == preset.id }
                            } label: { Image(systemName: "minus.circle") }
                                .buttonStyle(.borderless)
                        }
                    }
                }
                .textFieldStyle(.roundedBorder)
                .padding(4)
            }
            HStack {
                Button("Add Preset") {
                    state.presets.append(Preset(name: "New Preset", rect: .init(x: 0, y: 0, w: 0.5, h: 0.5)))
                }
                .disabled(state.presets.count >= Preset.maxCount)
                Button("Restore Defaults") { state.presets = Preset.defaults }
                Spacer()
                Text("\(state.presets.count) / \(Preset.maxCount)").foregroundStyle(.secondary)
            }
        }
        .padding(8)
    }
}
