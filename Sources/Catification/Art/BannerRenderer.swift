import AppKit
import UniformTypeIdentifiers

/// `Catification --render-banner <file.gif>` renders an animated banner for the README:
/// every coat preset on a little menu-bar strip, each cycling through its animations.
enum BannerRenderer {
    private static let script: [(anim: Anim, seconds: Double)] = [
        (.walk, 1.6), (.sit, 1.2), (.petted, 1.4), (.groom, 1.2), (.crouchUp, 0.8), (.run, 1.2), (.sleep, 2.0), (.peek, 1.2),
    ]

    @MainActor
    static func run(to path: String) {
        let zoom = 4
        let fps = 12.0
        let presets = CoatPreset.all
        let cellW = CatArt.W * zoom, cellH = CatArt.H * zoom
        let padding = 12
        let width = presets.count * cellW + padding * 2
        let height = cellH + padding * 2
        let total = script.reduce(0) { $0 + $1.seconds }
        let frameCount = Int(total * fps)

        let sheets = presets.map {
            SpriteSheet(appearance: CatAppearance(fur: $0.fur, secondary: $0.secondary, belly: $0.belly, eyes: $0.eyes, pattern: $0.pattern))
        }

        guard let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.gif.identifier as CFString, frameCount, nil) else { return }
        CGImageDestinationSetProperties(dest, [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: 0]] as CFDictionary)
        let frameProperties = [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFDelayTime: 1 / fps]] as CFDictionary

        for frame in 0..<frameCount {
            guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: PixelRenderer.colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            ctx.interpolationQuality = .none
            ctx.setFillColor(RGB(hex: 0x23252B).nsColor.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.setFillColor(RGB(hex: 0x3A3D45).nsColor.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: padding))

            for (i, sheet) in sheets.enumerated() {
                // Offset each cat so they don't all do the same thing at once.
                let t = (Double(frame) / fps + Double(i) * 0.9).truncatingRemainder(dividingBy: total)
                let (anim, local) = step(t)
                let image = sheet.image(anim, Int(local * anim.fps) % sheet.frameCount(anim), facingRight: i % 2 == 0)
                ctx.draw(image, in: CGRect(x: padding + i * cellW, y: padding, width: cellW, height: cellH))
            }
            if let image = ctx.makeImage() { CGImageDestinationAddImage(dest, image, frameProperties) }
        }
        CGImageDestinationFinalize(dest)
        print("Banner written to \(path)")
    }

    private static func step(_ time: Double) -> (Anim, Double) {
        var t = time
        for item in script {
            if t < item.seconds { return (item.anim, t) }
            t -= item.seconds
        }
        return (.stand, 0)
    }
}
