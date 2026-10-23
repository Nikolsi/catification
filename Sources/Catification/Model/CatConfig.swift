import Foundation

enum FurPattern: String, Codable, CaseIterable, Identifiable {
    case solid, tabby, calico, points

    var id: String { rawValue }

    var title: String {
        switch self {
        case .solid: L("Solid")
        case .tabby: L("Tabby")
        case .calico: L("Spotted")
        case .points: L("Colorpoint")
        }
    }

    var secondaryTitle: String {
        switch self {
        case .solid: L("Second color")
        case .tabby: L("Stripes")
        case .calico: L("Spots")
        case .points: L("Face, ears and paws")
        }
    }
}

struct Traits {
    var curiosity: Double
    var playfulness: Double
    var laziness: Double
    var affection: Double
    var patience: Double
    var speed: Double
}

enum Personality: String, Codable, CaseIterable, Identifiable {
    case playful, lazy, curious, affectionate, grumpy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .playful: L("Playful")
        case .lazy: L("Lazy")
        case .curious: L("Curious")
        case .affectionate: L("Affectionate")
        case .grumpy: L("Grumpy")
        }
    }

    var details: String {
        switch self {
        case .playful: L("Zooms around, starts chases and stalks other cats.")
        case .lazy: L("Sleeps a lot, walks slowly and puts up with squishing.")
        case .curious: L("Keeps exploring everything from end to end.")
        case .affectionate: L("Loves being petted and comes to the cursor on its own.")
        case .grumpy: L("Hates being squished and takes offence quickly. Still cute, though.")
        }
    }

    var traits: Traits {
        switch self {
        case .playful: Traits(curiosity: 1.0, playfulness: 1.9, laziness: 0.6, affection: 1.0, patience: 1.0, speed: 1.15)
        case .lazy: Traits(curiosity: 0.5, playfulness: 0.6, laziness: 2.0, affection: 1.1, patience: 1.6, speed: 0.8)
        case .curious: Traits(curiosity: 1.9, playfulness: 1.0, laziness: 0.8, affection: 0.9, patience: 1.0, speed: 1.05)
        case .affectionate: Traits(curiosity: 0.9, playfulness: 1.0, laziness: 1.0, affection: 2.0, patience: 1.4, speed: 1.0)
        case .grumpy: Traits(curiosity: 1.0, playfulness: 0.7, laziness: 1.1, affection: 0.5, patience: 0.4, speed: 1.0)
        }
    }
}

enum CatSize: String, Codable, CaseIterable, Identifiable {
    case small, normal, large

    var id: String { rawValue }

    var title: String {
        switch self {
        case .small: L("Kitten")
        case .normal: L("Normal")
        case .large: L("Big")
        }
    }

    var factor: Double {
        switch self {
        case .small: 0.75
        case .normal: 1.0
        case .large: 1.3
        }
    }
}

/// Everything that affects how the sprite looks; used as the sprite cache key.
struct CatAppearance: Hashable {
    var fur: RGB
    var secondary: RGB
    var belly: RGB
    var eyes: RGB
    var pattern: FurPattern
}

struct CatConfig: Codable, Identifiable, Hashable {
    var id = UUID()
    var name: String
    var fur: RGB
    var secondary: RGB
    var belly: RGB
    var eyes: RGB
    var pattern: FurPattern
    var personality: Personality
    var size: CatSize
    /// The owner's own words about this cat: its story, quirks, what it loves.
    var about = ""
    /// A customised character. Nil means "behave like the personality preset".
    var brain: CatBrain?

    /// The character the cat actually runs on.
    var effectiveBrain: CatBrain { brain ?? .preset(personality) }

    var appearance: CatAppearance {
        CatAppearance(fur: fur, secondary: secondary, belly: belly, eyes: eyes, pattern: pattern)
    }

    init(name: String, coat: CoatPreset, personality: Personality, size: CatSize = .normal) {
        self.name = name
        fur = coat.fur
        secondary = coat.secondary
        belly = coat.belly
        eyes = coat.eyes
        pattern = coat.pattern
        self.personality = personality
        self.size = size
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, fur, secondary, belly, eyes, pattern, personality, size, about, brain
    }

