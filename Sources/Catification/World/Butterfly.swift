import AppKit
import QuartzCore

/// A butterfly that flutters around, rests on things now and then, and dodges cats.
@MainActor
final class Butterfly {
    let id = UUID()
    let layer = CALayer()
    private(set) var x: CGFloat
    /// Bottom of the sprite.
    private(set) var y: CGFloat
    private var vx: CGFloat = 0
    private var vy: CGFloat = 0
    private var target: CGPoint
    private var resting = false
    private var restTime = 0.0
    private var age = 0.0
    private let lifetime = Double.random(in: 35...70)
    private var startled = 0.0
    private var flap = Double.random(in: 0...1)
    private let sprites: (open: EmoteArt.Sprite, closed: EmoteArt.Sprite)
    private let pixel: CGFloat
    private var shownOpen: Bool?
    private(set) var gone = false

    var point: CGPoint { CGPoint(x: x, y: y) }
    var isLeaving: Bool { age > lifetime }

    private static let palettes: [(wing: RGB, spot: RGB)] = [
        (RGB(hex: 0xFF9A2E), RGB(hex: 0x3A2A1E)),
        (RGB(hex: 0x6FC3FF), RGB(hex: 0x1F4E8C)),
        (RGB(hex: 0xFFE066), RGB(hex: 0xE38B2C)),
        (RGB(hex: 0xFF9ED2), RGB(hex: 0xB0418A)),
        (RGB(hex: 0xC9B6FF), RGB(hex: 0x5B3FB0)),
    ]

    init(world: CatWorld) {
        pixel = world.geo.furniturePixel
        let palette = Self.palettes.randomElement()!
        sprites = (Self.render(open: true, palette), Self.render(open: false, palette))
        let fromLeft = Bool.random()
        let region = Self.region(world)
        x = fromLeft ? -10 : world.geo.width + 10
        y = CGFloat.random(in: region)
        target = CGPoint(x: .random(in: 40...(world.geo.width - 40)), y: .random(in: region))
        layer.anchorPoint = CGPoint(x: 0.5, y: 0)
        layer.magnificationFilter = .nearest
        layer.zPosition = 16
        layer.disableImplicitAnimations()
    }

    private static func render(open: Bool, _ palette: (wing: RGB, spot: RGB)) -> EmoteArt.Sprite {
        let rows = open
            ? ["WW...WW", "WSWBWSW", ".WWBWW.", ".WW.WW."]
            : ["..W.W..", "..WBW..", "...B...", "...B..."]
        var c = PixelCanvas(width: 9, height: rows.count + 2)
        c.draw(rows, at: 1, 1, kind: .fx, outline: .hard)
        let colors: [Character: RGB] = ["W": palette.wing, "S": palette.spot, "B": RGB(hex: 0x2A2230), "O": RGB(hex: 0x2A2230)]
        return EmoteArt.Sprite(image: PixelRenderer.image(c) { colors[$0.code] }, width: c.width, height: c.height)
    }

    private static func region(_ world: CatWorld) -> ClosedRange<CGFloat> {
        let top = world.geo.height - 10
        let bottom = world.geo.mode == .menuBar ? max(10, world.geo.menuBarY - 120) : (world.geo.groundY ?? 0) + 15
        return bottom...max(bottom + 1, top)
    }

    /// A cat lunged nearby.
    func startle() {
        startled = 0.8
        resting = false
        vy = 150
        vx = .random(in: -90...90)
    }

    func update(dt: Double, world: CatWorld) {
        let d = CGFloat(dt)
        age += dt
        flap += dt * (resting ? 0.6 : 7)
        startled = max(0, startled - dt)

        let nearestCat = world.cats.min { hypot($0.x - x, $0.y - y) < hypot($1.x - x, $1.y - y) }
        let catDistance = nearestCat.map { hypot($0.headPoint().x - x, $0.headPoint().y - y) } ?? .infinity

        if resting {
            restTime -= dt
            if restTime <= 0 || catDistance < 45 * pixel / 2 || isLeaving {
                resting = false
                vy = 80
            }
            return
        }

        let region = Self.region(world)
        if isLeaving {
            target = CGPoint(x: x < world.geo.width / 2 ? -60 : world.geo.width + 60, y: region.upperBound)
        } else if hypot(target.x - x, target.y - y) < 20 {
            target = CGPoint(x: .random(in: 40...(world.geo.width - 40)), y: .random(in: region))
        }

        var ax = (target.x - x), ay = (target.y - y)
        let len = max(hypot(ax, ay), 1)
        ax /= len
        ay /= len
        var speed: CGFloat = 55
        // Shy of cats: veer off upwards when one gets close.
        if let cat = nearestCat, catDistance < 70 {
            let head = cat.headPoint()
            ax = (x - head.x) / max(catDistance, 1)
            ay = abs((y - head.y) / max(catDistance, 1)) + 0.6
            speed = 120
        }
        if startled > 0 { speed = 150 }
        vx += (ax * speed - vx) * min(1, d * 2.5)
        vy += (ay * speed - vy) * min(1, d * 2.5)
        let flutter = CGFloat(sin(flap * 2.3)) * 40
        x += vx * d
        y += (vy + flutter) * d
        y = min(max(y, region.lowerBound - 30), world.geo.height - 8)

        if isLeaving, x < -40 || x > world.geo.width + 40 { gone = true }

        // Sometimes settle on whatever is just below for a breather.
        if !isLeaving, startled == 0, catDistance > 90, Double.random(in: 0...1) < dt * 0.25,
           let spot = world.surfaceUnder(CGPoint(x: x, y: y)), let s = world.surface(spot.surface), y - s.y < 30 {
            y = s.y
            resting = true
            restTime = .random(in: 2...5)
        }
    }

    func sync() {
        let open = resting ? sin(flap * 2 * .pi) > 0.6 : sin(flap * 2 * .pi) > 0
        if open != shownOpen {
            let sprite = open ? sprites.open : sprites.closed
            layer.contents = sprite.image
            layer.bounds = CGRect(x: 0, y: 0, width: CGFloat(sprite.width) * pixel, height: CGFloat(sprite.height) * pixel)
            shownOpen = open
        }
        layer.position = CGPoint(x: (x * 2).rounded() / 2, y: ((y - pixel) * 2).rounded() / 2)
    }
}
