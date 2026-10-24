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
        // Water fountain: white ceramic, its shade, and water
        "z": RGB(hex: 0xC9C3D6), "o": RGB(hex: 0x7FC8F8), "w": RGB(hex: 0xD8F0FF),
        // Laundry: wicker, dark denim, teal, pale pink, shaded white
        "i": RGB(hex: 0xE2C28A), "l": RGB(hex: 0xB08A52), "d": RGB(hex: 0x33589A), "t": RGB(hex: 0x4FB8AE),
        "p": RGB(hex: 0xF6C3D2), "s": RGB(hex: 0xC8C2D2),
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

    static let fountainWidth = 13

    /// A pet water fountain: a white ceramic body with a window onto the water tank, a bowl of
    /// water on top and a little jet bubbling up.
    @MainActor static func fountain(frame: Int) -> Art {
        cached("fountain\(frame % 3)") {
            let jet = [
                ["......w......", ".....wow....."],
                [".....w.w.....", "......o......"],
                ["...w.....w...", ".....wow....."],
            ][frame % 3]
            let body = [
                "..ooooooooo..",
                ".ZZZZZZZZZZZ.",
                ".ZoooooooooZ.",
                ".ZowwooooooZ.",
                ".ZZZZZZZZZZz.",
                "..ZZZZZZZZz..",
                "..zzzzzzzzz..",
            ]
            var c = PixelCanvas(width: fountainWidth + 2, height: jet.count + body.count + 2)
            c.draw(body, at: 1, 1 + jet.count, kind: .body, outline: .hard)
            // The jet and drops float above the bowl, unoutlined.
            c.draw(jet, at: 1, 1, kind: .fx, outline: .none)
            return c
        }
    }

    // MARK: Laundry

    static let stackWidth = 22

    /// Clean laundry, neatly folded: a towel, a T-shirt, a sweater, and a shirt with its collar on top.
    /// After a cat has slept on it, `fur` scatters tufts of that cat's coat over it.
    @MainActor static func laundryStack(fur: RGB? = nil) -> Art {
        let key = "stack" + (fur.map { "\($0.bytes)" } ?? "")
        if let art = cache[key] { return art }
        let canvas = stackCanvas(furred: fur != nil)
        let image = PixelRenderer.image(canvas) { cell in
            switch cell.code {
            case "O": outline
            case "1": fur
            case "2": fur?.scaled(0.8)
            default: palette[cell.code]
            }
        }
        let art = Art(image: image, width: canvas.width, height: canvas.height)
        cache[key] = art
        return art
    }

    private static func stackCanvas(furred: Bool) -> PixelCanvas {
        let layers: [(Character, Character)] = [("Z", "s"), ("L", "U"), ("p", "P"), ("t", "J")]
        var c = PixelCanvas(width: stackWidth + 2, height: layers.count * 3 + 3)
        for (i, (fabric, shade)) in layers.enumerated() {
            let inset = i == layers.count - 1 ? 1 : 0
            let w = stackWidth - inset * 2
            let top = "." + String(repeating: fabric, count: w - 2) + "."
            let middle = String(repeating: fabric, count: w / 2 - 1) + String(shade) + String(repeating: fabric, count: w - w / 2)
            let bottom = String(repeating: shade, count: w)
            c.draw([top, middle, bottom], at: 1 + inset, 1 + (layers.count - 1 - i) * 3 + 1, kind: .body, outline: .hard)
        }
        // A collar on the shirt at the top.
        c.draw(["ZZ.ZZ", ".ZZZ."], at: 1 + stackWidth / 2 - 2, 2, kind: .fx, outline: .none)
        if furred {
            // Cat hair everywhere, mostly where it lay on top.
            let tufts: [(Int, Int, String)] = [
                (3, 2, "11"), (7, 3, "2"), (9, 2, "1"), (15, 2, "11"), (19, 3, "1"), (10, 4, "22"), (13, 3, "1"), (5, 4, "1"),
                (17, 4, "2"), (3, 6, "1"), (12, 6, "2"), (20, 7, "2"), (6, 9, "1"), (17, 10, "1"), (2, 12, "2"),
            ]
            for (x, y, wisp) in tufts {
                c.draw([wisp], at: x, y, kind: .fx, outline: .none)
            }
        }
        return c
    }

    static let basketWidth = 24
    static let basketNapLift: CGFloat = 4

    /// A wicker laundry basket, clothes spilling over the rim. The front hides a napping cat's lower half.
    @MainActor static func laundryBasket(front: Bool) -> Art {
        cached(front ? "basketFront" : "basketBack") {
            var body = ["llllllllllllllllllllllll"]
            for row in 0..<7 {
                let a = row % 2 == 0 ? "iiil" : "liii"
                var line = String(repeating: a, count: basketWidth / 4)
                if row == 6 { line = "." + line.dropFirst().dropLast() + "." }
                body.append(line)
            }
            let spill = [
                "..........EE........ZP..",
                ".....hZ..EEEE.......PZ..",
                "...hZhhZhEEEEE....tttZP.",
                ".hhZhhZhhEEEEEEtttttttt.",
            ]
            var c = PixelCanvas(width: basketWidth + 2, height: body.count + spill.count + 4)
            if !front {
                c.draw(spill, at: 1, 1, kind: .leg, outline: .hard)
            }
            c.draw(body, at: 1, 1 + spill.count, kind: .body, outline: .hard)
            // A sleeve and a towel corner hanging over the rim, in front.
            c.draw(["hZ", "ZZ", "hZ", "ZZ", "hh"], at: 3, 1 + spill.count, kind: .arm, outline: .hard)
            c.draw(["ttt", "tt.", "t.."], at: 19, 1 + spill.count, kind: .arm, outline: .hard)
            return c
        }
    }

    static let chairWidth = 18
    /// Height of the heap of clothes on the seat, from the floor, in sprite pixels.
    static let chairTop = 15

    /// A chair piled with clothes: a shirt over the back, a heap on the seat a cat can sleep on.
    @MainActor static func clothesChair() -> Art {
        cached("chair") {
            var c = PixelCanvas(width: chairWidth + 2, height: 28)
            // Back legs and backrest, front legs, seat.
            c.draw(Array(repeating: "WD", count: 25), at: 2, 1, kind: .leg, outline: .hard)
            c.draw(Array(repeating: "WD", count: 10), at: 16, 16, kind: .leg, outline: .hard)
            c.draw(["HHHHHHHHHHHHHHHH", "WWWWWWWWWWWWWWWW"], at: 2, 15, kind: .body, outline: .hard)
            c.draw(["WWW"], at: 2, 5, kind: .body, outline: .hard)
            // A shirt over the backrest, hanging down both sides.
            c.draw([
                ".ttttt.",
                "tttJttt",
                "tt...tt",
                "tt...tt",
                "tJ...tt",
                "tt....t",
                "J.....J",
            ], at: 0, 1, kind: .arm, outline: .hard)
            // Clothes heaped on the seat.
            c.draw([
                "....PPPPP......",
                "..BBPPPPPPP.EE.",
                ".BBBBBBBPPEEEEE",
                "BBBBBBBBBBBBEEE",
            ], at: 4, 11, kind: .tail, outline: .hard)
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


    /// A pile of clothes: jeans at the bottom, a striped sweater, a T-shirt and a sock on top.
    /// Each garment has its own outline so they read as separate things.

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
