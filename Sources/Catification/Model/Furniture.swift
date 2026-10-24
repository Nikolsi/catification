import Foundation

enum WorldMode: String, Codable, CaseIterable, Identifiable {
    case menuBar, screen, desktop

    var id: String { rawValue }

    var title: String {
        switch self {
        case .menuBar: L("Menu bar only")
        case .screen: L("Whole screen, above windows")
        case .desktop: L("Desktop, behind windows")
        }
    }

    var details: String {
        switch self {
        case .menuBar: L("Cats stroll along the menu bar only.")
        case .screen: L("Cats roam the whole screen: the menu bar, shelves, window tops and the bottom edge.")
        case .desktop: L("Cats and furniture live on the desktop, behind your windows, and never get in the way.")
        }
    }

    var hasFurniture: Bool { self != .menuBar }
    var hasMenuBar: Bool { self != .desktop }
}

enum FurnitureKind: String, Codable, CaseIterable, Identifiable {
    case shelf, post, bed, bowl, trash, box, closedBox, wardrobe, flowerPot, fountain, laundryStack, laundryBasket, clothesChair

    var id: String { rawValue }

    var title: String {
        switch self {
        case .shelf: L("Shelf")
        case .post: L("Scratching post")
        case .bed: L("Cat bed")
        case .bowl: L("Bowl")
        case .trash: L("Trash can")
        case .box: L("Open box")
        case .closedBox: L("Closed box")
        case .wardrobe: L("Wardrobe")
        case .flowerPot: L("Flower pot")
        case .fountain: L("Water fountain")
        case .laundryStack: L("Clean laundry")
        case .laundryBasket: L("Laundry basket")
        case .clothesChair: L("Chair with clothes")
        }
    }

    /// Beds, bowls and the trash can are loose objects that fall onto whatever is below them.
    var isProp: Bool { self != .shelf && self != .post }

    /// Furniture a cat can curl up inside.
    var isNapSpot: Bool { [.bed, .box, .laundryBasket, .wardrobe, .flowerPot].contains(self) }

    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        // The old pile of laundry is a laundry basket now.
        guard let kind = raw == "laundry" ? .laundryBasket : FurnitureKind(rawValue: raw) else {
            throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Unknown furniture: \(raw)"))
        }
        self = kind
    }
}

/// Coordinates are in points relative to the bottom-left corner of the screen.
struct Furniture: Codable, Identifiable, Hashable {
    var id = UUID()
    var kind: FurnitureKind
    /// Shelf: left edge. Post, bed, bowl: centre.
    var x: Double
    /// Shelf: top surface. Bed, bowl: bottom. Post: unused, it always stands on the floor.
    var y: Double
    /// Shelf width.
    var width: Double = 0
    /// Post height.
    var height: Double = 0
    /// Bowl fill level, 0...1.
    var food: Double = 1
    /// Clean laundry a cat has slept on is covered in its fur, until it's washed.
    var fur: RGB?

    static func make(_ kind: FurnitureKind, at x: Double, _ y: Double) -> Furniture {
        switch kind {
        case .shelf: Furniture(kind: .shelf, x: x - 100, y: y, width: 200)
        case .post: Furniture(kind: .post, x: x, y: 0, height: 240)
        default: Furniture(kind: kind, x: x, y: y)
        }
    }

    /// A staircase from the floor to the menu bar: the scratching post, then shelves zigzagging up,
    /// each step low enough for a cat to jump.
    static func defaults(screenWidth w: Double, screenHeight h: Double, floor: Double) -> [Furniture] {
        let maxStep = 170.0
        let postHeight = 190.0
        let top = h - 40
        let postX = w * 0.86
        let steps = max(1, Int(((top - floor - postHeight) / maxStep).rounded(.up)))
        let stepHeight = (top - floor - postHeight) / Double(steps)

        var items = [Furniture(kind: .post, x: postX, y: floor, height: postHeight)]
        var stairs: [Furniture] = []
        for i in 0..<(steps - 1) {
            let centre = postX - (i % 2 == 0 ? 230 : 430)
            stairs.append(Furniture(kind: .shelf, x: centre - 90, y: floor + postHeight + stepHeight * Double(i + 1), width: 180))
        }
        items += stairs
        if stairs.count > 1 {
            items.append(Furniture(kind: .bed, x: stairs[1].x + 90, y: stairs[1].y))
        }
        // A lounge shelf on the left, one jump off the floor.
        let lounge = Furniture(kind: .shelf, x: w * 0.08, y: floor + 190, width: 230)
        items.append(lounge)
        items.append(Furniture(kind: .bowl, x: w * 0.3, y: floor))
        items.append(Furniture(kind: .fountain, x: w * 0.3 + 60, y: floor))
        // Where the Dock's Trash usually is.
        items.append(Furniture(kind: .trash, x: w - 70, y: floor))
        return items
    }

    /// Bumped when the default layout changes in a way that old saved layouts should be replaced.
    static let layoutVersion = 2
}
