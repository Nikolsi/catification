import AppKit

/// A world you drive yourself: seeded, never shown, stepped by hand.
///
///     let world = World(seed: 42)
///     world.spawn(character: cat)
///     world.run(for: 3600)          // an hour, in a fraction of that
///     print(world.report.text)
///
/// The same seed, cats and steps give the same report every time. For tuning behaviour and for tests.
@MainActor
final class World {
    let report = DayReport()
    /// Someone looks after the cats: an empty bowl gets filled after a few minutes. Without that,
    /// hungry cats end up waiting by the bowl, as they would at home.
    var feedsCats = true
    private var bowlEmptySince: Double?
    private var state: Sim.State
    private let store: SettingsStore
    private let world: CatWorld

    /// - Parameters:
    ///   - start: the simulated date and time when the world starts (routines depend on the hour).
    ///   - furniture: what stands in the room; by default the app's default layout for this size.
    init(seed: UInt64 = 1, size: CGSize = CGSize(width: 1512, height: 982), start: Date? = nil, furniture: [Furniture]? = nil) {
        _ = NSApplication.shared  // the world still makes a (hidden) panel and layers
        let menuBar: CGFloat = 37
        let geometry = WorldGeometry(
            mode: .screen, frame: CGRect(origin: .zero, size: size), menuBarHeight: menuBar,
            menuBarY: size.height - menuBar, groundY: 0, notch: (size.width / 2 - 92)...(size.width / 2 + 92))
        var items = furniture ?? Furniture.defaults(screenWidth: size.width, screenHeight: size.height, floor: 0)
        // Stable IDs: the order of things in dictionaries and sets depends on them, and so would the day.
        for i in items.indices { items[i].id = UUID(stable: "world.furniture.\(i)") }
        let store = SettingsStore(transientCats: [], furniture: items, mode: .screen)
        var state = Sim.State(seed: seed, start: start ?? Self.morning)
        // Steps come from `update(deltaTime:)`, not from a fixed frame rate.
        state.fixedStep = nil
        world = Sim.run(in: &state) { CatWorld(store: store, geometry: geometry, headless: true) }
        self.store = store
        self.state = state
        world.report = report
    }

    /// 9 am on a fixed day, so worlds don't depend on when they run.
    static let morning = DateComponents(calendar: .current, year: 2026, month: 1, day: 13, hour: 9).date ?? Date()

    /// Simulated time since the world started, in seconds.
    var time: Double { state.time }

    var cats: [Cat] { world.cats }

    /// Adds a cat, e.g. from a `.catprofile`. It drops in like it does in the app.
    @discardableResult
    func spawn(character: CatConfig) -> Cat? {
        Sim.run(in: &state) {
            store.cats.append(character)
            world.syncWithStore()
            return world.cats.first { $0.id == character.id }
        }
    }

    /// Something happens to a cat, as if the person at the computer did it.
    func emit(_ event: WorldEvent, to cat: Cat) {
        Sim.run(in: &state) {
            switch event {
            case .petted: cat.stroke(30, world: world)
            case .squished: cat.squish(world: world)
            }
        }
    }

    /// Advances the world by `deltaTime` seconds (at most 1/20 s; use `run(for:)` for longer).
    func update(deltaTime: Double) {
        Sim.run(in: &state) {
            let dt = Sim.advance(realDelta: deltaTime)
            world.step(dt)
            if feedsCats { lookAfterTheBowls() }
        }
    }

    /// Fills the bowls, as the owner does from the menu.
    func fillBowls() {
        Sim.run(in: &state) { world.refillBowls() }
    }

    private func lookAfterTheBowls() {
        let empty = world.furniture.contains { $0.kind == .bowl && $0.food < 0.2 }
        guard empty else { return bowlEmptySince = nil }
        let since = bowlEmptySince ?? Sim.time
        bowlEmptySince = since
        if Sim.time - since > 300 {
            world.refillBowls()
            bowlEmptySince = nil
        }
    }

    /// Runs the world for `seconds` of simulated time in steps of `step`.
    func run(for seconds: Double, step: Double = 1.0 / 60) {
        let end = state.time + seconds
        while state.time < end - step / 2 { update(deltaTime: step) }
    }
}

/// Things that can happen to a cat from outside.
enum WorldEvent {
    case petted, squished
}
