import AppKit

/// How a capture is handed to the target app.
enum Delivery: String, Codable, CaseIterable, Identifiable {
    /// Put the file (and image data) on the clipboard and press ⌘V. Best for chat apps.
    case attachment
    /// Paste the file's path as text. Best for terminal agents like Claude Code or Codex CLI.
    case path

    var id: String { rawValue }
    var label: String {
        switch self {
        case .attachment: "Attachment"
        case .path: "File path"
        }
    }
}

struct Target: Codable, Hashable, Identifiable {
    var name: String
    var bundleID: String
    var delivery: Delivery
    var symbol: String
    var isCustom: Bool = false

    var id: String { bundleID }

    var appURL: URL? { NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) }
    var isInstalled: Bool { appURL != nil }
    var icon: NSImage? { appURL.map { NSWorkspace.shared.icon(forFile: $0.path) } }

    static let presets: [Target] = [
        Target(name: "Claude", bundleID: "com.anthropic.claudefordesktop", delivery: .attachment, symbol: "sparkle"),
        Target(name: "Codex", bundleID: "com.openai.codex", delivery: .attachment, symbol: "chevron.left.forwardslash.chevron.right"),
        Target(name: "ChatGPT", bundleID: "com.openai.chat", delivery: .attachment, symbol: "bubble.left"),
        Target(name: "Cursor", bundleID: "com.todesktop.230313mzl4w4u92", delivery: .attachment, symbol: "cursorarrow"),
        Target(name: "Terminal", bundleID: "com.apple.Terminal", delivery: .path, symbol: "terminal"),
        Target(name: "Ghostty", bundleID: "com.mitchellh.ghostty", delivery: .path, symbol: "terminal"),
        Target(name: "iTerm", bundleID: "com.googlecode.iterm2", delivery: .path, symbol: "terminal"),
        Target(name: "Warp", bundleID: "dev.warp.Warp-Stable", delivery: .path, symbol: "terminal"),
    ]

    /// Builds a target from an app bundle the user picked.
    static func custom(appURL: URL) -> Target? {
        guard let bundle = Bundle(url: appURL), let id = bundle.bundleIdentifier else { return nil }
        let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? appURL.deletingPathExtension().lastPathComponent
        let looksLikeTerminal = ["terminal", "term", "ghostty", "warp", "kitty", "alacritty", "wezterm"]
            .contains { name.lowercased().contains($0) }
        return Target(name: name, bundleID: id, delivery: looksLikeTerminal ? .path : .attachment,
                      symbol: "app", isCustom: true)
    }
}
