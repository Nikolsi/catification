import CoreGraphics

/// A tiny 5px-tall pixel font, just enough for a cat to do ballistics in its head.
enum PixelFont {
    private static let glyphs: [Character: [String]] = [
        "0": ["###", "#.#", "#.#", "#.#", "###"],
        "1": [".#.", "##.", ".#.", ".#.", "###"],
        "2": ["###", "..#", "###", "#..", "###"],
        "3": ["###", "..#", ".##", "..#", "###"],
        "4": ["#.#", "#.#", "###", "..#", "..#"],
        "5": ["###", "#..", "###", "..#", "###"],
        "6": ["###", "#..", "###", "#.#", "###"],
        "7": ["###", "..#", ".#.", ".#.", ".#."],
        "8": ["###", "#.#", "###", "#.#", "###"],
        "9": ["###", "#.#", "###", "..#", "###"],
        "x": ["...", "...", "#.#", ".#.", "#.#"],
        "y": ["...", "#.#", "#.#", ".#.", ".#."],
        "v": ["...", "...", "#.#", "#.#", ".#."],
        "t": [".#.", "###", ".#.", ".#.", ".##"],
        "g": [".##", "#.#", ".##", "..#", "##."],
        "h": ["#..", "#..", "###", "#.#", "#.#"],
        "s": [".##", "#..", ".#.", "..#", "##."],
        "i": [".#.", "...", ".#.", ".#.", ".#."],
        "n": ["...", "...", "##.", "#.#", "#.#"],
        "c": ["...", "...", ".##", "#..", ".##"],
        "o": ["...", "...", ".#.", "#.#", ".#."],
        "=": ["...", "###", "...", "###", "..."],
        "+": ["...", ".#.", "###", ".#.", "..."],
        "-": ["...", "...", "###", "...", "..."],
        ".": [".", ".", ".", ".", "#"],
        "°": ["##", "##", "..", "..", ".."],
        "?": ["##.", "..#", ".#.", "...", ".#."],
        "!": ["#", "#", "#", ".", "#"],
        "²": ["##", ".#", "#.", "##", ".."],
        "₀": ["...", "...", "###", "#.#", "###"],
        "→": ["....", "..#.", "####", "..#.", "...."],
        "π": ["#####", ".#.#.", ".#.#.", ".#.#.", ".#..#"],
        "√": ["...##", "...#.", "#..#.", ".#.#.", "..#.."],
        "∫": ["..##", ".#..", ".#..", ".#..", "##.."],
        "Σ": ["####", "#...", ".#..", "#...", "####"],
        "Δ": ["..#..", ".#.#.", ".#.#.", "#...#", "#####"],
        "θ": [".#.", "#.#", "###", "#.#", ".#."],
        "∞": [".....", ".#.#.", "#.#.#", ".#.#.", "....."],
        " ": ["..", "..", "..", "..", ".."],
    ]

    static let colors = [RGB(hex: 0xF2F7FF), RGB(hex: 0x9EE6FF), RGB(hex: 0xFFE59A), RGB(hex: 0xC8F7A6)]
    private static let outline = RGB(hex: 0x1C2236)

    @MainActor private static var cache: [String: EmoteArt.Sprite] = [:]

    @MainActor
    static func sprite(_ text: String, color: RGB) -> EmoteArt.Sprite {
        let key = "\(text)|\(color.r),\(color.g),\(color.b)"
        if let s = cache[key] { return s }
        if cache.count > 200 { cache.removeAll() }

        let chars = text.compactMap { glyphs[$0] }
        let width = chars.reduce(0) { $0 + $1[0].count } + max(0, chars.count - 1) + 2
        var canvas = PixelCanvas(width: width, height: 7)
        var pixels: [(x: Int, y: Int, code: Character)] = []
        var cursor = 1
        for glyph in chars {
            for (row, line) in glyph.enumerated() {
                for (col, ch) in line.enumerated() where ch == "#" {
                    pixels.append((cursor + col, row + 1, "T"))
                }
            }
            cursor += glyph[0].count + 1
        }
        canvas.stamp(pixels, kind: .fx, origin: (0, 0), outline: .hard)
        let outline = Self.outline
        let image = PixelRenderer.image(canvas) { $0.code == "T" ? color : outline }
        let sprite = EmoteArt.Sprite(image: image, width: canvas.width, height: canvas.height)
        cache[key] = sprite
        return sprite
    }
}
