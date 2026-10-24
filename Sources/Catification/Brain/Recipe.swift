import Foundation

/// A habit made of several steps: when something happens (or at some time of day), the cat does
/// one thing after another. "After being petted, follows you around"; "in the evening, zoomies,
/// then a wash". Shown as "rituals" in the cat editor.
///
///     { "name": "Evening zoomies", "when": { "hours": [19, 23] },
///       "do": [ { "zoomies": true }, { "groom": 5 } ] }
struct Recipe: Codable, Hashable, Identifiable {
    var id = UUID()
    var name: String
    var enabled = true
    /// The built-in template this came from, if any.
    var template: RecipeTemplate?
    var trigger: RecipeTrigger
    /// Event recipes: the chance it happens when the event does (0…1).
    var chance: Double = 1
    /// Time-of-day recipes: how appealing it is next to everything else a cat could do
    /// (1.5 is about as likely as wandering off).
    var weight: Double = 1.5
    /// Seconds before it can happen again.
    var cooldown: Double = 600
    var steps: [RecipeStep]

    init(name: String, template: RecipeTemplate? = nil, trigger: RecipeTrigger, chance: Double = 1,
         weight: Double = 1.5, cooldown: Double = 600, steps: [RecipeStep]) {
        self.name = name
        self.template = template
        self.trigger = trigger
        self.chance = chance
        self.weight = weight
        self.cooldown = cooldown
        self.steps = steps
    }

    /// Whether this version knows how to run it (a profile from a newer version may not).
    var isRunnable: Bool {
        if case .unknown = trigger { return false }
        return !steps.isEmpty && !steps.contains { if case .unknown = $0 { true } else { false } }
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, enabled, template, trigger = "when", chance, weight, cooldown, steps = "do"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? ""
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        template = (try? c.decodeIfPresent(String.self, forKey: .template)).flatMap(RecipeTemplate.init(rawValue:))
        trigger = (try? c.decode(RecipeTrigger.self, forKey: .trigger)) ?? .unknown(.null)
        chance = min(1, max(0, try c.decodeIfPresent(Double.self, forKey: .chance) ?? 1))
        weight = min(5, max(0, try c.decodeIfPresent(Double.self, forKey: .weight) ?? 1.5))
        cooldown = max(0, try c.decodeIfPresent(Double.self, forKey: .cooldown) ?? 600)
        steps = try c.decodeIfPresent([RecipeStep].self, forKey: .steps) ?? []
    }
}

/// What starts a recipe.
enum RecipeTrigger: Codable, Hashable {
    /// Right after something happens to the cat.
    case event(CatEvent)
    /// Between two hours of the day (wrapping past midnight); the cat may choose it then.
    case hours(from: Int, to: Int)
    /// From a newer version: kept as it was, never runs.
    case unknown(JSONValue)

    func isActive(hour: Int) -> Bool {
        guard case .hours(let from, let to) = self else { return false }
        return from <= to ? (hour >= from && hour < to) : (hour >= from || hour < to)
    }

    init(from decoder: Decoder) throws {
        let raw = try JSONValue(from: decoder)
        if case .object(let o) = raw {
            if case .string(let s)? = o["event"], let event = CatEvent(rawValue: s) {
                self = .event(event)
                return
            }
            if case .array(let a)? = o["hours"], a.count == 2, case .number(let f) = a[0], case .number(let t) = a[1] {
                self = .hours(from: min(23, max(0, Int(f))), to: min(24, max(0, Int(t))))
                return
            }
        }
        self = .unknown(raw)
    }

    func encode(to encoder: Encoder) throws {
        switch self {
        case .event(let e): try JSONValue.object(["event": .string(e.rawValue)]).encode(to: encoder)
        case .hours(let f, let t): try JSONValue.object(["hours": .array([.number(Double(f)), .number(Double(t))])]).encode(to: encoder)
        case .unknown(let raw): try raw.encode(to: encoder)
        }
    }
}

/// One step of a recipe. In JSON each step is an object with one key: `{ "sit": 5 }`,
/// `{ "goTo": "laundry" }`, `{ "zoomies": true }`.
enum RecipeStep: Codable, Hashable {
    /// Walk (and jump) to a kind of place and sit there.
    case goTo(CatPlace)
    case sit(seconds: Double)
    case sleep(seconds: Double?)
    case groom(seconds: Double)
    case wait(seconds: Double)
    case rummage, scratch, zoomies, wander
    /// Come over to the cursor.
    case followCursor
    case emote(RecipeEmote)
    /// A line to say, once cats can speak (thought bubbles); skipped until then.
    case say(String)
    /// From a newer version: kept as it was; a recipe with one never runs.
    case unknown(JSONValue)

