import AppKit
import Observation
import ServiceManagement

@MainActor
@Observable
final class AppModel {
    private let defaults = UserDefaults.standard

    var enabled: Bool { didSet { save(enabled, "enabled"); applyWatching() } }
    var includeRecordings: Bool { didSet { save(includeRecordings, "includeRecordings"); watcher.includeRecordings = includeRecordings } }
    var onlyScreenshots: Bool { didSet { save(onlyScreenshots, "onlyScreenshots"); watcher.onlyScreenshots = onlyScreenshots } }
    var autoSend: Bool { didSet { save(autoSend, "autoSend") } }
    var restoreClipboard: Bool { didSet { save(restoreClipboard, "restoreClipboard") } }
    var prompt: String { didSet { save(prompt, "prompt") } }
    var targetID: String { didSet { save(targetID, "targetID") } }
    var customFolderPath: String? { didSet { save(customFolderPath, "customFolderPath"); applyWatching() } }
    var customTargets: [Target] { didSet { saveTargets() } }
    var deliveryOverrides: [String: Delivery] { didSet { saveTargets() } }
    var hotKeyEnabled: Bool { didSet { save(hotKeyEnabled, "hotKeyEnabled"); applyHotKey() } }
    /// Send to whichever app you were using when you took the capture.
    var followFrontmost: Bool { didSet { save(followFrontmost, "followFrontmost") } }
    /// Show the capture flying into the target app (spec 0005).
    var animateCaptures: Bool { didSet { save(animateCaptures, "animateCaptures") } }

    /// Every capture, newest first. Saved to disk.
    var recent: [Capture] = [] { didSet { if !isDemo { HistoryStore.save(recent) } } }
    /// The last app the user was working in (not Shotty, Finder or the screenshot UI).
    var lastApp: Target?
    var status: String?
    var isSending = false
    var accessibilityGranted = Sender.isTrusted
    var screenRecordingGranted = Permissions.screenRecording
    let unstableSignature = Permissions.isAdHocSigned
    var thumbnailSlowsCaptures = FolderWatcher.floatingThumbnailEnabled

    @ObservationIgnored private var watcher: FolderWatcher!
    @ObservationIgnored private var hotKey: HotKey?
    @ObservationIgnored private var activationObserver: NSObjectProtocol?

    /// Apps that are never "the app you were using".
    private static let ignoredBundleIDs: Set<String> = [
        "com.remidiy.shotty", "com.apple.finder", "com.apple.screencaptureui", "com.apple.Screenshot",
        "com.apple.dock", "com.apple.loginwindow", "com.apple.systemuiserver", "com.apple.controlcenter",
        "com.apple.notificationcenterui", "com.apple.Spotlight", "com.apple.WindowManager",
    ]

