import AppKit

enum Anim: CaseIterable {
    case stand, blink, squish, walk, run, jump, crouch, crouchUp, swipe, sit, sitBlink, petted, groom, sleep, dangle
    case hang, climb, scratch, eat, peek
    case sleepCurled, sleepSploot, sleepBelly, yawn, stretch, stalk, drink

    var fps: Double {
        switch self {
        case .stand: 1.2
        // Planted paws move 1px per frame, so this matches the base walking speed
        // of 11px/s and the paws don't slide.
        case .walk: 11
        case .run: 11
        case .crouch, .crouchUp: 7
        case .hang: 7
        case .climb: 5
        case .scratch: 9
        case .eat: 3
        case .peek: 1.5
        case .swipe: 4
        case .sit: 0.8
        case .petted: 3.5
        case .groom: 3
        case .sleep, .sleepCurled, .sleepSploot: 0.7
        case .sleepBelly: 0.9
        case .yawn: 3
        case .stretch: 1.4
        // Slower than walking, still 1px per frame so the paws don't slide.
        case .stalk: 7
        case .drink: 4
        case .dangle: 2.5
        case .blink, .squish, .jump, .sitBlink: 1
        }
    }

    /// Centre of the head relative to the bottom-centre of the canvas, in sprite pixels, facing right.
    var head: (dx: CGFloat, dy: CGFloat) {
        switch self {
        case .stand, .blink, .squish, .walk, .swipe: (5, 11)
        case .run, .jump: (5, 11.5)
        case .crouch, .crouchUp: (5, 8)
        case .eat: (5, 6)
        case .peek: (-1, 7)
        case .climb, .scratch: (-1, 13)
        case .hang: (-1, 14)
        case .sit, .sitBlink, .petted, .groom: (3, 11)
        case .sleep: (5, 5)
        case .sleepCurled: (4, 5)
        case .sleepSploot: (7, 5)
        case .sleepBelly: (7, 4)
        case .yawn: (3, 11)
        case .stretch: (6, 8)
        case .stalk: (5, 9)
        case .drink: (5, 10)
        case .dangle: (-1, 14)
        }
    }
}

/// Side-view pixel cat facing right, assembled from parts.
///
/// Codes: F fur, S stripe/secondary, D far-side (darker) fur, B belly/paws,
/// P pink, E eye colour, K ink (pupils, closed eyes), O outline (auto).
enum CatArt {
    static let W = 26
    static let H = 18

    enum Eyes { case open, closed, happy, squint, lookUp, yawn, yawnWide }

    static func head(_ eyes: Eyes) -> [String] {
        var rows = [
            ".F.....F.",
            "FPF...FPF",
            "FFFSFSFFF",
        ]
        switch eyes {
        case .open: rows += ["FFEFFFEFF", "FFKFFFKFF", "FFFBPBFFF"]
        case .closed: rows += ["FFFFFFFFF", "FKKFFFKKF", "FFFBPBFFF"]
        case .happy: rows += ["FFKFFFKFF", "FKFKFKFKF", "FFFBPBFFF"]
        case .squint: rows += ["FKFFFFFKF", "FFKFFFKFF", "FKFBPBFKF"]
        case .lookUp: rows += ["FFKFFFKFF", "FFEFFFEFF", "FFFBPBFFF"]
        case .yawn: rows += ["FFFFFFFFF", "FKKFFFKKF", "FFFBKBFFF"]
        case .yawnWide: rows += ["FKFFFFFKF", "FFKFFFKFF", "FFBKKKBFF"]
        }
        switch eyes {
        case .yawn: rows.append(".FFBPBFF.")
        case .yawnWide: rows.append(".FBKPKBF.")
        default: rows.append(".FFBBBFF.")
        }
        return rows
    }

    static let body = [
        ".FFSFFSFFSF.",
        "FFFSFFSFFSFF",
        "FFFFFFFFFFFF",
        "FFFFFFFFFFFF",
        ".BBBBBBBBBB.",
    ]

