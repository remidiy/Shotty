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

    // MARK: Sleep and wake (Pause)

    /// Asleep: thin closed lids, drooped a little.
    static let asleep = EyePose(dx: 0, dy: 0.025, openness: 0.12)
    /// Asleep without the droop (Reduce Motion: no travel).
    static let asleepStill = EyePose(openness: 0.12)

    static func asleepPose(reduceMotion: Bool) -> EyePose { reduceMotion ? asleepStill : asleep }

    /// Eyes slowly close (0.6 s).
    static func sleep(reduceMotion: Bool) -> [Key] {
        [Key(time: 0, pose: .rest),
         Key(time: 0.25, pose: EyePose(openness: 0.7)),
         Key(time: 0.6, pose: asleepPose(reduceMotion: reduceMotion))]
    }

    /// Waking like a dog: eyes open a little, a quick double blink, a slight head shake with
    /// decaying amplitude (±6, ±4, ±2 %), then centre. Reduce Motion: the eyes just open.
    static func wake(reduceMotion: Bool) -> [Key] {
        if reduceMotion {
            return [Key(time: 0, pose: asleepStill), Key(time: 0.3, pose: .rest)]
        }
        return [
            Key(time: 0.00, pose: asleep),
            Key(time: 0.15, pose: EyePose(dy: 0.01, openness: 0.55)),  // eyes open slightly
            Key(time: 0.27, pose: .rest),
            Key(time: 0.33, pose: EyePose(openness: 0.1)),             // blink
            Key(time: 0.39, pose: .rest),
            Key(time: 0.45, pose: EyePose(openness: 0.1)),             // blink
            Key(time: 0.51, pose: .rest),
            Key(time: 0.60, pose: EyePose(dx: 0.06)),                  // shake
            Key(time: 0.69, pose: EyePose(dx: -0.04)),
            Key(time: 0.77, pose: EyePose(dx: 0.02)),
            Key(time: 0.86, pose: .rest),
        ]
    }

    /// A sleepy half-open flutter when the sleeping logo is clicked. It doesn't wake Shotty.
    static func flutter(reduceMotion: Bool) -> [Key] {
        let lids = asleepPose(reduceMotion: reduceMotion)
        var half = lids; half.openness = 0.4
        return [Key(time: 0, pose: lids), Key(time: 0.18, pose: half), Key(time: 0.3, pose: half), Key(time: 0.6, pose: lids)]
    }

    static func duration(_ keys: [Key]) -> Double { keys.last?.time ?? 0 }

    /// The window logo's clock. `--sleep-tour` replaces it with one that advances 1/30 s per
    /// captured frame, and stretches `timeScale` so clips don't end early in real time.
    @MainActor static var now: () -> Date = { Date() }
    @MainActor static var timeScale: Double = 1

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
/// The eyes follow the mouse pointer while it moves (see `PointerTracker`), and a click blinks.
struct ShottyMark: View {
    var size: CGFloat = 28
    var animated = false
    var idleBlinks = false
    var replay = 0
    /// Shotty is paused: the eyes close and stay closed (no following, no idle blinks).
    var asleep = false
    /// A fixed pose (for rendering stills).
    var pose: EyePose? = nil

    enum Clip { case hello, blink, sleep, wake, flutter }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var playback: (start: Date, keys: [EyeAnimation.Key], clip: Clip)?
    @State private var shown = false
    @State private var anchor = ScreenAnchor()

    /// Where the pointer pulls the eyes. Only a blink mixes with it; other clips take over.
    private var gaze: EyePose {
        guard pose == nil, !asleep, playback == nil || playback?.clip == .blink else { return .rest }
        return PointerTracker.shared.gaze(from: anchor.screenCenter)
    }

    /// The pose with nothing playing.
    private var resting: EyePose { pose ?? (asleep ? EyeAnimation.asleepPose(reduceMotion: reduceMotion) : .rest) }

