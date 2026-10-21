import AppKit
import UniformTypeIdentifiers

/// `Catification --render-icon <dir.iconset>` draws the app icon (a pixel cat head on a warm
/// rounded square) at every size `iconutil` expects.
enum IconRenderer {
    @MainActor
    static func run(to directory: String) {
        let url = URL(fileURLWithPath: directory)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        for points in [16, 32, 128, 256, 512] {
            for scale in [1, 2] {
                let suffix = scale == 2 ? "@2x" : ""
                write(render(size: points * scale), to: url.appendingPathComponent("icon_\(points)x\(points)\(suffix).png"))
            }
        }
        print("Icon written to \(directory)")
    }

    private static func render(size: Int) -> CGImage {
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                            space: PixelRenderer.colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        let s = CGFloat(size)
        // Apple's grid: the body takes about 80% of the canvas, with room for the shadow.
        let body = CGRect(x: s * 0.1, y: s * 0.1, width: s * 0.8, height: s * 0.8)
        let path = CGPath(roundedRect: body, cornerWidth: s * 0.18, cornerHeight: s * 0.18, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.03, color: CGColor(gray: 0, alpha: 0.35))
        ctx.addPath(path)
        ctx.setFillColor(RGB(hex: 0xF6A55B).nsColor.cgColor)
        ctx.fillPath()
        ctx.restoreGState()

        ctx.saveGState()
        ctx.addPath(path)
        ctx.clip()
        let gradient = CGGradient(colorsSpace: PixelRenderer.colorSpace,
                                  colors: [RGB(hex: 0xFFE8BF).nsColor.cgColor, RGB(hex: 0xF7A85E).nsColor.cgColor] as CFArray,
                                  locations: [0, 1])!
        ctx.drawLinearGradient(gradient, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])
        ctx.restoreGState()

        // The cat head, scaled by a whole number so pixels stay square and crisp.
        var canvas = PixelCanvas(width: 11, height: 9)
        canvas.draw(CatArt.head(.open), at: 1, 1, kind: .head, outline: .hard)
        let g = CoatPreset.ginger
        let palette = CatPalette(CatAppearance(fur: g.fur, secondary: g.secondary, belly: g.belly, eyes: g.eyes, pattern: g.pattern))
        let head = PixelRenderer.image(canvas, color: palette.color)
        let scale = max(1, Int((body.width * 0.72) / CGFloat(canvas.width)))
        let w = canvas.width * scale, h = canvas.height * scale
        ctx.interpolationQuality = .none
        ctx.draw(head, in: CGRect(x: (size - w) / 2, y: (size - h) / 2 - size / 40, width: w, height: h))
        return ctx.makeImage()!
    }

    private static func write(_ image: CGImage, to url: URL) {
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
