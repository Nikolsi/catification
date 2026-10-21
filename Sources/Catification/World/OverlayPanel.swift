import AppKit

/// Transparent, click-through panel that floats above the menu bar on every Space.
final class OverlayPanel: NSPanel {
    init(frame: NSRect) {
        super.init(contentRect: frame, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        ignoresMouseEvents = true
        isMovable = false
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    // Borderless windows may still get pushed below the menu bar; we want to cover it.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

final class WorldView: NSView {
    weak var world: CatWorld?

    override var isFlipped: Bool { false }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    private func point(_ e: NSEvent) -> CGPoint { convert(e.locationInWindow, from: nil) }

    override func mouseDown(with event: NSEvent) { world?.mouseDown(at: point(event)) }
    override func mouseDragged(with event: NSEvent) { world?.mouseDragged(at: point(event)) }
    override func mouseUp(with event: NSEvent) { world?.mouseUp(at: point(event)) }
    override func rightMouseDown(with event: NSEvent) { world?.rightMouseDown(at: point(event), event: event, in: self) }
}

extension CALayer {
    /// Standalone layers animate every property change by default; the world moves
    /// things 60 times a second by itself, so implicit animations only get in the way.
    func disableImplicitAnimations() {
        let none = NSNull()
        actions = [
            "position": none, "bounds": none, "frame": none, "contents": none, "hidden": none,
            "zPosition": none, "opacity": none, "transform": none, "mask": none, "sublayers": none,
        ]
    }
}
