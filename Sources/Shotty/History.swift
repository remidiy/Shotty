import AppKit
import ImageIO

/// One capture in Shotty's history.
struct Capture: Identifiable, Hashable, Codable {
    var id = UUID()
    let url: URL
    let date: Date
    var sentTo: String?
    var error: String?

    var isMovie: Bool { FolderWatcher.movieExtensions.contains(url.pathExtension.lowercased()) }
    var exists: Bool { FileManager.default.fileExists(atPath: url.path) }
    var title: String { url.deletingPathExtension().lastPathComponent }
}

/// Saves the capture history to ~/Library/Application Support/Shotty/history.json.
enum HistoryStore {
    static let limit = 300

    private static var fileURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Shotty", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    static func load() -> [Capture] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? JSONDecoder().decode([Capture].self, from: data)) ?? []
    }

    static func save(_ items: [Capture]) {
        guard let data = try? JSONEncoder().encode(Array(items.prefix(limit))) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}

/// Small, cached thumbnails so a long history list stays smooth.
@MainActor
enum Thumbnails {
    private static let cache = NSCache<NSURL, NSImage>()

    static func image(for url: URL, maxPixel: Int = 120) -> NSImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cg = CGImageSourceCreateThumbnailAtIndex(src, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixel,
                  kCGImageSourceCreateThumbnailWithTransform: true,
              ] as CFDictionary) else { return nil }
        let image = NSImage(cgImage: cg, size: .zero)
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}
