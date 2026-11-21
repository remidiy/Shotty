import AppKit
import SwiftUI

/// `Shotty --demo` shows the panel and settings in normal windows with sample captures.
/// `Shotty --demo --snapshot <dir>` also writes PNGs of both and quits (used for the README).
/// Nothing is watched or sent in demo mode.
@MainActor
enum DemoWindow {
    static var isActive: Bool { CommandLine.arguments.contains("--demo") }
    private static var windows: [NSWindow] = []

    static func show(model: AppModel) {
        model.loadDemoCaptures()
        NSApp.setActivationPolicy(.regular)
        let panel = makeWindow(MenuView(model: model), material: .popover, origin: NSPoint(x: 200, y: 200), title: nil)
        let settings = makeWindow(SettingsView(model: model), material: .windowBackground, origin: NSPoint(x: 560, y: 200), title: "Shotty Settings")
        NSApp.activate()

        if let i = CommandLine.arguments.firstIndex(of: "--snapshot"), i + 1 < CommandLine.arguments.count {
            let dir = URL(fileURLWithPath: CommandLine.arguments[i + 1], isDirectory: true)
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                snapshot(panel, to: dir.appendingPathComponent("panel.png"))
                snapshot(settings, to: dir.appendingPathComponent("settings.png"))
                NSApp.terminate(nil)
            }
        }
    }

    private static func makeWindow<V: View>(_ view: V, material: NSVisualEffectView.Material, origin: NSPoint, title: String?) -> NSWindow {
        let host = NSHostingView(rootView: view)
        let effect = NSVisualEffectView()
        effect.material = material
        effect.blendingMode = .behindWindow
        effect.state = .active
        host.translatesAutoresizingMaskIntoConstraints = false
        effect.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: effect.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: effect.trailingAnchor),
            host.topAnchor.constraint(equalTo: effect.topAnchor),
            host.bottomAnchor.constraint(equalTo: effect.bottomAnchor),
        ])
        let size = host.fittingSize
        let win = NSWindow(contentRect: NSRect(origin: origin, size: size),
                           styleMask: title == nil ? [.borderless] : [.titled, .closable],
                           backing: .buffered, defer: false)
        if let title { win.title = title } else {
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 12
            effect.layer?.masksToBounds = true
            win.isOpaque = false
            win.backgroundColor = .clear
        }
        win.contentView = effect
        win.setContentSize(size)
        win.makeKeyAndOrderFront(nil)
        windows.append(win)
        return win
    }

    private static func snapshot(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView else { return }
        let rect = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: rect) else { return }
        view.cacheDisplay(in: rect, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
