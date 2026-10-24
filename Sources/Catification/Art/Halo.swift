import QuartzCore

/// How cats, furniture and toys stand out from busy menu bars and bright wallpapers.
enum Standout: String, Codable, CaseIterable, Identifiable {
    case off, shadow, lightSticker, sticker, glow

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: L("Off")
        case .shadow: L("Soft shadow")
        case .lightSticker: L("Light sticker")
        case .sticker: L("Sticker")
        case .glow: L("Glow")
        }
    }

    /// A light ring one sprite pixel wide around the silhouette.
    fileprivate var ring: (alpha: CGFloat, diagonals: Bool)? {
        switch self {
        case .lightSticker: (0.5, false)
        case .sticker: (0.92, true)
        default: nil
        }
    }

    /// A soft shadow (or glow) behind the sprite, in sprite pixels.
    fileprivate var shadow: (color: CGColor, opacity: Float, radius: CGFloat, dy: CGFloat)? {
        switch self {
        case .off: nil
        case .shadow: (CGColor(gray: 0, alpha: 1), 0.75, 2.5, -0.5)
        case .lightSticker: (CGColor(gray: 0, alpha: 1), 0.55, 2, -0.5)
        case .sticker: (CGColor(gray: 0, alpha: 1), 0.35, 1.5, 0)
        case .glow: (CGColor(gray: 1, alpha: 1), 0.9, 3, 0)
        }
    }
}

/// A ring and a shadow drawn behind a sprite layer, so the sprite itself and its geometry stay as
/// they are. Rings are worked out once per sprite image and cached; shadows are Core Animation's.
@MainActor
final class HaloLayer {
    private let ring = CALayer()
    private var shownImage: CGImage?
    private var shownStyle: Standout?
    private weak var shadowed: CALayer?

    init() {
        ring.magnificationFilter = .nearest
        ring.minificationFilter = .nearest
        ring.disableImplicitAnimations()
        ring.isHidden = true
    }

    /// Call after the sprite layer has its contents, bounds and position for this frame.
    func update(behind sprite: CALayer, image: CGImage?, pixel: CGFloat, style: Standout, visible: Bool = true) {
        if ring.superlayer == nil, let parent = sprite.superlayer { parent.addSublayer(ring) }
        let ringStyle = style.ring
        let showRing = visible && ringStyle != nil && image != nil && !sprite.isHidden
        ring.isHidden = !showRing
        if showRing, let image, let ringStyle {
            if image !== shownImage || style != shownStyle {
                ring.contents = Self.ring(of: image, alpha: ringStyle.alpha, diagonals: ringStyle.diagonals)
                shownImage = image
            }
            let b = sprite.bounds, a = sprite.anchorPoint
            let size = CGSize(width: b.width + 2 * pixel, height: b.height + 2 * pixel)
            let origin = CGPoint(x: sprite.position.x - a.x * b.width - pixel, y: sprite.position.y - a.y * b.height - pixel)
            ring.anchorPoint = a
            ring.bounds = CGRect(origin: .zero, size: size)
            ring.position = CGPoint(x: origin.x + a.x * size.width, y: origin.y + a.y * size.height)
            ring.zPosition = sprite.zPosition - 0.01
        }
        // The shadow goes behind the ring when there is one, otherwise behind the sprite.
        let target = showRing ? ring : sprite
        if style != shownStyle || target !== shadowed {
            for l in [ring, sprite] { l.shadowOpacity = 0 }
            if let s = style.shadow {
                target.shadowColor = s.color
                target.shadowOpacity = s.opacity
                target.shadowRadius = s.radius * pixel
                target.shadowOffset = CGSize(width: 0, height: s.dy * pixel)
            }
            shownStyle = style
            shadowed = target
        }
    }

    func remove() {
        ring.removeFromSuperlayer()
    }

    // MARK: Rings

    private struct Key: Hashable {
        let image: ObjectIdentifier
        let alpha: Int
        let diagonals: Bool
    }

    private static var cache: [Key: (source: CGImage, ring: CGImage)] = [:]

    /// The sprite's silhouette grown by one pixel and filled with a translucent white.
    static func ring(of image: CGImage, alpha: CGFloat, diagonals: Bool) -> CGImage {
        let key = Key(image: ObjectIdentifier(image), alpha: Int(alpha * 100), diagonals: diagonals)
        if let hit = cache[key], hit.source === image { return hit.ring }
        if cache.count > 600 { cache.removeAll() }

        let w = image.width, h = image.height
        var source = [UInt8](repeating: 0, count: w * h * 4)
        source.withUnsafeMutableBytes { buffer in
            let ctx = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: PixelRenderer.colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        let ow = w + 2, oh = h + 2
        var out = [UInt8](repeating: 0, count: ow * oh * 4)
        let level = UInt8(min(255, max(0, alpha * 255)))
        let neighbours = diagonals
            ? [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, 1), (1, -1), (-1, -1)]
            : [(0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)]
        for oy in 0..<oh {
            for ox in 0..<ow {
                let filled = neighbours.contains { dx, dy in
                    let sx = ox - 1 + dx, sy = oy - 1 + dy
                    return sx >= 0 && sy >= 0 && sx < w && sy < h && source[(sy * w + sx) * 4 + 3] > 127
                }
                guard filled else { continue }
                let i = (oy * ow + ox) * 4
                // Premultiplied white.
                out[i] = level; out[i + 1] = level; out[i + 2] = level; out[i + 3] = level
            }
        }
        let provider = CGDataProvider(data: Data(out) as CFData)!
        let ring = CGImage(width: ow, height: oh, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: ow * 4,
                           space: PixelRenderer.colorSpace, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                           provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
        cache[key] = (image, ring)
        return ring
    }
}