    init(from decoder: Decoder) throws {
        let raw = try JSONValue(from: decoder)
        guard case .object(let o) = raw, o.count == 1, let (key, value) = o.first else {
            self = .unknown(raw)
            return
        }
        let seconds = value.number.map { min(600, max(0, $0)) }
        switch key {
        case "goTo": self = value.string.flatMap(CatPlace.init(rawValue:)).map { .goTo($0) } ?? .unknown(raw)
        case "sit": self = .sit(seconds: seconds ?? 5)
        case "sleep": self = .sleep(seconds: seconds)
        case "groom": self = .groom(seconds: seconds ?? 4)
        case "wait": self = .wait(seconds: seconds ?? 2)
        case "rummage": self = .rummage
        case "scratch": self = .scratch
        case "zoomies": self = .zoomies
        case "wander": self = .wander
        case "followCursor": self = .followCursor
        case "emote": self = value.string.flatMap(RecipeEmote.init(rawValue:)).map { .emote($0) } ?? .unknown(raw)
        case "say": self = value.string.map { .say($0) } ?? .unknown(raw)
        default: self = .unknown(raw)
        }
    }

    func encode(to encoder: Encoder) throws {
        let json: JSONValue
        switch self {
        case .goTo(let p): json = .object(["goTo": .string(p.rawValue)])
        case .sit(let s): json = .object(["sit": .number(s)])
        case .sleep(let s): json = .object(["sleep": s.map { .number($0) } ?? .bool(true)])
        case .groom(let s): json = .object(["groom": .number(s)])
        case .wait(let s): json = .object(["wait": .number(s)])
        case .rummage: json = .object(["rummage": .bool(true)])
        case .scratch: json = .object(["scratch": .bool(true)])
        case .zoomies: json = .object(["zoomies": .bool(true)])
        case .wander: json = .object(["wander": .bool(true)])
        case .followCursor: json = .object(["followCursor": .bool(true)])
        case .emote(let e): json = .object(["emote": .string(e.rawValue)])
        case .say(let s): json = .object(["say": .string(s)])
        case .unknown(let raw): json = raw
        }
        try json.encode(to: encoder)
    }
}

enum RecipeEmote: String, Codable, CaseIterable {
    case heart, note, exclaim, question, anger, zzz

    var kind: EmoteKind {
        switch self {
        case .heart: .heart
        case .note: .note
        case .exclaim: .exclaim
        case .question: .question
        case .anger: .anger
        case .zzz: .zzz
        }
    }
}

/// Ready-made recipes to start from in the cat editor.
enum RecipeTemplate: String, Codable, CaseIterable, Identifiable {
    case followAfterPetting, eveningZoomies

    var id: String { rawValue }

    var title: String {
        switch self {
        case .followAfterPetting: L("After petting, follows you")
        case .eveningZoomies: L("Evening zoomies")
        }
    }

    func make() -> Recipe {
        switch self {
        case .followAfterPetting:
            Recipe(name: title, template: self, trigger: .event(.petted), chance: 0.8, cooldown: 120,
                   steps: [.emote(.heart), .followCursor, .sit(seconds: 6), .emote(.heart)])
        case .eveningZoomies:
            Recipe(name: title, template: self, trigger: .hours(from: 19, to: 23), weight: 1.5, cooldown: 1800,
                   steps: [.zoomies, .groom(seconds: 5)])
        }
    }
}

/// Any JSON, for keeping parts of a profile this version doesn't understand.
enum JSONValue: Codable, Hashable {
    case null
    case bool(Bool)
    case number(Double)
    case string(String)
    case array([JSONValue])
    case object([String: JSONValue])

    var number: Double? { if case .number(let n) = self { n } else { nil } }
    var string: String? { if case .string(let s) = self { s } else { nil } }

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let b = try? c.decode(Bool.self) { self = .bool(b) }
        else if let n = try? c.decode(Double.self) { self = .number(n) }
        else if let s = try? c.decode(String.self) { self = .string(s) }
        else if let a = try? c.decode([JSONValue].self) { self = .array(a) }
        else { self = .object(try c.decode([String: JSONValue].self)) }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null: try c.encodeNil()
        case .bool(let b): try c.encode(b)
        case .number(let n): try c.encode(n)
        case .string(let s): try c.encode(s)
        case .array(let a): try c.encode(a)
        case .object(let o): try c.encode(o)
        }
    }
}
