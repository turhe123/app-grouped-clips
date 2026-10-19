import AppKit
import ApplicationServices

/// Tracks the previously active app and pastes clips into it by synthesizing ⌘V.
final class PasteService {
    static let shared = PasteService()
    private(set) var previousApp: NSRunningApplication?
    private var observer: NSObjectProtocol?

    func start() {
        guard observer == nil else { return }
        previousApp = NSWorkspace.shared.frontmostApplication
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            self?.previousApp = app
        }
    }

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system Accessibility prompt (only the first time it is called per install).
    static func requestAccessIfNeeded() {
        let key = "askedAccessibility"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    /// Copies the clip; when Accessibility is granted, also closes the popup and pastes into the previous app.
    func paste(_ clip: Clip, store: ClipStore) {
        store.writeToPasteboard(clip)
        guard Self.isTrusted else {
            Self.requestAccessIfNeeded()
            store.notice = "Copied to the clipboard. To paste automatically, allow AppGroupedClips under System Settings › Privacy & Security › Accessibility."
            return
        }
        store.notice = nil
        PopupController.shared.close()
        previousApp?.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { Self.postCommandV() }
    }

    private static func postCommandV() {
        let source = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

/// Holds a reference to the MenuBarExtra popup window so it can be toggled and closed programmatically.
final class PopupController {
    static let shared = PopupController()
    weak var window: NSWindow?

    var isVisible: Bool { window?.isVisible ?? false }

    func close() { window?.close() }

    /// Opens or closes the popup by clicking the menu bar status item.
    func toggle() {
        if isVisible { close(); return }
        for w in NSApp.windows where w.className.contains("NSStatusBarWindow") {
            if let button = Self.findButton(in: w.contentView) {
                button.performClick(nil)
                return
            }
        }
    }

    private static func findButton(in view: NSView?) -> NSButton? {
        guard let view else { return nil }
        if let b = view as? NSButton { return b }
        for sub in view.subviews { if let b = findButton(in: sub) { return b } }
        return nil
    }
}
