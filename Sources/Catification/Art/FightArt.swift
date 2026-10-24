import CoreGraphics

/// The cartoon fight cloud: a tumbling ball of dust in both cats' colours, with paws, tails and
/// ears sticking out every which way and a pair of cross eyes peeking through.
enum FightArt {
    static let W = 46
    static let H = 30

    private static let dust = RGB(hex: 0xEDE6D8)
    private static let dustShade = RGB(hex: 0xC4BAA9)
    private static let outline = RGB(hex: 0x2A1E2A)

    /// A few different tangles to cycle through. `random` decides the shapes.
    static func frames(_ a: CatAppearance, _ b: CatAppearance, count: Int, random: inout SimRandom) -> [CGImage] {
        (0..<count).map { _ in frame(a, b, random: &random) }
    }

    private static func frame(_ a: CatAppearance, _ b: CatAppearance, random: inout SimRandom) -> CGImage {
        var c = PixelCanvas(width: W, height: H)
        let centre = (x: Double(W) / 2, y: Double(H) / 2 + 1)
        let radius = (x: 10.0, y: 6.0)

        // Paws, tails and ears go first, so the cloud covers their roots.
        let directions: [(Double, Double)] = [(1, 0), (-1, 0), (0.7, -0.7), (-0.7, -0.7), (0.7, 0.7), (-0.7, 0.7), (0.35, 1), (-0.35, 1)]
        var used = Set<Int>()
        for i in 0..<Int.random(in: 4...6, using: &random) {
            var d = Int.random(in: 0..<directions.count, using: &random)
            while used.contains(d) { d = (d + 1) % directions.count }
            used.insert(d)
            let (dx, dy) = directions[d]
            let first = i % 2 == 0
            let (fur, belly, stripe): (Character, Character, Character) = first ? ("a", "b", "s") : ("c", "d", "t")
            // From just inside the cloud's edge, reaching well out of it.
            let start = (x: centre.x + dx * (radius.x + 1), y: centre.y + dy * (radius.y + 1))
            let horizontal = abs(dx) > abs(dy)
            switch Int.random(in: 0..<5, using: &random) {
            case 0, 1, 2:
                // A paw: two pixels thick, pale toes at the end.
                var pixels: [(x: Int, y: Int, code: Character)] = []
                for step in 0..<8 {
                    let px = Int((start.x + dx * Double(step)).rounded()), py = Int((start.y + dy * Double(step)).rounded())
                    let code = step >= 6 ? belly : fur
                    pixels.append((px, py, code))
                    pixels.append((horizontal ? px : px + 1, horizontal ? py + 1 : py, code))
                }
                c.stamp(pixels, kind: .leg, origin: (pixels[0].x, pixels[0].y), outline: .hard)
            case 3:
                // A striped tail, wiggling out.
                var pixels: [(x: Int, y: Int, code: Character)] = []
                for step in 0..<9 {
                    let wiggle = [0.0, 1, 1, 0, -1, -1, 0, 1, 1][step]
                    let px = Int((start.x + dx * Double(step) + (horizontal ? 0 : wiggle)).rounded())
                    let py = Int((start.y + dy * Double(step) + (horizontal ? wiggle : 0)).rounded())
                    pixels.append((px, py, step % 2 == 0 ? fur : stripe))
                }
                c.stamp(pixels, kind: .tail, origin: (pixels[0].x, pixels[0].y), outline: .hard)
            default:
                // An ear poking up out of the top.
                let ex = Int(centre.x) + Int.random(in: -9...6, using: &random)
                let ey = Int(centre.y - radius.y) - 2
                c.draw([".\(fur).", "\(fur)P\(fur)", "\(fur)\(fur)\(fur)"], at: ex, ey, kind: .head, outline: .hard)
            }
        }

        // The cloud: a big puff in the middle and a ring of smaller ones round the edge, each
        // dust-coloured or tinted with one of the cats' fur, shaded underneath.
        var puffs: [(x: Double, y: Double, r: Double, tint: Int)] = [(centre.x, centre.y, 6.5, 0)]
        let ring = Int.random(in: 9...12, using: &random)
        let turn = Double.random(in: 0..<(2 * .pi), using: &random)
        for k in 0..<ring {
            let angle = turn + Double(k) / Double(ring) * 2 * .pi + .random(in: -0.2...0.2, using: &random)
            let tint = [0, 0, 0, 1, 2][Int.random(in: 0..<5, using: &random)]
            puffs.append((centre.x + cos(angle) * radius.x * .random(in: 0.7...0.9, using: &random),
                          centre.y + sin(angle) * radius.y * .random(in: 0.7...0.9, using: &random),
                          .random(in: 3...4.5, using: &random), tint))
        }
        var cloud: [(x: Int, y: Int, code: Character)] = []
        for y in 0..<H {
            for x in 0..<W {
                let px = Double(x) + 0.5, py = Double(y) + 0.5
                // The last puff drawn over a pixel decides its colour, so patches stay round.
                guard let puff = puffs.last(where: { (px - $0.x) * (px - $0.x) + (py - $0.y) * (py - $0.y) <= $0.r * $0.r }) else { continue }
                let shaded = py > puff.y + puff.r * 0.4
                let codes: [Character] = shaded ? ["w", "x", "y"] : ["W", "X", "Y"]
                cloud.append((x, y, codes[puff.tint]))
            }
        }
        c.stamp(cloud, kind: .body, origin: (0, 0), outline: .hard)

        // Swirls of motion inside.
        for _ in 0..<Int.random(in: 2...3, using: &random) {
            let sx = Int(centre.x) + Int.random(in: -7...4, using: &random)
            let sy = Int(centre.y) + Int.random(in: -3...3, using: &random)
            c.draw(Bool.random(using: &random) ? ["LL..", "..LL"] : ["..LL", "LL.."], at: sx, sy, kind: .fx, outline: .none)
        }
        // Cross eyes peeking out of the tangle.
        if Int.random(in: 0..<3, using: &random) > 0 {
            let ex = Int(centre.x) + Int.random(in: -6...1, using: &random)
            let ey = Int(centre.y) + Int.random(in: -3...0, using: &random)
            c.draw(["K....K", ".K..K."], at: ex, ey, kind: .fx, outline: .none)
        }

        let tintA = a.fur.mixed(with: dust, 0.35), tintB = b.fur.mixed(with: dust, 0.35)
        return PixelRenderer.image(c) { cell in
            switch cell.code {
            case "O": outline
            case "L": dustShade.scaled(0.8)
            case "W": dust
            case "w": dustShade
            case "X": tintA
            case "x": tintA.scaled(0.82)
            case "Y": tintB
            case "y": tintB.scaled(0.82)
            case "a": a.fur
            case "b": a.belly
            case "s": a.pattern == .tabby ? a.secondary : a.fur.scaled(0.85)
            case "c": b.fur
            case "d": b.belly
            case "t": b.pattern == .tabby ? b.secondary : b.fur.scaled(0.85)
            case "P": CatPalette.pink
            case "K": CatPalette.ink
            default: nil
            }
        }
    }
}
