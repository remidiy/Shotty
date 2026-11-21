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
    /// A `--pointer-tour` or `--sleep-tour` self-test is running.
    static var isTour: Bool { CommandLine.arguments.contains("--pointer-tour") || CommandLine.arguments.contains("--sleep-tour") }

    /// `--demo-app --open-main --pointer-tour <dir>`: moves a simulated pointer in a circle around
    /// the Home logo, writes a frame (window snapshot plus a drawn pointer) every 1/15 s, then
    /// holds still past the 3 s idle timeout so the eyes settle, and quits. Needs no screen access.
    static func pointerTour() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--pointer-tour"), i + 1 < args.count else { return }
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        if args[i + 1] != "-" { try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            MainActor.assumeIsolated {
                guard let window = NSApp.windows.first(where: { $0.title == "Home" }) else { NSApp.terminate(nil); return }
                // The Home header logo (48 pt) sits about 248 pt from the left and 100 pt from the top.
                let logo = CGPoint(x: window.frame.minX + 248, y: window.frame.maxY - 100)
                // `--pointer-tour -`: no frames, 30 updates a second for 10 s (for measuring CPU).
                let measuring = dir.lastPathComponent == "-"
                let fps = measuring ? 30.0 : 15.0, moving = measuring ? 300 : 60, total = moving + (measuring ? 0 : 60)
                var frame = 0
                var pointer = logo
                Timer.scheduledTimer(withTimeInterval: 1 / fps, repeats: true) { timer in
                    MainActor.assumeIsolated {
                        if frame < moving {
                            let a = Double(frame) / Double(moving) * 2 * .pi + .pi / 2
                            pointer = CGPoint(x: logo.x + 170 * cos(a), y: logo.y + 110 * sin(a))
                            PointerTracker.shared.simulate(pointer)
                        }
                        if !measuring {
                            tourFrame(window, logo: logo, pointer: pointer,
                                      to: dir.appendingPathComponent(String(format: "f%03d.png", frame)))
                        }
                        frame += 1
                        if frame >= total { timer.invalidate(); NSApp.terminate(nil) }
                    }
                }
            }
        }
    }

    /// `--demo-app --open-main --sleep-tour <dir>`: snapshots the Home logo at 30 fps while
    /// Shotty pauses (eyes fall asleep) and resumes (eyes wake up), then quits. `-` writes no frames.
    static func sleepTour() {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--sleep-tour"), i + 1 < args.count else { return }
        let measuring = args[i + 1] == "-"
        // `live`: the same schedule without frames, for recording the real screen.
        let live = args[i + 1] == "live"
        let dir = URL(fileURLWithPath: args[i + 1], isDirectory: true)
        if !measuring && !live { try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true) }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            MainActor.assumeIsolated {
                guard let window = NSApp.windows.first(where: { $0.title == "Home" }), let model = AppModel.current
                else { NSApp.terminate(nil); return }
                let logo = CGPoint(x: window.frame.minX + 248, y: window.frame.maxY - 100)
                // Measuring: 10 s asleep, then quit. Frames: 0.5 s awake, pause, 1.5 s, resume, 1.5 s,
                // on a virtual clock that advances 1/30 s per frame.
                let slow: Double = 1
                let total = measuring ? 300 : 105
                var frame = 0
                if !measuring && !live {
                    let t0 = Date()
                    EyeAnimation.now = { t0.addingTimeInterval(Double(frame) / 30) }
                    EyeAnimation.timeScale = 30
                }
                Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { timer in
                    MainActor.assumeIsolated {
                        if frame == Int(15 * slow) || (measuring && frame == 0) { model.enabled = false }
                        if !measuring && frame == Int(60 * slow) { model.enabled = true }
                        if !measuring && !live {
                            tourFrame(window, logo: logo, pointer: nil,
                                      to: dir.appendingPathComponent(String(format: "f%03d.png", frame)))
                        }
                        frame += 1
                        if frame >= total { timer.invalidate(); NSApp.terminate(nil) }
                    }
                }
            }
        }
    }

    private static func tourFrame(_ window: NSWindow, logo: CGPoint, pointer: CGPoint?, to url: URL) {
        guard let view = window.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        let shot = NSImage(size: view.bounds.size)
        shot.addRepresentation(rep)
        // A 440 × 300 pt canvas centred on the logo, in screen coordinates.
        let canvas = NSRect(x: logo.x - 220, y: logo.y - 150, width: 440, height: 300)
        let image = NSImage(size: canvas.size, flipped: false) { _ in
            NSColor(white: 0.12, alpha: 1).setFill()
            NSRect(origin: .zero, size: canvas.size).fill()
            let content = window.contentRect(forFrameRect: window.frame)
            shot.draw(in: NSRect(x: content.minX - canvas.minX, y: content.minY - canvas.minY,
                                 width: content.width, height: content.height))
            if let pointer, let arrow = NSImage(systemSymbolName: "cursorarrow", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 22, weight: .regular)) {
                let tinted = NSImage(size: arrow.size, flipped: false) { r in
                    arrow.draw(in: r); NSColor.white.set(); r.fill(using: .sourceAtop); return true
                }
                tinted.draw(at: NSPoint(x: pointer.x - canvas.minX - 4, y: pointer.y - canvas.minY - arrow.size.height + 4),
                            from: .zero, operation: .sourceOver, fraction: 1)
            }
            return true
        }
        if let tiff = image.tiffRepresentation, let out = NSBitmapImageRep(data: tiff) {
            try? out.representation(using: .png, properties: [:])?.write(to: url)
        }
    }
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
                eyeAnimationFrames(to: dir.appendingPathComponent("logo-animation-frames.png"))
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

    /// Stills of the logo's hello animation, with the menu bar icon's frame under each.
    private static func eyeAnimationFrames(to url: URL) {
        let moments: [(Double, String)] = [(0, "Rest"), (0.33, "Blink"), (0.72, "Left"), (1.2, "Right"), (1.6, "Up"), (1.95, "Settle")]
        let strip = HStack(spacing: 28) {
            ForEach(moments, id: \.0) { t, label in
                let pose = EyeAnimation.pose(at: t, in: EyeAnimation.hello)
                VStack(spacing: 10) {
                    ShottyMark(size: 96, pose: pose)
                    Image(nsImage: MenuBarIcon.image(active: true, pose: pose))
                        .renderingMode(.template)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 36, height: 36)
                        .foregroundStyle(.black)
                    Text(label).font(.system(size: 13, weight: .medium)).foregroundStyle(.black.opacity(0.6))
                }
            }
        }
        .padding(28)
        .background(Color(white: 0.96))
        let renderer = ImageRenderer(content: strip)
        renderer.scale = 2
        if let cg = renderer.cgImage {
            try? NSBitmapImageRep(cgImage: cg).representation(using: .png, properties: [:])?.write(to: url)
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
