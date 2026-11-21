import AppKit
import AVFoundation
import QuartzCore

/// Shows the capture flying from where it was taken into the target app's window (spec 0005).
/// Drawn in a transparent, click-through overlay so it never steals focus or input.
@MainActor
enum FlyInAnimation {
    enum Origin {
        /// A fresh capture: start at the capture's size, anchored at the pointer (or full screen).
        case capture
        /// Re-sent from history: start small at the pointer.
        case pointer
    }

    private static var overlays: [NSPanel] = []

    static func play(file: URL, origin: Origin, targetBundleID: String) {
        Task { @MainActor in
            guard let image = await cardImage(for: file) else { return }
            let screenFrame = overlayFrame()
            let start = startRect(for: image, origin: origin)
            let end = landingPoint(bundleID: targetBundleID)
            run(image: image, from: start, to: end, in: screenFrame)
        }
    }

    // MARK: - Geometry (all in Cocoa global coordinates, origin bottom-left of the main screen)

    private static func overlayFrame() -> NSRect {
        NSScreen.screens.reduce(NSRect.null) { $0.union($1.frame) }
    }

    private static func startRect(for image: NSImage, origin: Origin) -> NSRect {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main ?? NSScreen.screens[0]
        let scale = screen.backingScaleFactor
        var size = NSSize(width: image.size.width, height: image.size.height)
        // NSImage from a Retina PNG reports pixels as points; convert.
        if let rep = image.representations.first, rep.pixelsWide > 0 {
            size = NSSize(width: CGFloat(rep.pixelsWide) / scale, height: CGFloat(rep.pixelsHigh) / scale)
        }

        if origin == .pointer {
            let w: CGFloat = 160
            let h = w * size.height / max(size.width, 1)
            return NSRect(x: mouse.x - w / 2, y: mouse.y - h / 2, width: w, height: h)
        }
        // Full-screen capture: start as the whole screen.
        if size.width >= screen.frame.width * 0.95 && size.height >= screen.frame.height * 0.9 {
            return screen.frame
        }
        // Area/window capture: the selection ends at the pointer (bottom-right corner).
        var rect = NSRect(x: mouse.x - size.width, y: mouse.y, width: size.width, height: size.height)
        let bounds = screen.visibleFrame
        rect.origin.x = min(max(rect.minX, bounds.minX), bounds.maxX - rect.width)
        rect.origin.y = min(max(rect.minY, bounds.minY), bounds.maxY - rect.height)
        return rect
    }

    /// Lower-middle of the target app's front window, where chat inputs usually are.
    private static func landingPoint(bundleID: String) -> NSPoint {
        if let window = frontWindowFrame(bundleID: bundleID) {
            return NSPoint(x: window.midX, y: window.minY + min(110, window.height * 0.18))
        }
        let screen = NSScreen.main ?? NSScreen.screens[0]
        return NSPoint(x: screen.frame.midX, y: screen.frame.minY + 40) // towards the Dock
    }

