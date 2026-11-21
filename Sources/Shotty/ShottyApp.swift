import SwiftUI

@main
struct ShottyApp: App {
    @State private var model = AppModel()

    init() {
        // `Shotty --fly <image> <bundle-id>`: play the fly-in animation once (for checking it by eye).
        if let i = CommandLine.arguments.firstIndex(of: "--fly"), i + 2 < CommandLine.arguments.count {
            let file = URL(fileURLWithPath: CommandLine.arguments[i + 1])
            let bundle = CommandLine.arguments[i + 2]
            DispatchQueue.main.async {
                FlyInAnimation.play(file: file, origin: .capture, targetBundleID: bundle)
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { NSApp.terminate(nil) }
            }
        }
        if DemoWindow.isActive {
            let model = _model.wrappedValue
            DispatchQueue.main.async { DemoWindow.show(model: model) }
        }
        DockPolicy.start()
        if DemoWindow.isAppDemo { DispatchQueue.main.async { DemoWindow.pointerTour(); DemoWindow.sleepTour() } }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView(model: model)
        } label: {
            MenuBarLabel(enabled: model.enabled)
        }
        .menuBarExtraStyle(.window)

        // The full app window (spec 0007). Shows Shotty in the Dock while open.
        Window("Shotty", id: SceneID.main) {
            MainWindow(model: model)
        }
        .defaultSize(width: 860, height: 580)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .commands { ShottyCommands() }

        // First-launch walkthrough, shown once (and again from Help → Show Welcome…).
        Window("Welcome to Shotty", id: SceneID.welcome) {
            OnboardingView(model: model)
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        .restorationBehavior(.disabled)
        .defaultPosition(.center)

        Settings {
            SettingsView(model: model)
        }
    }
}

/// The menu bar icon. It's the one view SwiftUI creates at launch in a menu bar app,
/// so it also opens the welcome window on first launch.
struct MenuBarLabel: View {
    let enabled: Bool
    @Environment(\.openWindow) private var openWindow
    @State private var playing: Task<Void, Never>?

    var body: some View {
        // SwiftUI draws the resting icon. The moving frames (hello, following the pointer) are
        // set on the status item button directly by `MenuBarIcon`, because re-rendering a
        // MenuBarExtra label 30 times a second costs ~17% CPU, and a direct swap costs ~nothing.
        Image(nsImage: MenuBarIcon.cachedImage(active: enabled, pose: enabled ? .rest : EyeAnimation.asleepPose(reduceMotion: EyeAnimation.reduceMotion)))
            .accessibilityLabel("Shotty")
            .onAppear {
                MenuBarIcon.active = enabled
                PointerTracker.shared.retain()
                PointerTracker.shared.onUpdate = { MenuBarIcon.refresh() }
            }
            .onChange(of: enabled) { enabled ? wake() : sleep() }
            .task {
                guard !DemoWindow.isActive else { return }
                if Onboarding.shouldShow { openWindow(id: SceneID.welcome) }
                // `--open-main`: open the main window at launch (used for screenshots).
                if CommandLine.arguments.contains("--open-main") { openWindow(id: SceneID.main) }
                playHello()
            }
            .onReceive(NotificationCenter.default.publisher(for: EyeAnimation.playNotification)) { _ in playHello() }
    }

    /// Paused: the eyes close (still the filled icon), then it becomes the paused outline.
    private func sleep() {
        MenuBarIcon.active = true
        play(EyeAnimation.sleep(reduceMotion: EyeAnimation.reduceMotion)) {
            MenuBarIcon.active = false
        }
    }

    /// Resumed: the filled icon wakes up (open, double blink, little shake).
    private func wake() {
        MenuBarIcon.active = true
        play(EyeAnimation.wake(reduceMotion: EyeAnimation.reduceMotion))
    }

    private func playHello() {
        guard !EyeAnimation.reduceMotion, enabled else { return }
        play(EyeAnimation.hello)
    }

    /// Plays a clip by swapping pre-drawn template frames (~30 fps). No timer once it ends.
    private func play(_ keys: [EyeAnimation.Key], then done: @escaping @MainActor () -> Void = {}) {
        playing?.cancel()
        playing = Task { @MainActor in
            let start = Date()
            while !Task.isCancelled {
                let t = Date().timeIntervalSince(start)
                MenuBarIcon.helloPose = EyeAnimation.pose(at: t, in: keys)
                MenuBarIcon.refresh()
                if t >= EyeAnimation.duration(keys) { break }
                try? await Task.sleep(for: .milliseconds(33))
            }
            // A newer run cancelled this one and owns the state now.
            if Task.isCancelled { return }
            done()
            MenuBarIcon.helloPose = nil
            MenuBarIcon.refresh(force: true)
            playing = nil
        }
    }
}

enum SceneID {
    static let main = "main"
    static let welcome = "welcome"
}

struct ShottyCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(after: .newItem) {
            Button("Open Shotty Window") { openWindow(id: SceneID.main) }
                .keyboardShortcut("0")
        }
        CommandGroup(replacing: .help) {
            Button("Show Welcome…") { openWindow(id: SceneID.welcome) }
            Button("Shotty on GitHub") {
                NSWorkspace.shared.open(URL(string: "https://github.com/remidiy/Shotty")!)
            }
        }
    }
}

/// Shotty is a menu bar app (LSUIElement), but while one of its real windows is open it behaves
/// like a normal app: Dock icon, ⌘-Tab, main menu. When the last window closes it goes back to
/// the menu bar only.
@MainActor
enum DockPolicy {
    private static var observers: [NSObjectProtocol] = []

    static func start() {
        let center = NotificationCenter.default
        for name in [NSWindow.didBecomeKeyNotification, NSWindow.didBecomeMainNotification, NSWindow.willCloseNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                // Run after the window has actually closed/appeared.
                DispatchQueue.main.async { MainActor.assumeIsolated { update() } }
            })
        }
    }

    /// Titled, visible, non-panel windows (the main, welcome and Settings windows).
    private static var hasAppWindow: Bool {
        NSApp.windows.contains { w in
            w.isVisible && w.styleMask.contains(.titled) && !(w is NSPanel) && w.canBecomeMain
        }
    }

    /// Called when the main or welcome window opens: show in the Dock and come to the front.
    static func windowAppeared() {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                // Self-tests run in the background: off-screen window, no focus stealing.
                if DemoWindow.isTour {
                    for w in NSApp.windows where w.title == "Home" { w.setFrameOrigin(NSPoint(x: -4000, y: 200)) }
                    return
                }
                if !DemoWindow.isActive { NSApp.setActivationPolicy(.regular) }
                NSApp.activate()
            }
        }
    }

    static func update() {
        if DemoWindow.isActive { return }
        let want: NSApplication.ActivationPolicy = hasAppWindow ? .regular : .accessory
        guard NSApp.activationPolicy() != want else { return }
        NSApp.setActivationPolicy(want)
        if want == .regular { NSApp.activate() }
    }
}
