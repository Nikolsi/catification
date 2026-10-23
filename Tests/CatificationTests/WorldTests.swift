import XCTest
@testable import Catification

/// Behaviour over simulated time, with the fast-forward `World`.
@MainActor
final class WorldTests: XCTestCase {
    private func day(seed: UInt64 = 1, minutes: Double, _ cats: [CatConfig]) -> DayReport {
        let world = World(seed: seed)
        for cat in cats { world.spawn(character: cat) }
        world.run(for: minutes * 60)
        return world.report
    }

    func testSameSeedSameDay() {
        let cats = [CatConfig(name: "Ginger", coat: .ginger, personality: .playful),
                    CatConfig(name: "Midnight", coat: .tuxedo, personality: .curious)]
        let a = day(minutes: 10, cats), b = day(minutes: 10, cats)
        XCTAssertEqual(a.cats, b.cats)
        XCTAssertFalse(a.cats.first?.actions.isEmpty ?? true)
        XCTAssertNotEqual(a.cats, day(seed: 2, minutes: 10, cats).cats)
    }

    func testWorldsDontTouchTheAppsClock() {
        let time = Sim.time
        _ = day(minutes: 1, [CatConfig(name: "Ginger", coat: .ginger, personality: .playful)])
        XCTAssertEqual(Sim.time, time)
    }

    /// The point of habits: a cat that loves the trash spends far more of its day in it than one
    /// that hardly cares. (The curious preset already likes the trash: its habit is 1.5.)
    func testATrashLoverRummagesMore() {
        func cat(_ name: String, rummage: Double) -> CatConfig {
            var cat = CatConfig(name: name, coat: .gray, personality: .curious)
            var brain = CatBrain.preset(.curious)
            brain.habits[.rummage] = rummage
            cat.brain = brain
            return cat
        }
        let indifferent = day(minutes: 90, [cat("Indifferent", rummage: 0.5)]).day(of: "Indifferent")
        let lover = day(minutes: 90, [cat("Lover", rummage: 3)]).day(of: "Lover")
        let a = indifferent?.seconds["rummaging"] ?? 0, b = lover?.seconds["rummaging"] ?? 0
        XCTAssertGreaterThan(b, 3 * max(1, a), "rummaging: lover \(Int(b)) s, indifferent \(Int(a)) s")
    }

    func testPettingIsCounted() throws {
        let world = World()
        let cat = try XCTUnwrap(world.spawn(character: CatConfig(name: "Ginger", coat: .ginger, personality: .affectionate)))
        world.run(for: 5)  // land first
        world.emit(.petted, to: cat)
        world.run(for: 0.5)
        XCTAssertGreaterThan(world.report.day(of: "Ginger")?.seconds["petted"] ?? 0, 0)
    }
}
