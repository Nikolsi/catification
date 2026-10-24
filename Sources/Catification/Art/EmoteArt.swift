import CoreGraphics

enum EmoteKind: CaseIterable {
    case heart, zzz, anger, exclaim, note, question, check, fish, target, fluff, paper, bone, sparkBlue, sparkOrange, drop

    fileprivate var rows: [String] {
        switch self {
        case .heart: [".RR.RR.", "RWRRRRR", "RRRRRRR", ".RRRRR.", "..RRR..", "...R..."]
        case .zzz: ["ZZZZ", "..Z.", ".Z..", "ZZZZ"]
        case .anger: [".R.R.", "RR.RR", ".....", "RR.RR", ".R.R."]
        case .exclaim: ["YY", "YY", "YY", "..", "YY"]
        case .note: [".NNNN", ".N..N", ".N..N", "NN.NN", "NN.NN"]
        case .question: [".QQ.", "Q..Q", "..Q.", "....", "..Q."]
        case .check: ["....G", "...GG", "G.GG.", "GGG..", ".G..."]
        case .fish: [".FFF..F", "FKFFFFF", ".FFF..F"]
        case .target: ["...T...", "..TTT..", ".T...T.", "TT.T.TT", ".T...T.", "..TTT..", "...T..."]
        case .fluff: ["X"]
        case .paper: [".P.", "PPP", ".PP"]
        case .bone: ["B...B", "BBBBB", "B...B"]
        case .sparkBlue, .sparkOrange: [".X.", "XXX", ".X."]
        case .drop: ["X"]
        }
    }

    fileprivate var palette: [Character: RGB] {
        switch self {
        case .heart: ["R": RGB(hex: 0xFF5A8A), "W": RGB(hex: 0xFFFFFF)]
        case .zzz: ["Z": RGB(hex: 0xF4F7FF)]
        case .anger: ["R": RGB(hex: 0xFF4433)]
        case .exclaim: ["Y": RGB(hex: 0xFFD43B)]
        case .note: ["N": RGB(hex: 0x8FD7FF)]
        case .question: ["Q": RGB(hex: 0xFFF1A8)]
        case .check: ["G": RGB(hex: 0x7CE07C)]
        case .fish: ["F": RGB(hex: 0x8FC3E8), "K": RGB(hex: 0x1E2A3A)]
        case .target: ["T": RGB(hex: 0x9EE6FF)]
        case .fluff: ["X": RGB(hex: 0xE8D6AE)]
        case .paper: ["P": RGB(hex: 0xF4F4F0)]
        case .bone: ["B": RGB(hex: 0xF2EAD8)]
        case .sparkBlue: ["X": RGB(hex: 0x6CC8FF)]
        case .sparkOrange: ["X": RGB(hex: 0xFFB347)]
        case .drop: ["X": RGB(hex: 0x9FD8FF)]
        }
    }

    fileprivate var outline: RGB? {
        switch self {
        case .heart: RGB(hex: 0x6E1736)
        case .zzz: RGB(hex: 0x2E3350)
        case .anger: RGB(hex: 0x5E120B)
        case .exclaim: RGB(hex: 0x4D3A00)
        case .note: RGB(hex: 0x163C57)
        case .question: RGB(hex: 0x4A3F10)
        case .check: RGB(hex: 0x154A15)
        case .fish: RGB(hex: 0x1E2A3A)
        case .target: RGB(hex: 0x14324A)
        case .paper: RGB(hex: 0x6B6B6B)
        case .bone: RGB(hex: 0x6B5E48)
        case .fluff, .sparkBlue, .sparkOrange, .drop: nil
        }
    }
}

enum EmoteArt {
    struct Sprite {
        let image: CGImage
        /// Size in sprite pixels.
        let width: Int
        let height: Int
    }

    static let sprites: [EmoteKind: Sprite] = {
        var result: [EmoteKind: Sprite] = [:]
        for kind in EmoteKind.allCases {
            let rows = kind.rows
            let margin = kind.outline == nil ? 0 : 1
            var c = PixelCanvas(width: rows[0].count + margin * 2, height: rows.count + margin * 2)
            c.draw(rows, at: margin, margin, kind: .fx, outline: kind.outline == nil ? .none : .hard)
            let palette = kind.palette
            let outline = kind.outline
            let image = PixelRenderer.image(c) { cell in
                cell.code == "O" ? outline : palette[cell.code]
            }
            result[kind] = Sprite(image: image, width: c.width, height: c.height)
        }
        return result
    }()
}
