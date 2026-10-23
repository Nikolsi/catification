import AppKit

/// `Catification --demo <scene>` stages a short scripted scene for README recordings.
/// It uses throwaway in-memory settings, paints a backdrop over the stage so nothing else on
/// screen gets recorded, and prints the stage rectangle in `screencapture -R` format.
/// See `scripts/record-demos.sh`.
@MainActor
final class DemoDirector {
    enum Scene: String, CaseIterable {
        case notch, jump, miss, trash, butterflies, pet, play, naps, trailer

        /// How long the recording script should record, in seconds.
        var duration: Double {
            switch self {
            case .notch: 12
            case .jump: 11
            case .miss: 12
            case .trash: 11
            case .butterflies: 12
            case .pet: 9
            case .play: 11
            case .naps: 10
            case .trailer: 22
            }
        }
    }

    static var requested: Scene? {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--demo"), args.count > i + 1 else { return nil }
        return Scene(rawValue: args[i + 1])
    }

    let scene: Scene
    private weak var world: CatWorld?
    /// The director of the running demo, if any, so the world can report key moments.
    private(set) static weak var current: DemoDirector?
    private var startTime = CACurrentMediaTime()

    /// Prints a key moment for the trailer to time and aim its camera moves:
    /// "EVENT <name> <seconds> <cat> <x> <y>", where x and y place the cat in the stage (0…1,
    /// from the top left).
    func event(_ name: String, cat: Cat?) {
        var x = 0.5, y = 0.5
        if let cat, let stage = world?.demoStage {
            x = Double((cat.x - stage.minX) / stage.width)
            y = Double(1 - (cat.y + cat.catHeight / 2 - stage.minY) / stage.height)
        }
        let catName = (cat?.config.name ?? "-").replacingOccurrences(of: " ", with: "_")
        let seconds = CACurrentMediaTime() - startTime
        print(String(format: "EVENT %@ %.2f %@ %.3f %.3f", name, seconds, catName, x, y))
        fflush(stdout)
    }

    private var cursorTimer: Timer?

    // Room scenes share one stage in the bottom-left corner of the screen.
    // Small, so cats look big in an 880px-wide GIF recorded at 2x.
    private static let room = CGRect(x: 140, y: 0, width: 440, height: 300)
    private static let floor: CGFloat = 26
    private static var groundY: CGFloat { room.minY + floor }

    private let shelfA = UUID(), shelfB = UUID(), bed = UUID(), trash = UUID()

    init(scene: Scene) {
        self.scene = scene
    }

    // MARK: Settings for the scene

