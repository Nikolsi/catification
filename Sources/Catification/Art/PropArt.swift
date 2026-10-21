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