    var body: some View {
        let gaze = self.gaze
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: size * LogoGeometry.cornerRatio, style: .continuous)
                .fill(LinearGradient(colors: [LogoGeometry.top, LogoGeometry.bottom], startPoint: .top, endPoint: .bottom))
            Group {
                if let playback {
                    TimelineView(.animation) { context in
                        eyes(EyeAnimation.pose(at: EyeAnimation.now().timeIntervalSince(playback.start), in: playback.keys), gaze: gaze)
                    }
                } else {
                    eyes(resting, gaze: gaze)
                }
            }
            // Moves arrive 30 times a second, so they're drawn as-is (cheap); only the drift
            // back to centre after the pointer stops is animated.
            .animation(PointerTracker.shared.isFollowing ? nil : .spring(response: 0.45, dampingFraction: 0.8), value: gaze)
        }
        .background(ScreenAnchorReader(anchor: anchor))
        .onAppear { if pose == nil { PointerTracker.shared.retain() } }
        .onDisappear { if pose == nil { PointerTracker.shared.release() } }
        .frame(width: size, height: size)
        .opacity(animated && reduceMotion && !shown ? 0 : 1)
        .contentShape(.rect(cornerRadius: size * LogoGeometry.cornerRatio))
        // Click the logo and it blinks (a blink isn't travel, so Reduce Motion keeps it).
        .onTapGesture {
            guard pose == nil else { return }
            if asleep { play(EyeAnimation.flutter(reduceMotion: reduceMotion), .flutter) } else { play(EyeAnimation.blink, .blink) }
        }
        .accessibilityLabel("Shotty")
        .onAppear {
            guard animated else { return }
            if reduceMotion || asleep {
                withAnimation(.easeIn(duration: 0.3)) { shown = true }
            } else {
                play(EyeAnimation.hello, .hello)
            }
        }
        .onChange(of: replay) { if animated && !reduceMotion && !asleep { play(EyeAnimation.hello, .hello) } }
        .onChange(of: asleep) {
            guard pose == nil else { return }
            if asleep {
                play(EyeAnimation.sleep(reduceMotion: reduceMotion), .sleep)
            } else {
                play(EyeAnimation.wake(reduceMotion: reduceMotion), .wake)
            }
        }
        .task(id: idleBlinks && !reduceMotion && !asleep) {
            // No timer at all while asleep.
            guard idleBlinks && !reduceMotion && !asleep else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 8...12)))
                if Task.isCancelled { break }
                if playback == nil { play(EyeAnimation.blink, .blink) }
            }
        }
    }

    private func eyes(_ pose: EyePose, gaze: EyePose = .rest) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: size * LogoGeometry.eyeSize.width, height: size * LogoGeometry.eyeSize.height)
                    .scaleEffect(x: 1, y: pose.openness, anchor: .center)
                    .offset(x: size * (LogoGeometry.eyeOrigins[i].x + pose.dx + gaze.dx),
                            y: size * (LogoGeometry.eyeOrigins[i].y + pose.dy + gaze.dy))
            }
        }
        .frame(width: size, height: size, alignment: .topLeading)
    }

    private func play(_ keys: [EyeAnimation.Key], _ clip: Clip) {
        let start = EyeAnimation.now()
        playback = (start, keys, clip)
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(EyeAnimation.duration(keys) * EyeAnimation.timeScale))
            if playback?.start == start { playback = nil }
        }
    }
}

/// Remembers the AppKit view behind a logo, to find its centre on screen.
@MainActor
final class ScreenAnchor {
    weak var view: NSView?
    var screenCenter: CGPoint? {
        guard let view, let window = view.window else { return nil }
        let r = window.convertToScreen(view.convert(view.bounds, to: nil))
        return CGPoint(x: r.midX, y: r.midY)
    }
}

private struct ScreenAnchorReader: NSViewRepresentable {
    let anchor: ScreenAnchor
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        anchor.view = view
        return view
    }
    func updateNSView(_ view: NSView, context: Context) { anchor.view = view }
}

// MARK: - Menu bar icon

@MainActor
enum MenuBarIcon {
    private static var cache: [String: NSImage] = [:]
    private static weak var statusWindow: NSWindow?

    /// Same as `image`, with the eye offset snapped to half points (one Retina pixel), so moving
    /// the pointer only redraws the icon when the eyes actually move, and frames are reused.
    static func cachedImage(active: Bool, pose: EyePose) -> NSImage {
        let side: CGFloat = 15
        func snap(_ v: CGFloat) -> CGFloat { (v * side * 2).rounded() / (side * 2) }
        let p = EyePose(dx: snap(pose.dx), dy: snap(pose.dy), openness: (pose.openness * 20).rounded() / 20)
        let key = "\(active)|\(p.dx)|\(p.dy)|\(p.openness)"
        if let hit = cache[key] { return hit }
        let image = image(active: active, pose: p)
        if cache.count > 200 { cache.removeAll() }
        cache[key] = image
        return image
    }

    /// Whether Shotty is on (filled icon) or paused (outline).
    static var active = true
    /// The pose of the clip playing (hello, sleep, wake); otherwise the eyes follow the pointer,
    /// or sleep while paused.
    static var helloPose: EyePose?
    private static var shownKey = ""
    private static weak var button: NSButton?

    /// Puts the current frame on the status item, only if it differs from the one shown.
    static func refresh(force: Bool = false) {
        let pose = helloPose
            ?? (active ? PointerTracker.shared.gaze(from: statusItemCenter)
                       : EyeAnimation.asleepPose(reduceMotion: EyeAnimation.reduceMotion))
        let image = cachedImage(active: active, pose: pose)
        let key = "\(ObjectIdentifier(image))"
        guard force || key != shownKey, let button = statusButton else { return }
        shownKey = key
        button.image = image
    }

    private static var statusButton: NSButton? {
        if let button { return button }
        _ = statusItemCenter
        func find(_ view: NSView?) -> NSButton? {
            guard let view else { return nil }
            if let b = view as? NSButton { return b }
            for sub in view.subviews { if let b = find(sub) { return b } }
            return nil
        }
        button = find(statusWindow?.contentView)
        return button
    }

    /// Centre of Shotty's menu bar item on screen.
    static var statusItemCenter: CGPoint? {
        if statusWindow == nil {
            statusWindow = NSApp.windows.first { String(describing: type(of: $0)).contains("StatusBarWindow") }
        }
        guard let frame = statusWindow?.frame else { return nil }
        return CGPoint(x: frame.midX, y: frame.midY)
    }

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