    // Written out so cats saved by older versions (without `about` and `brain`) still load.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        fur = try c.decode(RGB.self, forKey: .fur)
        secondary = try c.decode(RGB.self, forKey: .secondary)
        belly = try c.decode(RGB.self, forKey: .belly)
        eyes = try c.decode(RGB.self, forKey: .eyes)
        pattern = try c.decode(FurPattern.self, forKey: .pattern)
        personality = try c.decode(Personality.self, forKey: .personality)
        size = try c.decode(CatSize.self, forKey: .size)
        about = try c.decodeIfPresent(String.self, forKey: .about) ?? ""
        brain = try c.decodeIfPresent(CatBrain.self, forKey: .brain)
    }

    mutating func apply(_ coat: CoatPreset) {
        fur = coat.fur
        secondary = coat.secondary
        belly = coat.belly
        eyes = coat.eyes
        pattern = coat.pattern
    }

    static var names: [String] {
        [
            "Whiskers", "Oscar", "Fluffy", "Luna", "Simba", "Muffin", "Peaches", "Mittens", "Bella", "Felix",
            "Bagheera", "Sammy", "Plushie", "Smokey", "Bagel", "Mars", "Dumpling", "Toffee", "Pumpkin", "Sprat",
        ].map(L)
    }

    static var defaults: [CatConfig] {
        [
            CatConfig(name: L("Ginger"), coat: .ginger, personality: .playful),
            CatConfig(name: L("Midnight"), coat: .tuxedo, personality: .curious),
            CatConfig(name: L("Marshmallow"), coat: .siamese, personality: .lazy),
        ]
    }
}

struct CoatPreset: Identifiable {
    let id: String
    let title: String
    let fur: RGB
    let secondary: RGB
    let belly: RGB
    let eyes: RGB
    let pattern: FurPattern

    init(_ id: String, _ title: String, fur: UInt32, secondary: UInt32, belly: UInt32, eyes: UInt32, _ pattern: FurPattern) {
        self.id = id
        self.title = title
        self.fur = RGB(hex: fur)
        self.secondary = RGB(hex: secondary)
        self.belly = RGB(hex: belly)
        self.eyes = RGB(hex: eyes)
        self.pattern = pattern
    }

    static let ginger = CoatPreset("ginger", L("Ginger tabby"), fur: 0xF0A04B, secondary: 0xC2671E, belly: 0xFFE6C7, eyes: 0x7BC043, .tabby)
    static let black = CoatPreset("black", L("Black"), fur: 0x3A3740, secondary: 0x2A272F, belly: 0x4D4954, eyes: 0xF2D23C, .solid)
    static let tuxedo = CoatPreset("tuxedo", L("Tuxedo"), fur: 0x34323A, secondary: 0x34323A, belly: 0xF4F1EA, eyes: 0x9BD85A, .solid)
    static let gray = CoatPreset("gray", L("Grey tabby"), fur: 0x9AA0A8, secondary: 0x5E636C, belly: 0xD9DCE0, eyes: 0xE8B23A, .tabby)
    static let white = CoatPreset("white", L("White"), fur: 0xF5F2EC, secondary: 0xE2DDD3, belly: 0xFFFFFF, eyes: 0x67B7F0, .solid)
    static let calico = CoatPreset("calico", L("Calico"), fur: 0xE9984A, secondary: 0x3B3540, belly: 0xFAF6EE, eyes: 0xC9A23A, .calico)
    static let siamese = CoatPreset("siamese", L("Siamese"), fur: 0xF1E4CC, secondary: 0x5B4033, belly: 0xFAF3E4, eyes: 0x4FA3E8, .points)
    static let british = CoatPreset("british", L("British Blue"), fur: 0x8A97A8, secondary: 0x75839A, belly: 0x9EAABA, eyes: 0xF0A030, .solid)
    static let peach = CoatPreset("peach", L("Peach"), fur: 0xF7D2A4, secondary: 0xE3A867, belly: 0xFFF1DE, eyes: 0x8FC75A, .tabby)

    static let all: [CoatPreset] = [ginger, black, tuxedo, gray, white, calico, siamese, british, peach]
}
