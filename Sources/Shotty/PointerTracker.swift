import AppKit
import Observation

/// Where the mouse pointer is, for the logo's eyes to follow (spec 0007).
///
/// Cheap by design: mouse-moved monitors (no permission needed) are installed only while some
/// logo is on screen and the feature is on, updates are throttled to 30 per second, and nothing
/// runs while the pointer is still. After 3 s without movement `isFollowing` turns off and the
/// eyes drift back to centre. Paused under Reduce Motion and while the screen is asleep or locked.
@MainActor
@Observable
final class PointerTracker {
    static let shared = PointerTracker()

    /// Pointer position in screen coordinates (AppKit: origin bottom-left, y up).
    private(set) var location: CGPoint = NSEvent.mouseLocation
    /// True while the pointer has moved in the last few seconds.
    private(set) var isFollowing = false

    /// The user setting "Eyes follow the pointer".
    var enabled = true { didSet { refresh() } }
    /// Shotty is paused and its eyes are asleep: no following, no monitors.
    var sleeping = false { didSet { refresh() } }

    @ObservationIgnored private var viewers = 0
    @ObservationIgnored private var monitors: [Any] = []
    @ObservationIgnored private var observers: [(NotificationCenter, NSObjectProtocol)] = []
    @ObservationIgnored private var lastPublish: TimeInterval = 0
    @ObservationIgnored private var trailingScheduled = false
    @ObservationIgnored private var idleWork: DispatchWorkItem?
    @ObservationIgnored private var screenAsleep = false
    @ObservationIgnored var simulating = false
    /// Called after every update (and when the eyes should return to centre). The menu bar icon
    /// uses it to swap its image directly instead of going through SwiftUI.
    @ObservationIgnored var onUpdate: (() -> Void)?

    static let interval: TimeInterval = 1.0 / 30
    static let idleAfter: TimeInterval = 3

    private init() {
        let ws = NSWorkspace.shared.notificationCenter
        let dist = DistributedNotificationCenter.default()
        func on(_ center: NotificationCenter, _ name: Notification.Name, _ asleep: Bool?) {
            observers.append((center, center.addObserver(forName: name, object: nil, queue: .main) { _ in
                MainActor.assumeIsolated {
                    if let asleep { PointerTracker.shared.screenAsleep = asleep }
                    PointerTracker.shared.refresh()
                }
            }))
        }
        on(ws, NSWorkspace.screensDidSleepNotification, true)
        on(ws, NSWorkspace.screensDidWakeNotification, false)
        on(ws, NSWorkspace.sessionDidResignActiveNotification, true)
        on(ws, NSWorkspace.sessionDidBecomeActiveNotification, false)
        on(dist, Notification.Name("com.apple.screenIsLocked"), true)
        on(dist, Notification.Name("com.apple.screenIsUnlocked"), false)
        on(ws, NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, nil)
    }

    /// Whether eyes should follow right now (setting on, motion allowed, screen awake).
    var isActive: Bool { enabled && !sleeping && !screenAsleep && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }

    /// A logo came on screen. Balance with `release()`.
    func retain() { viewers += 1; refresh() }
    func release() { viewers = max(0, viewers - 1); refresh() }

    private func refresh() {
        let want = viewers > 0 && isActive
        if want && monitors.isEmpty {
            let mask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
            if let g = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { _ in
                MainActor.assumeIsolated { PointerTracker.shared.moved() }
            }) { monitors.append(g) }
            if let l = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
                MainActor.assumeIsolated { PointerTracker.shared.moved() }
                return event
            }) { monitors.append(l) }
        } else if !want && !monitors.isEmpty {
            monitors.forEach(NSEvent.removeMonitor)
            monitors.removeAll()
            idleWork?.cancel()
            if isFollowing { isFollowing = false }
            onUpdate?()
        }
    }

    /// Called for every mouse move; publishes at most 30 times a second, plus one trailing update.
    private func moved() {
        let now = ProcessInfo.processInfo.systemUptime
        if now - lastPublish >= Self.interval {
            publish(now)
        } else if !trailingScheduled {
            trailingScheduled = true
            DispatchQueue.main.asyncAfter(deadline: .now() + (Self.interval - (now - lastPublish))) {
                MainActor.assumeIsolated {
                    let tracker = PointerTracker.shared
                    tracker.trailingScheduled = false
                    tracker.publish(ProcessInfo.processInfo.systemUptime)
                }
            }
        }
    }

    private func publish(_ now: TimeInterval) {
        lastPublish = now
        if !simulating {
            let p = NSEvent.mouseLocation
            if p != location { location = p }
        }
        if !isFollowing { isFollowing = true }
        idleWork?.cancel()
        let work = DispatchWorkItem {
            MainActor.assumeIsolated {
                PointerTracker.shared.isFollowing = false
                PointerTracker.shared.onUpdate?()
            }
        }
        idleWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.idleAfter, execute: work)
        onUpdate?()
    }

    /// Pretends the pointer moved to `point` (the `--pointer-tour` self-test; no real events).
    func simulate(_ point: CGPoint) {
        simulating = true
        location = point
        publish(ProcessInfo.processInfo.systemUptime)
    }

    /// Eye offset (fractions of the mark's side, y down) for a logo centred at `center` on screen.
    /// Points toward the pointer, up to `maxOffset`, reaching it about 300 pt away.
    func gaze(from center: CGPoint?, maxOffset: CGFloat = 0.09) -> EyePose {
        guard isFollowing, isActive, let center else { return .rest }
        let vx = location.x - center.x
        let vy = location.y - center.y
        let d = hypot(vx, vy)
        guard d > 1 else { return .rest }
        let reach = maxOffset * min(1, d / 300)
        return EyePose(dx: vx / d * reach, dy: -vy / d * reach)
    }
}
