import AppKit
import Observation
import ServiceManagement

struct Capture: Identifiable, Hashable {
    let url: URL
    let date: Date
    var sentTo: String?
    var error: String?

    var id: URL { url }
    var isMovie: Bool { FolderWatcher.movieExtensions.contains(url.pathExtension.lowercased()) }
}

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

    var recent: [Capture] = []
    var status: String?
    var isSending = false
    var accessibilityGranted = Sender.isTrusted

    @ObservationIgnored private var watcher: FolderWatcher!

    init() {
        defaults.register(defaults: [
            "enabled": true, "includeRecordings": true, "onlyScreenshots": true,
            "autoSend": false, "restoreClipboard": true, "prompt": "",
        ])
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
        applyWatching()

        // Pick up an Accessibility grant made in System Settings while we run.
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self else { return }
                let trusted = Sender.isTrusted
                if trusted != self.accessibilityGranted { self.accessibilityGranted = trusted }
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

    var target: Target? { availableTargets.first { $0.bundleID == targetID } ?? availableTargets.first }

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
        guard let watcher else { return }
        if enabled { watcher.start(folder: folder) } else { watcher.stop() }
    }

    // MARK: - Sending

    private func captured(_ url: URL) {
        recent.insert(Capture(url: url, date: .now), at: 0)
        if recent.count > 8 { recent.removeLast(recent.count - 8) }
        guard enabled else { return }
        send(url)
    }

    func send(_ url: URL) {
        guard let target else { status = "Pick an app to send to."; return }
        isSending = true
        Task {
            defer { isSending = false }
            do {
                try await Sender.deliver(url, to: target, options: SendOptions(
                    prompt: prompt, autoSend: autoSend, restoreClipboard: restoreClipboard))
                mark(url, sentTo: target.name, error: nil)
                status = "Sent to \(target.name)"
            } catch {
                mark(url, sentTo: nil, error: error.localizedDescription)
                status = error.localizedDescription
            }
            accessibilityGranted = Sender.isTrusted
        }
    }

    func sendLatest() {
        if let latest = recent.first { send(latest.url); return }
        let names = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.creationDateKey])) ?? []
        let newest = names
            .filter { watcher.isCandidate($0) }
            .max { a, b in
                let da = (try? a.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                let db = (try? b.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
                return da < db
            }
        guard let newest else { status = "No screenshots in \(folder.lastPathComponent) yet."; return }
        recent.insert(Capture(url: newest, date: .now), at: 0)
        send(newest)
    }

    private func mark(_ url: URL, sentTo: String?, error: String?) {
        guard let i = recent.firstIndex(where: { $0.url == url }) else { return }
        recent[i].sentTo = sentTo
        recent[i].error = error
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
