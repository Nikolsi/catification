import QuartzCore

/// Hearts, Z's and portal sparks.
@MainActor
final class Particle {
    let layer = CALayer()
    private var position: CGPoint
    private var velocity: CGVector
    private let gravity: CGFloat
    private let drag: CGFloat
    private let wobble: CGFloat
    private let maxLife: Double
    private var life = 0.0
    private let phase = Double.random(in: 0...(2 * .pi), using: &Sim.rng)

    init(sprite: EmoteArt.Sprite, pixel: CGFloat, position: CGPoint, velocity: CGVector,
         gravity: CGFloat, life: Double, drag: CGFloat = 0, wobble: CGFloat = 0) {
        self.position = position
        self.velocity = velocity
        self.gravity = gravity
        self.drag = drag
        self.wobble = wobble
        maxLife = life
        layer.disableImplicitAnimations()
        layer.contents = sprite.image
        layer.magnificationFilter = .nearest
        layer.bounds = CGRect(x: 0, y: 0, width: CGFloat(sprite.width) * pixel, height: CGFloat(sprite.height) * pixel)
        layer.zPosition = 60
        update(0)
    }

    /// Returns false once the particle has faded out.
    @discardableResult
    func update(_ dt: Double) -> Bool {
        let d = CGFloat(dt)
        life += dt
        velocity.dy -= gravity * d
        let damping = max(0, 1 - drag * d)
        velocity.dx *= damping
        velocity.dy *= damping
        position.x += velocity.dx * d
        position.y += velocity.dy * d

        let t = life / maxLife
        let sway = wobble * CGFloat(sin(life * 6 + phase))
        layer.position = CGPoint(x: ((position.x + sway) * 2).rounded() / 2, y: (position.y * 2).rounded() / 2)
        layer.opacity = Float(t > 0.55 ? max(0, 1 - (t - 0.55) / 0.45) : 1)
        let pop = t < 0.12 ? 0.4 + 0.75 * (t / 0.12) : (t < 0.2 ? 1.15 - (t - 0.12) * 1.9 : 1)
        layer.setAffineTransform(CGAffineTransform(scaleX: pop, y: pop))
        return life < maxLife
    }
}
