import Foundation
import ImageIO

/// Watches one folder and reports new screenshots / screen recordings once they are fully written.
@MainActor
final class FolderWatcher {
    nonisolated static let imageExtensions: Set<String> = ["png", "jpg", "jpeg", "heic", "tiff", "tif", "gif"]
    nonisolated static let movieExtensions: Set<String> = ["mov", "mp4", "m4v"]
    private static let screenshotPrefixes = ["Screenshot", "Screen Shot", "Screen Recording", "CleanShot", "Bildschirmfoto", "Capture d"]

    var includeRecordings = true
    var onlyScreenshots = true

    private var source: DispatchSourceFileSystemObject?
    private var known: Set<String> = []
    private var pending: Set<String> = []
    private var scanScheduled = false
    private(set) var folder: URL?
    private let onNew: (URL) -> Void

    init(onNew: @escaping (URL) -> Void) {
        self.onNew = onNew
    }

    func start(folder: URL) {
        stop()
        self.folder = folder
        known = listing(of: folder)
        let fd = open(folder.path, O_EVTONLY)
        guard fd >= 0 else { return }
        let src = DispatchSource.makeFileSystemObjectSource(fileDescriptor: fd, eventMask: [.write, .rename], queue: .main)
        src.setEventHandler { [weak self] in
            MainActor.assumeIsolated { self?.scheduleScan() }
        }
        src.setCancelHandler { close(fd) }
        src.resume()
        source = src
    }

    func stop() {
        source?.cancel()
        source = nil
    }

    var isRunning: Bool { source != nil }

    private func scheduleScan() {
        guard !scanScheduled else { return }
        scanScheduled = true
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(30))
            scanScheduled = false
            scan()
        }
    }

    private func scan() {
        guard let folder else { return }
        let now = listing(of: folder)
        let added = now.subtracting(known).subtracting(pending)
        known = now
        for name in added {
            let url = folder.appendingPathComponent(name)
            guard isCandidate(url) else { continue }
            pending.insert(name)
            Task { @MainActor in
                if await Self.waitUntilReady(url) { onNew(url) }
                pending.remove(name)
            }
        }
    }

    private func listing(of folder: URL) -> Set<String> {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        return Set(names.filter { !$0.hasPrefix(".") })
    }

    func isCandidate(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        let isImage = Self.imageExtensions.contains(ext)
        let isMovie = Self.movieExtensions.contains(ext)
        guard isImage || (isMovie && includeRecordings) else { return false }
        guard onlyScreenshots else { return true }
        if Self.hasScreenCaptureFlag(url) { return true }
        let name = url.lastPathComponent
        return Self.screenshotPrefixes.contains { name.hasPrefix($0) }
    }

    /// macOS tags its own captures with this extended attribute.
    static func hasScreenCaptureFlag(_ url: URL) -> Bool {
        getxattr(url.path, "com.apple.metadata:kMDItemIsScreenCapture", nil, 0, 0, 0) > 0
    }

    /// Waits until the file is fully written.
    /// macOS writes screenshots to a hidden temp file and renames it, so images are usually
    /// ready on the first check; we confirm by decoding the header. Recordings are written
    /// over time, so for those we wait for the size to settle.
    static func waitUntilReady(_ url: URL) async -> Bool {
        let isMovie = movieExtensions.contains(url.pathExtension.lowercased())
        if !isMovie {
            for _ in 0..<100 { // up to ~5 s
                if let src = CGImageSourceCreateWithURL(url as CFURL, nil),
                   CGImageSourceGetStatus(src) == .statusComplete,
                   CGImageSourceGetCount(src) > 0 {
                    return true
                }
                try? await Task.sleep(for: .milliseconds(50))
            }
            return FileManager.default.fileExists(atPath: url.path)
        }
        var last: Int = -1
        for _ in 0..<240 { // up to ~60 s
            let size = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int) ?? -1
            if size > 0 && size == last { return true }
            last = size
            try? await Task.sleep(for: .milliseconds(250))
        }
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// True when macOS shows the floating thumbnail after a capture. While it is visible
    /// (about 5 seconds) macOS has not written the file yet, which is the main source of lag.
    static var floatingThumbnailEnabled: Bool {
        let value = CFPreferencesCopyAppValue("show-thumbnail" as CFString, "com.apple.screencapture" as CFString)
        return (value as? Bool) ?? true
    }

    /// Turns the floating thumbnail off (same as unticking it in the ⇧⌘5 Options menu).
    static func disableFloatingThumbnail() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["write", "com.apple.screencapture", "show-thumbnail", "-bool", "false"]
        try? task.run()
        task.waitUntilExit()
        CFPreferencesAppSynchronize("com.apple.screencapture" as CFString)
    }

    /// The folder macOS saves screenshots to (`defaults read com.apple.screencapture location`), or the Desktop.
    static func systemScreenshotFolder() -> URL {
        if let raw = CFPreferencesCopyAppValue("location" as CFString, "com.apple.screencapture" as CFString) as? String,
           !raw.isEmpty {
            let path = (raw as NSString).expandingTildeInPath
            var isDir: ObjCBool = false
            if FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                return URL(fileURLWithPath: path, isDirectory: true)
            }
        }
        return FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop", isDirectory: true)
    }
}
