import CoreGraphics

/// Pixel art for furniture and toys. Sizes are in sprite pixels; every image has a 1px outline margin.
enum PropArt {
    private static let palette: [Character: RGB] = [
        // Wood
        "H": RGB(hex: 0xE0A56A), "W": RGB(hex: 0xB97A45), "D": RGB(hex: 0x8A5530), "b": RGB(hex: 0x7A4A2A),
        // Sisal rope and felt
        "R": RGB(hex: 0xDCC79C), "r": RGB(hex: 0xB49A6E), "C": RGB(hex: 0x8E7BE0), "c": RGB(hex: 0xB3A5F0),
        // Bed
        "M": RGB(hex: 0xD9809B), "m": RGB(hex: 0xB5617D), "I": RGB(hex: 0xFFE9D6),
        // Bowl and kibble
        "U": RGB(hex: 0x4F9BE0), "L": RGB(hex: 0x9CCBF5), "u": RGB(hex: 0x2F6CA8), "K": RGB(hex: 0xA0622E), "k": RGB(hex: 0xC98446),
        // Yarn
        "Y": RGB(hex: 0xE85D8A), "y": RGB(hex: 0xB53A63),
        // Trash can
        "G": RGB(hex: 0xA9B4BF), "g": RGB(hex: 0x7D8894), "T": RGB(hex: 0x2C3138),
        // Cardboard box
        "A": RGB(hex: 0xC8955A), "a": RGB(hex: 0xA0703D), "e": RGB(hex: 0xDDB27A), "N": RGB(hex: 0x4A3424),
        // A pile of laundry
        "B": RGB(hex: 0x4F7BC8), "P": RGB(hex: 0xE88AA8), "E": RGB(hex: 0xE8C35A), "V": RGB(hex: 0x7FB86A), "Z": RGB(hex: 0xEFEAF4),
        "h": RGB(hex: 0xD9534F),
        // Flower pot
        "Q": RGB(hex: 0xC8643C), "q": RGB(hex: 0x9E4A2A), "F": RGB(hex: 0xDB7E55), "S": RGB(hex: 0x5A3A25),
        "J": RGB(hex: 0x4F9E4A), "j": RGB(hex: 0x7CC46A), "X": RGB(hex: 0xF2C14E),
        // Wardrobe insides and knobs
        "n": RGB(hex: 0x2A2230), "x": RGB(hex: 0xE0B050),
    ]
    private static let outline = RGB(hex: 0x3A2216)

    struct Art {
        let image: CGImage
        let width: Int
        let height: Int
    }

    private static func render(_ canvas: PixelCanvas) -> Art {
        let image = PixelRenderer.image(canvas) { $0.code == "O" ? outline : palette[$0.code] }
        return Art(image: image, width: canvas.width, height: canvas.height)
    }

    @MainActor private static var cache: [String: Art] = [:]

    @MainActor private static func cached(_ key: String, _ make: () -> PixelCanvas) -> Art {
        if let art = cache[key] { return art }
        if cache.count > 120 { cache.removeAll() }
        let art = render(make())
        cache[key] = art
        return art
    }

    /// The plank's top surface is canvas row 1.
    @MainActor static func shelf(width w: Int) -> Art {
        let w = max(w, 14)
        return cached("shelf\(w)") {
            var c = PixelCanvas(width: w + 2, height: 8)
            c.draw([String(repeating: "H", count: w), String(repeating: "W", count: w), String(repeating: "D", count: w)],
                   at: 1, 1, kind: .body, outline: .hard)
            c.draw(["bbb", "bb.", "b.."], at: 3, 4, kind: .leg, outline: .soft)
            c.draw(["bbb", ".bb", "..b"], at: w - 3, 4, kind: .leg, outline: .soft)
            return c
        }
    }

    static let postWidth = 22

