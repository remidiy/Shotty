// Renders Shotty's icon and logo PNGs: a round face with two eyes on a blue squircle.
// Usage: swift scripts/make-icon.swift <output-dir>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/icon")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

func render(size: Int, background: Bool) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ink = NSColor(srgbRed: 0.10, green: 0.12, blue: 0.22, alpha: 1)

    var faceRect = NSRect(x: 0, y: 0, width: s, height: s)
    if background {
        // macOS icon grid: 824pt squircle inside a 1024pt canvas.
        let inset = s * 100 / 1024
        let tile = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
        let path = NSBezierPath(roundedRect: tile, xRadius: tile.width * 0.225, yRadius: tile.width * 0.225)
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.28)
        shadow.shadowOffset = NSSize(width: 0, height: -s * 0.012)
        shadow.shadowBlurRadius = s * 0.025
        shadow.set()
        NSColor.black.setFill(); path.fill()
        NSGraphicsContext.current?.restoreGraphicsState()
        NSGradient(starting: NSColor(srgbRed: 0.36, green: 0.62, blue: 1.0, alpha: 1),
                   ending: NSColor(srgbRed: 0.20, green: 0.36, blue: 0.96, alpha: 1))!.draw(in: path, angle: -90)
        // soft glass highlight on the top half
        NSGraphicsContext.current?.saveGraphicsState()
        path.addClip()
        let shine = NSBezierPath(ovalIn: NSRect(x: tile.minX - tile.width * 0.2, y: tile.midY + tile.height * 0.05,
                                                width: tile.width * 1.4, height: tile.height * 0.9))
        NSColor.white.withAlphaComponent(0.14).setFill(); shine.fill()
        NSGraphicsContext.current?.restoreGraphicsState()
        faceRect = tile.insetBy(dx: tile.width * 0.2, dy: tile.width * 0.2)
    }

    let face = NSBezierPath(ovalIn: faceRect)
    if background {
        NSColor.white.setFill(); face.fill()
    } else {
        // Standalone logo: blue face, white eyes.
        NSGradient(starting: NSColor(srgbRed: 0.36, green: 0.62, blue: 1.0, alpha: 1),
                   ending: NSColor(srgbRed: 0.20, green: 0.36, blue: 0.96, alpha: 1))!.draw(in: face, angle: -90)
    }
    let d = faceRect.width
    let eyeW = d * 0.13, eyeH = d * 0.24, gap = d * 0.2
    let eyeY = faceRect.midY - eyeH / 2 + d * 0.03
    (background ? ink : NSColor.white).setFill()
    for x in [faceRect.midX - gap / 2 - eyeW, faceRect.midX + gap / 2] {
        NSBezierPath(roundedRect: NSRect(x: x, y: eyeY, width: eyeW, height: eyeH), xRadius: eyeW / 2, yRadius: eyeW / 2).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = out.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(size: base, background: true).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(size: base * 2, background: true).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try! render(size: 1024, background: true).write(to: out.appendingPathComponent("icon-1024.png"))
try! render(size: 512, background: false).write(to: out.appendingPathComponent("logo-512.png"))
print(out.path)