    func makeStore() -> SettingsStore {
        let r = Self.room, g = Self.groundY
        var cats: [CatConfig] = []
        var furniture: [Furniture] = []
        let stairs = [
            Furniture(id: shelfA, kind: .shelf, x: Double(r.minX + 170), y: Double(g + 110), width: 130),
            Furniture(id: shelfB, kind: .shelf, x: Double(r.minX + 290), y: Double(g + 210), width: 130),
        ]
        switch scene {
        case .notch:
            cats = [CatConfig(name: L("Ginger"), coat: .ginger, personality: .playful),
                    CatConfig(name: L("Midnight"), coat: .tuxedo, personality: .curious),
                    CatConfig(name: L("Marshmallow"), coat: .siamese, personality: .playful)]
        case .jump:
            cats = [CatConfig(name: L("Ginger"), coat: .ginger, personality: .playful)]
            furniture = stairs + [Furniture(id: bed, kind: .bed, x: Double(r.minX + 375), y: Double(g + 210))]
        case .miss:
            cats = [CatConfig(name: L("Midnight"), coat: .gray, personality: .curious)]
            furniture = stairs
        case .trash:
            cats = [CatConfig(name: L("Ginger"), coat: .ginger, personality: .curious)]
            furniture = [Furniture(id: trash, kind: .trash, x: Double(r.minX + 290), y: Double(g))]
        case .butterflies:
            cats = [CatConfig(name: L("Ginger"), coat: .ginger, personality: .playful),
                    CatConfig(name: L("Marshmallow"), coat: .calico, personality: .playful)]
            furniture = [Furniture(id: shelfA, kind: .shelf, x: Double(r.minX + 250), y: Double(g + 100), width: 150)]
        case .pet:
            cats = [CatConfig(name: L("Ginger"), coat: .ginger, personality: .affectionate)]
        case .play:
            cats = [CatConfig(name: L("Ginger"), coat: .ginger, personality: .playful),
                    CatConfig(name: L("Midnight"), coat: .tuxedo, personality: .playful)]
        case .trailer:
            cats = [CatConfig(name: L("Ginger"), coat: .ginger, personality: .playful),
                    CatConfig(name: L("Marshmallow"), coat: .siamese, personality: .lazy)]
            cats[1].brain = { var b = CatBrain.preset(.lazy); b.places = [.box: 50, .bed: 0, .friends: 0]; b.routines = []; return b }()
            // Placed in `start`, once the notch position is known.
        case .naps:
            // Each cat has one firm favourite spot.
            let spots: [(CoatPreset, CatPlace, FurnitureKind, CGFloat)] = [
                (.ginger, .box, .box, 50), (.siamese, .closedBox, .closedBox, 130), (.calico, .laundry, .laundry, 215),
                (.gray, .flowerPot, .flowerPot, 300), (.tuxedo, .wardrobe, .wardrobe, 385),
            ]
            for (coat, place, kind, x) in spots {
                var cat = CatConfig(name: coat.title, coat: coat, personality: .lazy)
                var brain = CatBrain.preset(.lazy)
                brain.places = [place: 3, .bed: 0, .friends: 0]
                brain.routines = []
                cat.brain = brain
                cats.append(cat)
                furniture.append(Furniture(kind: kind, x: Double(r.minX + x), y: Double(g)))
            }
        }
        return SettingsStore(transientCats: cats, furniture: furniture, mode: .screen)
    }

    // MARK: Running the scene

    func start(in world: CatWorld) {
        self.world = world
        Self.current = self
        startTime = CACurrentMediaTime()
        let stage: CGRect
        if scene == .trailer, let notch = world.geo.notch {
            // 480×270 points: 960×540 on a Retina screen, scaled up exactly 2× to 1920×1080 for the trailer.
            let mid = (notch.lowerBound + notch.upperBound) / 2
            stage = CGRect(x: (mid - 240).rounded(), y: world.geo.height - 270, width: 480, height: 270)
            world.setDemoStage(stage, floor: Self.floor, notch: CGRect(x: notch.lowerBound, y: world.geo.menuBarY,
                                                                       width: notch.upperBound - notch.lowerBound, height: world.geo.menuBarHeight),
                               menuBar: true)
            setUpTrailer(in: world, notch: notch, stage: stage)
        } else if scene == .notch, let notch = world.geo.notch {
            stage = CGRect(x: notch.lowerBound - 200, y: world.geo.menuBarY - 4,
                           width: notch.upperBound - notch.lowerBound + 400, height: world.geo.menuBarHeight + 4)
            world.setDemoStage(stage, floor: 0, notch: CGRect(x: notch.lowerBound, y: world.geo.menuBarY,
                                                              width: notch.upperBound - notch.lowerBound, height: world.geo.menuBarHeight))
        } else {
            stage = Self.room
            world.setDemoStage(stage, floor: Self.floor, notch: nil)
        }

        // screencapture wants top-left-origin global coordinates.
        let frame = world.geo.frame
        let primaryHeight = NSScreen.screens.first?.frame.height ?? frame.height
        let x = Int(frame.minX + stage.minX), y = Int(primaryHeight - (frame.minY + stage.maxY))
        print("\(x),\(y),\(Int(stage.width)),\(Int(stage.height)) \(scene.duration)")
        fflush(stdout)

        // The recording shows the cursor, so park it off-stage unless the scene needs it.
        if scene != .pet {
            CGWarpMouseCursorPosition(CGPoint(x: frame.maxX - 20, y: primaryHeight - frame.maxY + frame.height / 2))
        }

        // Put the cats where the scene needs them while they're still dropping in.
        for (cat, x) in zip(world.cats, startPositions) { cat.demoPlace(x: x) }
        if scene == .trailer, let sleeper = world.cats.last, let stage = world.demoStage {
            // The sleepy one starts on the floor, next to its box.
            sleeper.demoPlace(x: stage.minX + 130, y: stage.minY + Self.floor + 4)
        }
        if scene == .trailer, CommandLine.arguments.contains("--wait-go") {
            waitForGo()
        } else {
            script()
        }
    }

