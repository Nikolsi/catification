import AppKit
import QuartzCore

/// A ball of yarn: rolls along surfaces, falls off edges, bounces.
@MainActor
final class Ball {
    let layer = CALayer()
    let pixel: CGFloat
    var x: CGFloat
    var y: CGFloat
    var vx: CGFloat = 0
    var vy: CGFloat = 0
    var surface: SurfaceID?
    var held = false
    private var roll: CGFloat = 0
    private var shownFrame = -1

    var speed: CGFloat { hypot(vx, vy) }
    var size: CGFloat { CGFloat(PropArt.yarnSize + 2) * pixel }
    var hitRect: CGRect { CGRect(x: x - size / 2, y: y - pixel, width: size, height: size).insetBy(dx: -4, dy: -4) }

    init(x: CGFloat, y: CGFloat, pixel: CGFloat) {
        self.x = x
        self.y = y
        self.pixel = pixel
        layer.anchorPoint = CGPoint(x: 0.5, y: 0)
        layer.magnificationFilter = .nearest
        layer.zPosition = 14
        layer.disableImplicitAnimations()
    }

    func update(dt: Double, world: CatWorld) {
        guard !held else { return }
        let d = CGFloat(dt)
        let edge = size / 2
        if let id = surface {
            guard let s = world.surface(id), s.segmentIndex(containing: x, tolerance: 1) != nil else {
                surface = nil
                return
            }
            y = s.y
            vx *= CGFloat(exp(-dt * 0.9))
            if abs(vx) < 4 { vx = 0 }
            x += vx * d
        } else {
            let previousY = y
            vy -= Cat.gravity * d
            x += vx * d
            y += vy * d
            if y > world.geo.height - size {
                y = world.geo.height - size
                vy = -abs(vy) * 0.5
            }
            if vy <= 0, let s = world.landingSurface(x: x, from: previousY, to: y, ignoring: nil) {
                y = s.y
                if -vy > 160 {
                    vy = -vy * 0.45
                    vx *= 0.85
                } else {
                    vy = 0
                    surface = s.id
                }
            }
            if y < -size, let rescue = world.surfaceAbove(x: x, y: y) {
                y = rescue + 30
                vy = 0
            }
        }
        if x < edge {
            x = edge
            vx = abs(vx) * 0.6
        }
        if x > world.geo.width - edge {
            x = world.geo.width - edge
            vx = -abs(vx) * 0.6
        }
        roll += vx * d
    }

    func ride(dx: CGFloat, toY newY: CGFloat) {
        x += dx
        y = newY
    }

    func sync() {
        let frame = Int(abs(roll) / (pixel * 3)) % 3
        if frame != shownFrame {
            let art = PropArt.yarn(frame: frame)
            layer.contents = art.image
            layer.bounds = CGRect(x: 0, y: 0, width: CGFloat(art.width) * pixel, height: CGFloat(art.height) * pixel)
            shownFrame = frame
        }
        // The yarn's lowest pixel is one row above the canvas bottom.
        layer.position = CGPoint(x: (x * 2).rounded() / 2, y: ((y - pixel) * 2).rounded() / 2)
    }
}

/// A cat working out a jump: a dotted parabola drawn bit by bit, and a target mark.
@MainActor
final class CalculationFX {
    private let dots = CAShapeLayer()
    private let marker = CALayer()
    private let points: [CGPoint]
    private(set) var fading = false
    private var opacity: Float = 1

    init(points: [CGPoint], target: CGPoint, pixel: CGFloat, scale: CGFloat, root: CALayer) {
        self.points = points
        dots.disableImplicitAnimations()
        dots.contentsScale = scale
        dots.fillColor = NSColor(white: 1, alpha: 0.85).cgColor
        dots.strokeColor = NSColor(srgbRed: 0.08, green: 0.12, blue: 0.24, alpha: 0.8).cgColor
        dots.lineWidth = 1
        dots.zPosition = 45
        root.addSublayer(dots)

        if let sprite = EmoteArt.sprites[.target] {
            let p = max(1, pixel - 0.5)
            marker.disableImplicitAnimations()
            marker.contents = sprite.image
            marker.magnificationFilter = .nearest
            marker.bounds = CGRect(x: 0, y: 0, width: CGFloat(sprite.width) * p, height: CGFloat(sprite.height) * p)
            marker.position = target
            marker.zPosition = 46
            marker.opacity = 0
            root.addSublayer(marker)
            let pulse = CABasicAnimation(keyPath: "transform.scale")
            pulse.fromValue = 0.8
            pulse.toValue = 1.2
            pulse.duration = 0.35
            pulse.autoreverses = true
            pulse.repeatCount = .infinity
            marker.add(pulse, forKey: "pulse")
        }
    }