    static let sitBody = [
        "..FFFF..",
        ".FSFSFF.",
        "FFFFFFFF",
        "FFFFFFFF",
        "FFFFFFFF",
        "FFFFFFFF",
        ".FFBBBF.",
    ]

    static let sleepBody = [
        "..FFFFFFF...",
        ".FFSFFSFFF..",
        "FFFFFFFFFFF.",
        "FFFFFFFFFFFF",
        ".FFFFFFFFFF.",
    ]

    static let hangBody = [
        ".FFFFF.",
        "FFSFSFF",
        "FFFSFFF",
        "FFFFFFF",
        "FFFFFFF",
        ".BBBBB.",
    ]

    // Tails, root first. Roots sit right next to the body so the outlines merge.
    static let tailUpA = [(4, 10), (3, 9), (3, 8), (2, 7), (2, 6), (2, 5), (3, 4)]
    static let tailUpB = [(4, 10), (3, 9), (2, 8), (2, 7), (1, 6), (1, 5), (2, 4)]
    static let tailWalkA = [(4, 10), (3, 9), (2, 8), (2, 7), (1, 6)]
    static let tailWalkB = [(4, 10), (3, 9), (2, 9), (1, 8), (1, 7)]
    static let tailRun = [(4, 10), (3, 10), (2, 9), (1, 9)]
    static let tailRunHigh = [(4, 9), (3, 9), (2, 8), (1, 8)]
    static let tailCrouchA = [(4, 12), (3, 11), (3, 10), (2, 9), (2, 8)]
    static let tailCrouchB = [(4, 12), (3, 11), (2, 10), (2, 9), (1, 8)]
    static let tailSitA = [(8, 15), (7, 16), (6, 16), (5, 16), (4, 15)]
    static let tailSitB = [(8, 15), (7, 16), (6, 16), (5, 15), (5, 14)]
    static let tailSleep = [(5, 14), (4, 15), (5, 16), (6, 16), (7, 16), (8, 16), (9, 16), (10, 16)]
    static let tailHangA = [(15, 12), (16, 13), (16, 14), (17, 15)]
    static let tailHangB = [(15, 12), (16, 13), (17, 14), (17, 15)]

    struct Leg {
        var x: Int
        var far: Bool
        var lift = 0
    }

    static func legRows(far: Bool, height: Int) -> [String] {
        Array(repeating: far ? "DD" : "FF", count: max(0, height - 1)) + ["BB"]
    }

    /// Near back, far back, far front, near front.
    static func legs(_ nb: Int, _ fb: Int, _ ff: Int, _ nf: Int, lift: (Int, Int, Int, Int) = (0, 0, 0, 0)) -> [Leg] {
        [
            Leg(x: fb, far: true, lift: lift.1),
            Leg(x: ff, far: true, lift: lift.2),
            Leg(x: nb, far: false, lift: lift.0),
            Leg(x: nf, far: false, lift: lift.3),
        ]
    }

    static let baseLegs = legs(6, 9, 12, 15)

    static func standing(
        eyes: Eyes = .open,
        tail: [(Int, Int)],
        legs: [Leg],
        bodyY: Int = 9,
        headY: Int = 4,
        legY: Int = 14,
        legHeight: Int = 3,
        extra: ((inout PixelCanvas) -> Void)? = nil
    ) -> PixelCanvas {
        var c = PixelCanvas(width: W, height: H)
        c.tail(tail)
        for leg in legs where leg.far {
            c.draw(legRows(far: true, height: legHeight - leg.lift), at: leg.x, legY, kind: .leg)
        }
        for leg in legs where !leg.far {
            c.draw(legRows(far: false, height: legHeight - leg.lift), at: leg.x, legY, kind: .leg)
        }
        c.draw(body, at: 5, bodyY, kind: .body)
        c.draw(head(eyes), at: 14, headY, kind: .head, outline: .hard)
        extra?(&c)
        return c
    }