    /// The trailer script starts the story once recording is running, by creating this file.
    static let goFile = "/tmp/catification-trailer-go"

    private func waitForGo() {
        Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard FileManager.default.fileExists(atPath: Self.goFile) else { return }
                timer.invalidate()
                guard let self, let world = self.world else { return }
                world.tickDemoClock()
                self.startTime = CACurrentMediaTime()
                self.event("go", cat: nil)
                self.script()
            }
        }
    }

    private func setUpTrailer(in world: CatWorld, notch: ClosedRange<CGFloat>, stage: CGRect) {
        let menuBar = world.geo.menuBarY
        let ground = stage.minY + Self.floor
        world.store.furniture = [
            // A low shelf on the right, and a higher one to its left, under the notch.
            // The drop to the low shelf stays small enough not to need maths; the jump up to the
            // high one is big enough to calculate, and to miss.
            Furniture(id: shelfA, kind: .shelf, x: Double(stage.maxX - 120), y: Double(menuBar - 120), width: 110),
            Furniture(id: shelfB, kind: .shelf, x: Double(stage.maxX - 255), y: Double(menuBar - 45), width: 90),
            Furniture(id: trash, kind: .box, x: Double(stage.minX + 80), y: Double(ground)),
        ]
        // Pick up the furniture now rather than on the next turn of the run loop.
        world.reloadFurnitureForDemo()
    }

    private var startPositions: [CGFloat] {
        let r = Self.room
        switch scene {
        case .notch: return []
        case .jump: return [r.minX + 70]
        case .miss: return [r.minX + 90]
        case .trash: return [r.minX + 150]
        case .butterflies: return [r.minX + 110, r.minX + 320]
        case .pet: return [r.midX]
        case .play: return [r.minX + 150, r.minX + 240]
        case .naps: return [r.minX + 90, r.minX + 170, r.minX + 250, r.minX + 330, r.minX + 340]
        case .trailer:
            guard let stage = world?.demoStage else { return [] }
            return [stage.minX + 40, stage.minX + 130]
        }
    }

    private func at(_ seconds: Double, _ action: @escaping (CatWorld) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            MainActor.assumeIsolated {
                guard let world = self?.world else { return }
                action(world)
            }
        }
    }

    private func script() {
        let r = Self.room
        switch scene {
        case .notch:
            // Back and forth across the notch.
            for (i, t) in stride(from: 1.0, to: 30, by: 3.4).enumerated() {
                at(t) { world in
                    guard let notch = world.geo.notch else { return }
                    let x = i % 2 == 0 ? notch.upperBound + 150 : notch.lowerBound - 150
                    for (k, cat) in world.cats.enumerated() {
                        cat.call(to: x + CGFloat(k - 1) * 30, world: world)
                    }
                }
            }
        case .jump:
            at(1.6) { world in
                guard let cat = world.cats.first, let s = world.surface(.shelf(self.shelfB)) else { return }
                cat.go(to: .shelf(self.shelfB), x: s.segments[0].lowerBound + 40, then: .sit, running: true, world: world)
            }
        case .miss:
            at(1.6) { world in
                guard let cat = world.cats.first, let s = world.surface(.shelf(self.shelfA)) else { return }
                cat.demoMiss = true
                cat.go(to: .shelf(self.shelfA), x: s.segments[0].lowerBound + 60, then: .sit, running: true, world: world)
            }
            at(7.6) { world in
                guard let cat = world.cats.first, let s = world.surface(.shelf(self.shelfA)) else { return }
                cat.go(to: .shelf(self.shelfA), x: s.segments[0].lowerBound + 60, then: .sit, running: true, world: world)
            }
        case .trash:
            at(1.5) { world in _ = world.cats.first?.goRummage(world) }
        case .butterflies:
            at(0.6) { world in
                world.releaseButterfly()
                world.releaseButterfly()
            }
            for t in stride(from: 1.8, to: 30, by: 4.0) {
                at(t) { world in
                    for (i, cat) in world.cats.enumerated() where cat.huntKind == nil {
                        let butterflies = world.butterflies
                        guard !butterflies.isEmpty else { return }
                        cat.startHunting(.butterfly, target: butterflies[i % butterflies.count].id, world: world)
                    }
                }
            }
        case .pet:
            at(1.2) { world in
                guard let cat = world.cats.first else { return }
                cat.go(to: .ground, x: r.midX, then: .sit, world: world)
            }
            at(2.6) { world in self.strokeCursor(over: world.cats.first, in: world, for: 3.8) }
            for t in [6.9, 7.7] {
                at(t) { world in world.cats.first?.squish(world: world) }
            }
        case .naps:
            at(1.6) { world in
                for cat in world.cats { cat.goToSleep(world) }
            }
        case .trailer:
            // Cat → notch → portals → a shelf → maths → a missed jump, hanging off the edge.
            at(0.3) { world in
                world.cats.last?.demoNoWake = true
                world.cats.last?.goToSleep(world)
            }
            // Each step starts once the cat has sat down after the previous one, so timing
            // differences between runs can't make steps overlap.
            steps = [
                { world in
                    guard let cat = world.cats.first, let stage = world.demoStage else { return }
                    cat.go(to: .menuBar, x: stage.maxX - 60, then: .sit, running: true, world: world)
                },
                { world in
                    guard let cat = world.cats.first, let s = world.surface(.shelf(self.shelfA)) else { return }
                    cat.go(to: .shelf(self.shelfA), x: s.segments[0].upperBound - 30, then: .sit, running: true, world: world)
                },
                { world in
                    guard let cat = world.cats.first, let s = world.surface(.shelf(self.shelfB)) else { return }
                    cat.demoMiss = true
                    cat.go(to: .shelf(self.shelfB), x: s.segments[0].lowerBound + 30, then: .sit, running: true, world: world)
                },
            ]
            at(1.2) { world in self.runSteps(in: world) }
        case .play:
            for t in [1.5, 6.5] {
                at(t) { world in
                    guard world.cats.count > 1 else { return }
                    let a = world.cats[0], b = world.cats[1]
                    if a.isPlayable, b.isPlayable { a.startPlay(with: b, world: world) }
                }
            }
        }
    }

    private var steps: [(CatWorld) -> Void] = []
    private var stepTimer: Timer?

    /// Runs `steps` one after another, each once the hero cat is sitting (or standing) still.
    private func runSteps(in world: CatWorld) {
        guard !steps.isEmpty else { return }
        steps.removeFirst()(world)
        var settled = 0.0
        stepTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, let world = self.world, let cat = world.cats.first else { return timer.invalidate() }
                settled = cat.activity == .sit && cat.surface != nil ? settled + 0.1 : 0
                guard settled >= 0.4 else { return }
                timer.invalidate()
                self.runSteps(in: world)
            }
        }
    }

    /// Moves the real cursor back and forth over a cat, which is exactly how petting works.
    private func strokeCursor(over cat: Cat?, in world: CatWorld, for seconds: Double) {
        guard let cat else { return }
        let frame = world.geo.frame
        let primaryHeight = NSScreen.screens.first?.frame.height ?? frame.height
        let start = CACurrentMediaTime()
        cursorTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                let t = CACurrentMediaTime() - start
                guard t < seconds else {
                    timer.invalidate()
                    self?.cursorTimer = nil
                    return
                }
                // Along the cat's back, like a hand would.
                let p = CGPoint(x: cat.x + CGFloat(sin(t * 4)) * 7 * cat.pixel, y: cat.y + 8 * cat.pixel)
                CGWarpMouseCursorPosition(CGPoint(x: frame.minX + p.x, y: primaryHeight - (frame.minY + p.y)))
            }
        }
    }
}
