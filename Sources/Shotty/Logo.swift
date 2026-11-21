import AppKit
import SwiftUI

/// Geometry of Shotty's mark, on the 512-unit canvas of the website logo (apps/shotty-site/public/logo.svg):
/// a blue rounded square with two white capsule eyes sitting slightly above centre.
enum LogoGeometry {
    static let cornerRatio: CGFloat = 115.0 / 512.0
    static let eyeSize = CGSize(width: 67.0 / 512.0, height: 123.0 / 512.0)
    /// Eye origins (top-left, y down) as fractions of the side.
    static let eyeOrigins: [CGPoint] = [CGPoint(x: 172.0 / 512.0, y: 179.0 / 512.0),
                                        CGPoint(x: 273.0 / 512.0, y: 179.0 / 512.0)]
    static let top = Color(red: 0x5C / 255.0, green: 0x9E / 255.0, blue: 1.0)
    static let bottom = Color(red: 0x33 / 255.0, green: 0x5C / 255.0, blue: 0xF5 / 255.0)
}

// MARK: - Eye animation (spec 0007)

/// Where the eyes look and how open they are. Offsets are fractions of the mark's side (y down).
struct EyePose: Equatable {
    var dx: CGFloat = 0
    var dy: CGFloat = 0
    var openness: CGFloat = 1

    static let rest = EyePose()
}

/// The "hello" the logo does when a window opens: blink, glance left, right, up, settle.
/// One timeline drives both the SwiftUI logo and the menu bar icon, so they move the same way.
enum EyeAnimation {
    struct Key { let time: Double; let pose: EyePose }

    static let glance: CGFloat = 0.08

    /// About 2 s.
    static let hello: [Key] = [
        Key(time: 0.00, pose: .rest),
        Key(time: 0.25, pose: .rest),
        Key(time: 0.33, pose: EyePose(openness: 0.1)),        // blink
        Key(time: 0.42, pose: .rest),
        Key(time: 0.62, pose: EyePose(dx: -glance)),          // glance left
        Key(time: 0.82, pose: EyePose(dx: -glance)),
        Key(time: 1.10, pose: EyePose(dx: glance)),           // glance right
        Key(time: 1.28, pose: EyePose(dx: glance)),
        Key(time: 1.50, pose: EyePose(dy: -glance)),          // glance up
        Key(time: 1.70, pose: EyePose(dy: -glance)),
        Key(time: 1.95, pose: .rest),                         // settle
    ]

    /// A single quiet blink, used now and then while a window is open.
    static let blink: [Key] = [
        Key(time: 0.00, pose: .rest),
        Key(time: 0.08, pose: EyePose(openness: 0.1)),
        Key(time: 0.17, pose: .rest),
    ]

    static func duration(_ keys: [Key]) -> Double { keys.last?.time ?? 0 }

    /// The pose `t` seconds into `keys`, eased in and out between keyframes.
    static func pose(at t: Double, in keys: [Key]) -> EyePose {
        guard let first = keys.first, t > first.time else { return keys.first?.pose ?? .rest }
        for (a, b) in zip(keys, keys.dropFirst()) where t <= b.time {
            let span = b.time - a.time
            let p = span > 0 ? (t - a.time) / span : 1
            let e = CGFloat(p < 0.5 ? 2 * p * p : 1 - pow(-2 * p + 2, 2) / 2)  // easeInOut
            return EyePose(dx: a.pose.dx + (b.pose.dx - a.pose.dx) * e,
                           dy: a.pose.dy + (b.pose.dy - a.pose.dy) * e,
                           openness: a.pose.openness + (b.pose.openness - a.pose.openness) * e)
        }
        return keys.last?.pose ?? .rest
    }

    /// Posted when the menu bar panel opens, so the icon and the panel's logo play together.
    static let playNotification = Notification.Name("ShottyPlayEyeAnimation")

    static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
}

// MARK: - SwiftUI logo