    static func sitting(eyes: Eyes, tail: [(Int, Int)], groomArmY: Int? = nil) -> PixelCanvas {
        var c = PixelCanvas(width: W, height: H)
        c.tail(tail)
        c.draw(sitBody, at: 8, 10, kind: .body)
        if groomArmY == nil {
            c.draw(legRows(far: false, height: 6), at: 15, 11, kind: .leg, outline: .hard)
        }
        c.draw(head(eyes), at: 12, 4, kind: .head, outline: .hard)
        if let y = groomArmY {
            c.draw(["BB", "FF", "FF"], at: 15, y, kind: .arm, outline: .hard)
        }
        return c
    }

    static func sleeping(breathIn: Bool) -> PixelCanvas {
        var c = PixelCanvas(width: W, height: H)
        if breathIn {
            c.draw(["...FFFFF...."] + sleepBody, at: 6, 11, kind: .body)
        } else {
            c.draw(sleepBody, at: 6, 12, kind: .body)
        }
        c.tail(tailSleep, outline: .hard)
        c.draw(head(.closed), at: 14, 10, kind: .head, outline: .hard)
        return c
    }

    /// Curled up in a round ball, head tucked in, the tail wrapped round the nose.
    static func sleepingCurled(breathIn: Bool) -> PixelCanvas {
        var c = PixelCanvas(width: W, height: H)
        let body = [
            "....FFFFFF....",
            "..FFSFFSFFFF..",
            ".FFFFSFFSFFFF.",
            "FFFFFFFFFFFFFF",
            "FFFFFFFFFFFFFF",
            "FFFFFFFFFFFFFF",
            ".FFFFFFFFFFFF.",
        ]
        // Breathing in, the whole ball grows by a row.
        c.draw(breathIn ? Array(body.prefix(3)) + ["FFFFFFFFFFFFFF"] + body.dropFirst(3) : body, at: 4, breathIn ? 8 : 9, kind: .body)
        c.draw(head(.closed), at: 12, 10, kind: .head, outline: .hard)
        // In front of the face, so it wraps round it.
        c.tail([(4, 15), (5, 16), (6, 16), (7, 16), (8, 16), (9, 16), (10, 16), (11, 16), (12, 16),
                (13, 16), (14, 16), (15, 16), (16, 16), (17, 16), (18, 16), (19, 15)], outline: .hard)
        return c
    }

    /// Flat on the belly with the paws stretched out front and back, chin down.
    static func sleepingSploot(breathIn: Bool) -> PixelCanvas {
        var c = PixelCanvas(width: W, height: H)
        c.tail([(4, 13), (3, 13), (2, 12), (1, 12), (0, 11)])
        c.draw(["DDDDBB"], at: 0, 15, kind: .leg)
        c.draw(["DDDDDDBB"], at: 18, 15, kind: .leg)
        let body = [
            "..FFSFFSFFSFF...",
            ".FFFSFFSFFSFFFF.",
            "FFFFFFFFFFFFFFFF",
        ]
        c.draw(breathIn ? ["....FFFFFF......"] + body : body, at: 3, breathIn ? 12 : 13, kind: .body)
        c.draw(["FFFFBB"], at: 0, 16, kind: .leg, outline: .hard)
        c.draw(["FFFFFFBB"], at: 17, 16, kind: .leg, outline: .hard)
        c.draw(head(.closed), at: 15, 9, kind: .head, outline: .hard)
        return c
    }

    /// On its back, belly up, paws in the air and the face upside down.
    static func sleepingBelly(twitch: Bool) -> PixelCanvas {
        var c = PixelCanvas(width: W, height: H)
        c.tail([(5, 16), (4, 16), (3, 16), (2, 15), (1, 15)])
        let paw = ["BB", "FF", "FF"], farPaw = ["BB", "DD", "DD"]
        c.draw(farPaw, at: 9, 10, kind: .leg)
        c.draw(farPaw, at: 15, twitch ? 11 : 10, kind: .leg)
        c.draw([
            ".BBBBBBBBBBB.",
            "FFFFFFFFFFFFF",
            "FFSFFSFFSFFFF",
            ".FFFFFFFFFFF.",
        ], at: 5, 13, kind: .body)
        c.draw(paw, at: 7, 10, kind: .leg, outline: .hard)
        c.draw(paw, at: 13, 10, kind: .leg, outline: .hard)
        c.draw(Array(head(.closed).reversed()), at: 16, 10, kind: .head, outline: .hard)
        return c
    }

