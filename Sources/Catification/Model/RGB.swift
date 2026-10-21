import AppKit
import SwiftUI

/// sRGB colour that can be stored in settings and fed into the pixel renderer.
struct RGB: Codable, Hashable {
    var r: Double
    var g: Double
    var b: Double

    init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(hex: UInt32) {
        r = Double((hex >> 16) & 0xFF) / 255
        g = Double((hex >> 8) & 0xFF) / 255
        b = Double(hex & 0xFF) / 255
    }

    init(_ color: Color) {
        let ns = NSColor(color).usingColorSpace(.sRGB) ?? .gray
        r = Double(ns.redComponent)
        g = Double(ns.greenComponent)
        b = Double(ns.blueComponent)
    }

    var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: 1) }
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }

    func scaled(_ f: Double) -> RGB { RGB(r * f, g * f, b * f) }

    func mixed(with o: RGB, _ t: Double) -> RGB {
        RGB(r + (o.r - r) * t, g + (o.g - g) * t, b + (o.b - b) * t)
    }

    var bytes: (UInt8, UInt8, UInt8) {
        func c(_ v: Double) -> UInt8 { UInt8((min(1, max(0, v)) * 255).rounded()) }
        return (c(r), c(g), c(b))
    }
}