    init() {
        defaults.register(defaults: [
            "enabled": true, "includeRecordings": true, "onlyScreenshots": true,
            "autoSend": false, "restoreClipboard": true, "prompt": "", "hotKeyEnabled": true,
            "followFrontmost": true, "animateCaptures": true,
        ])
        animateCaptures = defaults.bool(forKey: "animateCaptures")
        followFrontmost = defaults.bool(forKey: "followFrontmost")
        hotKeyEnabled = defaults.bool(forKey: "hotKeyEnabled")
        enabled = defaults.bool(forKey: "enabled")
        includeRecordings = defaults.bool(forKey: "includeRecordings")
        onlyScreenshots = defaults.bool(forKey: "onlyScreenshots")
        autoSend = defaults.bool(forKey: "autoSend")
        restoreClipboard = defaults.bool(forKey: "restoreClipboard")
        prompt = defaults.string(forKey: "prompt") ?? ""
        customFolderPath = defaults.string(forKey: "customFolderPath")
        customTargets = (defaults.data(forKey: "customTargets")).flatMap { try? JSONDecoder().decode([Target].self, from: $0) } ?? []
        deliveryOverrides = (defaults.data(forKey: "deliveryOverrides")).flatMap { try? JSONDecoder().decode([String: Delivery].self, from: $0) } ?? [:]
        let firstInstalled = Target.presets.first(where: \.isInstalled)?.bundleID ?? Target.presets[0].bundleID
        targetID = defaults.string(forKey: "targetID") ?? firstInstalled

        watcher = FolderWatcher { [weak self] url in self?.captured(url) }
        watcher.includeRecordings = includeRecordings
        watcher.onlyScreenshots = onlyScreenshots
        if DemoWindow.isAppDemo {
            loadDemoCaptures()  // sample data only: nothing is watched, saved or sent
        } else {
            recent = HistoryStore.load()
        }
        applyWatching()
        applyHotKey()
        if !isDemo { trackFrontmostApp() }

        // Pick up an Accessibility grant made in System Settings while we run.
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let trusted = Sender.isTrusted
                if trusted != self.accessibilityGranted { self.accessibilityGranted = trusted }
                let screen = Permissions.screenRecording
                if screen != self.screenRecordingGranted { self.screenRecordingGranted = screen }
                let slow = FolderWatcher.floatingThumbnailEnabled
                if slow != self.thumbnailSlowsCaptures { self.thumbnailSlowsCaptures = slow }
            }
        }
    }

    // MARK: - Targets

    var availableTargets: [Target] {
        (Target.presets.filter(\.isInstalled) + customTargets).map { target in
            var t = target
            if let override = deliveryOverrides[t.bundleID] { t.delivery = override }
            return t
        }
    }

    /// The fixed app used when "app you were using" is off, or when there is no such app yet.
    var fixedTarget: Target? { availableTargets.first { $0.bundleID == targetID } ?? availableTargets.first }

    /// Where the next capture goes.
    var target: Target? {
        if followFrontmost, var app = lastApp {
            if let override = deliveryOverrides[app.bundleID] { app.delivery = override }
            return app
        }
        return fixedTarget
    }

    private func trackFrontmostApp() {
        if let app = NSWorkspace.shared.frontmostApplication { noteActivated(app) }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            MainActor.assumeIsolated { self?.noteActivated(app) }
        }
    }

    private func noteActivated(_ app: NSRunningApplication) {
        guard let id = app.bundleIdentifier, !Self.ignoredBundleIDs.contains(id),
              app.activationPolicy == .regular else { return }
        if lastApp?.bundleID == id { return }
        lastApp = Target.forApp(bundleID: id, name: app.localizedName ?? id)
    }

    func setDelivery(_ delivery: Delivery, for target: Target) {
        deliveryOverrides[target.bundleID] = delivery
    }

    func addCustomTarget() {
        let panel = NSOpenPanel()
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.application]
        panel.prompt = "Add App"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url, let t = Target.custom(appURL: url) else { return }
        if !availableTargets.contains(where: { $0.bundleID == t.bundleID }) { customTargets.append(t) }
        targetID = t.bundleID
        followFrontmost = false
    }

    func removeCustomTarget(_ target: Target) {
        customTargets.removeAll { $0.bundleID == target.bundleID }
        if targetID == target.bundleID { targetID = availableTargets.first?.bundleID ?? "" }
    }

    // MARK: - Folder

    var folder: URL {
        if let path = customFolderPath { return URL(fileURLWithPath: path, isDirectory: true) }
        return FolderWatcher.systemScreenshotFolder()
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.directoryURL = folder
        panel.prompt = "Watch Folder"
        NSApp.activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        customFolderPath = url.path
    }

    func useSystemFolder() { customFolderPath = nil }

    private func applyWatching() {
        guard let watcher, !isDemo else { return }
        if enabled { watcher.start(folder: folder) } else { watcher.stop() }
    }

    // MARK: - Sending

    private func captured(_ url: URL) {
        if isDemo { return }
        let destination = target  // the app you were in when the file appeared
        remember(url)
        guard enabled else { return }
        send(url, to: destination, origin: .capture)
    }

    private func remember(_ url: URL) {
        recent.removeAll { $0.url == url }
        recent.insert(Capture(url: url, date: .now), at: 0)
        if recent.count > HistoryStore.limit { recent.removeLast(recent.count - HistoryStore.limit) }
    }

    func send(_ url: URL, to destination: Target? = nil, origin: FlyInAnimation.Origin = .pointer) {
        guard FileManager.default.fileExists(atPath: url.path) else {
            status = "\(url.lastPathComponent) was moved or deleted."
            return
        }
        guard let target = destination ?? target else { status = "Switch to the app you want, then capture."; return }
        isSending = true
        let start = Date()
        if animateCaptures {
            FlyInAnimation.play(file: url, origin: origin, targetBundleID: target.bundleID)
        }
        Task {
            defer { isSending = false }
            do {
                try await Sender.deliver(url, to: target, options: SendOptions(
                    prompt: prompt, autoSend: autoSend, restoreClipboard: restoreClipboard))
                mark(url, sentTo: target.name, error: nil)
                let ms = Int(Date().timeIntervalSince(start) * 1000)
                status = "Sent to \(target.name) in \(ms) ms"
            } catch {
                mark(url, sentTo: nil, error: error.localizedDescription)
                status = error.localizedDescription
            }
            accessibilityGranted = Sender.isTrusted
        }
    }

    func removeFromHistory(_ capture: Capture) {
        recent.removeAll { $0.id == capture.id }
    }

    func clearHistory() { recent.removeAll() }

    func copyToClipboard(_ capture: Capture) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.writeObjects([capture.url as NSURL])
        status = "Copied \(capture.title)"
    }

    /// Capture with Shotty's own shortcut: no floating thumbnail, so it sends immediately.
    func instantCapture() {
        let destination = target  // decide before the capture UI appears
        InstantCapture.run { [weak self] url in
            guard let self, let url else { return }
            self.remember(url)
            self.send(url, to: destination, origin: .capture)
        }
    }

    func makeCapturesInstant() {
        FolderWatcher.disableFloatingThumbnail()
        thumbnailSlowsCaptures = FolderWatcher.floatingThumbnailEnabled
        status = thumbnailSlowsCaptures ? "Couldn't change the setting. Untick Show Floating Thumbnail in ⇧⌘5 → Options." : "Screenshots now save instantly."
    }

    private func applyHotKey() {
        hotKey?.unregister()
        hotKey = nil
        guard hotKeyEnabled else { return }
        hotKey = HotKey(keyCode: InstantCapture.keyCode, modifiers: InstantCapture.modifiers) { [weak self] in
            self?.instantCapture()
        }
    }

    /// Sends the newest capture: whichever is newer of the last history item and the newest file in the folder.
    func sendLatest() {
        let created: (URL) -> Date = { (try? $0.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast }
        let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        let newestFile = files.filter { watcher.isCandidate($0) }.max { created($0) < created($1) }
        let lastKept = recent.first { $0.exists }

        let pick: URL?
        switch (lastKept, newestFile) {
        case let (kept?, file?): pick = created(file) > kept.date ? file : kept.url
        case let (kept?, nil): pick = kept.url
        case let (nil, file?): pick = file
        default: pick = nil
        }
        guard let pick else { status = "No screenshots in \(folder.lastPathComponent) yet."; return }
        if recent.first?.url != pick { remember(pick) }
        send(pick)
    }

    private func mark(_ url: URL, sentTo: String?, error: String?) {
        guard let i = recent.firstIndex(where: { $0.url == url }) else { return }
        recent[i].sentTo = sentTo
        recent[i].error = error
    }

    // MARK: - Demo

    var isDemo = false

    func loadDemoCaptures() {
        isDemo = true
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ShottyDemo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        lastApp = Target.presets.first { $0.name == "Cursor" }
        let names = [("Screenshot 2026-11-21 at 10.42.17.png", "Cursor", 40.0),
                     ("Screen Recording 2026-11-21 at 10.31.02.mov", "Claude", 700.0),
                     ("Shotty 2026-11-21 101504.png", "Ghostty", 1700.0),
                     ("Screenshot 2026-11-21 at 09.58.40.png", "Claude", 4200.0),
                     ("Screenshot 2026-11-20 at 18.12.03.png", "Codex", 64000.0)]
        let colors: [NSColor] = [.systemBlue, .systemPurple, .systemTeal, .systemOrange, .systemPink]
        recent = names.enumerated().map { i, item in
            let url = dir.appendingPathComponent(item.0)
            if !item.0.hasSuffix(".mov") {
                // Simple stand-in "screenshot": a window shape on a tinted backdrop.
                let image = NSImage(size: NSSize(width: 160, height: 100), flipped: false) { r in
                    colors[i].withAlphaComponent(0.35).setFill(); r.fill()
                    NSColor.white.setFill()
                    NSBezierPath(roundedRect: r.insetBy(dx: 22, dy: 16), xRadius: 6, yRadius: 6).fill()
                    colors[i].setFill()
                    NSBezierPath(rect: NSRect(x: 30, y: 62, width: 60, height: 8)).fill()
                    return true
                }
                if let tiff = image.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                    try? rep.representation(using: .png, properties: [:])?.write(to: url)
                }
            }
            return Capture(url: url, date: Date().addingTimeInterval(-item.2), sentTo: item.1)
        }
        status = "Sent to Cursor in 182 ms"
    }

    // MARK: - Launch at login

    var launchAtLogin: Bool {
        get { SMAppService.mainApp.status == .enabled }
        set {
            do {
                if newValue { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            } catch {
                status = "Couldn't change login item: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Persistence

    private func save(_ value: Any?, _ key: String) { defaults.set(value, forKey: key) }

    private func saveTargets() {
        defaults.set(try? JSONEncoder().encode(customTargets), forKey: "customTargets")
        defaults.set(try? JSONEncoder().encode(deliveryOverrides), forKey: "deliveryOverrides")
    }
}
