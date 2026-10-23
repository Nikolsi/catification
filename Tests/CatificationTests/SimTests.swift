import XCTest
@testable import Catification

@MainActor
final class SimTests: XCTestCase {
    func testSeededRandomIsRepeatable() {
        var a = SimRandom(seed: 42), b = SimRandom(seed: 42), c = SimRandom(seed: 43)
        let first = (0..<5).map { _ in a.next() }
        XCTAssertEqual(first, (0..<5).map { _ in b.next() })
        XCTAssertNotEqual(first, (0..<5).map { _ in c.next() })
    }

    /// Pins the algorithm (SplitMix64): changing it would change every seeded run and demo recording.
    func testKnownSequence() {
        var r = SimRandom(seed: 0)
        XCTAssertEqual(r.next(), 0xE220_A839_7B1D_CDAF)
        XCTAssertEqual(r.next(), 0x6E78_9E6A_A1B9_65F4)
    }

    func testSeededRunsHaveFixedStepsAndAKnownClock() throws {
        let start = try XCTUnwrap(DateComponents(calendar: .current, year: 2026, month: 1, day: 13, hour: 9, minute: 40).date)
        Sim.seed(7, start: start)
        XCTAssertEqual(Sim.date, start)
        XCTAssertEqual(Sim.advance(realDelta: 0.5), 1.0 / 60)
        XCTAssertEqual(Sim.date.timeIntervalSince(start), 1.0 / 60, accuracy: 1e-5)  // Date keeps ~0.1 µs
        for _ in 0..<(60 * 60 * 60 * 3) { _ = Sim.advance(realDelta: 0) }  // three hours
        XCTAssertEqual(Sim.hour, 12)

        Sim.seed(7, start: start)
        let draws = (0..<3).map { _ in Double.random(in: 0..<1, using: &Sim.rng) }
        Sim.seed(7, start: start)
        XCTAssertEqual(draws, (0..<3).map { _ in Double.random(in: 0..<1, using: &Sim.rng) })
    }
}
