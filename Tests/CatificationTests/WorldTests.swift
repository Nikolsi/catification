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
    /// that hardly cares, at least twice as much. (The curious preset already likes the trash: its habit is 1.5.)
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
        XCTAssertGreaterThan(b, 2 * max(1, a), "rummaging: lover \(Int(b)) s, indifferent \(Int(a)) s")
    }

    /// Lazy cats sleep a lot more than playful ones (#30): about a third of the time against a tenth.
    func testLazyCatsSleepMuchMoreThanPlayfulOnes() {
        let report = day(minutes: 60, [CatConfig(name: "Lazy", coat: .gray, personality: .lazy),
                                       CatConfig(name: "Playful", coat: .ginger, personality: .playful)])
        func asleep(_ name: String) -> Double {
            guard let day = report.day(of: name) else { return 0 }
            return (day.seconds["sleep"] ?? 0) / max(1, day.seconds.values.reduce(0, +))
        }
        XCTAssertGreaterThan(asleep("Lazy"), 0.2)
        XCTAssertGreaterThan(asleep("Lazy"), 2 * asleep("Playful"), "lazy \(asleep("Lazy")), playful \(asleep("Playful"))")
    }

    func testTheOwnerFillsAnEmptyBowl() {
        let world = World()
        world.spawn(character: CatConfig(name: "Ginger", coat: .ginger, personality: .playful))
        world.run(for: 30 * 60)
        let early = world.report.day(of: "Ginger")?.actions.values.reduce(0, +) ?? 0
        world.run(for: 60 * 60)
        let later = (world.report.day(of: "Ginger")?.actions.values.reduce(0, +) ?? 0) - early
        // Without someone feeding them, hungry cats sit by the empty bowl from about half an hour on
        // and stop doing anything else.
        XCTAssertGreaterThan(later, early, "first half hour \(early) actions, next hour \(later)")
    }

    /// Playful cats sometimes end a pounce in a rough-and-tumble wrestle.
    func testPlayfulCatsWrestle() {
        let report = day(minutes: 30, [CatConfig(name: "Ginger", coat: .ginger, personality: .playful),
                                       CatConfig(name: "Midnight", coat: .tuxedo, personality: .playful)])
        let wrestles = report.cats.reduce(0) { $0 + ($1.moments["wrestle"] ?? 0) }
        XCTAssertGreaterThan(wrestles, 0)
        XCTAssertGreaterThan(report.cats.reduce(0) { $0 + ($1.seconds["wrestle"] ?? 0) }, 0)
    }

    /// The default room has a water fountain; cats get thirsty, more so after running about, and drink.
    func testCatsDrinkFromTheFountain() {
        let report = day(minutes: 60, [CatConfig(name: "Ginger", coat: .ginger, personality: .playful)])
        XCTAssertGreaterThan(report.day(of: "Ginger")?.count(.drink) ?? 0, 0)
        XCTAssertGreaterThan(report.day(of: "Ginger")?.seconds["drinking"] ?? 0, 0)
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
