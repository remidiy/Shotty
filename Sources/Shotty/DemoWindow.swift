import AppKit
import SwiftUI

/// `Shotty --demo` shows the panel and settings in normal windows with sample captures.
/// `Shotty --demo --snapshot <dir>` also writes PNGs of both and quits (used for the README).
/// Nothing is watched or sent in demo mode.
@MainActor
enum DemoWindow {
    static var isActive: Bool { CommandLine.arguments.contains("--demo") }
    /// `Shotty --demo-app`: the normal app (menu bar, main window, onboarding) with sample captures.
    /// History isn't saved and nothing is sent. Used for screenshots.
    static var isAppDemo: Bool { CommandLine.arguments.contains("--demo-app") }
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
                menuBarIconSheet(to: dir.appendingPathComponent("menubar-icon.png"))
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

    /// The menu bar icon (on and paused) on a light and a dark menu bar, at 4×.
    private static func menuBarIconSheet(to url: URL) {
        let scale: CGFloat = 4, cell = NSSize(width: 44, height: 24)
        let size = NSSize(width: cell.width * 2 * scale, height: cell.height * 2 * scale)
        let image = NSImage(size: size, flipped: false) { _ in
            for (row, dark) in [false, true].enumerated() {
                let y = CGFloat(1 - row) * cell.height * scale
                (dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.94, alpha: 1)).setFill()
                NSRect(x: 0, y: y, width: size.width, height: cell.height * scale).fill()
                for (col, active) in [true, false].enumerated() {
                    let icon = MenuBarIcon.image(active: active)
                    let tinted = NSImage(size: icon.size, flipped: false) { r in
                        icon.draw(in: r)
                        (dark ? NSColor.white : NSColor.black).set()
                        r.fill(using: .sourceAtop)
                        return true
                    }
                    let side = 18 * scale
                    tinted.draw(in: NSRect(x: CGFloat(col) * cell.width * scale + (cell.width * scale - side) / 2,
                                           y: y + (cell.height * scale - side) / 2, width: side, height: side))
                }
            }
            return true
        }
        if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            try? rep.representation(using: .png, properties: [:])?.write(to: url)
        }
    }

    private static func snapshot(_ window: NSWindow, to url: URL) {
        guard let view = window.contentView else { return }
        let rect = view.bounds
        guard let rep = view.bitmapImageRepForCachingDisplay(in: rect) else { return }
        view.cacheDisplay(in: rect, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: url)
    }
}
