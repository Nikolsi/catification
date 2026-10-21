import CoreGraphics

/// All animation frames of one cat appearance, pre-rendered in both directions.
final class SpriteSheet {
    static let width = CatArt.W
    static let height = CatArt.H

    private var right: [Anim: [CGImage]] = [:]
    private var left: [Anim: [CGImage]] = [:]
    private var boxes: [Anim: [CGRect]] = [:]

    init(appearance: CatAppearance) {
        let palette = CatPalette(appearance)
        for (anim, canvases) in CatArt.frames {
            right[anim] = canvases.map { PixelRenderer.image($0, color: palette.color) }
            left[anim] = canvases.map { PixelRenderer.image($0, flip: true, color: palette.color) }
            boxes[anim] = canvases.map { PixelRenderer.opaqueBounds($0) }
        }
    }

    func frameCount(_ anim: Anim) -> Int { right[anim]?.count ?? 1 }

    func image(_ anim: Anim, _ index: Int, facingRight: Bool) -> CGImage {
        let list = (facingRight ? right[anim] : left[anim])!
        return list[index % list.count]
    }

    /// Opaque area in sprite pixels, y up from the canvas bottom.
    func bounds(_ anim: Anim, _ index: Int, facingRight: Bool) -> CGRect {
        let list = boxes[anim]!
        let b = list[index % list.count]
        if facingRight { return b }
        return CGRect(x: CGFloat(Self.width) - b.maxX, y: b.minY, width: b.width, height: b.height)
    }

    @MainActor private static var cache: [CatAppearance: SpriteSheet] = [:]

    @MainActor static func cached(_ appearance: CatAppearance) -> SpriteSheet {
        if let sheet = cache[appearance] { return sheet }
        if cache.count > 48 { cache.removeAll() }
        let sheet = SpriteSheet(appearance: appearance)
        cache[appearance] = sheet
        return sheet
    }
}
