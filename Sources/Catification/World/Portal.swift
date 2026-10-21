import AppKit
import QuartzCore

/// A glowing Portal-style oval, seen edge-on.
final class PortalLayer: CALayer {
    static let blue = NSColor(srgbRed: 0.18, green: 0.62, blue: 1.0, alpha: 1)
    static let orange = NSColor(srgbRed: 1.0, green: 0.55, blue: 0.12, alpha: 1)

    init(color: NSColor, size: CGSize, scale: CGFloat) {
        super.init()
        bounds = CGRect(origin: .zero, size: size)
        contentsScale = scale
        disableImplicitAnimations()

        let ring = CAShapeLayer()
        ring.frame = bounds
        ring.contentsScale = scale
        ring.path = CGPath(ellipseIn: bounds.insetBy(dx: 1.5, dy: 1.5), transform: nil)
        ring.fillColor = color.withAlphaComponent(0.3).cgColor
        ring.strokeColor = color.cgColor
        ring.lineWidth = 2.2
        ring.shadowColor = color.cgColor
        ring.shadowOpacity = 1
        ring.shadowRadius = 4
        ring.shadowOffset = .zero

        let core = CAShapeLayer()
        core.frame = bounds
        core.contentsScale = scale
        core.path = CGPath(ellipseIn: bounds.insetBy(dx: size.width * 0.33, dy: size.height * 0.14), transform: nil)
        core.fillColor = (color.blended(withFraction: 0.6, of: .white) ?? color).withAlphaComponent(0.7).cgColor

        addSublayer(ring)
        addSublayer(core)

        let pulse = CABasicAnimation(keyPath: "shadowRadius")
        pulse.fromValue = 2.5
        pulse.toValue = 6.5
        pulse.duration = 0.45
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        ring.add(pulse, forKey: "pulse")

        let shimmer = CABasicAnimation(keyPath: "opacity")
        shimmer.fromValue = 0.45
        shimmer.toValue = 1
        shimmer.duration = 0.3
        shimmer.autoreverses = true
        shimmer.repeatCount = .infinity
        core.add(shimmer, forKey: "shimmer")
    }

    override init(layer: Any) { super.init(layer: layer) }
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func open() {
        let grow = CASpringAnimation(keyPath: "transform.scale.y")
        grow.fromValue = 0.05
        grow.toValue = 1
        grow.damping = 9
        grow.stiffness = 260
        grow.mass = 0.6
        grow.duration = grow.settlingDuration
        add(grow, forKey: "openY")

        let widen = CABasicAnimation(keyPath: "transform.scale.x")
        widen.fromValue = 0.2
        widen.toValue = 1
        widen.duration = 0.2
        add(widen, forKey: "openX")
    }

    func close() {
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in self?.removeFromSuperlayer() }
        let shrink = CABasicAnimation(keyPath: "transform.scale.y")
        shrink.fromValue = 1
        shrink.toValue = 0.02
        shrink.duration = 0.2
        shrink.fillMode = .forwards
        shrink.isRemovedOnCompletion = false
        add(shrink, forKey: "close")
        CATransaction.commit()
    }
}
