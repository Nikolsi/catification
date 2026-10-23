import XCTest
@testable import Catification

final class BrainTests: XCTestCase {
    private let everything = Set(CatAction.allCases)

    /// The weights `Cat.decide()` used before brains existed, copied verbatim.
    private func legacyWeights(_ t: Traits, energy: Double, grumpy: Bool, available: Set<CatAction>) -> [CatAction: Double] {
        var w: [CatAction: Double] = [
            .idle: 1.0, .sit: 1.5, .groom: 0.7,
            .wander: 1.6 * t.curiosity,
            .zoomies: 0.45 * t.playfulness * energy * (grumpy ? 0.3 : 1),
            .nap: (1.1 - energy) * 2.2 * t.laziness,
            .explore: 1.3 * t.curiosity,
            .scratch: 0.6,
            .rummage: 0.5 * t.curiosity,
            .play: 1.4 * t.playfulness * energy,
            .chaseBall: 0.8 * t.playfulness * energy,
        ]
        if t.affection > 1.2 { w[.visitCursor] = 1.6 }
        return w.filter { available.contains($0.key) && $0.value > 0 }
    }

    func testPresetsReproduceTheOldWeights() {
        for personality in Personality.allCases {
            var brain = CatBrain.preset(personality)
            brain.routines = []  // time-of-day habits are new; compare the rest
            for energy in [0.2, 0.5, 0.9] {
                for grumpy in [false, true] {
                    let context = PlannerContext(energy: energy, social: 0.5, curiosity: 0.5, grumpy: grumpy, hour: 10, available: everything)
                    let scores = Dictionary(uniqueKeysWithValues: UtilityPlanner.scores(brain: brain, context: context).map { ($0.action, $0.score) })
                    let legacy = legacyWeights(personality.traits, energy: energy, grumpy: grumpy, available: everything)
                    XCTAssertEqual(Set(scores.keys), Set(legacy.keys), "\(personality) energy \(energy)")
                    for (action, weight) in legacy {
                        XCTAssertEqual(scores[action] ?? -1, weight, accuracy: 1e-9, "\(personality) \(action)")
                    }
                }
            }
        }
    }

    func testOnlyAvailableActionsAreScored() {
        let context = PlannerContext(energy: 0.8, available: [.sit, .nap])
        let actions = Set(UtilityPlanner.scores(brain: CatBrain(), context: context).map(\.action))
        XCTAssertEqual(actions, [.sit, .nap])
    }

    func testHabitsChangeWhatACatPrefers() {
        var trashLover = CatBrain()
        trashLover.habits[.rummage] = 3
        let context = PlannerContext(energy: 0.8, available: everything)
        let plain = UtilityPlanner.scores(brain: CatBrain(), context: context)
        let loved = UtilityPlanner.scores(brain: trashLover, context: context)
        XCTAssertEqual(share(.rummage, in: loved), share(.rummage, in: plain) * 3 / (1 + share(.rummage, in: plain) * 2), accuracy: 1e-9)
        XCTAssertGreaterThan(share(.rummage, in: loved), 2 * share(.rummage, in: plain))
    }

    func testTiredCatsPreferNapping() {
        let tired = UtilityPlanner.scores(brain: CatBrain(), context: PlannerContext(energy: 0.15, available: everything))
        let fresh = UtilityPlanner.scores(brain: CatBrain(), context: PlannerContext(energy: 0.95, available: everything))
        XCTAssertGreaterThan(share(.nap, in: tired), 4 * share(.nap, in: fresh))
    }

    func testNeedsSwayChoices() {
        let bored = UtilityPlanner.scores(brain: CatBrain(), context: PlannerContext(energy: 0.7, curiosity: 1, available: everything))
        let content = UtilityPlanner.scores(brain: CatBrain(), context: PlannerContext(energy: 0.7, curiosity: 0, available: everything))
        XCTAssertGreaterThan(share(.explore, in: bored), share(.explore, in: content))
        let lonely = UtilityPlanner.scores(brain: CatBrain(), context: PlannerContext(energy: 0.7, social: 1, available: everything))
        let busy = UtilityPlanner.scores(brain: CatBrain(), context: PlannerContext(energy: 0.7, social: 0, available: everything))
        XCTAssertGreaterThan(share(.play, in: lonely), share(.play, in: busy))
    }