    func reveal(_ progress: Double) {
        let count = min(points.count, Int(Double(points.count) * min(1, progress * 1.2)))
        let path = CGMutablePath()
        for p in points.prefix(count) {
            path.addRect(CGRect(x: (p.x * 2).rounded() / 2 - 1.25, y: (p.y * 2).rounded() / 2 - 1.25, width: 2.5, height: 2.5))
        }
        dots.path = path
        marker.opacity = progress > 0.75 ? 1 : 0
    }

    func fadeOut() {
        if !fading { reveal(1) }
        fading = true
    }

    /// Returns false once it has faded away.
    func update(dt: Double) -> Bool {
        guard fading else { return true }
        opacity -= Float(dt / 0.5)
        dots.opacity = max(0, opacity)
        marker.opacity = max(0, opacity)
        return opacity > 0
    }

    func remove() {
        dots.removeFromSuperlayer()
        marker.removeFromSuperlayer()
    }
}

/// Runtime state of a loose object (bed or bowl): it falls until it rests on something.
struct PropBody {
    var x: CGFloat
    var y: CGFloat
    var vy: CGFloat = 0
    var surface: SurfaceID?
    var held = false
}

/// Layers for one piece of furniture, plus its outline in arrange mode.
@MainActor
final class FurnitureView {
    let main = CALayer()
    /// The front rim of a bed, drawn over a cat sleeping in it.
    let front = CALayer()
    let outline = CAShapeLayer()
    private var key = ""
    private(set) var frame: CGRect = .zero

    init(root: CALayer) {
        for l in [main, front] {
            l.anchorPoint = .zero
            l.magnificationFilter = .nearest
            l.disableImplicitAnimations()
            root.addSublayer(l)
        }
        front.isHidden = true
        outline.disableImplicitAnimations()
        outline.fillColor = NSColor(srgbRed: 0.4, green: 0.85, blue: 1, alpha: 0.08).cgColor
        outline.strokeColor = NSColor(srgbRed: 0.4, green: 0.85, blue: 1, alpha: 0.95).cgColor
        outline.lineWidth = 1.5
        outline.lineDashPattern = [5, 3]
        outline.zPosition = 48
        outline.isHidden = true
        root.addSublayer(outline)
    }

    func update(art: PropArt.Art, front frontArt: PropArt.Art?, origin: CGPoint, pixel: CGFloat, z: CGFloat, key newKey: String) {
        if newKey != key {
            main.contents = art.image
            front.contents = frontArt?.image
            front.isHidden = frontArt == nil
            key = newKey
        }
        let size = CGSize(width: CGFloat(art.width) * pixel, height: CGFloat(art.height) * pixel)
        let o = CGPoint(x: (origin.x * 2).rounded() / 2, y: (origin.y * 2).rounded() / 2)
        main.bounds = CGRect(origin: .zero, size: size)
        main.position = o
        main.zPosition = z
        front.bounds = main.bounds
        front.position = o
        front.zPosition = 8
        frame = CGRect(origin: o, size: size)
    }

    func showOutline(_ show: Bool, handles: [CGRect]) {
        outline.isHidden = !show
        guard show else { return }
        let path = CGMutablePath()
        path.addRect(frame.insetBy(dx: -3, dy: -3))
        for h in handles { path.addRect(h) }
        outline.path = path
    }

    func remove() {
        main.removeFromSuperlayer()
        front.removeFromSuperlayer()
        outline.removeFromSuperlayer()
    }
}
