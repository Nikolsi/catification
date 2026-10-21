import AppKit
import UniformTypeIdentifiers

/// `Catification --render-social <file.png>` draws the 1280×640 GitHub social preview:
/// a menu bar with the notch and portals, the title, and a row of cats on the floor.
/// Everything important stays inside the 40pt safe border GitHub recommends.
enum SocialPreviewRenderer {
    @MainActor
    static func run(to path: String) {
        let width = 1280, height = 640
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: PixelRenderer.colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return }
        let W = CGFloat(width), H = CGFloat(height)

        // Room: the same wall and floor as the demo recordings.
        let wall = CGGradient(colorsSpace: PixelRenderer.colorSpace,
                              colors: [RGB(hex: 0x3B3552).nsColor.cgColor, RGB(hex: 0x1F1D2A).nsColor.cgColor] as CFArray,
                              locations: [0, 1])!
        ctx.drawLinearGradient(wall, start: CGPoint(x: 0, y: H), end: .zero, options: [])
        let floor: CGFloat = 96
        ctx.setFillColor(RGB(hex: 0x6B4A35).nsColor.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: W, height: floor))
        ctx.setFillColor(RGB(hex: 0x8C6446).nsColor.cgColor)
        ctx.fill(CGRect(x: 0, y: floor - 6, width: W, height: 6))

        // Menu bar with the notch and the two portals.
        let barHeight: CGFloat = 44
        ctx.setFillColor(RGB(hex: 0x111116).nsColor.cgColor)
        ctx.fill(CGRect(x: 0, y: H - barHeight, width: W, height: barHeight))
        let notch = CGRect(x: W / 2 - 110, y: H - barHeight - 10, width: 220, height: barHeight + 20)
        ctx.addPath(CGPath(roundedRect: notch, cornerWidth: 18, cornerHeight: 18, transform: nil))
        ctx.setFillColor(CGColor(gray: 0, alpha: 1))
        ctx.fillPath()
        for (x, color) in [(notch.minX - 14, PortalLayer.blue), (notch.maxX + 14, PortalLayer.orange)] {
            let oval = CGRect(x: x - 6, y: H - barHeight + 4, width: 12, height: barHeight - 8)
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 10, color: color.cgColor)
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(3)
            ctx.strokeEllipse(in: oval)
            ctx.restoreGState()
            ctx.setFillColor(color.withAlphaComponent(0.35).cgColor)
            ctx.fillEllipse(in: oval)
        }

        ctx.interpolationQuality = .none
        func sheet(_ preset: CoatPreset) -> SpriteSheet {
            SpriteSheet(appearance: CatAppearance(fur: preset.fur, secondary: preset.secondary, belly: preset.belly,
                                                  eyes: preset.eyes, pattern: preset.pattern))
        }
        func drawCat(_ preset: CoatPreset, _ anim: Anim, frame: Int = 0, right: Bool = true, x: CGFloat, y: CGFloat, scale: CGFloat) {
            let image = sheet(preset).image(anim, frame, facingRight: right)
            let w = CGFloat(CatArt.W) * scale, h = CGFloat(CatArt.H) * scale
            ctx.draw(image, in: CGRect(x: (x - w / 2).rounded(), y: y.rounded(), width: w, height: h))
        }
        func drawSprite(_ sprite: EmoteArt.Sprite, x: CGFloat, y: CGFloat, scale: CGFloat) {
            ctx.draw(sprite.image, in: CGRect(x: x.rounded(), y: y.rounded(),
                                              width: CGFloat(sprite.width) * scale, height: CGFloat(sprite.height) * scale))
        }

        // Two little cats on the menu bar, one about to step into the blue portal.
        drawCat(.ginger, .walk, frame: 1, x: notch.minX - 70, y: H - barHeight, scale: 2)
        drawCat(.siamese, .walk, frame: 3, right: false, x: notch.maxX + 120, y: H - barHeight, scale: 2)

        // Title.
        func text(_ string: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, centerY: CGFloat) {
            var font = NSFont.systemFont(ofSize: size, weight: weight)
            if let rounded = font.fontDescriptor.withDesign(.rounded) { font = NSFont(descriptor: rounded, size: size) ?? font }
            let attributed = NSAttributedString(string: string, attributes: [.font: font, .foregroundColor: color])
            let line = CTLineCreateWithAttributedString(attributed)
            let bounds = CTLineGetBoundsWithOptions(line, .useOpticalBounds)
            ctx.textPosition = CGPoint(x: (W - bounds.width) / 2 - bounds.minX, y: centerY - bounds.height / 2 - bounds.minY)
            CTLineDraw(line, ctx)
        }
        text("Catification", size: 112, weight: .heavy, color: .white, centerY: 400)
        text("Tiny pixel cats that live on your Mac’s menu bar", size: 36, weight: .semibold,
             color: NSColor(srgbRed: 0.85, green: 0.82, blue: 0.95, alpha: 1), centerY: 305)

        // Cats on the floor, each doing its thing.
        let scale: CGFloat = 5, y = floor - 5
        drawCat(.ginger, .sit, x: 175, y: y, scale: scale)
        drawCat(.tuxedo, .walk, frame: 2, x: 390, y: y, scale: scale)
        drawCat(.gray, .crouchUp, x: 640, y: y, scale: scale)
        drawCat(.calico, .petted, x: 885, y: y, scale: scale)
        drawCat(.siamese, .sleep, frame: 1, right: false, x: 1105, y: y, scale: scale)

        // The grey one is working out a jump...
        let formulaColors = PixelFont.colors
        drawSprite(PixelFont.sprite("θ=45°", color: formulaColors[1]), x: 560, y: 228, scale: 3)
        drawSprite(PixelFont.sprite("√2gh", color: formulaColors[2]), x: 690, y: 208, scale: 3)
        // ...the calico is being loved, and the siamese is dreaming.
        if let heart = EmoteArt.sprites[.heart] {
            drawSprite(heart, x: 915, y: 196, scale: 4)
            drawSprite(heart, x: 860, y: 222, scale: 3)
        }
        if let z = EmoteArt.sprites[.zzz] {
            drawSprite(z, x: 1035, y: 160, scale: 3)
            drawSprite(z, x: 1010, y: 190, scale: 2)
        }

        guard let image = ctx.makeImage(),
              let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)
        else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
        print("Social preview written to \(path)")
    }
}
