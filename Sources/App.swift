import SwiftUI
import AppKit

/// App entry point: a window-style menu bar extra plus a Settings scene.
@main
struct AppGroupedClipsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = ClipStore.shared

    var body: some Scene {
        MenuBarExtra("AppGroupedClips", systemImage: "square.stack.3d.up.fill") {
            ContentView().environmentObject(store)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView().environmentObject(store)
        }
    }
}

/// Starts the pasteboard monitor, hotkey and focus tracking, and reports a corrupt history file.
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UserDefaults.standard.register(defaults: [
            "maxPerApp": 100,
            "captureImages": true,
            "hotKeyCode": HotKeyManager.defaultKeyCode,
            "hotKeyMods": HotKeyManager.defaultModifiers,
            "hotKeyLabel": "⇧⌘C",
        ])
        ClipStore.shared.start()
        PasteService.shared.start()
        HotKeyManager.shared.action = { PopupController.shared.toggle() }
        HotKeyManager.shared.registerFromDefaults()

        if let warning = ClipStore.shared.loadWarning {
            DispatchQueue.main.async {
                NSApp.activate(ignoringOtherApps: true)
                let alert = NSAlert()
                alert.messageText = "Clipboard history was reset"
                alert.informativeText = warning
                alert.runModal()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        ClipStore.shared.saveNow()
    }

    static func openDonate() {
        NSWorkspace.shared.open(URL(string: "https://ko-fi.com/leodavidai")!)
    }
}
