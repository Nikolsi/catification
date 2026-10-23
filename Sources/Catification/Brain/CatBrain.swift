import CryptoKit
import Foundation

/// Something a cat can decide to do. Each one maps onto an existing behaviour in `Cat`.
enum CatAction: String, Codable, CaseIterable, CodingKeyRepresentable, Identifiable {
    case idle, sit, groom, wander, explore, zoomies, nap, scratch, rummage, play, chaseBall, visitCursor

    var id: String { rawValue }

    var title: String {
        switch self {
        case .idle: L("Stand around")
        case .sit: L("Sit")
        case .groom: L("Groom")
        case .wander: L("Stroll")
        case .explore: L("Explore")
        case .zoomies: L("Zoomies")
        case .nap: L("Nap")
        case .scratch: L("Scratch the post")
        case .rummage: L("Rummage in the trash")
        case .play: L("Play with other cats")
        case .chaseBall: L("Chase the yarn")
        case .visitCursor: L("Come for cuddles")
        }
    }
}

/// Favourite places, used when a cat picks somewhere to nap.
enum CatPlace: String, Codable, CaseIterable, CodingKeyRepresentable, Identifiable {
    case bed, high, friends, perch, shelf, menuBar, floor, windows, cursor, bowl, trash, box, laundry, wardrobe, flowerPot

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bed: L("In the cat bed")
        case .high: L("Up high")
        case .friends: L("Next to a friend")
        case .perch: L("On the scratching post")
        case .shelf: L("On a shelf")
        case .menuBar: L("On the menu bar")
        case .floor: L("On the floor")
        case .windows: L("On top of a window")
        case .cursor: L("Near your cursor")
        case .bowl: L("By the food bowl")
        case .trash: L("By the trash can")
        case .box: L("In a cardboard box")
        case .laundry: L("In the pile of laundry")
        case .wardrobe: L("On the wardrobe's bottom shelf")
        case .flowerPot: L("In the flower pot")
        }
    }

    /// Furniture this spot is inside of, if any.
    var furniture: FurnitureKind? {
        switch self {
        case .bed: .bed
        case .box: .box
        case .laundry: .laundry
        case .wardrobe: .wardrobe
        case .flowerPot: .flowerPot
        default: nil
        }
    }

    /// An ordinary cat likes its bed and napping next to friends; any other spot is a quirk.
    var defaultPreference: Double {
        self == .bed || self == .friends ? 1 : 0
    }
}

/// Things that happen to a cat, which it may react to.
enum CatEvent: String, Codable, CaseIterable, Identifiable {
    case petted, squished, pickedUp, droppedHard, missedJump, wokeUp, ate, greeted

    var id: String { rawValue }

    var title: String {
        switch self {
        case .petted: L("Petted")
        case .squished: L("Squished")
        case .pickedUp: L("Picked up")
        case .droppedHard: L("Dropped from high up")
        case .missedJump: L("Missed a jump")
        case .wokeUp: L("Woke up")
        case .ate: L("Ate")
        case .greeted: L("Said hello to a cat")
        }
    }
}

/// How a cat responds to an event. Emotes show at once; actions happen at the cat's next decision.
enum ReactionResponse: String, Codable, CaseIterable, Identifiable {
    case followCursor, sulk, napInBed, zoomies, groom, hearts, anger, question

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followCursor: L("Follows the cursor")
        case .sulk: L("Sulks and walks off")
        case .napInBed: L("Goes for a nap")
        case .zoomies: L("Gets the zoomies")
        case .groom: L("Grooms (\"I meant to do that\")")
        case .hearts: L("Shows hearts")
        case .anger: L("Gets angry")
        case .question: L("Looks puzzled")
        }
    }

    /// The action a response turns into, if it's more than an emote.
    var action: CatAction? {
        switch self {
        case .followCursor: .visitCursor
        case .napInBed: .nap
        case .zoomies: .zoomies
        case .groom: .groom
        case .sulk, .hearts, .anger, .question: nil
        }
    }
}

struct Reaction: Codable, Hashable, Identifiable {
    var id = UUID()
    var event: CatEvent
    var response: ReactionResponse
    /// 0…1
    var chance: Double
    /// Seconds before the same reaction can fire again.
    var cooldown: Double = 20

    init(event: CatEvent, response: ReactionResponse, chance: Double, cooldown: Double = 20) {
        self.event = event
        self.response = response
        self.chance = chance
        self.cooldown = cooldown
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        event = try c.decode(CatEvent.self, forKey: .event)
        response = try c.decode(ReactionResponse.self, forKey: .response)
        chance = min(1, max(0, try c.decodeIfPresent(Double.self, forKey: .chance) ?? 0.5))
        cooldown = max(0, try c.decodeIfPresent(Double.self, forKey: .cooldown) ?? 20)
    }
}

/// A time-of-day habit: between `fromHour` and `toHour` (wrapping past midnight) the action is
/// more (or less) likely, optionally at a preferred place.
struct Routine: Codable, Hashable, Identifiable {
    var id = UUID()
    var fromHour: Int
    var toHour: Int
    var action: CatAction
    var boost: Double
    var place: CatPlace?

    init(fromHour: Int, toHour: Int, action: CatAction, boost: Double, place: CatPlace? = nil) {
        self.fromHour = fromHour
        self.toHour = toHour
        self.action = action
        self.boost = boost
        self.place = place
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        fromHour = min(23, max(0, try c.decode(Int.self, forKey: .fromHour)))
        toHour = min(24, max(0, try c.decode(Int.self, forKey: .toHour)))
        action = try c.decode(CatAction.self, forKey: .action)
        boost = min(5, max(0, try c.decodeIfPresent(Double.self, forKey: .boost) ?? 2))
        place = try c.decodeIfPresent(CatPlace.self, forKey: .place)
    }

