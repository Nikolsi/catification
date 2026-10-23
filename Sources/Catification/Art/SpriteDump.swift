import AppKit
import UniformTypeIdentifiers

/// `Catification --dump-sprites out.png` renders every animation of every coat preset
/// into one enlarged sheet. Handy when tweaking the pixel art.
enum SpriteDump {
    @MainActor
    static func run(to path: String) {
        let anims = Anim.allCases
        let presets = CoatPreset.all
        let zoom = 6
        let cellW = CatArt.W * zoom, cellH = CatArt.H * zoom
        let columns = anims.reduce(0) { $0 + CatArt.frames[$1]!.count }
        let width = columns * cellW, height = presets.count * cellH * 2 + 300

        guard let ctx = CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: PixelRenderer.colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return }
        ctx.interpolationQuality = .none

        for (row, preset) in presets.enumerated() {
            let appearance = CatAppearance(fur: preset.fur, secondary: preset.secondary, belly: preset.belly, eyes: preset.eyes, pattern: preset.pattern)
            let sheet = SpriteSheet(appearance: appearance)
            // Each preset twice: on a light and on a dark "menu bar".
            for (variant, bg) in [RGB(hex: 0xE9E9EC), RGB(hex: 0x2A2A2E)].enumerated() {
                let y = height - (row * 2 + variant + 1) * cellH
                ctx.setFillColor(bg.nsColor.cgColor)
                ctx.fill(CGRect(x: 0, y: y, width: width, height: cellH))
                var col = 0
                for anim in anims {
                    for i in 0..<sheet.frameCount(anim) {
                        let img = sheet.image(anim, i, facingRight: true)
                        ctx.draw(img, in: CGRect(x: col * cellW, y: y, width: cellW, height: cellH))
                        col += 1
                    }
                }
            }
        }

        // Props, formulas and emotes along the bottom.
        let extras: [CGImage] = [
            PropArt.shelf(width: 30).image, PropArt.post(height: 40).image, PropArt.bed(front: false).image,
            PropArt.bowl(food: 2).image, PropArt.bowl(food: 1).image, PropArt.bowl(food: 0).image,
            PropArt.trash(front: false).image, PropArt.trash(front: true).image, PropArt.yarn(frame: 0).image,
            PropArt.box(front: false).image, PropArt.laundry(front: false).image,
            PropArt.flowerPot(squashed: false, front: false).image, PropArt.flowerPot(squashed: true, front: false).image,
            PropArt.wardrobe(front: false).image,
            PixelFont.sprite("Δx=137", color: PixelFont.colors[1]).image, PixelFont.sprite("θ=45°", color: PixelFont.colors[2]).image,
            PixelFont.sprite("√2gh", color: PixelFont.colors[0]).image, PixelFont.sprite("x²+y²", color: PixelFont.colors[3]).image,
        ] + [EmoteKind.question, .check, .fish, .target, .paper, .bone].compactMap { EmoteArt.sprites[$0]?.image }
        ctx.setFillColor(RGB(hex: 0x3A3F4A).nsColor.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: 300))
        var px = 10
        for img in extras {
            ctx.draw(img, in: CGRect(x: px, y: 10, width: img.width * zoom, height: img.height * zoom))
            px += img.width * zoom + 20
        }

        guard let image = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        print("Sprites written to \(path)")
    }
}
