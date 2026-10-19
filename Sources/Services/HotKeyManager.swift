import AppKit
import Carbon.HIToolbox

/// Registers a single system-wide hotkey through the Carbon Event Manager.
final class HotKeyManager {
    static let shared = HotKeyManager()
    var action: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    /// Default: ⌘⇧C.
    static let defaultKeyCode = kVK_ANSI_C
    static let defaultModifiers = cmdKey | shiftKey

    func register(keyCode: Int, modifiers: Int) {
        unregister()
        if handlerRef == nil {
            var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
            InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
                DispatchQueue.main.async { HotKeyManager.shared.action?() }
                return noErr
            }, 1, &spec, nil, &handlerRef)
        }
        let id = EventHotKeyID(signature: OSType(0x4147_4350), id: 1)
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr { NSLog("AppGroupedClips: hotkey registration failed (\(status))") }
    }

    func registerFromDefaults() {
        let d = UserDefaults.standard
        register(keyCode: d.integer(forKey: "hotKeyCode"), modifiers: d.integer(forKey: "hotKeyMods"))
    }

    func unregister() {
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        hotKeyRef = nil
    }

    /// Converts AppKit modifier flags to Carbon modifier bits.
    static func carbonModifiers(_ flags: NSEvent.ModifierFlags) -> Int {
        var m = 0
        if flags.contains(.command) { m |= cmdKey }
        if flags.contains(.shift) { m |= shiftKey }
        if flags.contains(.option) { m |= optionKey }
        if flags.contains(.control) { m |= controlKey }
        return m
    }

    static func symbols(_ flags: NSEvent.ModifierFlags) -> String {
        (flags.contains(.control) ? "⌃" : "") + (flags.contains(.option) ? "⌥" : "")
            + (flags.contains(.shift) ? "⇧" : "") + (flags.contains(.command) ? "⌘" : "")
    }
}
