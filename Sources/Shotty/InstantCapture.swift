import AppKit
import Carbon.HIToolbox

/// A system-wide shortcut registered with Carbon (works without Accessibility).
@MainActor
final class HotKey {
    private var ref: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private static var action: (() -> Void)?

    init(keyCode: Int, modifiers: Int, action: @escaping () -> Void) {
        HotKey.action = action
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            DispatchQueue.main.async { HotKey.action?() }
            return noErr
        }, 1, &spec, nil, &handlerRef)
        let id = EventHotKeyID(signature: OSType(0x5348_5459), id: 1) // "SHTY"
        RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers), id, GetApplicationEventTarget(), 0, &ref)
    }

    func unregister() {
        if let ref { UnregisterEventHotKey(ref) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        ref = nil
        handlerRef = nil
    }
}

/// Runs macOS's own `screencapture` tool. Unlike ⇧⌘4 it never shows the floating
/// thumbnail, so the file exists the instant you finish selecting.
enum InstantCapture {
    /// ⌃⇧4
    static let keyCode = kVK_ANSI_4
    static let modifiers = controlKey | shiftKey
    static let shortcutLabel = "⌃⇧4"

    static var folder: URL {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures/Shotty", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Lets the user pick an area (press Space for a window). Calls back with the file, or nil if cancelled.
    static func run(completion: @escaping @MainActor (URL?) -> Void) {
        let stamp = Date.now.formatted(.iso8601.year().month().day().time(includingFractionalSeconds: false)
            .timeSeparator(.omitted).dateTimeSeparator(.space))
        let url = folder.appendingPathComponent("Shotty \(stamp).png")
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", "-x", url.path] // interactive, no sound
        task.terminationHandler = { _ in
            let exists = FileManager.default.fileExists(atPath: url.path)
            Task { @MainActor in completion(exists ? url : nil) }
        }
        do { try task.run() } catch { Task { @MainActor in completion(nil) } }
    }
}
