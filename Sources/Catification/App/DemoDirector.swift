import AppKit
import SwiftUI

/// `Catification --demo <scene>` stages a short scripted scene for README recordings.
/// It uses throwaway in-memory settings, paints a backdrop over the stage so nothing else on
/// screen gets recorded, and prints the stage rectangle in `screencapture -R` format.
/// See `scripts/record-demos.sh`.
@MainActor
final class DemoDirector {
    enum Scene: String, CaseIterable {
        case notch, jump, miss, trash, butterflies, pet, play, ambush, naps, poses, trailer, windows

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
            case .poses: 22
            case .ambush: 15
            case .trailer: 22
            case .windows: 20
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
        // Before any cat exists, so the same scene plays out the same way every time. The play
        // scene's seed is one where the cats end up wrestling.
        Sim.seed(Sim.commandLineSeed ?? (scene == .play ? 5 : 1), start: Self.date)
    }

    /// Scenes happen on a Tuesday at 9:40, like the clock in their menu bar says.
    private static let date = DateComponents(calendar: .current, year: 2026, month: 1, day: 13, hour: 9, minute: 40).date ?? Date()

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
        case .windows:
            cats = [CatConfig(name: L("Ginger"), coat: .ginger, personality: .playful),
                    CatConfig(name: L("Marshmallow"), coat: .siamese, personality: .lazy)]
        case .trailer:
            cats = [CatConfig(name: L("Ginger"), coat: .ginger, personality: .playful),
                    CatConfig(name: L("Marshmallow"), coat: .siamese, personality: .lazy)]
            cats[1].brain = { var b = CatBrain.preset(.lazy); b.places = [.box: 50, .bed: 0, .friends: 0]; b.routines = []; return b }()
            // Placed in `start`, once the notch position is known.
        case .ambush:
            cats = [CatConfig(name: L("Ginger"), coat: .ginger, personality: .playful),
                    CatConfig(name: L("Smokey"), coat: .gray, personality: .lazy)]
        case .poses:
            // Four ways to sleep, then a big stretch.
            let poses: [(CoatPreset, SleepPose)] = [(.ginger, .loaf), (.gray, .curled), (.tuxedo, .sploot), (.calico, .bellyUp)]
            for (coat, pose) in poses {
                var cat = CatConfig(name: coat.title, coat: coat, personality: .lazy)
                var brain = CatBrain.preset(.lazy)
                brain.sleepPose = pose
                brain.routines = []
                cat.brain = brain
                cats.append(cat)
            }
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
        if scene == .windows, let notch = world.geo.notch {
            // 640×360 points at the top of the screen, around the notch: 1280×720 on Retina.
            let mid = (notch.lowerBound + notch.upperBound) / 2
            stage = CGRect(x: (mid - 320).rounded(), y: world.geo.height - 360, width: 640, height: 360)
            world.store.walkOnWindows = true
            world.demoWindows = true
            world.demoFormulaScale = 1.5
            world.setDemoStage(stage, floor: 0, notch: CGRect(x: notch.lowerBound, y: world.geo.menuBarY,
                                                              width: notch.upperBound - notch.lowerBound, height: world.geo.menuBarHeight),
                               menuBar: true, backdrop: false)
            setUpWindows(in: world, stage: stage)
        } else if scene == .trailer, let notch = world.geo.notch {
            // 480×270 points: 960×540 on a Retina screen, scaled up exactly 2× to 1920×1080 for the trailer.
            let mid = (notch.lowerBound + notch.upperBound) / 2
            stage = CGRect(x: (mid - 240).rounded(), y: world.geo.height - 270, width: 480, height: 270)
            world.setDemoStage(stage, floor: Self.floor, notch: CGRect(x: notch.lowerBound, y: world.geo.menuBarY,
                                                                       width: notch.upperBound - notch.lowerBound, height: world.geo.menuBarHeight),
                               menuBar: true)
            setUpTrailer(in: world, notch: notch, stage: stage)
            world.demoFormulaScale = 2
        } else if scene == .notch, let notch = world.geo.notch {
            stage = CGRect(x: notch.lowerBound - 200, y: world.geo.menuBarY - 4,
                           width: notch.upperBound - notch.lowerBound + 400, height: world.geo.menuBarHeight + 4)
            world.setDemoStage(stage, floor: 0, notch: CGRect(x: notch.lowerBound, y: world.geo.menuBarY,
                                                              width: notch.upperBound - notch.lowerBound, height: world.geo.menuBarHeight))
        } else if scene == .poses || scene == .ambush {
            // A low strip: everything happens on the floor, so the cats look big.
            stage = CGRect(x: Self.room.minX, y: Self.room.minY, width: Self.room.width, height: 120)
            world.setDemoStage(stage, floor: Self.floor, notch: nil)
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
        if scene == .windows, world.cats.count > 1 {
            // The hero drops onto the terminal, a sleepy friend onto the Notes window. Again a moment
            // later if one fell past its window before the window list caught up.
            func drop(_ world: CatWorld) {
                guard let terminal, let notes, let t = windowTop(terminal), let n = windowTop(notes) else { return }
                let hero = world.cats[0], friend = world.cats[1]
                if hero.surface != .window(terminal.windowNumber) { hero.demoPlace(x: t.x - 40, y: t.y + 12) }
                if friend.surface != .window(notes.windowNumber) { friend.demoPlace(x: n.x + 55, y: n.y + 12) }
            }
            drop(world)
            at(0.8, drop)
            at(1.6) { world in
                world.cats[0].begin(.sit, for: 60)
                world.cats[1].demoNoWake = true
                world.cats[1].goToSleep(world, here: true)
            }
        }
        if scene == .trailer || scene == .windows, CommandLine.arguments.contains("--wait-go") {
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
                // However long the wait was, the story itself always plays out the same way.
                Sim.seed(Sim.commandLineSeed ?? 1, start: Self.date.addingTimeInterval(60))
                self.startTime = CACurrentMediaTime()
                self.event("go", cat: nil)
                self.script()
            }
        }
    }

    // MARK: Real windows

    private var wallpaper: NSWindow?
    private var terminal: NSWindow?
    private var notes: NSWindow?

    /// A wallpaper behind everything in the stage, and two real windows for the cats to walk on.
    private func setUpWindows(in world: CatWorld, stage: CGRect) {
        let frame = world.geo.frame
        let screenStage = stage.offsetBy(dx: frame.minX, dy: frame.minY)

        let wall = NSWindow(contentRect: screenStage, styleMask: .borderless, backing: .buffered, defer: false)
        // An ordinary window, so it hides other apps' windows from the cats as well as the camera.
        // Its top edge is above the menu bar, so nobody walks on it.
        wall.level = .normal
        wall.ignoresMouseEvents = true
        wall.isReleasedWhenClosed = false
        wall.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        let view = NSView(frame: CGRect(origin: .zero, size: screenStage.size))
        view.wantsLayer = true
        let gradient = CAGradientLayer()
        gradient.frame = view.bounds
        gradient.colors = [RGB(hex: 0x2B1E5C).nsColor.cgColor, RGB(hex: 0x6A3B8E).nsColor.cgColor, RGB(hex: 0xE9895B).nsColor.cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        view.layer?.addSublayer(gradient)
        wall.contentView = view
        if #available(macOS 14, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
        wall.orderFrontRegardless()
        wallpaper = wall

        func window(_ title: String, _ rect: CGRect, dark: Bool, content: some View) -> NSWindow {
            let w = NSWindow(contentRect: rect.offsetBy(dx: frame.minX, dy: frame.minY),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
            w.title = title
            w.isReleasedWhenClosed = false
            w.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
            w.contentView = NSHostingView(rootView: content)
            w.setFrame(rect.offsetBy(dx: frame.minX, dy: frame.minY), display: true)
            w.orderFrontRegardless()
            return w
        }
        terminal = window("Terminal — zsh", CGRect(x: stage.minX + 40, y: stage.minY + 16, width: 300, height: 150), dark: true,
                          content: VStack(alignment: .leading, spacing: 5) {
                              Text("~/catification % make run").foregroundColor(.green)
                              Text("Built build/Catification.app").foregroundColor(.white)
                              Text("~/catification % ▍").foregroundColor(.white)
                          }
                          .font(.system(size: 12, design: .monospaced))
                          .padding(10)
                          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                          .background(Color(white: 0.1)))
        notes = window("Notes", CGRect(x: stage.minX + 372, y: stage.minY + 108, width: 232, height: 140), dark: false,
                       content: VStack(alignment: .leading, spacing: 6) {
                           Text("Today").font(.system(size: 15, weight: .bold))
                           Text("☑︎ pet the cats")
                           Text("☐ feed the cats")
                           Text("☐ ship v0.2")
                       }
                       .font(.system(size: 13))
                       .foregroundColor(.black)
                       .padding(12)
                       .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                       .background(Color(white: 0.99)))
    }

    private var cursorWindow: NSWindow?
    private var cursorPoint: CGPoint?

    /// An arrow drawn by us. The real cursor stays parked off stage: it takes its shape from
    /// whichever app is in front (the terminal running the recording would show a text cursor).
    private func showCursor(at point: CGPoint) {
        let cursor = NSCursor.arrow
        let size = cursor.image.size
        cursorPoint = point
        let origin = CGPoint(x: point.x - cursor.hotSpot.x, y: point.y - size.height + cursor.hotSpot.y)
        if let w = cursorWindow { return w.setFrameOrigin(origin) }
        let w = NSWindow(contentRect: CGRect(origin: origin, size: size), styleMask: .borderless, backing: .buffered, defer: false)
        w.level = .screenSaver
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = true
        w.isReleasedWhenClosed = false
        w.contentView = NSImageView(image: cursor.image)
        w.orderFrontRegardless()
        cursorWindow = w
    }

    private func windowTop(_ w: NSWindow?) -> (x: CGFloat, y: CGFloat)? {
        guard let w, let frame = world?.geo.frame else { return nil }
        return (w.frame.midX - frame.minX, w.frame.maxY - frame.minY)
    }

    /// Drags a window by its title bar, like a person would, with a drawn cursor that first moves
    /// over to the title bar.
    private func drag(_ w: NSWindow?, by delta: CGVector, over seconds: Double, then done: @escaping () -> Void) {
        guard let w else { return }
        let start = w.frame.origin
        let grab = CGPoint(x: w.frame.width * 0.62, y: w.frame.height - 12)
        let from = cursorPoint ?? CGPoint(x: w.frame.maxX + 90, y: w.frame.minY - 30)
        let approach = 0.7
        let began = CACurrentMediaTime()
        func ease(_ t: Double) -> CGFloat { CGFloat(t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2) }
        Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { timer in
            MainActor.assumeIsolated {
                let elapsed = CACurrentMediaTime() - began
                if elapsed < approach {
                    let k = ease(elapsed / approach)
                    let to = CGPoint(x: start.x + grab.x, y: start.y + grab.y)
                    self.showCursor(at: CGPoint(x: from.x + (to.x - from.x) * k, y: from.y + (to.y - from.y) * k))
                    return
                }
                let t = min(1, (elapsed - approach) / seconds)
                let origin = CGPoint(x: start.x + delta.dx * ease(t), y: start.y + delta.dy * ease(t))
                w.setFrameOrigin(origin)
                self.showCursor(at: CGPoint(x: origin.x + grab.x, y: origin.y + grab.y))
                if t >= 1 {
                    timer.invalidate()
                    done()
                }
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
        case .windows: return []
        case .poses: return [r.minX + 60, r.minX + 160, r.minX + 270, r.minX + 380]
        case .ambush: return [r.minX + 120, r.minX + 220]
        case .trailer:
            guard let stage = world?.demoStage else { return [] }
            return [stage.minX + 40, stage.minX + 130]
        }
    }

    /// Runs `action` after `seconds` of simulated time.
    private func at(_ seconds: Double, _ action: @escaping (CatWorld) -> Void) {
        world?.after(seconds) { [weak self] in
            guard let world = self?.world else { return }
            action(world)
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
        case .ambush:
            // A sleeping cat, a sneaky one, a pounce, a fight cloud, and a very cross cat.
            at(0.8) { world in
                guard world.cats.count > 1 else { return }
                let sleeper = world.cats[1]
                sleeper.demoPose = .curled
                sleeper.demoNoWake = true
                sleeper.goToSleep(world, here: true)
                world.cats[0].begin(.sit, for: 3)
            }
            at(3.6) { world in
                guard world.cats.count > 1 else { return }
                world.cats[0].ambush(world.cats[1], world: world)
            }
        case .poses:
            for (i, cat) in world?.cats.enumerated() ?? [].enumerated() {
                cat.demoPose = cat.config.brain?.sleepPose
                at(1.2 + Double(i) * 0.5) { world in
                    cat.demoNoWake = true
                    cat.goToSleep(world, here: true)
                }
            }
            at(18.5) { _ in
                guard let ginger = self.world?.cats.first else { return }
                ginger.demoNoWake = false
                ginger.wakeUp()
            }
        case .windows:
            // Drag the terminal with the cat riding on it, then the cat jumps over to the Notes window.
            at(2.0) { world in
                self.event("drag", cat: world.cats.first)
                self.drag(self.terminal, by: CGVector(dx: 70, dy: 30), over: 2.4) {
                    self.at(0.7) { world in
                        guard let cat = world.cats.first, let notes = self.notes, let n = self.windowTop(notes) else { return }
                        cat.go(to: .window(notes.windowNumber), x: n.x - 40, then: .sit, running: true, world: world)
                        self.whenLanded(on: .window(notes.windowNumber)) { world in
                            world.cats.first?.showEmote(.heart, for: 1.6)
                            self.at(1.4) { world in
                                self.event("drag2", cat: world.cats.first)
                                self.drag(self.notes, by: CGVector(dx: -40, dy: -24), over: 2.0) {}
                            }
                        }
                    }
                }
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

    /// Checks `done` every 0.1 s of simulated time until it returns true.
    private func poll(_ done: @escaping (CatWorld) -> Bool) {
        at(0.1) { [weak self] world in
            if !done(world) { self?.poll(done) }
        }
    }

    /// Calls back once the hero has landed and sat down on a surface.
    private func whenLanded(on surface: SurfaceID, then action: @escaping (CatWorld) -> Void) {
        poll { world in
            guard let cat = world.cats.first, cat.surface == surface, cat.activity == .sit else { return false }
            action(world)
            return true
        }
    }

    private var steps: [(CatWorld) -> Void] = []

    /// Runs `steps` one after another, each once the hero cat is sitting (or standing) still.
    private func runSteps(in world: CatWorld) {
        guard !steps.isEmpty else { return }
        steps.removeFirst()(world)
        var settled = 0.0
        poll { [weak self] world in
            guard let cat = world.cats.first else { return true }
            settled = cat.activity == .sit && cat.surface != nil ? settled + 0.1 : 0
            guard settled >= 0.4 else { return false }
            self?.runSteps(in: world)
            return true
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
