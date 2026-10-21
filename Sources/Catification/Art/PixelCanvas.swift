import CoreGraphics
import Foundation

enum PartKind: UInt8 {
    case head, body, leg, tail, arm, fx
}

enum OutlineMode {
    case none
    /// Outline only into empty cells, so parts merge into one silhouette.
    case soft
    /// Outline over anything, so the part stands out in front of what is behind it.
    case hard
}

/// One sprite pixel. Colour is resolved later from `code` by a palette, so the same
/// art can be re-coloured for every cat. `lx`/`ly` are coordinates local to the part,
/// which lets patterns (calico patches, colour points) move together with the part.
struct Cell {
    var code: Character
    var kind: PartKind
    var lx: Int
    var ly: Int
}

struct PixelCanvas {
    let width: Int
    let height: Int
    private(set) var cells: [Cell?]

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
        cells = Array(repeating: nil, count: width * height)
    }

    subscript(x: Int, y: Int) -> Cell? {
        guard x >= 0, y >= 0, x < width, y < height else { return nil }
        return cells[y * width + x]
    }

    mutating func stamp(_ pixels: [(x: Int, y: Int, code: Character)], kind: PartKind, origin: (x: Int, y: Int), outline: OutlineMode) {
        let w = width, h = height
        func inside(_ x: Int, _ y: Int) -> Bool { x >= 0 && y >= 0 && x < w && y < h }

        var filled = Set<Int>()
        for p in pixels where inside(p.x, p.y) { filled.insert(p.y * w + p.x) }

        if outline != .none {
            for p in pixels {
                for (dx, dy) in [(1, 0), (-1, 0), (0, 1), (0, -1)] {
                    let nx = p.x + dx, ny = p.y + dy
                    guard inside(nx, ny) else { continue }
                    let i = ny * w + nx
                    if filled.contains(i) { continue }
                    if outline == .soft, cells[i] != nil { continue }
                    cells[i] = Cell(code: "O", kind: kind, lx: 0, ly: 0)
                }
            }
        }
        for p in pixels where inside(p.x, p.y) {
            cells[p.y * w + p.x] = Cell(code: p.code, kind: kind, lx: p.x - origin.x, ly: p.y - origin.y)
        }
    }

    /// Draws ASCII art; `.` is transparent.
    mutating func draw(_ rows: [String], at x: Int, _ y: Int, kind: PartKind, outline: OutlineMode = .soft) {
        var pixels: [(x: Int, y: Int, code: Character)] = []
        for (r, row) in rows.enumerated() {
            for (c, ch) in row.enumerated() where ch != "." {
                pixels.append((x + c, y + r, ch))
            }
        }
        stamp(pixels, kind: kind, origin: (x, y), outline: outline)
    }

    /// A 1px tail from root to tip; every other pixel counting from the tip is a stripe.
    mutating func tail(_ points: [(Int, Int)], outline: OutlineMode = .soft) {
        guard let root = points.first else { return }
        let n = points.count
        let pixels = points.enumerated().map { i, p in
            (x: p.0, y: p.1, code: Character((n - 1 - i) % 2 == 0 ? "S" : "F"))
        }
        stamp(pixels, kind: .tail, origin: (root.0, root.1), outline: outline)
    }
}

enum PixelRenderer {
    static let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

    static func image(_ canvas: PixelCanvas, flip: Bool = false, scale: Int = 1, color: (Cell) -> RGB?) -> CGImage {
        let w = canvas.width * scale, h = canvas.height * scale
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        for y in 0..<canvas.height {
            for x in 0..<canvas.width {
                guard let cell = canvas[x, y], let rgb = color(cell) else { continue }
                let (r, g, b) = rgb.bytes
                let px = flip ? canvas.width - 1 - x : x
                for sy in 0..<scale {
                    for sx in 0..<scale {
                        let i = ((y * scale + sy) * w + px * scale + sx) * 4
                        bytes[i] = r
                        bytes[i + 1] = g
                        bytes[i + 2] = b
                        bytes[i + 3] = 255
                    }
                }
            }
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
            space: colorSpace,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
        )!
    }

    /// Bounding box of non-empty cells, in pixels with y going up from the canvas bottom.
    static func opaqueBounds(_ canvas: PixelCanvas) -> CGRect {
        var minX = Int.max, minY = Int.max, maxX = Int.min, maxY = Int.min
        for y in 0..<canvas.height {
            for x in 0..<canvas.width where canvas[x, y] != nil {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard minX <= maxX else { return .zero }
        return CGRect(x: minX, y: canvas.height - 1 - maxY, width: maxX - minX + 1, height: maxY - minY + 1)
    }
}
