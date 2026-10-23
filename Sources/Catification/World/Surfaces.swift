import AppKit

enum SurfaceID: Hashable {
    case menuBar
    case ground
    case shelf(UUID)
    case perch(UUID)
    case window(Int)
    case icon(String)
    /// The top of a tall piece of furniture (the wardrobe).
    case top(UUID)

    var isWindow: Bool {
        if case .window = self { return true }
        return false
    }

    /// Belongs to something outside our control that can move or vanish (windows, desktop icons).
    var isDynamic: Bool {
        switch self {
        case .window, .icon: true
        default: false
        }
    }
}

/// Something a cat can stand on: a horizontal line, possibly broken into several pieces
/// (a window edge partly covered by other windows).
struct Surface {
    let id: SurfaceID
    var y: CGFloat
    var segments: [ClosedRange<CGFloat>]
    /// Tracks movement: when the anchor of a surface shifts, everything standing on it rides along.
    var anchor: CGPoint

    func segmentIndex(containing x: CGFloat, tolerance: CGFloat = 0) -> Int? {
        segments.firstIndex { x >= $0.lowerBound - tolerance && x <= $0.upperBound + tolerance }
    }

    func nearestSegmentIndex(to x: CGFloat) -> Int? {
        segments.indices.min {
            distance(x, segments[$0]) < distance(x, segments[$1])
        }
    }

    private func distance(_ x: CGFloat, _ r: ClosedRange<CGFloat>) -> CGFloat {
        x < r.lowerBound ? r.lowerBound - x : (x > r.upperBound ? x - r.upperBound : 0)
    }
}

/// A scratching post: cats can climb between the floor and its perch.
struct ClimbLink {
    let post: UUID
    let x: CGFloat
    let bottom: SurfaceID
    let top: SurfaceID
}

/// Polls the window list so cats can walk on top of other apps' windows.
/// Only window bounds are used, which needs no special permission.
@MainActor
final class WindowTracker {
    struct Window {
        let id: Int
        /// In panel coordinates.
        let frame: CGRect
    }

    private(set) var windows: [Window] = []
    private var lastPoll: CFTimeInterval = -10

    func clear() {
        windows = []
        lastPoll = -10
    }

    func update(now: CFTimeInterval, interval: Double, panelFrame: CGRect) {
        guard now - lastPoll >= interval else { return }
        lastPoll = now
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return
        }
        // Window bounds come in a top-left-origin space anchored at the primary display.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? panelFrame.height
        var result: [Window] = []
        for info in list {
            guard (info[kCGWindowLayer as String] as? Int) == 0,
                  (info[kCGWindowAlpha as String] as? Double ?? 1) > 0.05,
                  let boundsDict = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  let number = info[kCGWindowNumber as String] as? Int
            else { continue }
            let frame = CGRect(
                x: bounds.minX - panelFrame.minX,
                y: primaryHeight - bounds.maxY - panelFrame.minY,
                width: bounds.width,
                height: bounds.height
            )
            result.append(Window(id: number, frame: frame))
        }
        windows = result
    }

    /// Visible parts of window top edges. `windows` is ordered front to back, so each edge is
    /// cut wherever a window in front of it covers the space a cat would occupy.
    func surfaces(width: CGFloat, below ceiling: CGFloat, above floor: CGFloat, clearance: CGFloat) -> [Surface] {
        var result: [Surface] = []
        for (i, w) in windows.enumerated() {
            guard w.frame.width >= 160, w.frame.height >= 80 else { continue }
            let y = w.frame.maxY
            guard y < ceiling - 8, y > floor + 30 else { continue }
            var segments: [ClosedRange<CGFloat>] = []
            let lo = max(w.frame.minX, 0), hi = min(w.frame.maxX, width)
            if hi > lo { segments = [lo...hi] }
            for front in windows[..<i] where front.frame.minY < y + clearance && front.frame.maxY > y - 2 {
                segments = Self.subtract(front.frame.minX...front.frame.maxX, from: segments)
                if segments.isEmpty { break }
            }
            segments = segments.filter { $0.upperBound - $0.lowerBound >= 44 }
            if !segments.isEmpty {
                result.append(Surface(id: .window(w.id), y: y, segments: segments, anchor: CGPoint(x: w.frame.minX, y: y)))
            }
        }
        return result
    }

    private static func subtract(_ cut: ClosedRange<CGFloat>, from segments: [ClosedRange<CGFloat>]) -> [ClosedRange<CGFloat>] {
        var out: [ClosedRange<CGFloat>] = []
        for s in segments {
            if cut.upperBound <= s.lowerBound || cut.lowerBound >= s.upperBound {
                out.append(s)
                continue
            }
            if cut.lowerBound > s.lowerBound { out.append(s.lowerBound...cut.lowerBound) }
            if cut.upperBound < s.upperBound { out.append(cut.upperBound...s.upperBound) }
        }
        return out
    }
}
