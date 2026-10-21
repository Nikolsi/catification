import AppKit

/// Where the cats live. In menu bar mode that is a strip along the menu bar plus some room below
/// for carrying cats around; in the full-screen modes it is the whole screen.
struct WorldGeometry: Equatable {
    var mode: WorldMode
    /// Overlay panel frame in screen coordinates.
    var frame: NSRect
    var menuBarHeight: CGFloat
    /// The bottom edge of the menu bar in panel coordinates.
    var menuBarY: CGFloat
    /// The floor: the bottom of the screen; nil in menu bar mode.
    var groundY: CGFloat?
    /// Horizontal span hidden by the camera notch, in panel coordinates.
    var notch: ClosedRange<CGFloat>?

    var width: CGFloat { frame.width }
    var height: CGFloat { frame.height }

    static let carryRoom: CGFloat = 260

    @MainActor
    static func current(mode: WorldMode, virtualNotch: Bool) -> WorldGeometry {
        let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let sf = screen.frame
        let insetTop = screen.safeAreaInsets.top

        var menuBar = sf.maxY - screen.visibleFrame.maxY
        if insetTop > 0 { menuBar = max(menuBar, insetTop) }
        if menuBar < 12 { menuBar = 24 }

        let frame: NSRect
        let ground: CGFloat?
        if mode == .menuBar {
            frame = NSRect(x: sf.minX, y: sf.maxY - menuBar - carryRoom, width: sf.width, height: menuBar + carryRoom)
            ground = nil
        } else {
            frame = sf
            // The Dock only covers the middle of the bottom edge and its real extent isn't public,
            // so the floor is simply the bottom of the screen.
            ground = 0
        }

        var notch: ClosedRange<CGFloat>?
        if insetTop > 0, let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
            let lo = left.width, hi = sf.width - right.width
            if hi > lo { notch = lo...hi }
        }
        if notch == nil, virtualNotch {
            notch = (sf.width / 2 - 70)...(sf.width / 2 + 70)
        }

        return WorldGeometry(
            mode: mode, frame: frame, menuBarHeight: menuBar,
            menuBarY: frame.height - menuBar, groundY: ground, notch: notch
        )
    }

    /// Points per sprite pixel, snapped to half points so the art stays crisp on Retina.
    func pixel(for size: CatSize) -> CGFloat {
        let base = menuBarHeight * 0.74 / 14
        return max(1, (base * size.factor * 2).rounded() / 2)
    }

    /// Pixel scale for furniture: the same as a normal-sized cat.
    var furniturePixel: CGFloat { pixel(for: .normal) }
}