    /// Front paws stretched far ahead, past the nose; chest low, rump and tail up.
    static func stretching(eyes: Eyes) -> PixelCanvas {
        var c = PixelCanvas(width: W, height: H)
        c.tail([(2, 9), (1, 8), (1, 7), (0, 6), (0, 5), (1, 4)])
        c.draw(legRows(far: true, height: 5), at: 6, 12, kind: .leg)
        c.draw(["DDDDDDDDBB"], at: 15, 15, kind: .leg)
        c.draw(legRows(far: false, height: 5), at: 4, 12, kind: .leg)
        c.draw([
            "FFFFF.........",
            "FFSFFSFF......",
            "FFFFFSFFSFF...",
            ".FFFFFFFFFFFF.",
            "..BBFFFFFFFFFF",
            ".....BBBBBBBBB",
        ], at: 3, 8, kind: .body)
        c.draw(head(eyes), at: 14, 9, kind: .head, outline: .hard)
        c.draw(["FFFFFFFFFBB"], at: 14, 16, kind: .leg, outline: .hard)
        return c
    }

    static func dangling(swing: Bool) -> PixelCanvas {
        var c = PixelCanvas(width: W, height: H)
        c.tail(swing ? tailHangB : tailHangA)
        c.draw(legRows(far: false, height: swing ? 2 : 3), at: 10, 13, kind: .leg)
        c.draw(legRows(far: false, height: 3), at: 13, 13, kind: .leg)
        c.draw(hangBody, at: 9, 7, kind: .body)
        c.draw(["F", "F", "B"], at: 8, 8, kind: .arm, outline: .hard)
        c.draw(["F", "F", "B"], at: 16, 8, kind: .arm, outline: .hard)
        c.draw(head(.open), at: 8, 1, kind: .head, outline: .hard)
        return c
    }

    /// Hanging off a ledge by the front paws, which are at the very top of the canvas.
    static func hanging(kick: Bool) -> PixelCanvas {
        var c = PixelCanvas(width: W, height: H)
        c.tail(kick ? tailHangB : tailHangA)
        c.draw(legRows(far: false, height: kick ? 2 : 3), at: 10, 13, kind: .leg)
        c.draw(legRows(far: false, height: kick ? 3 : 2), at: 13, 13, kind: .leg)
        c.draw(hangBody, at: 9, 7, kind: .body)
        c.draw(head(.squint), at: 8, 1, kind: .head, outline: .hard)
        c.draw(["B", "F", "F"], at: 7, 0, kind: .arm, outline: .hard)
        c.draw(["B", "F", "F"], at: 17, 0, kind: .arm, outline: .hard)
        return c
    }

    /// Hugging a scratching post, seen from the front; paws reach up in turn.
    static func climbing(leftUp: Bool) -> PixelCanvas {
        var c = PixelCanvas(width: W, height: H)
        c.tail([(15, 14), (16, 15), (17, 16)])
        c.draw(legRows(far: false, height: leftUp ? 2 : 3), at: 10, 14, kind: .leg)
        c.draw(legRows(far: false, height: leftUp ? 3 : 2), at: 13, 14, kind: .leg)
        c.draw(hangBody, at: 9, 8, kind: .body)
        c.draw(head(.closed), at: 8, 2, kind: .head, outline: .hard)
        c.draw(["B", "F", "F"], at: 7, leftUp ? 1 : 5, kind: .arm, outline: .hard)
        c.draw(["B", "F", "F"], at: 17, leftUp ? 5 : 1, kind: .arm, outline: .hard)
        return c
    }

