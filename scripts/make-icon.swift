// Renders Shotty's icon and logo PNGs from the website mark (apps/shotty-site/public/logo.svg):
// a blue vertical-gradient rounded square with two white capsule eyes.
// Usage: swift scripts/make-icon.swift <output-dir>
import AppKit

let out = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "build/icon")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)

let top = NSColor(srgbRed: 0x5C / 255.0, green: 0x9E / 255.0, blue: 1.0, alpha: 1)
let bottom = NSColor(srgbRed: 0x33 / 255.0, green: 0x5C / 255.0, blue: 0xF5 / 255.0, alpha: 1)

/// `iconGrid`: macOS icon grid (824/1024 tile with a soft drop shadow). Otherwise full bleed.
func render(size: Int, iconGrid: Bool) -> Data {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.current = ctx
    // Draw in SVG coordinates (y down).
    ctx.cgContext.translateBy(x: 0, y: s)
    ctx.cgContext.scaleBy(x: 1, y: -1)

    let inset = iconGrid ? s * 100 / 1024 : 0
    let tile = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let side = tile.width
    let radius = side * 115 / 512
    let path = NSBezierPath(roundedRect: tile, xRadius: radius, yRadius: radius)

    if iconGrid {
        NSGraphicsContext.current?.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.25)
        shadow.shadowOffset = NSSize(width: 0, height: -s * 0.01)  // shadows ignore the flip: negative is down
        shadow.shadowBlurRadius = s * 0.02
        shadow.set()
        bottom.setFill(); path.fill()
        NSGraphicsContext.current?.restoreGraphicsState()
    }
    // angle 90 in a flipped context runs from top (y=0) to bottom.
    NSGradient(starting: top, ending: bottom)!.draw(in: path, angle: 90)

    NSColor.white.setFill()
    let eyeW = side * 67 / 512, eyeH = side * 123 / 512
    for x in [172.0, 273.0] {
        let r = NSRect(x: tile.minX + side * x / 512, y: tile.minY + side * 179 / 512, width: eyeW, height: eyeH)
        NSBezierPath(roundedRect: r, xRadius: eyeW / 2, yRadius: eyeW / 2).fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}

let iconset = out.appendingPathComponent("AppIcon.iconset")
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(size: base, iconGrid: true).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(size: base * 2, iconGrid: true).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
try! render(size: 1024, iconGrid: true).write(to: out.appendingPathComponent("icon-1024.png"))
try! render(size: 512, iconGrid: false).write(to: out.appendingPathComponent("logo-512.png"))
print(out.path)