    static func frontWindowFrame(bundleID: String) -> NSRect? {
        let pids = Set(NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).map(\.processIdentifier))
        guard !pids.isEmpty,
              let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return nil }
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        for info in list { // front-to-back order
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t, pids.contains(pid),
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let dict = info[kCGWindowBounds as String] as? NSDictionary,
                  let cg = CGRect(dictionaryRepresentation: dict),
                  cg.width > 200, cg.height > 150 else { continue }
            // CG window bounds are top-left based; flip to Cocoa.
            return NSRect(x: cg.minX, y: primaryHeight - cg.maxY, width: cg.width, height: cg.height)
        }
        return nil
    }

    // MARK: - Image

    private static func cardImage(for file: URL) async -> NSImage? {
        if FolderWatcher.movieExtensions.contains(file.pathExtension.lowercased()) {
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: file))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1600, height: 1600)
            guard let (cg, _) = try? await generator.image(at: .zero) else { return nil }
            return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
        }
        return NSImage(contentsOf: file)
    }

    // MARK: - Overlay + Core Animation

    private static func run(image: NSImage, from start: NSRect, to end: NSPoint, in frame: NSRect) {
        let panel = NSPanel(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false

        let host = NSView(frame: NSRect(origin: .zero, size: frame.size))
        host.wantsLayer = true
        panel.contentView = host
        panel.orderFrontRegardless()
        overlays.append(panel)

        // Convert global points into the overlay's coordinates.
        let local = { (p: NSPoint) in NSPoint(x: p.x - frame.minX, y: p.y - frame.minY) }
        let startCenter = local(NSPoint(x: start.midX, y: start.midY))
        let endCenter = local(end)

        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let scale = panel.backingScaleFactor

        let card = CALayer()
        card.contents = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
        card.contentsGravity = .resizeAspectFill
        card.contentsScale = scale
        card.bounds = CGRect(origin: .zero, size: start.size)
        card.position = startCenter
        card.cornerRadius = 10
        card.masksToBounds = true
        card.borderWidth = 2
        card.borderColor = NSColor.white.withAlphaComponent(0.9).cgColor

        // Shadow lives on a container so the card can clip its corners.
        let container = CALayer()
        container.bounds = card.bounds
        container.position = startCenter
        container.shadowColor = NSColor.black.cgColor
        container.shadowOpacity = 0.35
        container.shadowRadius = 18
        container.shadowOffset = CGSize(width: 0, height: -6)
        card.position = CGPoint(x: card.bounds.midX, y: card.bounds.midY)
        container.addSublayer(card)
        host.layer?.addSublayer(container)

        let finish = {
            panel.orderOut(nil)
            overlays.removeAll { $0 === panel }
        }

        if reduceMotion {
            let fade = CABasicAnimation(keyPath: "opacity")
            fade.fromValue = 1; fade.toValue = 0; fade.duration = 0.35
            container.opacity = 0
            CATransaction.begin()
            CATransaction.setCompletionBlock(finish)
            container.add(fade, forKey: "fade")
            CATransaction.commit()
            return
        }

        // Final chip size: ~72pt wide, keeping the aspect ratio.
        let chipWidth: CGFloat = 72
        let chipHeight = max(36, chipWidth * start.height / max(start.width, 1))
        let chip = CGSize(width: chipWidth, height: min(chipHeight, 90))

        let lift: CFTimeInterval = 0.12, fly: CFTimeInterval = 0.5, land: CFTimeInterval = 0.25
        let total = lift + fly + land

        // Arc: control point above the straight line, so the card rises then dives in.
        let mid = CGPoint(x: (startCenter.x + endCenter.x) / 2, y: max(startCenter.y, endCenter.y) + 140)
        let path = CGMutablePath()
        path.move(to: startCenter)
        path.addQuadCurve(to: endCenter, control: mid)

        let move = CAKeyframeAnimation(keyPath: "position")
        move.path = path
        move.beginTime = lift
        move.duration = fly
        move.timingFunction = CAMediaTimingFunction(controlPoints: 0.55, 0, 0.75, 0.6) // accelerate in
        move.fillMode = .both

        let liftScale = CABasicAnimation(keyPath: "transform.scale")
        liftScale.fromValue = 1; liftScale.toValue = 0.96
        liftScale.duration = lift
        liftScale.timingFunction = CAMediaTimingFunction(name: .easeOut)
        liftScale.fillMode = .forwards

        let shrink = CABasicAnimation(keyPath: "bounds.size")
        shrink.fromValue = NSValue(size: start.size)
        shrink.toValue = NSValue(size: chip)
        shrink.beginTime = lift
        shrink.duration = fly
        shrink.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        shrink.fillMode = .both

        let absorb = CABasicAnimation(keyPath: "transform.scale")
        absorb.fromValue = 0.96; absorb.toValue = 0.4
        absorb.beginTime = lift + fly
        absorb.duration = land
        absorb.timingFunction = CAMediaTimingFunction(name: .easeIn)
        absorb.fillMode = .forwards // .both would override the lift before it starts

        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1; fade.toValue = 0
        fade.beginTime = lift + fly
        fade.duration = land
        fade.fillMode = .forwards

        let group = CAAnimationGroup()
        group.animations = [move, liftScale, shrink, absorb, fade]
        group.duration = total
        group.fillMode = .forwards
        group.isRemovedOnCompletion = false

        // The card inside follows the container's size.
        let cardShrink = CABasicAnimation(keyPath: "bounds.size")
        cardShrink.fromValue = NSValue(size: start.size)
        cardShrink.toValue = NSValue(size: chip)
        cardShrink.beginTime = CACurrentMediaTime() + lift
        cardShrink.duration = fly
        cardShrink.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        cardShrink.fillMode = .both
        cardShrink.isRemovedOnCompletion = false
        let cardRecenter = CABasicAnimation(keyPath: "position")
        cardRecenter.fromValue = NSValue(point: NSPoint(x: start.width / 2, y: start.height / 2))
        cardRecenter.toValue = NSValue(point: NSPoint(x: chip.width / 2, y: chip.height / 2))
        cardRecenter.beginTime = cardShrink.beginTime
        cardRecenter.duration = fly
        cardRecenter.timingFunction = cardShrink.timingFunction
        cardRecenter.fillMode = .both
        cardRecenter.isRemovedOnCompletion = false

        // Landing ripple.
        let ring = CAShapeLayer()
        ring.path = CGPath(ellipseIn: CGRect(x: -20, y: -20, width: 40, height: 40), transform: nil)
        ring.position = endCenter
        ring.fillColor = NSColor.clear.cgColor
        ring.strokeColor = NSColor.controlAccentColor.cgColor
        ring.lineWidth = 3
        ring.opacity = 0
        host.layer?.addSublayer(ring)

        let ringScale = CABasicAnimation(keyPath: "transform.scale")
        ringScale.fromValue = 0.4; ringScale.toValue = 2.2
        let ringFade = CAKeyframeAnimation(keyPath: "opacity")
        ringFade.values = [0, 0.9, 0]
        ringFade.keyTimes = [0, 0.2, 1]
        let ringGroup = CAAnimationGroup()
        ringGroup.animations = [ringScale, ringFade]
        ringGroup.beginTime = CACurrentMediaTime() + lift + fly - 0.05
        ringGroup.duration = 0.45
        ringGroup.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ringGroup.fillMode = .both
        ringGroup.isRemovedOnCompletion = false

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            // The ring outlasts the card slightly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { finish() }
        }
        container.add(group, forKey: "flyIn")
        card.add(cardShrink, forKey: "shrink")
        card.add(cardRecenter, forKey: "recenter")
        ring.add(ringGroup, forKey: "ripple")
        CATransaction.commit()
    }
}