    func isActive(hour: Int) -> Bool {
        fromHour <= toHour ? (hour >= fromHour && hour < toHour) : (hour >= fromHour || hour < toHour)
    }
}

/// How quickly a cat gets lonely or bored, and how much that sways its choices.
struct NeedSettings: Codable, Hashable {
    /// Per second while nothing satisfies the need.
    var socialRate: Double = 0.004
    var curiosityRate: Double = 0.005
    /// 0 means needs don't affect choices; 1 means a full need doubles the related actions.
    var influence: Double = 0.6

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        socialRate = try c.decodeIfPresent(Double.self, forKey: .socialRate) ?? 0.004
        curiosityRate = try c.decodeIfPresent(Double.self, forKey: .curiosityRate) ?? 0.005
        influence = try c.decodeIfPresent(Double.self, forKey: .influence) ?? 0.6
    }
}

/// Short lines a cat can say, per situation. Empty for now; filled by the user or by an AI later.
enum PhraseSituation: String, Codable, CaseIterable, CodingKeyRepresentable {
    case wokeUp, petted, squished, missedJump, ate, hungry, bored, playing, sleepy, greeting, rummaging, hunting
}

/// A cat's character as data: what it likes doing, where it likes to be, how it reacts and
/// when. The behaviour engine (`UtilityPlanner`, `Cat.react`) runs entirely on this.
struct CatBrain: Codable, Hashable {
    static let currentVersion = 1

    var version = CatBrain.currentVersion
    /// Multipliers on the base appeal of each action. 1 is neutral, 0 never, 2 twice as often.
    var habits: [CatAction: Double] = [:]
    /// Preference for napping places. 1 is neutral.
    var places: [CatPlace: Double] = [:]
    var needs = NeedSettings()
    var routines: [Routine] = []
    var reactions: [Reaction] = []
    var phrases: [PhraseSituation: [String]] = [:]

    init() {}

    // Lenient on purpose: profiles may come from older versions, other people or a language
    // model, so anything missing falls back to a default and values are kept in range.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decodeIfPresent(Int.self, forKey: .version) ?? CatBrain.currentVersion
        // Keys this version doesn't know (from a newer profile) are skipped, not fatal.
        func known<Key: RawRepresentable & Hashable, Value>(_ raw: [String: Value]?, _: Key.Type) -> [Key: Value] where Key.RawValue == String {
            Dictionary((raw ?? [:]).compactMap { k, v in Key(rawValue: k).map { ($0, v) } }, uniquingKeysWith: { a, _ in a })
        }
        habits = known(try c.decodeIfPresent([String: Double].self, forKey: .habits), CatAction.self).mapValues { min(3, max(0, $0)) }
        places = known(try c.decodeIfPresent([String: Double].self, forKey: .places), CatPlace.self).mapValues { min(3, max(0, $0)) }
        needs = try c.decodeIfPresent(NeedSettings.self, forKey: .needs) ?? NeedSettings()
        routines = try c.decodeIfPresent([Routine].self, forKey: .routines) ?? []
        reactions = try c.decodeIfPresent([Reaction].self, forKey: .reactions) ?? []
        phrases = known(try c.decodeIfPresent([String: [String]].self, forKey: .phrases), PhraseSituation.self)
    }

    func habit(_ action: CatAction) -> Double { habits[action] ?? 1 }
    func place(_ place: CatPlace) -> Double { places[place] ?? place.defaultPreference }

    /// The brain behind each built-in personality. Habit values reproduce the weights the
    /// app used before brains existed, so a cat that was never customised behaves the same.
    static func preset(_ personality: Personality) -> CatBrain {
        let t = personality.traits
        var brain = CatBrain()
        brain.habits = [
            .wander: t.curiosity, .explore: t.curiosity, .rummage: t.curiosity,
            .zoomies: t.playfulness, .play: t.playfulness, .chaseBall: t.playfulness,
            .nap: t.laziness,
            .visitCursor: t.affection > 1.2 ? 1 : 0,
        ]
        brain.needs.socialRate = 0.004 * t.playfulness
        brain.needs.curiosityRate = 0.005 * t.curiosity
        switch personality {
        case .playful:
            brain.reactions = [Reaction(event: .missedJump, response: .zoomies, chance: 0.4)]
        case .lazy:
            brain.places[.bed] = 1.6
            brain.reactions = [Reaction(event: .wokeUp, response: .napInBed, chance: 0.25, cooldown: 120)]
            brain.routines = [Routine(fromHour: 13, toHour: 16, action: .nap, boost: 2, place: .bed)]
        case .curious:
            brain.places[.high] = 0.8
            brain.reactions = [Reaction(event: .droppedHard, response: .question, chance: 0.6)]
        case .affectionate:
            brain.reactions = [Reaction(event: .petted, response: .followCursor, chance: 0.5, cooldown: 30)]
        case .grumpy:
            brain.reactions = [
                Reaction(event: .squished, response: .sulk, chance: 0.5),
                Reaction(event: .pickedUp, response: .anger, chance: 0.8, cooldown: 5),
            ]
        }
        // Presets are rebuilt on every use, so their IDs must not change between calls:
        // reaction cooldowns are tracked by ID.
        for i in brain.reactions.indices {
            brain.reactions[i].id = UUID(stable: "\(personality.rawValue).reaction.\(i)")
        }
        for i in brain.routines.indices {
            brain.routines[i].id = UUID(stable: "\(personality.rawValue).routine.\(i)")
        }
        return brain
    }
}

extension UUID {
    /// A UUID derived from a string, the same on every call and every launch.
    init(stable name: String) {
        let digest = Array(SHA256.hash(data: Data(name.utf8)))
        self.init(uuid: (digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
                         digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]))
    }
}