    /// Just a head and two paws, for peeking out of the trash can.
    static func peeking(_ eyes: Eyes) -> PixelCanvas {
        var c = PixelCanvas(width: W, height: H)
        c.draw(head(eyes), at: 8, 8, kind: .head, outline: .hard)
        c.draw(["BB"], at: 6, 14, kind: .arm, outline: .hard)
        c.draw(["BB"], at: 17, 14, kind: .arm, outline: .hard)
        return c
    }

    static let frames: [Anim: [PixelCanvas]] = {
        var f: [Anim: [PixelCanvas]] = [:]
        f[.stand] = [standing(tail: tailUpA, legs: baseLegs), standing(tail: tailUpB, legs: baseLegs)]
        f[.blink] = [standing(eyes: .closed, tail: tailUpA, legs: baseLegs)]
        f[.squish] = [standing(eyes: .squint, tail: tailUpA, legs: baseLegs)]
        // Diagonal pairs (near back + far front, far back + near front) alternate.
        // A raised leg swings forward; a planted one slides back as the body moves on.
        f[.walk] = [
            standing(tail: tailWalkA, legs: legs(5, 10, 11, 16)),
            standing(tail: tailWalkA, legs: legs(6, 9, 12, 15, lift: (1, 0, 1, 0))),
            standing(tail: tailWalkB, legs: legs(7, 8, 13, 14)),
            standing(tail: tailWalkB, legs: legs(6, 9, 12, 15, lift: (0, 1, 0, 1))),
        ]
        let stretched = standing(tail: tailRunHigh, legs: legs(4, 6, 15, 17, lift: (1, 1, 1, 1)), bodyY: 8, headY: 3, legY: 13)
        f[.run] = [stretched, standing(tail: tailRun, legs: legs(8, 10, 12, 14))]
        f[.jump] = [stretched]
        f[.crouch] = [tailCrouchA, tailCrouchB].map {
            standing(tail: $0, legs: baseLegs, bodyY: 11, headY: 7, legY: 16, legHeight: 1)
        }
        f[.crouchUp] = [tailCrouchA, tailCrouchB].map {
            standing(eyes: .lookUp, tail: $0, legs: baseLegs, bodyY: 11, headY: 7, legY: 16, legHeight: 1)
        }
        f[.eat] = [10, 9].map {
            standing(eyes: .closed, tail: tailUpA, legs: baseLegs, headY: $0)
        }
        f[.hang] = [hanging(kick: false), hanging(kick: true)]
        f[.climb] = [climbing(leftUp: true), climbing(leftUp: false)]
        f[.scratch] = f[.climb]
        f[.peek] = [peeking(.open), peeking(.open), peeking(.lookUp), peeking(.closed)]
        f[.swipe] = [
            standing(tail: tailUpA, legs: baseLegs),
            standing(tail: tailUpB, legs: Array(baseLegs.prefix(3))) { c in
                c.draw([".BB", "FF."], at: 21, 10, kind: .arm, outline: .hard)
            },
        ]
        f[.sit] = [sitting(eyes: .open, tail: tailSitA), sitting(eyes: .open, tail: tailSitB)]
        f[.sitBlink] = [sitting(eyes: .closed, tail: tailSitA)]
        f[.petted] = [sitting(eyes: .happy, tail: tailSitA), sitting(eyes: .happy, tail: tailSitB)]
        f[.groom] = [sitting(eyes: .closed, tail: tailSitA, groomArmY: 9), sitting(eyes: .closed, tail: tailSitA, groomArmY: 10)]
        f[.sleep] = [sleeping(breathIn: false), sleeping(breathIn: true)]
        f[.dangle] = [dangling(swing: false), dangling(swing: true)]
        f[.sleepCurled] = [sleepingCurled(breathIn: false), sleepingCurled(breathIn: true)]
        f[.sleepSploot] = [sleepingSploot(breathIn: false), sleepingSploot(breathIn: true)]
        f[.sleepBelly] = [sleepingBelly(twitch: false), sleepingBelly(twitch: false), sleepingBelly(twitch: true), sleepingBelly(twitch: false)]
        f[.yawn] = [sitting(eyes: .closed, tail: tailSitA), sitting(eyes: .yawn, tail: tailSitA),
                    sitting(eyes: .yawnWide, tail: tailSitB), sitting(eyes: .yawn, tail: tailSitB)]
        f[.stretch] = [stretching(eyes: .closed), stretching(eyes: .yawnWide)]
        // Lapping at a fountain: the chin at the height of its bowl, bobbing.
        f[.drink] = [5, 6].map { standing(eyes: .closed, tail: tailUpA, legs: baseLegs, headY: $0) }
        // Creeping up on someone: low body, head down, tail low.
        func low(_ tail: [(Int, Int)], _ legs: [Leg]) -> PixelCanvas {
            standing(tail: tail, legs: legs, bodyY: 10, headY: 7, legY: 15, legHeight: 2)
        }
        f[.stalk] = [
            low(tailCrouchA, legs(5, 10, 11, 16)),
            low(tailCrouchA, legs(6, 9, 12, 15)),
            low(tailCrouchB, legs(7, 8, 13, 14)),
            low(tailCrouchB, legs(6, 9, 12, 15)),
        ]
        return f
    }()

