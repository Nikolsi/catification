import XCTest
@testable import Catification

final class ArtTests: XCTestCase {
    func testSoftOutlineMergesHardOutlineSeparates() {
        var soft = PixelCanvas(width: 5, height: 3)
        soft.draw(["F"], at: 1, 1, kind: .body)
        soft.draw(["F"], at: 3, 1, kind: .leg, outline: .soft)
        // The cell between the two pixels was already an outline; a soft outline leaves it alone
        // and never paints over the first pixel.
        XCTAssertEqual(soft[1, 1]?.code, "F")
        XCTAssertEqual(soft[2, 1]?.code, "O")
        XCTAssertEqual(soft[2, 1]?.kind, .body)

        var hard = PixelCanvas(width: 5, height: 3)
        hard.draw(["FF"], at: 1, 1, kind: .body)
        hard.draw(["F"], at: 3, 1, kind: .head, outline: .hard)
        // A hard outline cuts into what's behind it.
        XCTAssertEqual(hard[2, 1]?.code, "O")
        XCTAssertEqual(hard[2, 1]?.kind, .head)
    }

    func testEveryAnimationHasFramesThatFitTheCanvas() {
        for anim in Anim.allCases {
            let frames = CatArt.frames[anim]
            XCTAssertFalse(frames?.isEmpty ?? true, "\(anim) has no frames")
            for canvas in frames ?? [] {
                XCTAssertEqual(canvas.width, CatArt.W)
                XCTAssertEqual(canvas.height, CatArt.H)
                let box = PixelRenderer.opaqueBounds(canvas)
                XCTAssertGreaterThan(box.width, 0, "\(anim) frame is empty")
            }
        }
    }

    func testEveryPresetRecoloursEveryCode() {
        let codes: [Character] = ["F", "S", "D", "B", "P", "E", "K", "O"]
        for preset in CoatPreset.all {
            let palette = CatPalette(CatAppearance(fur: preset.fur, secondary: preset.secondary, belly: preset.belly,
                                                   eyes: preset.eyes, pattern: preset.pattern))
            for code in codes {
                for kind in [PartKind.head, .body, .leg, .tail, .arm] {
                    XCTAssertNotNil(palette.color(Cell(code: code, kind: kind, lx: 2, ly: 3)), "\(preset.id) \(code)")
                }
            }
        }
    }

    @MainActor
    func testPixelFontRendersEveryFormulaGlyph() {
        for text in ["Δx=137", "θ=45°", "√2gh", "x²+y²", "sinθ", "cosθ", "v₀t", "t=0.74", "π", "∫", "Σ", "∞", "?"] {
            let sprite = PixelFont.sprite(text, color: PixelFont.colors[0])
            XCTAssertGreaterThan(sprite.width, 2, text)
            XCTAssertEqual(sprite.height, 7, text)
        }
    }

    // MARK: Standing out

    @MainActor
    func testRingIsTheSilhouetteGrownByOnePixel() {
        // A single opaque pixel: a plus sign without diagonals, a 3×3 square with them.
        var c = PixelCanvas(width: 1, height: 1)
        c.draw(["X"], at: 0, 0, kind: .fx, outline: .none)
        let dot = PixelRenderer.image(c) { _ in RGB(0, 0, 0) }
        func opaque(_ image: CGImage) -> Int {
            var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
            bytes.withUnsafeMutableBytes { buffer in
                CGContext(data: buffer.baseAddress, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                          space: PixelRenderer.colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)?
                    .draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            }
            return stride(from: 3, to: bytes.count, by: 4).filter { bytes[$0] > 0 }.count
        }
        let plus = HaloLayer.ring(of: dot, alpha: 0.5, diagonals: false)
        XCTAssertEqual(plus.width, 3)
        XCTAssertEqual(opaque(plus), 5)
        XCTAssertEqual(opaque(HaloLayer.ring(of: dot, alpha: 0.9, diagonals: true)), 9)
    }
}