    func testRoutinesApplyOnlyInTheirHours() {
        var brain = CatBrain()
        brain.routines = [Routine(fromHour: 22, toHour: 2, action: .zoomies, boost: 4)]
        func zoomies(at hour: Int) -> Double {
            let scores = UtilityPlanner.scores(brain: brain, context: PlannerContext(energy: 0.8, hour: hour, available: everything))
            return scores.first { $0.action == .zoomies }?.score ?? 0
        }
        XCTAssertEqual(zoomies(at: 23), 4 * zoomies(at: 12), accuracy: 1e-9)
        XCTAssertEqual(zoomies(at: 1), 4 * zoomies(at: 12), accuracy: 1e-9)
        XCTAssertEqual(zoomies(at: 2), zoomies(at: 12), accuracy: 1e-9)
    }

    func testPickRespectsWeights() {
        let scores: [(action: CatAction, score: Double)] = [(.sit, 1), (.nap, 3)]
        XCTAssertEqual(UtilityPlanner.pick(from: scores, random: 0.1), .sit)
        XCTAssertEqual(UtilityPlanner.pick(from: scores, random: 0.3), .nap)
        XCTAssertNil(UtilityPlanner.pick(from: []))
    }

    // MARK: Persistence

    func testBrainRoundTripsThroughJSON() throws {
        var brain = CatBrain.preset(.grumpy)
        brain.habits[.rummage] = 2.5
        brain.places[.high] = 1.5
        brain.phrases[.ate] = ["Finally."]
        let data = try JSONEncoder().encode(brain)
        XCTAssertEqual(try JSONDecoder().decode(CatBrain.self, from: data), brain)
        // Enum-keyed dictionaries are written as readable JSON objects, not arrays.
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        XCTAssertNotNil(json["habits"] as? [String: Double])
    }

    func testPartialAndOutOfRangeBrainsAreCleanedUp() throws {
        let json = #"""
        {"habits": {"rummage": 9, "nap": -1}, "reactions": [{"event": "petted", "response": "hearts", "chance": 4}],
         "routines": [{"fromHour": 30, "toHour": 2, "action": "nap"}]}
        """#
        let brain = try JSONDecoder().decode(CatBrain.self, from: Data(json.utf8))
        XCTAssertEqual(brain.habit(.rummage), 3)
        XCTAssertEqual(brain.habit(.nap), 0)
        XCTAssertEqual(brain.reactions.first?.chance, 1)
        XCTAssertEqual(brain.routines.first?.fromHour, 23)
        XCTAssertEqual(brain.routines.first?.boost, 2)
        XCTAssertEqual(brain.needs, NeedSettings())
    }

    func testCatsSavedBeforeBrainsStillLoad() throws {
        let old = #"""
        {"id": "5C1A4A9E-2F43-4C1B-9E3B-3D7E2B8F9A10", "name": "Ginger",
         "fur": {"r": 1, "g": 0.6, "b": 0.3}, "secondary": {"r": 0.8, "g": 0.4, "b": 0.1},
         "belly": {"r": 1, "g": 0.9, "b": 0.8}, "eyes": {"r": 0.5, "g": 0.75, "b": 0.26},
         "pattern": "tabby", "personality": "lazy", "size": "normal"}
        """#
        let cat = try JSONDecoder().decode(CatConfig.self, from: Data(old.utf8))
        XCTAssertEqual(cat.about, "")
        XCTAssertNil(cat.brain)
        XCTAssertEqual(cat.effectiveBrain, CatBrain.preset(.lazy))
    }

    func testCatProfileExportsTheFullCharacterAndImportsAsANewCat() throws {
        var cat = CatConfig(name: "Barsik", coat: .gray, personality: .grumpy)
        cat.about = "Loved digging in the trash."
        let data = try CatProfile(cat: cat).encoded()
        let imported = try CatProfile.decode(data)
        XCTAssertNotEqual(imported.id, cat.id)
        XCTAssertEqual(imported.name, "Barsik")
        XCTAssertEqual(imported.about, cat.about)
        // The preset is written out in full, so the file keeps working if presets change.
        XCTAssertEqual(imported.brain, CatBrain.preset(.grumpy))
    }

    private func share(_ action: CatAction, in scores: [(action: CatAction, score: Double)]) -> Double {
        let total = scores.reduce(0) { $0 + $1.score }
        return (scores.first { $0.action == action }?.score ?? 0) / total
    }
}