    /// Cushion on top (canvas row 1 is the perch surface), sisal column, wooden base on the bottom row.
    @MainActor static func post(height h: Int) -> Art {
        let h = max(h, 16)
        return cached("post\(h)") {
            let w = postWidth
            var c = PixelCanvas(width: w + 2, height: h + 2)
            let columnTop = 6, columnBottom = h - 2
            var rope: [String] = []
            for row in columnTop...columnBottom {
                rope.append((row % 2 == 0 ? "rRRRRr" : "rrRRrr"))
            }
            c.draw(rope, at: 1 + (w - 6) / 2, columnTop, kind: .body, outline: .hard)
            c.draw([String(repeating: "W", count: w), String(repeating: "D", count: w)], at: 1, h - 1, kind: .leg, outline: .hard)
            c.draw([String(repeating: "W", count: w - 2), String(repeating: "D", count: w - 2)], at: 2, 4, kind: .leg, outline: .hard)
            c.draw(["." + String(repeating: "c", count: w - 4) + ".", String(repeating: "C", count: w - 2)], at: 2, 1, kind: .head, outline: .hard)
            return c
        }
    }

    static let bedWidth = 22

    /// Back part, drawn behind a sleeping cat, and the front rim drawn over it.
    @MainActor static func bed(front: Bool) -> Art {
        cached(front ? "bedFront" : "bedBack") {
            let rows = [
                "...MMMMMMMMMMMMMMMM...",
                ".MMMIIIIIIIIIIIIIIMMM.",
                "MMIIIIIIIIIIIIIIIIIIMM",
                "MMMIIIIIIIIIIIIIIIIMMM",
                "MMMMMMMMMMMMMMMMMMMMMM",
                ".MmmmmmmmmmmmmmmmmmmM.",
                "..MMMMMMMMMMMMMMMMMM..",
            ]
            var c = PixelCanvas(width: bedWidth + 2, height: rows.count + 2)
            if front {
                c.draw(Array(rows[3...]), at: 1, 4, kind: .body, outline: .hard)
            } else {
                c.draw(rows, at: 1, 1, kind: .body, outline: .hard)
            }
            return c
        }
    }

    static let bowlWidth = 12

    /// `food`: 0 empty, 1 some, 2 full. The bowl's bottom is the last content row.
    @MainActor static func bowl(food: Int) -> Art {
        cached("bowl\(food)") {
            var rows = [
                food >= 2 ? "...kKkKkK..." : "............",
                food >= 1 ? ".KkKkKkKkKk." : "............",
                "UUUUUUUUUUUU",
                ".ULLUUUUUUU.",
                "..UUUUUUUU..",
                "...uuuuuu...",
            ]
            if food == 0 { rows.removeFirst(2) }
            var c = PixelCanvas(width: bowlWidth + 2, height: rows.count + 2)
            c.draw(rows, at: 1, 1, kind: .body, outline: .hard)
            return c
        }
    }

    static let trashWidth = 14
    /// Rows from the bottom of the can to the top of its rim.
    static let trashHeight = 15

    /// An open trash can. The front (rim and body) is drawn over a cat rummaging inside,
    /// so only its head pokes out above the rim.
    @MainActor static func trash(front: Bool) -> Art {
        cached(front ? "trashFront" : "trashBack") {
            var rows = ["GGGGGGGGGGGGGG", "gTTTTTTTTTTTTg"]
            for _ in 0..<12 { rows.append(".GgGGgGGgGGgG.") }
            rows.append("..gggggggggg..")
            var c = PixelCanvas(width: trashWidth + 2, height: rows.count + 2)
            if front {
                c.draw([rows[0]], at: 1, 1, kind: .head, outline: .hard)
                c.draw(Array(rows[2...]), at: 1, 3, kind: .body, outline: .hard)
            } else {
                c.draw(rows, at: 1, 1, kind: .body, outline: .hard)
            }
            return c
        }
    }

    // MARK: Cosy nap spots
    //
    // Each comes as a back part (drawn behind a napping cat) and a front part drawn over it, so the
    // cat looks like it's inside. `napLift` is how high above the bottom the cat lies, in pixels.

    static let boxWidth = 20
    /// Low enough that only the ears of a cat napping inside show above the front.
    static let boxNapLift: CGFloat = 2