    /// Menu bar icon: a template cat face.
    static func statusIcon() -> NSImage {
        var c = PixelCanvas(width: 11, height: 9)
        c.draw(head(.open), at: 1, 1, kind: .head, outline: .hard)
        let scale = 3
        let cg = PixelRenderer.image(c, scale: scale) { cell in
            switch cell.code {
            case "E", "K", "P": nil
            default: RGB(0, 0, 0)
            }
        }
        let image = NSImage(cgImage: cg, size: NSSize(width: CGFloat(c.width) * 1.5, height: CGFloat(c.height) * 1.5))
        image.isTemplate = true
        return image
    }
}

struct CatPalette {
    let a: CatAppearance
    let outline: RGB
    static let pink = RGB(hex: 0xF29BB0)
    static let ink = RGB(hex: 0x241C24)

    init(_ appearance: CatAppearance) {
        a = appearance
        let f = appearance.fur
        let luminance = 0.2126 * f.r + 0.7152 * f.g + 0.0722 * f.b
        // A dark outline would vanish around a dark cat, especially on a dark menu bar.
        outline = luminance < 0.3
            ? f.mixed(with: RGB(hex: 0xB9B2C8), 0.45)
            : f.scaled(0.3).mixed(with: RGB(hex: 0x1A1024), 0.35)
    }

    func color(_ cell: Cell) -> RGB? {
        switch cell.code {
        case "O": outline
        case "E": a.eyes
        case "K": Self.ink
        case "P": Self.pink
        case "F": fur(cell)
        case "S": a.pattern == .tabby ? a.secondary : fur(cell)
        case "D": fur(cell).scaled(0.78)
        case "B": a.pattern == .points && cell.kind != .body && isPoint(cell) ? a.secondary : a.belly
        default: nil
        }
    }

    private func fur(_ cell: Cell) -> RGB {
        switch a.pattern {
        case .solid, .tabby: a.fur
        case .calico: calico(cell)
        case .points: isPoint(cell) ? a.secondary : a.fur
        }
    }

    private func isPoint(_ cell: Cell) -> Bool {
        switch cell.kind {
        case .tail, .leg, .arm: true
        case .head: cell.ly <= 1 || (cell.ly >= 3 && cell.lx >= 2 && cell.lx <= 6)
        case .body, .fx: false
        }
    }

    /// Blocky 3×3 patches, stable per part so they move with it.
    private func calico(_ cell: Cell) -> RGB {
        let k = Int(cell.kind.rawValue)
        let bx = (cell.lx + 2 * k + 9) / 3
        let by = (cell.ly + k + 9) / 3
        let v = (bx &* 92_837_111) ^ (by &* 689_287_499) ^ (k &* 283_923_481)
        switch UInt(bitPattern: v) % 5 {
        case 0, 1: return a.fur
        case 2: return a.secondary
        default: return a.belly
        }
    }
}
