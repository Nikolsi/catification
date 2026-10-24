import Foundation

/// Where the simulation gets time and chance from.
///
/// Normally that is the real clock and system randomness. `Sim.seed(_:)` makes a run repeatable:
/// a fixed sequence of random numbers, fixed 1/60 s steps and a clock that starts at a known date,
/// for demo recordings, tests and the fast-forward runner.
@MainActor
enum Sim {
    static var rng = SimRandom()
    /// Seconds of simulated time since launch, advanced by the world every tick.
    private(set) static var time: Double = 0
    /// Set in repeatable runs: every tick advances the simulation by exactly this much.
    private(set) static var fixedStep: Double?
    /// Set in repeatable runs: the date and time at `time == 0`.
    private(set) static var startDate: Date?

    /// The simulated date: the real one, unless the run is repeatable.
    static var date: Date { startDate.map { $0.addingTimeInterval(time) } ?? Date() }
    static var hour: Int { Calendar.current.component(.hour, from: date) }

    /// `--seed <number>` on the command line.
    static var commandLineSeed: UInt64? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--seed"), args.count > i + 1 else { return nil }
        return UInt64(args[i + 1])
    }

    /// Makes the rest of the run repeatable. `start` is the simulated date from now on.
    static func seed(_ seed: UInt64, start: Date? = nil) {
        rng = SimRandom(seed: seed)
        fixedStep = 1.0 / 60
        startDate = (start ?? date).addingTimeInterval(-time)
    }

    /// Everything above, so a world can keep its own and run with it (`run(in:_:)`).
    struct State {
        var rng: SimRandom
        var time: Double = 0
        var fixedStep: Double?
        var startDate: Date?

        init(rng: SimRandom, time: Double, fixedStep: Double?, startDate: Date?) {
            self.rng = rng
            self.time = time
            self.fixedStep = fixedStep
            self.startDate = startDate
        }

        /// A repeatable state: seeded randomness, fixed 1/60 s steps, the clock at `start`.
        init(seed: UInt64, start: Date) {
            rng = SimRandom(seed: seed)
            fixedStep = 1.0 / 60
            startDate = start
        }
    }

    /// Runs `body` with `state` as the simulation's time and chance, then hands the changes back.
    /// Several worlds can live in one process this way (tests, the fast-forward runner).
    static func run<T>(in state: inout State, _ body: () throws -> T) rethrows -> T {
        let saved = State(rng: rng, time: time, fixedStep: fixedStep, startDate: startDate)
        set(state)
        defer {
            state = State(rng: rng, time: time, fixedStep: fixedStep, startDate: startDate)
            set(saved)
        }
        return try body()
    }

    private static func set(_ s: State) {
        rng = s.rng
        time = s.time
        fixedStep = s.fixedStep
        startDate = s.startDate
    }

    /// Advances simulated time by one tick and returns its length.
    static func advance(realDelta: Double) -> Double {
        let dt = fixedStep ?? min(realDelta, 1.0 / 20)
        time += dt
        return dt
    }
}

/// SplitMix64: tiny, fast and good enough for cats. Seeded, it gives the same numbers on every Mac.
struct SimRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64? = nil) {
        var system = SystemRandomNumberGenerator()
        state = seed ?? system.next()
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