    @MainActor static func box(front: Bool) -> Art {
        cached(front ? "boxFront" : "boxBack") {
            let rows = [
                "ee................ee",
                "eAe..............eAe",
                "aAAAAAAAAAAAAAAAAAAa",
                "aNNNNNNNNNNNNNNNNNNa",
                "aNNNNNNNNNNNNNNNNNNa",
                "AAAAAAAAAeeAAAAAAAAA",
                "AAAAAAAAAeeAAAAAAAAA",
                "AAAAAAAAAeeAAAAAAAAA",
                "AAAAAAAAAeeAAAAAAAAA",
                "aAAAAAAAAeeAAAAAAAAa",
                "aaaaaaaaaaaaaaaaaaaa",
            ]
            var c = PixelCanvas(width: boxWidth + 2, height: rows.count + 2)
            if front {
                c.draw(Array(rows[5...]), at: 1, 6, kind: .body, outline: .hard)
            } else {
                c.draw(rows, at: 1, 1, kind: .body, outline: .hard)
            }
            return c
        }
    }

    /// A taped-up box: no way in, but a fine thing to sleep on top of.
    @MainActor static func closedBox() -> Art {
        cached("closedBox") {
            let rows = [
                "aaaaaaaaaaaaaaaaaaaa",
                "AAAAAAAAAeeAAAAAAAAA",
                "AAAAAAAAAeeAAAAAAAAA",
                "aaaaaaaaaeeaaaaaaaaa",
                "AAAAAAAAAeeAAAAAAAAA",
                "AAAAAAAAAeeAAAAAAAAA",
                "AAAAAAAAAeeAAAAAAAAA",
                "aAAAAAAAAeeAAAAAAAAa",
                "aaaaaaaaaaaaaaaaaaaa",
            ]
            var c = PixelCanvas(width: boxWidth + 2, height: rows.count + 2)
            c.draw(rows, at: 1, 1, kind: .body, outline: .hard)
            return c
        }
    }

    static let laundryWidth = 28
    static let laundryNapLift: CGFloat = 3

    /// A pile of clothes: jeans at the bottom, a striped sweater, a T-shirt and a sock on top.
    /// Each garment has its own outline so they read as separate things.
    @MainActor static func laundry(front: Bool) -> Art {
        cached(front ? "laundryFront" : "laundryBack") {
            let jeans = [
                "...BBBBBBBBBBBBBBBBBBBBBB...",
                ".BBBBLBBBBBBBBBBBBBBBLBBBBB.",
                "BBBBBLBBBBBBBBBBBBBBBLBBBBBB",
                "BBBBBBBBBBBBB..BBBBBBBBBBBBB",
            ]
            let sweater = [
                ".....hhZZhh....",
                "...hhZZhhZZhh..",
                "..hhZZhhZZhhZh.",
                ".hhZZhhZZhhZZhh",
                "hhZZhhZZhhZZhh.",
                "hh.............",
                "ZZ.............",
            ]
            let shirt = [
                ".....EEEE.......",
                "..EEEEEEEEEE....",
                ".EEEEEEEEEEEEE..",
                "EEEEEEEEEEEEEEE.",
                "EEEEEEEEEEEEEEEE",
                ".EEEEEEEEEEEEEE.",
            ]
            let sock = [
                "PP...",
                "PP...",
                "PPPZZ",
            ]
            var c = PixelCanvas(width: laundryWidth + 2, height: 17)
            if front {
                // The jeans in front hide the napping cat's lower half.
                c.draw(jeans, at: 1, 12, kind: .body, outline: .hard)
            } else {
                c.draw(jeans, at: 1, 12, kind: .body, outline: .hard)
                c.draw(shirt, at: 12, 6, kind: .leg, outline: .hard)
                c.draw(sweater, at: 1, 5, kind: .arm, outline: .hard)
                c.draw(sock, at: 13, 2, kind: .tail, outline: .hard)
            }
            return c
        }
    }

    static let potWidth = 22
    static let potNapLift: CGFloat = 6

