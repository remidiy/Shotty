import AppKit
import ApplicationServices
import UniformTypeIdentifiers

enum SendError: LocalizedError {
    case appMissing(String)
    case noAccessibility

    var errorDescription: String? {
        switch self {
        case .appMissing(let name): "\(name) isn't installed."
        case .noAccessibility: "Shotty needs Accessibility access to paste."
        }
    }
}

struct SendOptions {
    var prompt: String
    var autoSend: Bool
    var restoreClipboard: Bool
}

/// Brings the target app forward and pastes the capture (and optional prompt) into it.
@MainActor
enum Sender {
    static var isTrusted: Bool { AXIsProcessTrusted() }

    static func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    static func deliver(_ file: URL, to target: Target, options: SendOptions) async throws {
        guard isTrusted else {
            requestAccessibility()
            throw SendError.noAccessibility
        }
        let pasteboard = NSPasteboard.general
        let snapshot = options.restoreClipboard ? PasteboardSnapshot(pasteboard) : nil
        let prompt = options.prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        // Fill the clipboard first so the paste can fire the moment the app is in front.
        switch target.delivery {
        case .attachment:
            writeFile(file, to: pasteboard)
        case .path:
            let quoted = shellQuoted(file.path)
            writeText(prompt.isEmpty ? quoted + " " : "\(prompt) \(quoted) ", to: pasteboard)
        }

        try await activate(target)
        pasteShortcut()

        if target.delivery == .attachment && !prompt.isEmpty {
            try await Task.sleep(for: .milliseconds(200))
            writeText(prompt, to: pasteboard)
            pasteShortcut()
        }

        if options.autoSend {
            // Chat apps need a moment to attach the image before Return sends it.
            try await Task.sleep(for: .milliseconds(target.delivery == .attachment ? 700 : 80))
            press(key: 0x24) // Return
        }

        if let snapshot {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(1000))
                snapshot.restore(to: pasteboard)
            }
        }
    }

    // MARK: - Activation

    private static func activate(_ target: Target) async throws {
        if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == target.bundleID { return }
        guard let appURL = target.appURL else { throw SendError.appMissing(target.name) }
        let wasRunning = !NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID).isEmpty
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        _ = try await NSWorkspace.shared.openApplication(at: appURL, configuration: config)
        // Poll quickly until the app is frontmost instead of sleeping a fixed time.
        let deadline = Date().addingTimeInterval(wasRunning ? 1.5 : 6)
        while NSWorkspace.shared.frontmostApplication?.bundleIdentifier != target.bundleID, Date() < deadline {
            try await Task.sleep(for: .milliseconds(15))
        }
        // Let its key window take focus. A cold launch needs longer for the input box to exist.
        try await Task.sleep(for: .milliseconds(wasRunning ? 120 : 1200))
    }

    // MARK: - Pasteboard

    private static func writeFile(_ file: URL, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        let item = NSPasteboardItem()
        item.setString(file.absoluteString, forType: .fileURL)
        let type = UTType(filenameExtension: file.pathExtension)
        if type?.conforms(to: .image) == true, let data = try? Data(contentsOf: file) {
            if type?.conforms(to: .png) == true {
                item.setData(data, forType: .png)
            } else if let image = NSImage(data: data), let tiff = image.tiffRepresentation {
                item.setData(tiff, forType: .tiff)
            }
        }
        pasteboard.writeObjects([item])
    }

    private static func writeText(_ text: String, to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private static func shellQuoted(_ path: String) -> String {
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/._-+"))
        if path.unicodeScalars.allSatisfy({ safe.contains($0) }) { return path }
        return "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    // MARK: - Keyboard

    private static func pasteShortcut() {
        press(key: 0x09, flags: .maskCommand) // V
    }

    private static func press(key: CGKeyCode, flags: CGEventFlags = []) {
        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: key, keyDown: false)
        down?.flags = flags
        up?.flags = flags
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }
}

/// A copy of everything on the clipboard so it can be put back after pasting.
struct PasteboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    init(_ pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            var dict: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) { dict[type] = data }
            }
            return dict
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let restored = items.map { dict -> NSPasteboardItem in
            let item = NSPasteboardItem()
            for (type, data) in dict { item.setData(data, forType: type) }
            return item
        }
        pasteboard.writeObjects(restored)
    }
}
