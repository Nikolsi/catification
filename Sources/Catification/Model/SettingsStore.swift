import AppKit
import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @Published var cats: [CatConfig] { didSet { save() } }
    @Published var catsVisible: Bool { didSet { save() } }
    @Published var speed: Double { didSet { save() } }
    @Published var moodEmotes: Bool { didSet { save() } }
    @Published var virtualNotch: Bool { didSet { save() } }
    @Published var mode: WorldMode { didSet { save() } }
    @Published var walkOnWindows: Bool { didSet { save() } }
    @Published var jumpMath: Bool { didSet { save() } }
    @Published var butterflies: Bool { didSet { save() } }
    @Published var climbIcons: Bool { didSet { save() } }
    @Published var furniture: [Furniture] { didSet { save() } }

    /// UI-only: which cat is open in the settings window.
    @Published var selectedCatID: UUID?

    private struct Snapshot: Codable {
        var cats: [CatConfig]
        var catsVisible: Bool
        var speed: Double
        var moodEmotes: Bool
        var virtualNotch: Bool
        var mode: WorldMode
        var walkOnWindows: Bool
        var jumpMath: Bool
        var butterflies: Bool
        var climbIcons: Bool
        var furniture: [Furniture]?
        var layoutVersion: Int

        init(cats: [CatConfig], catsVisible: Bool, speed: Double, moodEmotes: Bool, virtualNotch: Bool,
             mode: WorldMode, walkOnWindows: Bool, jumpMath: Bool, butterflies: Bool, climbIcons: Bool, furniture: [Furniture]?, layoutVersion: Int) {
            self.cats = cats
            self.catsVisible = catsVisible
            self.speed = speed
            self.moodEmotes = moodEmotes
            self.virtualNotch = virtualNotch
            self.mode = mode
            self.walkOnWindows = walkOnWindows
            self.jumpMath = jumpMath
            self.butterflies = butterflies
            self.climbIcons = climbIcons
            self.furniture = furniture
            self.layoutVersion = layoutVersion
        }

        // Every field is optional on disk so that settings from older versions keep loading.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            cats = try c.decodeIfPresent([CatConfig].self, forKey: .cats) ?? CatConfig.defaults
            catsVisible = try c.decodeIfPresent(Bool.self, forKey: .catsVisible) ?? true
            speed = try c.decodeIfPresent(Double.self, forKey: .speed) ?? 1
            moodEmotes = try c.decodeIfPresent(Bool.self, forKey: .moodEmotes) ?? true
            virtualNotch = try c.decodeIfPresent(Bool.self, forKey: .virtualNotch) ?? false
            mode = try c.decodeIfPresent(WorldMode.self, forKey: .mode) ?? .screen
            walkOnWindows = try c.decodeIfPresent(Bool.self, forKey: .walkOnWindows) ?? true
            jumpMath = try c.decodeIfPresent(Bool.self, forKey: .jumpMath) ?? true
            butterflies = try c.decodeIfPresent(Bool.self, forKey: .butterflies) ?? true
            climbIcons = try c.decodeIfPresent(Bool.self, forKey: .climbIcons) ?? false
            furniture = try c.decodeIfPresent([Furniture].self, forKey: .furniture)
            layoutVersion = try c.decodeIfPresent(Int.self, forKey: .layoutVersion) ?? 0
        }
    }

    private static let key = "catification.settings.v1"
    /// False for demo recordings: nothing is read from or written to the user's settings.
    private var persists = true

    init() {
        let snapshot = UserDefaults.standard.data(forKey: Self.key)
            .flatMap { try? JSONDecoder().decode(Snapshot.self, from: $0) }
        cats = snapshot?.cats ?? CatConfig.defaults
        catsVisible = snapshot?.catsVisible ?? true
        speed = snapshot?.speed ?? 1.0
        moodEmotes = snapshot?.moodEmotes ?? true
        virtualNotch = snapshot?.virtualNotch ?? false
        mode = snapshot?.mode ?? .screen
        walkOnWindows = snapshot?.walkOnWindows ?? true
        jumpMath = snapshot?.jumpMath ?? true
        butterflies = snapshot?.butterflies ?? true
        climbIcons = snapshot?.climbIcons ?? false
        // Older default layouts weren't connected from the floor to the menu bar; replace them.
        if let saved = snapshot?.furniture, (snapshot?.layoutVersion ?? 0) >= Furniture.layoutVersion {
            furniture = saved
        } else {
            furniture = Self.defaultFurniture()
        }
        selectedCatID = cats.first?.id
    }

    /// Settings that live only in memory, for demo recordings.
    init(transientCats cats: [CatConfig], furniture: [Furniture], mode: WorldMode) {
        persists = false
        self.cats = cats
        catsVisible = true
        speed = 1
        moodEmotes = true
        virtualNotch = false
        self.mode = mode
        walkOnWindows = false
        jumpMath = true
        butterflies = false
        climbIcons = false
        self.furniture = furniture
    }

    private func save() {
        guard persists else { return }
        let snapshot = Snapshot(
            cats: cats, catsVisible: catsVisible, speed: speed, moodEmotes: moodEmotes, virtualNotch: virtualNotch,
            mode: mode, walkOnWindows: walkOnWindows, jumpMath: jumpMath, butterflies: butterflies, climbIcons: climbIcons, furniture: furniture,
            layoutVersion: Furniture.layoutVersion
        )
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    private static func defaultFurniture() -> [Furniture] {
        guard let screen = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 0 }) ?? NSScreen.main else { return [] }
        return Furniture.defaults(screenWidth: screen.frame.width, screenHeight: screen.frame.height, floor: 0)
    }

    @discardableResult
    func addRandomCat() -> CatConfig {
        let used = Set(cats.map(\.name))
        let name = CatConfig.names.filter { !used.contains($0) }.randomElement() ?? String(format: L("Kitty %d"), cats.count + 1)
        let cat = CatConfig(
            name: name,
            coat: CoatPreset.all.randomElement()!,
            personality: Personality.allCases.randomElement()!,
            size: Double.random(in: 0...1) < 0.25 ? .small : .normal
        )
        cats.append(cat)
        return cat
    }

    func remove(_ id: UUID) {
        cats.removeAll { $0.id == id }
        if selectedCatID == id { selectedCatID = cats.first?.id }
    }

    func resetCats() {
        cats = CatConfig.defaults
        selectedCatID = cats.first?.id
    }

    func resetFurniture() {
        furniture = Self.defaultFurniture()
    }
}