/// Shotty's logo as a SwiftUI view (same mark as the app icon and the website).
/// With `animated`, the eyes say hello when the view appears (and whenever `replay` changes);
/// with `idleBlinks`, they blink every 8–12 s while it's on screen. Reduce Motion: a fade only.
struct ShottyMark: View {
    var size: CGFloat = 28
    var animated = false
    var idleBlinks = false
    var replay = 0
    /// A fixed pose (for rendering stills).
    var pose: EyePose? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playback: (start: Date, keys: [EyeAnimation.Key])?
    @State private var shown = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: size * LogoGeometry.cornerRatio, style: .continuous)
                .fill(LinearGradient(colors: [LogoGeometry.top, LogoGeometry.bottom], startPoint: .top, endPoint: .bottom))
            if let playback {
                TimelineView(.animation) { context in
                    eyes(EyeAnimation.pose(at: context.date.timeIntervalSince(playback.start), in: playback.keys))
                }
            } else {
                eyes(pose ?? .rest)
            }
        }
        .frame(width: size, height: size)
        .opacity(animated && reduceMotion && !shown ? 0 : 1)
        .contentShape(.rect(cornerRadius: size * LogoGeometry.cornerRatio))
        // Click the logo and it blinks (a blink isn't travel, so Reduce Motion keeps it).
        .onTapGesture { if pose == nil { play(EyeAnimation.blink) } }
        .accessibilityLabel("Shotty")
        .onAppear {
            guard animated else { return }
            if reduceMotion {
                withAnimation(.easeIn(duration: 0.3)) { shown = true }
            } else {
                play(EyeAnimation.hello)
            }
        }
        .onChange(of: replay) { if animated && !reduceMotion { play(EyeAnimation.hello) } }
        .task(id: idleBlinks && !reduceMotion) {
            guard idleBlinks && !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 8...12)))
                if Task.isCancelled { break }
                if playback == nil { play(EyeAnimation.blink) }
            }
        }
    }

    private func eyes(_ pose: EyePose) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: size * LogoGeometry.eyeSize.width, height: size * LogoGeometry.eyeSize.height)
                    .scaleEffect(x: 1, y: pose.openness, anchor: .center)
                    .offset(x: size * (LogoGeometry.eyeOrigins[i].x + pose.dx),
                            y: size * (LogoGeometry.eyeOrigins[i].y + pose.dy))
            }
        }
        .frame(width: size, height: size, alignment: .topLeading)
    }

    private func play(_ keys: [EyeAnimation.Key]) {
        let start = Date()
        playback = (start, keys)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(EyeAnimation.duration(keys)))
            if playback?.start == start { playback = nil }
        }
    }
}

// MARK: - Menu bar icon

enum MenuBarIcon {
    /// 18×18 template image for the menu bar: the rounded square with the eyes cut out.
    /// When paused, the square is drawn as an outline with the eyes filled.
    static func image(active: Bool, pose: EyePose = .rest) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { rect in
            let tile = rect.insetBy(dx: 1.5, dy: 1.5)
            let side = tile.width
            NSColor.black.setFill()
            NSColor.black.setStroke()
            // Eyes slightly bigger than the exact proportions so they read at 18 pt.
            let eyeW = max(side * LogoGeometry.eyeSize.width, 2.2)
            let eyeH = max(side * LogoGeometry.eyeSize.height, 4.2) * max(pose.openness, 0.12)
            let eyes = LogoGeometry.eyeOrigins.map { o -> NSBezierPath in
                let cx = tile.minX + side * (o.x + LogoGeometry.eyeSize.width / 2 + pose.dx)
                let cy = tile.minY + side * (o.y + LogoGeometry.eyeSize.height / 2 + pose.dy)
                let r = min(eyeW, eyeH) / 2
                return NSBezierPath(roundedRect: NSRect(x: cx - eyeW / 2, y: cy - eyeH / 2, width: eyeW, height: eyeH),
                                    xRadius: r, yRadius: r)
            }
            let radius = side * LogoGeometry.cornerRatio
            if active {
                NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius).fill()
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                eyes.forEach { $0.fill() }
            } else {
                let outline = NSBezierPath(roundedRect: tile.insetBy(dx: 0.75, dy: 0.75), xRadius: radius - 0.75, yRadius: radius - 0.75)
                outline.lineWidth = 1.5
                outline.stroke()
                eyes.forEach { $0.fill() }
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Shotty"
        return image
    }
}