    /// A potted plant. When a cat naps in it the plant is squashed flat, and the crushed leaves
    /// stick out from under the cat (they're part of the front, drawn over it).
    @MainActor static func flowerPot(squashed: Bool, front: Bool) -> Art {
        cached("pot\(squashed)\(front)") {
            let upright = [
                "..........X...........",
                ".........jJJj.........",
                "......jj.jJJj.jj......",
                ".....jJJj.JJ.jJJj.....",
                "......jJJjJJjJJj......",
                "........jJJJJj........",
                "..........JJ..........",
                "..........JJ..........",
            ]
            let crushed = [
                "......................",
                "......................",
                "......................",
                "......................",
                "......................",
                "X.....................",
                "jJj.....j....j....jJj.",
                "jJJJj..jJj..jJj..jJJJj",
            ]
            let pot = [
                "....FFFFFFFFFFFFFF....",
                ".....QQQQQQQQQQQQ.....",
                ".....QQQQQQQQQQQQ.....",
                "......QQQQQQQQQQ......",
                "......QQQQQQQQQQ......",
                ".......qqqqqqqq.......",
            ]
            let soil = ["....SSSSSSSSSSSSSS...."]
            var c = PixelCanvas(width: potWidth + 2, height: upright.count + pot.count + 2)
            let potRow = 1 + upright.count
            switch (squashed, front) {
            case (false, false):
                c.draw(upright, at: 1, 1, kind: .head, outline: .soft)
                c.draw(soil, at: 1, potRow - 1, kind: .body, outline: .none)
                c.draw(pot, at: 1, potRow, kind: .body, outline: .hard)
            case (false, true):
                c.draw(pot, at: 1, potRow, kind: .body, outline: .hard)
            case (true, false):
                c.draw(soil, at: 1, potRow - 1, kind: .body, outline: .none)
                c.draw(pot, at: 1, potRow, kind: .body, outline: .hard)
            case (true, true):
                c.draw(pot, at: 1, potRow, kind: .body, outline: .hard)
                c.draw(crushed, at: 1, 1, kind: .head, outline: .hard)
            }
            return c
        }
    }

    static let wardrobeWidth = 26
    static let wardrobeHeight = 38
    static let wardrobeNapLift: CGFloat = 3

    /// A wardrobe with an open bottom shelf a cat can curl up on, and a top it can climb onto.
    @MainActor static func wardrobe(front: Bool) -> Art {
        cached(front ? "wardrobeFront" : "wardrobeBack") {
            let w = wardrobeWidth
            var rows: [String] = []
            rows.append(String(repeating: "H", count: w))
            rows.append(String(repeating: "D", count: w))
            for i in 0..<20 {
                let knob = i == 10 ? "x" : "W"
                rows.append("DD" + String(repeating: "W", count: 9) + knob + "DD" + knob + String(repeating: "W", count: 9) + "DD")
            }
            rows.append(String(repeating: "D", count: w))
            for _ in 0..<11 { rows.append("DD" + String(repeating: "n", count: w - 4) + "DD") }
            rows.append(String(repeating: "H", count: w))
            rows.append(String(repeating: "D", count: w))
            rows.append("bb" + String(repeating: ".", count: w - 4) + "bb")
            var c = PixelCanvas(width: w + 2, height: rows.count + 2)
            if front {
                // The sides and the edge above the open shelf, drawn over a napping cat.
                let cubby = rows.count - 3 - 11
                var frame: [String] = [String(repeating: "D", count: w)]
                for _ in 0..<11 { frame.append("DD" + String(repeating: ".", count: w - 4) + "DD") }
                frame += Array(rows[(rows.count - 3)...])
                c.draw(frame, at: 1, 1 + cubby - 1, kind: .body, outline: .none)
            } else {
                c.draw(rows, at: 1, 1, kind: .body, outline: .hard)
            }
            return c
        }
    }

    static let yarnSize = 7

    @MainActor static func yarn(frame: Int) -> Art {
        let f = frame % 3
        return cached("yarn\(f)") {
            let frames = [
                ["..YYY..", ".YyYYY.", "YYYyYYY", "YyYYyYY", "YYyYYYY", ".YYYyY.", "..YYY.."],
                ["..YYY..", ".YYyYY.", "YyYYYyY", "YYyYYYY", "YYYyYyY", ".YyYYY.", "..YYY.."],
                ["..YYY..", ".YYYyY.", "YYyYYYY", "YYYyYYY", "YyYYyYY", ".YYyYY.", "..YYY.."],
            ]
            var c = PixelCanvas(width: yarnSize + 2, height: yarnSize + 2)
            c.draw(frames[f], at: 1, 1, kind: .body, outline: .hard)
            return c
        }
    }
}
