import AppKit
import SwiftUI

/// Shotty's mark: a round face with two friendly eyes.
struct BotFace: View {
    var size: CGFloat = 28
    var faceColor: Color = .white
    var eyeColor: Color = Color(red: 0.12, green: 0.13, blue: 0.2)

    var body: some View {
        ZStack {
            Circle().fill(faceColor)
            HStack(spacing: size * 0.2) {
                Capsule().fill(eyeColor).frame(width: size * 0.13, height: size * 0.24)
                Capsule().fill(eyeColor).frame(width: size * 0.13, height: size * 0.24)
            }
            .offset(y: -size * 0.03)
        }
        .frame(width: size, height: size)
    }
}

enum MenuBarIcon {
    /// Template image for the menu bar: a filled circle with the eyes cut out.
    /// When paused the face is drawn as an outline instead.
    static func image(active: Bool) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let face = NSBezierPath(ovalIn: rect.insetBy(dx: 1.5, dy: 1.5))
            NSColor.black.setFill()
            NSColor.black.setStroke()
            let eyeW: CGFloat = 2.4, eyeH: CGFloat = 4.4, gap: CGFloat = 3.4
            let eyeY = rect.midY - eyeH / 2 + 0.6
            let left = NSBezierPath(roundedRect: NSRect(x: rect.midX - gap / 2 - eyeW, y: eyeY, width: eyeW, height: eyeH),
                                    xRadius: eyeW / 2, yRadius: eyeW / 2)
            let right = NSBezierPath(roundedRect: NSRect(x: rect.midX + gap / 2, y: eyeY, width: eyeW, height: eyeH),
                                     xRadius: eyeW / 2, yRadius: eyeW / 2)
            if active {
                face.fill()
                NSGraphicsContext.current?.compositingOperation = .destinationOut
                left.fill()
                right.fill()
            } else {
                face.lineWidth = 1.5
                face.stroke()
                left.fill()
                right.fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
