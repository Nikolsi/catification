import SwiftUI

/// Demo recordings drive the cat editor with a drawn cursor, so they need to find its controls
/// on screen. Views marked with `demoTarget` can be looked up by name; outside a demo the
/// modifier does nothing.
@MainActor
enum DemoTargets {
    static var enabled = false
    fileprivate static var views: [String: WeakView] = [:]

    /// The marked view, while it's on screen.
    static func view(_ name: String) -> NSView? {
        guard let view = views[name]?.view, view.window != nil else { return nil }
        return view
    }

    /// Where the marked view is, in global screen coordinates.
    static func frame(_ name: String) -> CGRect? {
        guard let view = view(name), let window = view.window else { return nil }
        return window.convertToScreen(view.convert(view.bounds, to: nil))
    }
}

fileprivate final class WeakView {
    weak var view: NSView?
    init(_ view: NSView) { self.view = view }
}

private struct DemoTargetView: NSViewRepresentable {
    let name: String

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DemoTargets.views[name] = WeakView(view)
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {
        DemoTargets.views[name] = WeakView(view)
    }
}

extension View {
    @ViewBuilder
    func demoTarget(_ name: String) -> some View {
        if DemoTargets.enabled {
            background(DemoTargetView(name: name))
        } else {
            self
        }
    }
}
