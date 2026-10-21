import AppKit
import ApplicationServices

/// Reads where Finder's desktop icons are, through the Accessibility API, so cats can climb them.
/// Needs the Accessibility permission; without it there are simply no icons.
@MainActor
final class DesktopIconTracker {
    struct Icon {
        let name: String
        /// Icon frame in panel coordinates.
        let frame: CGRect
    }

    private(set) var icons: [Icon] = []
    private var lastPoll: CFTimeInterval = -10

    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that leads to System Settings → Privacy → Accessibility.
    static func requestAccess() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }

    func clear() {
        icons = []
        lastPoll = -10
    }

    func update(now: CFTimeInterval, interval: Double, panelFrame: CGRect) {
        guard now - lastPoll >= interval else { return }
        lastPoll = now
        guard Self.isTrusted,
              let finder = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.finder").first
        else {
            icons = []
            return
        }
        let app = AXUIElementCreateApplication(finder.processIdentifier)
        // Never let a busy Finder stall the animation for long.
        AXUIElementSetMessagingTimeout(app, 0.2)

        var found: [(String, CGRect)] = []
        collect(app, depth: 0, onDesktop: false, into: &found)

        // Accessibility frames use a top-left origin anchored at the primary display.
        let primaryHeight = NSScreen.screens.first?.frame.height ?? panelFrame.height
        icons = found.map { name, r in
            Icon(name: name, frame: CGRect(x: r.minX - panelFrame.minX, y: primaryHeight - r.maxY - panelFrame.minY,
                                           width: r.width, height: r.height))
        }
    }

    /// The desktop is an AXScrollArea of the Finder application; icons are AXImage elements in it.
    /// Finder windows and the menu bar are skipped, they're big and not what we want.
    private func collect(_ element: AXUIElement, depth: Int, onDesktop: Bool, into result: inout [(String, CGRect)]) {
        guard depth <= 5 else { return }
        let role = string(element, kAXRoleAttribute) ?? ""
        if role == kAXWindowRole || role == kAXMenuBarRole { return }
        let desktop = onDesktop || role == kAXScrollAreaRole
        if desktop, role == kAXImageRole, let frame = frame(element), frame.width > 8, frame.height > 8 {
            result.append((string(element, kAXTitleAttribute) ?? "\(result.count)", frame))
            return
        }
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else { return }
        for child in children {
            collect(child, depth: depth + 1, onDesktop: desktop, into: &result)
        }
    }

    private func string(_ e: AXUIElement, _ attribute: String) -> String? {
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(e, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func frame(_ e: AXUIElement) -> CGRect? {
        var p: AnyObject?, s: AnyObject?
        guard AXUIElementCopyAttributeValue(e, kAXPositionAttribute as CFString, &p) == .success,
              AXUIElementCopyAttributeValue(e, kAXSizeAttribute as CFString, &s) == .success,
              let pv = p, let sv = s else { return nil }
        var point = CGPoint.zero, size = CGSize.zero
        AXValueGetValue(pv as! AXValue, .cgPoint, &point)
        AXValueGetValue(sv as! AXValue, .cgSize, &size)
        return CGRect(origin: point, size: size)
    }

    /// The top of every icon that no window covers is a tiny ledge.
    func surfaces(covering windows: [WindowTracker.Window], clearance: CGFloat) -> [Surface] {
        icons.compactMap { icon in
            let r = icon.frame
            let top = r.maxY
            let band = CGRect(x: r.minX, y: top - 2, width: r.width, height: clearance + 2)
            guard !windows.contains(where: { $0.frame.intersects(band) }) else { return nil }
            let inset = min(6, r.width / 4)
            return Surface(id: .icon(icon.name), y: top, segments: [(r.minX + inset)...(r.maxX - inset)],
                           anchor: CGPoint(x: r.minX, y: top))
        }
    }
}
