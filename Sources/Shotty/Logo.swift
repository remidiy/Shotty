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

/// Shotty's logo as a SwiftUI view (same mark as the app icon and the website).
struct ShottyMark: View {
    var size: CGFloat = 28

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: size * LogoGeometry.cornerRatio, style: .continuous)
                .fill(LinearGradient(colors: [LogoGeometry.top, LogoGeometry.bottom], startPoint: .top, endPoint: .bottom))
            ForEach(0..<2, id: \.self) { i in
                Capsule()
                    .fill(.white)
                    .frame(width: size * LogoGeometry.eyeSize.width, height: size * LogoGeometry.eyeSize.height)
                    .offset(x: size * LogoGeometry.eyeOrigins[i].x, y: size * LogoGeometry.eyeOrigins[i].y)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("Shotty")
    }
}

enum MenuBarIcon {
    /// 18×18 template image for the menu bar: the rounded square with the eyes cut out.
    /// When paused, the square is drawn as an outline with the eyes filled.
    static func image(active: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: true) { rect in
            let tile = rect.insetBy(dx: 1.5, dy: 1.5)
            let side = tile.width
            NSColor.black.setFill()
            NSColor.black.setStroke()
            // Eyes slightly bigger than the exact proportions so they read at 18 pt.
            let eyeW = max(side * LogoGeometry.eyeSize.width, 2.2)
            let eyeH = max(side * LogoGeometry.eyeSize.height, 4.2)
            let eyes = LogoGeometry.eyeOrigins.map { o -> NSBezierPath in
                let cx = tile.minX + side * (o.x + LogoGeometry.eyeSize.width / 2)
                let cy = tile.minY + side * (o.y + LogoGeometry.eyeSize.height / 2)
                return NSBezierPath(roundedRect: NSRect(x: cx - eyeW / 2, y: cy - eyeH / 2, width: eyeW, height: eyeH),
                                    xRadius: eyeW / 2, yRadius: eyeW / 2)
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
