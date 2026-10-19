import SwiftUI
import AppKit
import ServiceManagement

/// Preferences: history limits, hotkey, capture options, ignored apps, login item and clearing history.
struct SettingsView: View {
    @EnvironmentObject private var store: ClipStore
    @AppStorage("maxPerApp") private var maxPerApp = 100
    @AppStorage("captureImages") private var captureImages = true
    @AppStorage("ignoredApps") private var ignoredApps = ""
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var alsoFavorites = false
    @State private var confirmClear = false
    @State private var axTrusted = PasteService.isTrusted

    private var ignoredList: [String] { ignoredApps.split(separator: "\n").map(String.init) }

    var body: some View {
        Form {
            Section("History") {
                Stepper("Maximum history per app: \(maxPerApp)", value: $maxPerApp, in: 20...500, step: 10)
                Toggle("Capture images", isOn: $captureImages)
            }
            Section("Shortcut") {
                LabeledContent("Open clipboard popup") { HotKeyRecorder() }
            }
            Section("Ignored apps") {
                if ignoredList.isEmpty {
                    Text("No ignored apps. Use “Never Record From This App” in the popup, or add one below.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                ForEach(ignoredList, id: \.self) { id in
                    HStack {
                        Image(nsImage: store.icon(for: id)).resizable().frame(width: 16, height: 16)
                        Text(Self.appName(for: id))
                        Spacer()
                        Button { setIgnored(ignoredList.filter { $0 != id }) } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.borderless)
                    }
                }
                Menu("Add Running App") {
                    ForEach(runningApps, id: \.bundleIdentifier) { app in
                        Button(app.localizedName ?? app.bundleIdentifier ?? "App") {
                            if let b = app.bundleIdentifier { setIgnored(ignoredList + [b]) }
                        }
                    }
                }
            }
            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in setLaunchAtLogin(enabled) }
                if let loginError { Text(loginError).font(.caption).foregroundStyle(.red) }
                HStack {
                    Label(axTrusted ? "Accessibility granted — Return pastes directly"
                                    : "Accessibility not granted — Return only copies",
                          systemImage: axTrusted ? "checkmark.seal" : "exclamationmark.triangle")
                        .foregroundStyle(axTrusted ? .green : .orange)
                    Spacer()
                    if !axTrusted {
                        Button("Open Settings") { PasteService.openAccessibilitySettings() }
                    }
                }
            }
            Section("Danger zone") {
                Toggle("Also delete favorites", isOn: $alsoFavorites)
                Button("Clear History…", role: .destructive) { confirmClear = true }
            }
            Section {
                HStack {
                    Text("AppGroupedClips is free and open source.").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                    Button("Support / Donate ❤️") { AppDelegate.openDonate() }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480, height: 600)
        .onAppear {
            NSApp.activate(ignoringOtherApps: true)
            axTrusted = PasteService.isTrusted
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            axTrusted = PasteService.isTrusted
        }
        .confirmationDialog(alsoFavorites ? "Delete all clips including favorites?" : "Delete all clips except favorites?",
                            isPresented: $confirmClear) {
            Button("Clear History", role: .destructive) { store.clear(keepFavorites: !alsoFavorites) }
        }
    }

    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != nil
                && $0.bundleIdentifier != Bundle.main.bundleIdentifier && !ignoredList.contains($0.bundleIdentifier ?? "") }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }

    private func setIgnored(_ list: [String]) {
        ignoredApps = list.joined(separator: "\n")
    }

    private static func appName(for bundleID: String) -> String {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleID
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginError = nil
        } catch {
            loginError = "Could not update login item: \(error.localizedDescription)"
        }
        launchAtLogin = SMAppService.mainApp.status == .enabled
    }
}

/// Click-to-record control for the global hotkey.
struct HotKeyRecorder: View {
    @AppStorage("hotKeyCode") private var keyCode = HotKeyManager.defaultKeyCode
    @AppStorage("hotKeyMods") private var mods = HotKeyManager.defaultModifiers
    @AppStorage("hotKeyLabel") private var label = "⇧⌘C"
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack {
            Button(recording ? "Press shortcut…" : label) { recording ? stop() : start() }
                .frame(minWidth: 110)
            Button("Reset") {
                keyCode = HotKeyManager.defaultKeyCode
                mods = HotKeyManager.defaultModifiers
                label = "⇧⌘C"
                HotKeyManager.shared.register(keyCode: keyCode, modifiers: mods)
            }
        }
        .onDisappear(perform: stop)
    }

    private func start() {
        recording = true
        HotKeyManager.shared.unregister()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { stop(); return nil } // Escape cancels
            let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
            guard !flags.intersection([.command, .option, .control]).isEmpty else { NSSound.beep(); return nil }
            keyCode = Int(event.keyCode)
            mods = HotKeyManager.carbonModifiers(flags)
            label = HotKeyManager.symbols(flags) + (event.charactersIgnoringModifiers ?? "?").uppercased()
            stop()
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        if recording { HotKeyManager.shared.register(keyCode: keyCode, modifiers: mods) }
        recording = false
    }
}
