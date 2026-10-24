import AppKit
import Combine
import QuartzCore

/// Owns the overlay panel, runs the simulation loop and routes mouse input.
@MainActor
final class CatWorld {
    let store: SettingsStore
    private let panel: OverlayPanel
    private let view: WorldView
    let root = CALayer()
    private(set) var geo: WorldGeometry
    private(set) var cats: [Cat] = []

    // Surfaces.
    private(set) var surfaces: [SurfaceID: Surface] = [:]
    private(set) var links: [ClimbLink] = []
    private var anchors: [SurfaceID: CGPoint] = [:]
    private let windowTracker = WindowTracker()
    private let iconTracker = DesktopIconTracker()

    // Furniture and toys.
    var furniture: [Furniture] = []
    var furnitureViews: [UUID: FurnitureView] = [:]
    var props: [UUID: PropBody] = [:]
    private(set) var ball: Ball?
    private(set) var butterflies: [Butterfly] = []
    private var nextButterfly = Sim.time + .random(in: 6...15, using: &Sim.rng)
    private(set) var editMode = false
    private(set) var laserOn = false
    private let laserDot = CALayer()

    // Effects.
    private var particles: [Particle] = []
    private var calculations: [UUID: CalculationFX] = [:]
    private var fadingCalculations: [CalculationFX] = []
    private var portals: (left: PortalLayer, right: PortalLayer)?
    private var portalUsers = 0
    private var portalLastUse: CFTimeInterval = 0

    // Time and input.
    private var timer: Timer?
    private var lastTime = CACurrentMediaTime()
    /// Simulated time (`Sim.time`): use it for everything cats do, so seeded runs repeat exactly.
    private(set) var now = Sim.time
    private(set) var mouse: CGPoint = .zero
    private var lastMouse: CGPoint = .zero

    enum FurnitureGrab {
        case move(dx: CGFloat, dy: CGFloat)
        case left, right, top
    }

    private enum DragTarget {
        case cat(Cat)
        case ball
        case furniture(UUID, FurnitureGrab)
    }

    private struct Drag {
        let target: DragTarget
        let start: CGPoint
        var active = false
        var samples: [(t: CFTimeInterval, p: CGPoint)] = []
        var original: Furniture?
    }
    private var drag: Drag?

    private var syncScheduled = false
    private var cancellables = Set<AnyCancellable>()

    var contextMenuProvider: ((Cat) -> NSMenu)?

    /// Demo recordings confine the world to a "stage" with its own backdrop.
    private(set) var demoStage: CGRect?
    private var backdropLayers: [CALayer] = []
    private var demoClock: CATextLayer?
    /// Demo recordings can make the jump formulas bigger, to stay readable in a video on a phone.
    var demoFormulaScale: CGFloat = 1
    /// Demo recordings with real windows: cats walk on them even inside a stage, and the
    /// window list is read every frame so riding a dragged window looks smooth.
    var demoWindows = false

    /// Where cats, toys and butterflies may go. The whole panel, unless a demo stage is set.
    var playArea: CGRect { demoStage ?? CGRect(origin: .zero, size: geo.frame.size) }
    var onEditModeChange: ((Bool) -> Void)?

    /// Never shown and stepped by hand (`step(_:)`): the fast-forward runner and tests. No timer,
    /// no real windows, nobody at the mouse.
    let headless: Bool
    /// Counts what the cats do, if someone is interested (the fast-forward runner).
    var report: DayReport?

    init(store: SettingsStore, geometry: WorldGeometry? = nil, headless: Bool = false) {
        self.store = store
        self.headless = headless
        geo = geometry ?? WorldGeometry.current(mode: store.mode, virtualNotch: store.virtualNotch)
        panel = OverlayPanel(frame: geo.frame)
        view = WorldView(frame: NSRect(origin: .zero, size: geo.frame.size))
        view.layer = root
        view.wantsLayer = true
        root.frame = view.bounds
        root.disableImplicitAnimations()
        panel.contentView = view
        view.world = self

        laserDot.disableImplicitAnimations()
        laserDot.bounds = CGRect(x: 0, y: 0, width: 6, height: 6)
        laserDot.cornerRadius = 3
        laserDot.backgroundColor = NSColor(srgbRed: 1, green: 0.12, blue: 0.1, alpha: 1).cgColor
        laserDot.shadowColor = laserDot.backgroundColor
        laserDot.shadowOpacity = 1
        laserDot.shadowRadius = 5
        laserDot.shadowOffset = .zero
        laserDot.zPosition = 70
        laserDot.isHidden = true
        root.addSublayer(laserDot)

        applyPanelLevel()
        syncFurniture()
        rebuildSurfaces()
        syncCats()
        applyVisibility()

        if headless {
            mouse = CGPoint(x: -10_000, y: -10_000)
            lastMouse = mouse
            return
        }
        store.objectWillChange
            .sink { [weak self] _ in MainActor.assumeIsolated { self?.scheduleSync() } }
            .store(in: &cancellables)
        NotificationCenter.default.addObserver(
            self, selector: #selector(screensChanged),
            name: NSApplication.didChangeScreenParametersNotification, object: nil
        )

        let timer = Timer(timeInterval: 1.0 / 60, target: self, selector: #selector(tick), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Settings sync

    private func scheduleSync() {
        guard !syncScheduled else { return }
        syncScheduled = true
        // objectWillChange fires before the value changes, so read the store on the next turn.
        DispatchQueue.main.async { [weak self] in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.syncScheduled = false
                let g = WorldGeometry.current(mode: self.store.mode, virtualNotch: self.store.virtualNotch)
                if g != self.geo, self.demoStage == nil { self.relayout(g) }
                self.syncFurniture()
                self.syncCats()
                self.applyVisibility()
            }
        }
    }

    private func syncCats() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let configs = store.cats
        for cat in cats where !configs.contains(where: { $0.id == cat.id }) {
            remove(cat)
        }
        for config in configs {
            if let cat = cats.first(where: { $0.id == config.id }) {
                if cat.config != config { cat.apply(config: config, world: self) }
            } else {
                let cat = Cat(config: config, world: self)
                cats.append(cat)
                cat.attach(to: root)
                cat.spawn(world: self)
                sparkle(at: CGPoint(x: cat.x, y: cat.y + cat.catHeight / 2), kind: .sparkOrange, count: 6)
            }
        }
    }

    private func remove(_ cat: Cat) {
        if cat.transit != nil { portalUsers = max(0, portalUsers - 1) }
        if case .cat(let c)? = drag?.target, c === cat { drag = nil }
        finishCalculation(for: cat)
        sparkle(at: CGPoint(x: cat.x, y: cat.y + cat.catHeight / 2), kind: .sparkBlue, count: 8)
        cat.detach()
        cats.removeAll { $0 === cat }
    }

    /// Picks up changes to the store now. The app does this on its own on the next turn of the run loop.
    func syncWithStore() {
        syncFurniture()
        syncCats()
    }

    private func applyVisibility() {
        guard !headless else { return }
        if store.catsVisible {
            if !panel.isVisible { panel.orderFrontRegardless() }
        } else if panel.isVisible {
            panel.orderOut(nil)
        }
    }

    private func applyPanelLevel() {
        if geo.mode == .desktop {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)) + 1)
        } else {
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 1)
        }
    }

    @objc private func screensChanged() {
        relayout(WorldGeometry.current(mode: store.mode, virtualNotch: store.virtualNotch))
    }

    private func relayout(_ g: WorldGeometry) {
        let modeChanged = g.mode != geo.mode
        geo = g
        if !g.mode.hasFurniture, editMode { setEditMode(false) }
        panel.setFrame(g.frame, display: true)
        applyPanelLevel()
        view.frame = NSRect(origin: .zero, size: g.frame.size)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.frame = view.bounds
        if let p = portals {
            p.left.removeFromSuperlayer()
            p.right.removeFromSuperlayer()
            portals = nil
        }
        portalUsers = 0
        drag = nil
        for fx in calculations.values { fx.remove() }
        calculations = [:]
        windowTracker.clear()
        iconTracker.clear()
        for id in props.keys { props[id]?.surface = nil }
        if !g.mode.hasFurniture { removeBall() }
        for b in butterflies { b.layer.removeFromSuperlayer() }
        butterflies = []
        anchors = [:]
        rebuildSurfaces()
        if modeChanged {
            for cat in cats { cat.reset(world: self) }
        } else {
            for cat in cats where cat.surface == nil || surfaces[cat.surface!] == nil { cat.reset(world: self) }
        }
        CATransaction.commit()
    }

    // MARK: - Loop

    @objc private func tick() {
        let t = CACurrentMediaTime()
        let dt = Sim.advance(realDelta: t - lastTime)
        lastTime = t
        let m = NSEvent.mouseLocation
        mouse = CGPoint(x: m.x - geo.frame.minX, y: m.y - geo.frame.minY)
        step(dt)

        // Only catch the mouse while it is over something interactive; everywhere else
        // clicks go straight through to the menu bar and the apps below.
        let over = wantsMouse(at: mouse)
        if panel.ignoresMouseEvents == over { panel.ignoresMouseEvents = !over }
        lastMouse = mouse
    }

    /// One step of the simulation, `dt` seconds long; `Sim.time` has already moved on by `dt`.
    func step(_ dt: Double) {
        now = Sim.time
        runDue()
        guard store.catsVisible else { return }

        CATransaction.begin()
        CATransaction.setDisableActions(true)

        updateWindowTracking()
        rebuildSurfaces()
        updateDrag()
        handleStroking()
        for cat in cats { cat.update(dt: dt, world: self) }
        report?.tick(cats, dt: dt)
        updateProps(dt)
        ball?.update(dt: dt, world: self)
        updateButterflies(dt)
        particles.removeAll { p in
            let alive = p.update(dt)
            if !alive { p.layer.removeFromSuperlayer() }
            return !alive
        }
        fadingCalculations.removeAll { fx in
            let alive = fx.update(dt: dt)
            if !alive { fx.remove() }
            return !alive
        }
        updatePortals()
        updateFights(dt)

        for cat in cats { cat.sync(world: self) }
        syncFurnitureViews()
        ball?.sync()
        for b in butterflies { b.sync() }
        laserDot.isHidden = !laserOn
        if laserOn { laserDot.position = mouse }

        CATransaction.commit()
    }

    /// A notable moment for a cat (jump, hang, portal…): demo recordings and the report hear about it.
    func note(_ moment: String, cat: Cat) {
        DemoDirector.current?.event(moment, cat: cat)
        report?.moment(moment, cat: cat)
    }

    private var climbingIcons: Bool { store.climbIcons && geo.mode.hasFurniture }

    private func updateWindowTracking() {
        let tracking = (geo.mode == .screen && store.walkOnWindows) || geo.mode == .desktop || climbingIcons
        guard tracking, !headless else { return }
        let riding = cats.contains { $0.surface?.isWindow == true } || ball?.surface?.isWindow == true
        windowTracker.update(now: now, interval: demoWindows ? 0 : (riding ? 0.08 : 0.3), panelFrame: geo.frame)
        if climbingIcons {
            let onIcon = cats.contains { if case .icon? = $0.surface { return true } else { return false } }
            iconTracker.update(now: now, interval: onIcon ? 0.5 : 2, panelFrame: geo.frame)
        }
    }

    // MARK: - Surfaces

    private func rebuildSurfaces() {
        var list: [Surface] = []
        var newLinks: [ClimbLink] = []
        let area = playArea
        if geo.mode.hasMenuBar, area.maxY >= geo.menuBarY {
            list.append(Surface(id: .menuBar, y: geo.menuBarY, segments: [area.minX...area.maxX], anchor: CGPoint(x: 0, y: geo.menuBarY)))
        }
        if let g = geo.groundY, area.minY <= g + 1 {
            list.append(Surface(id: .ground, y: g, segments: [area.minX...area.maxX], anchor: CGPoint(x: 0, y: g)))
        }
        if geo.mode.hasFurniture {
            let p = geo.furniturePixel
            for f in furniture {
                switch f.kind {
                case .shelf:
                    let y = CGFloat(f.y), x = CGFloat(f.x)
                    list.append(Surface(id: .shelf(f.id), y: y, segments: [x...(x + CGFloat(f.width))], anchor: CGPoint(x: x, y: y)))
                case .post:
                    guard let g = geo.groundY else { break }
                    let x = CGFloat(f.x)
                    let perchY = g + CGFloat(postPixels(f)) * p
                    let half = CGFloat(PropArt.postWidth - 2) / 2 * p
                    list.append(Surface(id: .perch(f.id), y: perchY, segments: [(x - half)...(x + half)], anchor: CGPoint(x: x, y: perchY)))
                    newLinks.append(ClimbLink(post: f.id, x: x, bottom: .ground, top: .perch(f.id)))
                case .wardrobe, .closedBox:
                    // Tall or closed things have a top cats can climb onto.
                    guard let body = props[f.id], body.surface != nil else { break }
                    let art = f.kind == .wardrobe ? PropArt.wardrobe(front: false) : PropArt.closedBox()
                    let top = body.y + CGFloat(art.height - 2) * p
                    let half = CGFloat(art.width - 2) / 2 * p - p
                    list.append(Surface(id: .top(f.id), y: top, segments: [(body.x - half)...(body.x + half)], anchor: CGPoint(x: body.x, y: top)))
                default:
                    break
                }
            }
        }
        if geo.mode == .screen, store.walkOnWindows, demoStage == nil || demoWindows {
            list += windowTracker.surfaces(width: geo.width, below: geo.menuBarY, above: geo.groundY ?? 0,
                                           clearance: 16 * geo.furniturePixel)
        }

        if climbingIcons, demoStage == nil {
            list += iconTracker.surfaces(covering: windowTracker.windows, clearance: 16 * geo.furniturePixel)
        }

        var fresh: [SurfaceID: Surface] = [:]
        for s in list { fresh[s.id] = s }
        // Everything standing on a surface that moved rides along with it.
        for (id, s) in fresh {
            guard let old = anchors[id], old != s.anchor else { continue }
            surfaceMoved(id, dx: s.anchor.x - old.x, toY: s.y)
        }
        surfaces = fresh
        links = newLinks
        anchors = fresh.mapValues(\.anchor)
        validateRiders()
    }

    private func surfaceMoved(_ id: SurfaceID, dx: CGFloat, toY y: CGFloat) {
        for cat in cats where cat.surface == id { cat.ride(dx: dx, toY: y) }
        if let b = ball, b.surface == id { b.ride(dx: dx, toY: y) }
        for (pid, body) in props where body.surface == id {
            props[pid]?.x = body.x + dx
            props[pid]?.y = y
        }
    }

    private func validateRiders() {
        for cat in cats {
            if let id = cat.surface {
                if surfaces[id]?.segmentIndex(containing: cat.x, tolerance: 2) == nil { cat.fallOff() }
            } else if let post = cat.climbPost, !furniture.contains(where: { $0.id == post && abs(CGFloat($0.x) - cat.x) < 1 }) {
                cat.fallOff()
            }
        }
        if let b = ball, let id = b.surface, surfaces[id]?.segmentIndex(containing: b.x, tolerance: 1) == nil {
            b.surface = nil
        }
        for (pid, body) in props {
            if let id = body.surface, surfaces[id]?.segmentIndex(containing: body.x, tolerance: 1) == nil {
                props[pid]?.surface = nil
            }
        }
    }

    func surface(_ id: SurfaceID) -> Surface? { surfaces[id] }
    func surfaceY(_ id: SurfaceID) -> CGFloat? { surfaces[id]?.y }

    /// The highest surface crossed from above between `from` and `to` at `x`.
    func landingSurface(x: CGFloat, from previousY: CGFloat, to y: CGFloat, ignoring: SurfaceID?, staticOnly: Bool = false) -> Surface? {
        surfaces.values
            .filter { s in
                s.id != ignoring && !(staticOnly && s.id.isDynamic)
                    && previousY >= s.y - 0.01 && y <= s.y && s.segmentIndex(containing: x) != nil
            }
            .max { $0.y != $1.y ? $0.y < $1.y : $0.id > $1.id }
    }

    func hasSurfaceBelow(x: CGFloat, y: CGFloat) -> Bool {
        surfaces.values.contains { $0.y <= y + 1 && $0.segmentIndex(containing: x) != nil }
    }

    /// The nearest surface above a point, for things that fell out of the world.
    func surfaceAbove(x: CGFloat, y: CGFloat) -> CGFloat? {
        surfaces.values.filter { $0.y > y && $0.segmentIndex(containing: x) != nil }.map(\.y).min()
            ?? surfaces.values.map(\.y).min()
    }

    /// Where a point would be if dropped straight down onto whatever is just under it.
    func surfaceUnder(_ p: CGPoint) -> (surface: SurfaceID, x: CGFloat)? {
        surfaces.values
            .filter { $0.y <= p.y + 4 && p.y - $0.y < 80 && $0.segmentIndex(containing: p.x) != nil }
            .max { $0.y != $1.y ? $0.y < $1.y : $0.id > $1.id }
            .map { ($0.id, p.x) }
    }

    /// The highest the feet of a cat can be before its head leaves the screen.
    func ceiling(for cat: Cat) -> CGFloat {
        playArea.maxY - CGFloat(CatArt.H - 3) * cat.pixel
    }

    func clampOnSurface(_ value: CGFloat, _ id: SurfaceID, for cat: Cat) -> CGFloat {
        let wide = id == .menuBar || id == .ground
        let edge = wide ? cat.halfWidth + 2 : cat.halfWidth * 0.5
        var v = min(max(value, playArea.minX + edge), playArea.maxX - edge)
        guard let s = surfaces[id], let i = s.segmentIndex(containing: v) ?? s.nearestSegmentIndex(to: v) else { return v }
        let seg = s.segments[i]
        let m: CGFloat = wide ? 0 : 3 * cat.pixel
        let lo = seg.lowerBound + m, hi = seg.upperBound - m
        v = lo <= hi ? min(max(v, lo), hi) : (seg.lowerBound + seg.upperBound) / 2
        if id == .menuBar, let p = portalXs {
            let a = p.left - cat.halfWidth - 3, b = p.right + cat.halfWidth + 3
            if v > a, v < b { v = (v - a) < (b - v) ? a : b }
        }
        return v
    }

    func sameSegment(_ id: SurfaceID, _ a: CGFloat, _ b: CGFloat) -> Bool {
        guard let s = surfaces[id], let i = s.segmentIndex(containing: a, tolerance: 3) else { return false }
        return s.segmentIndex(containing: b, tolerance: 3) == i
    }

    var hasOtherSurfaces: Bool {
        surfaces.count > 1 || surfaces.values.contains { $0.segments.count > 1 }
    }

    // MARK: - Navigation

    private func limits(for cat: Cat) -> NavLimits {
        NavLimits(up: 9 * CGFloat(CatArt.H) * cat.pixel, across: 120 * cat.pixel, margin: 4 * cat.pixel)
    }

    private func explore(for cat: Cat) -> (start: Navigator.Node, map: [Navigator.Node: Navigator.Entry])? {
        guard let id = cat.surface, let s = surfaces[id],
              let i = s.segmentIndex(containing: cat.x, tolerance: 3) ?? s.nearestSegmentIndex(to: cat.x) else { return nil }
        let start = Navigator.Node(id: id, segment: i)
        let map = Navigator.explore(from: start, x: cat.x, surfaces: surfaces, links: links, limits: limits(for: cat)) { sid, v in
            self.clampOnSurface(v, sid, for: cat)
        }
        return (start, map)
    }

    func route(for cat: Cat, to dest: SurfaceID, x: CGFloat) -> Route? {
        guard let d = surfaces[dest], let di = d.segmentIndex(containing: x, tolerance: 3) ?? d.nearestSegmentIndex(to: x),
              let explored = explore(for: cat),
              let hops = Navigator.hops(to: Navigator.Node(id: dest, segment: di), in: explored.map)
        else { return nil }
        return Route(hops: hops, goal: dest, goalX: x)
    }

    /// Recomputes a planned hop against the surfaces as they are now (windows move).
    func refreshHop(_ hop: Hop, from x: CGFloat, for cat: Cat) -> Hop? {
        switch hop.kind {
        case .climbUp, .climbDown:
            return links.contains { abs($0.x - hop.takeoffX) < 1 } ? hop : nil
        case .jump:
            guard let a = surfaces[hop.from], let ai = a.segmentIndex(containing: x, tolerance: 4),
                  let b = surfaces[hop.to], let bi = b.segmentIndex(containing: hop.landX, tolerance: 6) ?? b.nearestSegmentIndex(to: hop.landX),
                  var fresh = Navigator.hop(from: a, ai, at: x, to: b, bi, limits: limits(for: cat))
            else { return nil }
            fresh.takeoffX = clampOnSurface(fresh.takeoffX, a.id, for: cat)
            fresh.landX = clampOnSurface(fresh.landX, b.id, for: cat)
            if abs(fresh.takeoffX - x) < 4 * cat.pixel { fresh.takeoffX = x }
            return fresh
        }
    }

    func randomDestination(for cat: Cat) -> (surface: SurfaceID, x: CGFloat)? {
        guard let explored = explore(for: cat) else { return nil }
        let candidates = explored.map.keys.filter { $0 != explored.start }.sorted()
        guard let node = candidates.randomElement(using: &Sim.rng), let s = surfaces[node.id], node.segment < s.segments.count else { return nil }
        let seg = s.segments[node.segment]
        let m = min(6 * cat.pixel, (seg.upperBound - seg.lowerBound) / 2)
        return (node.id, CGFloat.random(in: (seg.lowerBound + m)...(seg.upperBound - m), using: &Sim.rng))
    }

    /// The highest furniture a cat can reach (shelves and perches, not the menu bar or windows).
    func highSpot(for cat: Cat) -> (surface: SurfaceID, x: CGFloat)? {
        guard let explored = explore(for: cat) else { return nil }
        let furniture = explored.map.keys.filter { node in
            switch node.id {
            case .shelf, .perch, .top: true
            default: false
            }
        }
        guard let best = furniture.sorted().max(by: { (surfaces[$0.id]?.y ?? 0) < (surfaces[$1.id]?.y ?? 0) }),
              let s = surfaces[best.id], best.segment < s.segments.count else { return nil }
        let seg = s.segments[best.segment]
        let m = min(6 * cat.pixel, (seg.upperBound - seg.lowerBound) / 2)
        return (best.id, CGFloat.random(in: (seg.lowerBound + m)...(seg.upperBound - m), using: &Sim.rng))
    }

    /// Somewhere fitting for a cat to nap at one of its favourite kinds of place.
    func napSpot(_ place: CatPlace, for cat: Cat) -> (surface: SurfaceID, x: CGFloat)? {
        func anywhere(on id: SurfaceID) -> (surface: SurfaceID, x: CGFloat)? {
            guard let s = surfaces[id], let seg = s.segments.randomElement(using: &Sim.rng) else { return nil }
            return (id, clampOnSurface(.random(in: seg, using: &Sim.rng), id, for: cat))
        }
        func beside(_ x: CGFloat, on id: SurfaceID) -> (surface: SurfaceID, x: CGFloat)? {
            let side: CGFloat = cat.x < x ? -1 : 1
            return (id, clampOnSurface(x + side * 14 * cat.pixel, id, for: cat))
        }
        switch place {
        case .perch:
            return furniture.filter { $0.kind == .post }.randomElement(using: &Sim.rng).flatMap { post in
                surfaces[.perch(post.id)] != nil ? (SurfaceID.perch(post.id), CGFloat(post.x)) : nil
            }
        case .shelf:
            return furniture.filter { $0.kind == .shelf }.randomElement(using: &Sim.rng).flatMap { anywhere(on: .shelf($0.id)) }
        case .menuBar:
            return anywhere(on: .menuBar)
        case .floor:
            return anywhere(on: .ground)
        case .windows:
            return surfaces.keys.filter(\.isWindow).sorted().randomElement(using: &Sim.rng).flatMap { anywhere(on: $0) }
        case .cursor:
            return surfaceUnder(mouse).flatMap { beside($0.x, on: $0.surface) }
        case .bowl:
            return nearestBowl(for: cat).flatMap { beside($0.x, on: $0.surface) }
        case .trash:
            return furniture.filter { $0.kind == .trash }.compactMap { self.place($0.id, kind: .trash) }.randomElement(using: &Sim.rng)
                .flatMap { beside($0.x, on: $0.surface) }
        case .closedBox:
            return furniture.filter { $0.kind == .closedBox }.randomElement(using: &Sim.rng).flatMap { box in
                surfaces[.top(box.id)] != nil ? (SurfaceID.top(box.id), props[box.id]?.x ?? CGFloat(box.x)) : nil
            }
        case .bed, .high, .friends, .box, .laundry, .wardrobe, .flowerPot:
            return nil  // handled by the cat itself: furniture to curl up in, the top shelf or a sleeping friend
        }
    }

    func randomSpot(on id: SurfaceID, near x: CGFloat, for cat: Cat) -> CGFloat {
        guard let s = surfaces[id] else { return x }
        if id == .menuBar { return clampOnSurface(.random(in: playArea.minX...playArea.maxX, using: &Sim.rng), id, for: cat) }
        let seg = s.segments[s.segmentIndex(containing: x, tolerance: 3) ?? s.nearestSegmentIndex(to: x) ?? 0]
        return clampOnSurface(.random(in: seg, using: &Sim.rng), id, for: cat)
    }

    func spawnPoint(for cat: Cat) -> CGPoint {
        if geo.mode.hasMenuBar, playArea.maxY >= geo.menuBarY {
            let x = clampOnSurface(.random(in: playArea.minX...playArea.maxX, using: &Sim.rng), .menuBar, for: cat)
            return CGPoint(x: x, y: min(ceiling(for: cat), geo.menuBarY + 10))
        }
        let ground = geo.groundY ?? 0
        return CGPoint(x: clampOnSurface(.random(in: playArea.minX...playArea.maxX, using: &Sim.rng), .ground, for: cat), y: ground + 80)
    }

    var mouseNearCats: Bool {
        mouse.x >= 0 && mouse.x <= geo.width && mouse.y >= 0 && mouse.y <= geo.height
    }

    func playmate(for cat: Cat) -> Cat? {
        guard let s = cat.surface else { return nil }
        return cats.filter {
            $0 !== cat && $0.isPlayable && $0.energy > 0.3 && $0.surface == s
                && sameSegment(s, cat.x, $0.x) && abs($0.x - cat.x) < 500
        }.randomElement(using: &Sim.rng)
    }

    func sleepingBuddy(for cat: Cat) -> Cat? {
        cats.filter { $0 !== cat && $0.isAsleep && $0.surface != nil }.randomElement(using: &Sim.rng)
    }

    /// Sends every cat towards a point given in screen coordinates.
    func callCats(toScreenX sx: CGFloat) {
        let x = sx - geo.frame.minX
        for cat in cats { cat.call(to: x, world: self) }
    }

    // MARK: - Posts, bowls, beds

    struct PostInfo {
        let id: UUID
        let x: CGFloat
        let base: SurfaceID
        let perch: SurfaceID
    }

    struct PlaceInfo {
        let id: UUID
        let x: CGFloat
        let surface: SurfaceID
    }

    var hasPosts: Bool { geo.groundY != nil && furniture.contains { $0.kind == .post } }

    func post(_ id: UUID) -> PostInfo? {
        guard geo.groundY != nil, let f = furniture.first(where: { $0.id == id && $0.kind == .post }) else { return nil }
        return PostInfo(id: id, x: CGFloat(f.x), base: .ground, perch: .perch(id))
    }

    func randomPost() -> PostInfo? {
        furniture.filter { $0.kind == .post }.randomElement(using: &Sim.rng).flatMap { post($0.id) }
    }

    func postID(for hop: Hop) -> UUID? {
        links.first { abs($0.x - hop.takeoffX) < 1 }?.post
    }

    private func postPixels(_ f: Furniture) -> Int {
        max(16, Int((CGFloat(f.height) / geo.furniturePixel).rounded()))
    }

    var hasBowl: Bool { geo.mode.hasFurniture && furniture.contains { $0.kind == .bowl } }

    private func place(_ id: UUID, kind: FurnitureKind) -> PlaceInfo? {
        guard geo.mode.hasFurniture, furniture.contains(where: { $0.id == id && $0.kind == kind }),
              let body = props[id], let s = body.surface else { return nil }
        return PlaceInfo(id: id, x: body.x, surface: s)
    }

    func bowl(_ id: UUID) -> PlaceInfo? { place(id, kind: .bowl) }

    var hasTrash: Bool { geo.mode.hasFurniture && furniture.contains { $0.kind == .trash } }

    /// Where a trash can stands; `y` is its bottom.
    func trash(_ id: UUID) -> (id: UUID, x: CGFloat, y: CGFloat, surface: SurfaceID)? {
        guard let info = place(id, kind: .trash), let body = props[id] else { return nil }
        return (id, info.x, body.y, info.surface)
    }

    func randomTrash(for cat: Cat) -> PlaceInfo? {
        furniture.filter { $0.kind == .trash && !trashOccupied($0.id, by: cat) }
            .compactMap { place($0.id, kind: .trash) }
            .randomElement(using: &Sim.rng)
    }

    func trashOccupied(_ id: UUID, by cat: Cat) -> Bool {
        cats.contains { $0 !== cat && $0.trashID == id && $0.activity == .rummaging }
    }

    func spawnTrashBit(at point: CGPoint) {
        let kind: EmoteKind = Double.random(in: 0...1, using: &Sim.rng) < 0.25 ? .bone : .paper
        addParticle(kind, at: point, velocity: CGVector(dx: .random(in: -70...70, using: &Sim.rng), dy: .random(in: 110...200, using: &Sim.rng)),
                    gravity: 520, life: .random(in: 0.8...1.2, using: &Sim.rng), pixel: geo.furniturePixel)
    }
    func bed(_ id: UUID) -> PlaceInfo? { place(id, kind: .bed) }

    /// A piece of furniture a cat can sleep inside, wherever it currently stands.
    func napFurniture(_ id: UUID) -> (info: PlaceInfo, kind: FurnitureKind)? {
        guard let f = furniture.first(where: { $0.id == id }), f.kind.isNapSpot, let info = place(id, kind: f.kind) else { return nil }
        return (info, f.kind)
    }

    func freeNapFurniture(_ kind: FurnitureKind, for cat: Cat) -> PlaceInfo? {
        furniture.filter { $0.kind == kind }
            .compactMap { place($0.id, kind: kind) }
            .filter { spot in !cats.contains { $0 !== cat && $0.claims(bed: spot.id) } }
            .randomElement(using: &Sim.rng)
    }

    /// How high above the furniture's bottom a napping cat lies, in points.
    func napLift(_ kind: FurnitureKind) -> CGFloat {
        let p = geo.furniturePixel
        switch kind {
        case .box: return PropArt.boxNapLift * p
        case .laundry: return PropArt.laundryNapLift * p
        case .wardrobe: return PropArt.wardrobeNapLift * p
        case .flowerPot: return PropArt.potNapLift * p
        default: return 2 * p
        }
    }

    func nearestBowl(for cat: Cat) -> PlaceInfo? {
        furniture.filter { $0.kind == .bowl }
            .compactMap { bowl($0.id) }
            .min { abs($0.x - cat.x) < abs($1.x - cat.x) }
    }

    func freeBed(for cat: Cat) -> PlaceInfo? { freeNapFurniture(.bed, for: cat) }

    /// One portion of food; false if the bowl is empty.
    func takeFood(from id: UUID) -> Bool {
        guard let i = furniture.firstIndex(where: { $0.id == id }), furniture[i].food >= 0.2 else { return false }
        furniture[i].food = max(0, furniture[i].food - 0.25)
        commitFurniture()
        return true
    }

    func refillBowls() {
        for i in furniture.indices where furniture[i].kind == .bowl {
            furniture[i].food = 1
            if let body = props[furniture[i].id] {
                sparkle(at: CGPoint(x: body.x, y: body.y + 8), kind: .sparkOrange, count: 8)
            }
        }
        commitFurniture()
    }

    private func refill(_ id: UUID) {
        guard let i = furniture.firstIndex(where: { $0.id == id }) else { return }
        furniture[i].food = 1
        if let body = props[id] { sparkle(at: CGPoint(x: body.x, y: body.y + 8), kind: .sparkOrange, count: 8) }
        commitFurniture()
    }

    // MARK: - Furniture

    private var furnitureDragging: Bool {
        if case .furniture? = drag?.target { return true }
        return false
    }

    /// Demo scenes set furniture before the first frame; apply it right away.
    func reloadFurnitureForDemo() {
        syncFurniture()
        anchors = [:]
        rebuildSurfaces()
    }

    private func syncFurniture() {
        guard !furnitureDragging else { return }
        furniture = store.furniture
        let ids = Set(furniture.map(\.id))
        for (id, view) in furnitureViews where !ids.contains(id) {
            view.remove()
            furnitureViews[id] = nil
            props[id] = nil
        }
        for f in furniture {
            if furnitureViews[f.id] == nil { furnitureViews[f.id] = FurnitureView(root: root) }
            if f.kind.isProp, props[f.id] == nil {
                props[f.id] = PropBody(x: CGFloat(f.x), y: CGFloat(f.y))
            }
        }
    }

    /// Writes the live furniture (including where beds and bowls ended up) back to settings.
    private func commitFurniture() {
        for i in furniture.indices {
            if let body = props[furniture[i].id] {
                furniture[i].x = Double(body.x)
                furniture[i].y = Double(body.y)
            }
        }
        if store.furniture != furniture { store.furniture = furniture }
    }

    private func updateProps(_ dt: Double) {
        guard geo.mode.hasFurniture else { return }
        for (id, var body) in props where !body.held {
            if let s = body.surface, let surf = surfaces[s] {
                body.y = surf.y
            } else {
                let previousY = body.y
                body.vy -= Cat.gravity * CGFloat(dt)
                body.y += body.vy * CGFloat(dt)
                if let s = landingSurface(x: body.x, from: previousY, to: body.y, ignoring: nil, staticOnly: true) {
                    body.y = s.y
                    body.vy = 0
                    body.surface = s.id
                    props[id] = body
                    if !furnitureDragging { commitFurniture() }
                    continue
                }
                if body.y < -200 {
                    body.y = geo.groundY ?? geo.menuBarY
                    body.vy = 0
                }
            }
            props[id] = body
        }
    }

    private func layout(_ f: Furniture) -> (art: PropArt.Art, front: PropArt.Art?, origin: CGPoint, z: CGFloat, key: String)? {
        let p = geo.furniturePixel
        switch f.kind {
        case .shelf:
            let art = PropArt.shelf(width: Int((CGFloat(f.width) / p).rounded()))
            return (art, nil, CGPoint(x: CGFloat(f.x) - p, y: CGFloat(f.y) + p - CGFloat(art.height) * p), 4, "s\(art.width)")
        case .post:
            guard let g = geo.groundY else { return nil }
            let art = PropArt.post(height: postPixels(f))
            return (art, nil, CGPoint(x: CGFloat(f.x) - CGFloat(art.width) * p / 2, y: g - p), 5, "p\(art.height)")
        case .bed:
            guard let body = props[f.id] else { return nil }
            let art = PropArt.bed(front: false)
            return (art, PropArt.bed(front: true), CGPoint(x: body.x - CGFloat(art.width) * p / 2, y: body.y - p), 6, "bed")
        case .trash:
            guard let body = props[f.id] else { return nil }
            let art = PropArt.trash(front: false)
            // Rattles while a cat digs around inside.
            let busy = cats.contains { $0.trashID == f.id && $0.rummageHidden }
            let shake = busy ? CGFloat(sin(now * 40)) * p * 0.6 : 0
            return (art, PropArt.trash(front: true), CGPoint(x: body.x - CGFloat(art.width) * p / 2 + shake, y: body.y - p), 6, "trash")
        case .closedBox:
            guard let body = props[f.id] else { return nil }
            let art = PropArt.closedBox()
            return (art, nil, CGPoint(x: body.x - CGFloat(art.width) * p / 2, y: body.y - p), 6, "closedBox")
        case .box, .laundry, .wardrobe, .flowerPot:
            guard let body = props[f.id] else { return nil }
            let occupied = cats.contains { $0.isAsleep && $0.bedID == f.id }
            let back: PropArt.Art, front: PropArt.Art
            switch f.kind {
            case .box: (back, front) = (PropArt.box(front: false), PropArt.box(front: true))
            case .laundry: (back, front) = (PropArt.laundry(front: false), PropArt.laundry(front: true))
            case .wardrobe: (back, front) = (PropArt.wardrobe(front: false), PropArt.wardrobe(front: true))
            default:
                // A cat napping in the pot squashes the plant.
                (back, front) = (PropArt.flowerPot(squashed: occupied, front: false), PropArt.flowerPot(squashed: occupied, front: true))
            }
            return (back, front, CGPoint(x: body.x - CGFloat(back.width) * p / 2, y: body.y - p), 6,
                    "\(f.kind.rawValue)\(f.kind == .flowerPot && occupied)")
        case .bowl:
            guard let body = props[f.id] else { return nil }
            let level = f.food >= 0.6 ? 2 : (f.food > 0.05 ? 1 : 0)
            let art = PropArt.bowl(food: level)
            return (art, nil, CGPoint(x: body.x - CGFloat(art.width) * p / 2, y: body.y - p), 9, "bowl\(level)")
        }
    }

    private func syncFurnitureViews() {
        let visible = geo.mode.hasFurniture
        for f in furniture {
            guard let view = furnitureViews[f.id] else { continue }
            guard visible, let l = layout(f) else {
                view.main.isHidden = true
                view.front.isHidden = true
                view.showOutline(false, handles: [])
                continue
            }
            view.main.isHidden = false
            view.update(art: l.art, front: l.front, origin: l.origin, pixel: geo.furniturePixel, z: l.z, key: l.key)
            view.showOutline(editMode, handles: handles(for: f, frame: view.frame))
        }
    }

    private func handles(for f: Furniture, frame r: CGRect) -> [CGRect] {
        let s: CGFloat = 7
        switch f.kind {
        case .shelf:
            return [CGRect(x: r.minX - s / 2, y: r.maxY - s, width: s, height: s),
                    CGRect(x: r.maxX - s / 2, y: r.maxY - s, width: s, height: s)]
        case .post:
            return [CGRect(x: r.midX - s / 2, y: r.maxY - s / 2, width: s, height: s)]
        default:
            return []
        }
    }

    private func furnitureHit(at p: CGPoint) -> (UUID, FurnitureGrab)? {
        let order: [FurnitureKind: Int] = [.bowl: 0, .flowerPot: 1, .trash: 2, .box: 3, .closedBox: 3, .laundry: 4, .bed: 5, .wardrobe: 6, .post: 7, .shelf: 8]
        let sorted = furniture.sorted { order[$0.kind]! < order[$1.kind]! }
        for f in sorted {
            guard let r = furnitureViews[f.id]?.frame, r.insetBy(dx: -6, dy: -6).contains(p) else { continue }
            switch f.kind {
            case .shelf:
                if p.x < r.minX + 8 { return (f.id, .left) }
                if p.x > r.maxX - 8 { return (f.id, .right) }
                return (f.id, .move(dx: p.x - CGFloat(f.x), dy: p.y - CGFloat(f.y)))
            case .post:
                if p.y > r.maxY - 12 { return (f.id, .top) }
                return (f.id, .move(dx: p.x - CGFloat(f.x), dy: 0))
            default:
                let body = props[f.id]
                return (f.id, .move(dx: p.x - (body?.x ?? CGFloat(f.x)), dy: p.y - (body?.y ?? CGFloat(f.y))))
            }
        }
        return nil
    }

    private func bowlHit(at p: CGPoint) -> UUID? {
        guard geo.mode.hasFurniture else { return nil }
        return furniture.first { $0.kind == .bowl && furnitureViews[$0.id]?.frame.insetBy(dx: -4, dy: -4).contains(p) == true }?.id
    }

    func setEditMode(_ on: Bool) {
        guard on != editMode else { return }
        editMode = on && geo.mode.hasFurniture
        if !editMode, furnitureDragging { drag = nil }
        commitFurniture()
        onEditModeChange?(editMode)
    }

    func addFurniture(_ kind: FurnitureKind) {
        guard geo.mode.hasFurniture else { return }
        let x = Double(geo.width / 2 + .random(in: -120...120, using: &Sim.rng))
        let y = Double(geo.height * 0.55)
        let item = Furniture.make(kind, at: x, y)
        furniture.append(item)
        furnitureViews[item.id] = FurnitureView(root: root)
        if kind.isProp { props[item.id] = PropBody(x: CGFloat(item.x), y: CGFloat(item.y)) }
        sparkle(at: CGPoint(x: x, y: y), kind: .sparkBlue, count: 8)
        commitFurniture()
    }

    func removeFurniture(_ id: UUID) {
        furniture.removeAll { $0.id == id }
        furnitureViews[id]?.remove()
        furnitureViews[id] = nil
        props[id] = nil
        commitFurniture()
    }

    private func applyFurnitureDrag(_ id: UUID, _ grab: FurnitureGrab, original: Furniture, to p: CGPoint) {
        guard let i = furniture.firstIndex(where: { $0.id == id }) else { return }
        var f = furniture[i]
        let minY = Double((geo.groundY ?? 0) + 30), maxY = Double(geo.menuBarY - 10)
        switch grab {
        case .move(let dx, let dy):
            f.x = Double(p.x - dx)
            if f.kind == .shelf { f.y = min(max(Double(p.y - dy), minY), maxY) }
            if f.kind.isProp {
                f.y = Double(p.y - dy)
                props[id] = PropBody(x: CGFloat(f.x), y: CGFloat(f.y), held: true)
            }
        case .left:
            let right = original.x + original.width
            f.x = min(Double(p.x), right - 40)
            f.width = right - f.x
        case .right:
            f.width = max(40, Double(p.x) - original.x)
        case .top:
            let g = Double(geo.groundY ?? 0)
            f.height = min(max(Double(p.y) - g, 70), Double(geo.menuBarY) - g - 20)
        }
        f.x = min(max(f.x, -f.width + 30), Double(geo.width) - 30)
        furniture[i] = f
    }

    // MARK: - Ball and laser

    var ballInfo: (point: CGPoint, surface: SurfaceID?, speed: CGFloat)? {
        guard let b = ball, !b.held else { return nil }
        return (CGPoint(x: b.x, y: b.y), b.surface, b.speed)
    }

    func spawnBall() {
        removeBall()
        let b = Ball(x: geo.width / 2 + .random(in: -200...200, using: &Sim.rng), y: geo.menuBarY - 30, pixel: geo.furniturePixel)
        b.vx = .random(in: -160...160, using: &Sim.rng)
        b.vy = 120
        root.addSublayer(b.layer)
        ball = b
    }

    func removeBall() {
        ball?.layer.removeFromSuperlayer()
        ball = nil
    }

    func kickBall(dir: CGFloat, power: CGFloat) {
        guard let b = ball, !b.held else { return }
        b.surface = nil
        b.vx = dir * 200 * power + .random(in: -30...30, using: &Sim.rng)
        b.vy = 130 * power
    }

    func setLaser(_ on: Bool) {
        laserOn = on
        if !on { laserDot.isHidden = true }
    }

    func huntTarget(_ kind: Cat.HuntKind, for cat: Cat) -> (point: CGPoint, surface: SurfaceID?)? {
        switch kind {
        case .butterfly:
            guard let b = butterflies.first(where: { $0.id == cat.huntTargetID }), !b.isLeaving else { return nil }
            return (b.point, surfaceUnder(b.point)?.surface)
        case .laser:
            guard laserOn, mouseNearCats else { return nil }
            return (mouse, surfaceUnder(mouse)?.surface)
        case .ball:
            guard let info = ballInfo else { return nil }
            return (info.point, info.surface)
        }
    }

    // MARK: - Butterflies

    private func updateButterflies(_ dt: Double) {
        if store.butterflies, butterflies.count < 2, now > nextButterfly {
            releaseButterfly()
        }
        for b in butterflies { b.update(dt: dt, world: self) }
        butterflies.removeAll { b in
            if b.gone { b.layer.removeFromSuperlayer() }
            return b.gone
        }
    }

    func releaseButterfly() {
        let b = Butterfly(world: self)
        root.addSublayer(b.layer)
        butterflies.append(b)
        nextButterfly = now + .random(in: 25...60, using: &Sim.rng)
    }

    func nearestButterfly(to p: CGPoint, within radius: CGFloat) -> Butterfly? {
        butterflies
            .filter { hypot($0.point.x - p.x, $0.point.y - p.y) < radius }
            .min { hypot($0.point.x - p.x, $0.point.y - p.y) < hypot($1.point.x - p.x, $1.point.y - p.y) }
    }

    func startleButterflies(near p: CGPoint) {
        for b in butterflies where hypot(b.point.x - p.x, b.point.y - p.y) < 90 { b.startle() }
    }

    // MARK: - Mouse

    private func topCat(at p: CGPoint, margin: CGFloat = 0) -> Cat? {
        cats.filter { $0.canInteract && $0.hitRect.insetBy(dx: -margin, dy: -margin).contains(p) }
            .max { $0.layer.zPosition < $1.layer.zPosition }
    }

    private func wantsMouse(at p: CGPoint) -> Bool {
        if drag != nil || topCat(at: p) != nil { return true }
        if let b = ball, b.hitRect.contains(p) { return true }
        if editMode { return furnitureHit(at: p) != nil }
        return bowlHit(at: p) != nil
    }

    /// On the desktop, cats hidden behind app windows shouldn't react to the cursor.
    private func pointIsCovered(_ p: CGPoint) -> Bool {
        geo.mode == .desktop && windowTracker.windows.contains { $0.frame.contains(p) }
    }

    private func handleStroking() {
        guard drag == nil, !pointIsCovered(mouse) else { return }
        let distance = hypot(mouse.x - lastMouse.x, mouse.y - lastMouse.y)
        // A little more generous than the sprite itself: cats are small, hands are not steady.
        guard distance > 0.4, distance < 150, let cat = topCat(at: mouse, margin: 6) else { return }
        cat.stroke(distance, world: self)
    }

    func mouseDown(at p: CGPoint) {
        let sample = [(t: CACurrentMediaTime(), p: p)]
        if editMode, let (id, grab) = furnitureHit(at: p) {
            drag = Drag(target: .furniture(id, grab), start: p, samples: sample, original: furniture.first { $0.id == id })
        } else if let cat = topCat(at: p) {
            drag = Drag(target: .cat(cat), start: p, samples: sample)
        } else if let b = ball, b.hitRect.contains(p) {
            drag = Drag(target: .ball, start: p, samples: sample)
        } else if let bowl = bowlHit(at: p) {
            refill(bowl)
        }
    }

    func mouseDragged(at p: CGPoint) {
        guard var d = drag else { return }
        if !d.active, hypot(p.x - d.start.x, p.y - d.start.y) > 4 {
            d.active = true
            switch d.target {
            case .cat(let cat): cat.pickUp(world: self)
            case .ball: ball?.held = true
            case .furniture: break
            }
        }
        d.samples.append((CACurrentMediaTime(), p))
        if d.samples.count > 8 { d.samples.removeFirst() }
        drag = d
        updateDrag(at: p)
    }

    private func updateDrag(at point: CGPoint? = nil) {
        guard let d = drag, d.active else { return }
        let p = point ?? mouse
        switch d.target {
        case .cat(let cat):
            cat.carry(to: p, world: self)
        case .ball:
            ball?.x = p.x
            ball?.y = p.y - (ball?.size ?? 0) / 2
            ball?.surface = nil
        case .furniture(let id, let grab):
            if let original = d.original { applyFurnitureDrag(id, grab, original: original, to: p) }
        }
    }

    func mouseUp(at p: CGPoint) {
        guard let d = drag else { return }
        drag = nil
        let velocity = throwVelocity(d.samples)
        switch d.target {
        case .cat(let cat):
            if d.active { cat.drop(velocity: velocity, world: self) } else { cat.squish(world: self) }
        case .ball:
            guard let b = ball else { return }
            b.held = false
            if d.active {
                b.vx = max(-900, min(900, velocity.dx))
                b.vy = max(-600, min(900, velocity.dy))
            } else {
                kickBall(dir: Bool.random(using: &Sim.rng) ? 1 : -1, power: 0.8)
            }
        case .furniture(let id, _):
            if props[id] != nil { props[id]?.held = false }
            commitFurniture()
        }
    }

    private func throwVelocity(_ samples: [(t: CFTimeInterval, p: CGPoint)]) -> CGVector {
        let t = CACurrentMediaTime()
        let recent = samples.filter { t - $0.t < 0.1 }
        guard let first = recent.first, let last = recent.last, last.t - first.t > 0.005 else { return .zero }
        let span = CGFloat(last.t - first.t)
        return CGVector(dx: (last.p.x - first.p.x) / span, dy: (last.p.y - first.p.y) / span)
    }

    func rightMouseDown(at p: CGPoint, event: NSEvent, in view: NSView) {
        if editMode, let (id, _) = furnitureHit(at: p), let f = furniture.first(where: { $0.id == id }) {
            let menu = NSMenu()
            menu.addItem(ActionItem(String(format: L("Delete %@"), f.kind.title.lowercased())) { [weak self] in self?.removeFurniture(id) })
            NSMenu.popUpContextMenu(menu, with: event, for: view)
            return
        }
        guard let cat = topCat(at: p), let menu = contextMenuProvider?(cat) else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: view)
    }

    // MARK: - Portals

    private var portalSize: CGSize {
        CGSize(width: max(7, geo.menuBarHeight * 0.24), height: geo.menuBarHeight * 0.86)
    }

    /// Portal centres, just outside the notch.
    var portalXs: (left: CGFloat, right: CGFloat)? {
        guard geo.mode.hasMenuBar, let n = geo.notch else { return nil }
        let w = portalSize.width
        return (n.lowerBound - w / 2 - 2, n.upperBound + w / 2 + 2)
    }

    func touchPortals() {
        portalLastUse = now
        guard portals == nil, let xs = portalXs else { return }
        let size = portalSize
        let scale = panel.backingScaleFactor
        let left = PortalLayer(color: PortalLayer.blue, size: size, scale: scale)
        let right = PortalLayer(color: PortalLayer.orange, size: size, scale: scale)
        for (layer, x) in [(left, xs.left), (right, xs.right)] {
            layer.position = CGPoint(x: x, y: geo.menuBarY + size.height / 2 + 1)
            layer.zPosition = 50
            root.addSublayer(layer)
            layer.open()
        }
        portals = (left, right)
    }

    func portalTransitBegan(at x: CGFloat) {
        portalUsers += 1
        touchPortals()
        sparkle(at: CGPoint(x: x, y: geo.menuBarY + portalSize.height / 2), kind: sparkKind(x), count: 5)
    }

    func portalTransitEnded(at x: CGFloat) {
        portalUsers = max(0, portalUsers - 1)
        portalLastUse = now
        sparkle(at: CGPoint(x: x, y: geo.menuBarY + portalSize.height / 2), kind: sparkKind(x), count: 5)
    }

    private func sparkKind(_ x: CGFloat) -> EmoteKind {
        guard let n = geo.notch else { return .sparkBlue }
        return x < (n.lowerBound + n.upperBound) / 2 ? .sparkBlue : .sparkOrange
    }

    private func updatePortals() {
        guard let p = portals, portalUsers == 0, now - portalLastUse > 0.9 else { return }
        p.left.close()
        p.right.close()
        portals = nil
    }

    // MARK: - Demo stage

    /// Confines the world to `stage` (panel coordinates) and paints a backdrop behind it, so a
    /// screen recording shows only the cats. `floor` raises the ground inside the stage.
    func setDemoStage(_ stage: CGRect, floor: CGFloat, notch: CGRect?, menuBar: Bool = false, backdrop: Bool = true) {
        demoStage = stage
        if geo.groundY != nil, floor > 0 { geo.groundY = stage.minY + floor }
        for l in backdropLayers { l.removeFromSuperlayer() }
        backdropLayers = []

        if backdrop {
            let wall = CAGradientLayer()
            wall.frame = stage
            wall.colors = [RGB(hex: 0x3B3552).nsColor.cgColor, RGB(hex: 0x262433).nsColor.cgColor]
            wall.startPoint = CGPoint(x: 0.5, y: 1)
            wall.endPoint = CGPoint(x: 0.5, y: 0)
            wall.zPosition = 1
            backdropLayers.append(wall)
        }
        if floor > 0 {
            let boards = CALayer()
            boards.frame = CGRect(x: stage.minX, y: stage.minY, width: stage.width, height: floor)
            boards.backgroundColor = RGB(hex: 0x6B4A35).nsColor.cgColor
            let edge = CALayer()
            edge.frame = CGRect(x: stage.minX, y: stage.minY + floor - 3, width: stage.width, height: 3)
            edge.backgroundColor = RGB(hex: 0x8C6446).nsColor.cgColor
            for l in [boards, edge] { l.zPosition = 2 }
            backdropLayers += [boards, edge]
        }
        if menuBar {
            // A recognisable macOS menu bar, so the cats obviously live on a Mac.
            let height = geo.menuBarHeight
            let bar = CALayer()
            bar.frame = CGRect(x: stage.minX, y: geo.menuBarY, width: stage.width, height: height)
            bar.backgroundColor = RGB(hex: 0x16151C).nsColor.cgColor
            bar.zPosition = 1.5
            backdropLayers.append(bar)
            let scale = panel.backingScaleFactor
            @discardableResult
            func label(_ text: String, x: CGFloat, alignRight: Bool = false, bold: Bool = false) -> CATextLayer {
                let font = NSFont.systemFont(ofSize: 13, weight: bold ? .bold : .medium)
                let attributed = NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: NSColor(white: 0.92, alpha: 1)])
                let size = attributed.size()
                let layer = CATextLayer()
                layer.string = attributed
                layer.contentsScale = scale
                layer.frame = CGRect(x: alignRight ? x - size.width : x, y: geo.menuBarY + (height - size.height) / 2,
                                     width: ceil(size.width), height: ceil(size.height))
                layer.zPosition = 1.6
                backdropLayers.append(layer)
                return layer
            }
            if let apple = NSImage(systemSymbolName: "applelogo", accessibilityDescription: nil)?
                .withSymbolConfiguration(.init(pointSize: 14, weight: .medium)) {
                let tinted = NSImage(size: apple.size, flipped: false) { rect in
                    apple.draw(in: rect)
                    NSColor(white: 0.92, alpha: 1).set()
                    rect.fill(using: .sourceAtop)
                    return true
                }
                let layer = CALayer()
                layer.contents = tinted
                layer.contentsScale = scale
                layer.frame = CGRect(x: stage.minX + 14, y: geo.menuBarY + (height - apple.size.height) / 2,
                                     width: apple.size.width, height: apple.size.height)
                layer.zPosition = 1.6
                backdropLayers.append(layer)
            }
            label("Finder", x: stage.minX + 40, bold: true)
            label("File   Edit   View", x: stage.minX + 92)
            demoClock = label("Tue 9:40", x: stage.maxX - 14, alignRight: true)
        }
        if let notch {
            // The real notch is hardware: on a recording the pixels under it are visible.
            let cutout = CAShapeLayer()
            cutout.path = CGPath(roundedRect: notch.insetBy(dx: 0, dy: -10), cornerWidth: 9, cornerHeight: 9, transform: nil)
            cutout.fillColor = CGColor(gray: 0, alpha: 1)
            cutout.zPosition = 49
            backdropLayers.append(cutout)
        }
        for l in backdropLayers {
            l.disableImplicitAnimations()
            root.addSublayer(l)
        }
        anchors = [:]
        rebuildSurfaces()
    }

    /// The clock in a demo menu bar ticks over when a recording's story starts: a visible
    /// sync mark for the trailer script.
    // MARK: - Scheduling in simulated time

    private var scheduled: [(at: Double, action: () -> Void)] = []

    /// Runs `action` after `seconds` of simulated time: like `asyncAfter`, but repeatable in seeded runs.
    func after(_ seconds: Double, _ action: @escaping () -> Void) {
        scheduled.append((now + seconds, action))
    }

    private func runDue() {
        guard scheduled.contains(where: { $0.at <= now }) else { return }
        let due = scheduled.filter { $0.at <= now }.sorted { $0.at < $1.at }
        scheduled.removeAll { $0.at <= now }
        for item in due { item.action() }
    }

    func tickDemoClock() {
        guard let clock = demoClock, let text = clock.string as? NSAttributedString else { return }
        clock.string = NSAttributedString(string: "Tue 9:41", attributes: text.attributes(at: 0, effectiveRange: nil))
    }

    // MARK: - Jump calculations

    func startCalculation(for cat: Cat, from: CGPoint, to: CGPoint) {
        finishCalculation(for: cat)
        let b = Navigator.ballistic(from: from, to: to, ceiling: ceiling(for: cat), gravity: Cat.gravity)
        let lift = 5 * cat.pixel
        let points = Navigator.trajectory(from: CGPoint(x: from.x, y: from.y + lift), vx: b.vx, vy: b.vy,
                                          duration: b.duration, gravity: Cat.gravity, spacing: 7)
        calculations[cat.id] = CalculationFX(points: points, target: CGPoint(x: to.x, y: to.y + lift),
                                             pixel: cat.pixel, scale: panel.backingScaleFactor, root: root)
        cat.calcLooksUp = to.y > from.y + 10
    }

    func updateCalculation(for cat: Cat, progress: Double) {
        calculations[cat.id]?.reveal(progress)
    }

    func finishCalculation(for cat: Cat) {
        guard let fx = calculations.removeValue(forKey: cat.id) else { return }
        fx.fadeOut()
        fadingCalculations.append(fx)
    }

    func spawnFormula(near cat: Cat, hop: Hop) {
        guard let toY = surfaceY(hop.to) else { return }
        let p = cat.pixel
        let b = Navigator.ballistic(from: CGPoint(x: cat.x, y: cat.y), to: CGPoint(x: hop.landX, y: toY),
                                    ceiling: ceiling(for: cat), gravity: Cat.gravity)
        let angle = Int((atan2(b.vy, max(abs(b.vx), 1)) * 180 / .pi).rounded())
        var texts = [
            "Δx=\(Int(abs(hop.landX - cat.x) / p))", "Δy=\(Int((toY - cat.y) / p))", "θ=\(angle)°",
            "v=\(Int(hypot(b.vx, b.vy) / p))", String(format: "t=%.2f", b.duration), "g=9.8",
            "√2gh", "π", "∫", "Σ", "x²+y²", "sinθ", "cosθ", "v₀t", "?",
        ]
        if Double.random(in: 0...1, using: &Sim.rng) < 0.04 { texts.append("∞") }
        let sprite = PixelFont.sprite(texts.randomElement(using: &Sim.rng)!, color: PixelFont.colors.randomElement(using: &Sim.rng)!)
        let head = cat.headPoint()
        let nearTop = head.y > geo.height - 60
        let start = CGPoint(x: head.x + .random(in: -34...34, using: &Sim.rng), y: head.y + (nearTop ? -.random(in: 10...30, using: &Sim.rng) : .random(in: 4...24, using: &Sim.rng)))
        addParticle(sprite, at: start, velocity: CGVector(dx: .random(in: -6...6, using: &Sim.rng), dy: nearTop ? -10 : 12),
                    gravity: 0, life: 1.5, pixel: p * demoFormulaScale, wobble: 1.5)
    }

    // MARK: - Particles

    private func addParticle(_ sprite: EmoteArt.Sprite, at p: CGPoint, velocity: CGVector, gravity: CGFloat,
                             life: Double, pixel: CGFloat, drag: CGFloat = 0, wobble: CGFloat = 0) {
        let particle = Particle(sprite: sprite, pixel: pixel, position: p, velocity: velocity,
                                gravity: gravity, life: life, drag: drag, wobble: wobble)
        root.addSublayer(particle.layer)
        particles.append(particle)
    }

    private func addParticle(_ kind: EmoteKind, at p: CGPoint, velocity: CGVector, gravity: CGFloat,
                             life: Double, pixel: CGFloat, drag: CGFloat = 0, wobble: CGFloat = 0) {
        guard let sprite = EmoteArt.sprites[kind] else { return }
        addParticle(sprite, at: p, velocity: velocity, gravity: gravity, life: life, pixel: pixel, drag: drag, wobble: wobble)
    }

    func spawnHearts(from cat: Cat, count: Int, burst: Bool) {
        let head = cat.headPoint()
        let p = max(1, cat.pixel - 0.5)
        for _ in 0..<count {
            if burst {
                // Pop up and rain down.
                let angle = CGFloat.random(in: 0.35...(.pi - 0.35), using: &Sim.rng)
                let speed = CGFloat.random(in: 90...170, using: &Sim.rng)
                addParticle(.heart, at: head, velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                            gravity: 320, life: .random(in: 1.1...1.6, using: &Sim.rng), pixel: p)
            } else if hasHeadroom(above: head) {
                let start = CGPoint(x: head.x + .random(in: -4...4, using: &Sim.rng) * cat.pixel, y: head.y + 2 * cat.pixel)
                addParticle(.heart, at: start, velocity: CGVector(dx: .random(in: -22...22, using: &Sim.rng), dy: .random(in: 18...34, using: &Sim.rng)),
                            gravity: 0, life: .random(in: 0.9...1.3, using: &Sim.rng), pixel: p, drag: 1.2, wobble: 3)
            } else {
                // Up against the top of the screen (a cat on the menu bar): float out sideways
                // and drift down instead, or the hearts would vanish off the edge at once.
                let side: CGFloat = Bool.random(using: &Sim.rng) ? 1 : -1
                let start = CGPoint(x: head.x + side * .random(in: 5...9, using: &Sim.rng) * cat.pixel, y: head.y - 2 * cat.pixel)
                addParticle(.heart, at: start, velocity: CGVector(dx: side * .random(in: 25...45, using: &Sim.rng), dy: -.random(in: 10...25, using: &Sim.rng)),
                            gravity: 15, life: .random(in: 1.1...1.5, using: &Sim.rng), pixel: p, drag: 0.8, wobble: 3)
            }
        }
    }

    /// Whether something rising from `point` stays on screen for a moment.
    private func hasHeadroom(above point: CGPoint) -> Bool {
        playArea.maxY - point.y > 45
    }

    func spawnHeart(at point: CGPoint, pixel: CGFloat) {
        let rising = hasHeadroom(above: point)
        addParticle(.heart, at: rising ? point : CGPoint(x: point.x, y: point.y - 16),
                    velocity: CGVector(dx: 0, dy: rising ? 14 : -10), gravity: 0, life: 1.6, pixel: pixel, wobble: 2)
    }

    func spawnZ(from cat: Cat) {
        let head = cat.headPoint()
        let dir: CGFloat = cat.facingRight ? 1 : -1
        let rising = hasHeadroom(above: head)
        addParticle(.zzz, at: CGPoint(x: head.x + dir * (rising ? 4 : 8) * cat.pixel, y: head.y + (rising ? 3 : -2) * cat.pixel),
                    velocity: CGVector(dx: dir * (rising ? 6 : 12), dy: rising ? 10 : -6), gravity: 0, life: 2.2,
                    pixel: max(1, cat.pixel - 1), wobble: 2)
    }

    // MARK: - Fights

    private var fights: [UUID: (cloud: FightCloud, starter: Cat, bottom: CGPoint, symbolTimer: Double)] = [:]

    /// Two cats start wrestling: they disappear into a fight cloud.
    func startFight(_ a: Cat, _ b: Cat, at bottom: CGPoint) {
        fights[a.id]?.cloud.remove()
        let cloud = FightCloud(a.config.appearance, b.config.appearance, pixel: a.pixel, root: root)
        fights[a.id] = (cloud, a, bottom, 0.15)
        sparkle(at: CGPoint(x: bottom.x, y: bottom.y + 8 * a.pixel), kind: .sparkOrange, count: 6)
    }

    func moveFight(of cat: Cat, to bottom: CGPoint) {
        fights[cat.id]?.bottom = bottom
    }

    private func updateFights(_ dt: Double) {
        for (id, fight) in fights {
            guard fight.starter.activity == .wrestle else {
                // Over: a last puff of dust where the cloud was.
                fight.cloud.remove()
                fights[id] = nil
                for _ in 0..<5 { spawnFluff(at: CGPoint(x: fight.bottom.x, y: fight.bottom.y + 8 * fight.starter.pixel)) }
                continue
            }
            fight.cloud.update(dt: dt, bottom: fight.bottom)
            var timer = fight.symbolTimer - dt
            if timer <= 0 {
                timer = .random(in: 0.18...0.35, using: &Sim.looks)
                spawnFightSymbol(at: CGPoint(x: fight.bottom.x, y: fight.bottom.y + 14 * fight.starter.pixel), pixel: fight.starter.pixel)
            }
            fights[id]?.symbolTimer = timer
        }
    }

    /// A few angry symbols popping out over a cat.
    func spawnFightSymbols(from cat: Cat, count: Int) {
        for _ in 0..<count { spawnFightSymbol(at: CGPoint(x: cat.x, y: cat.y + 14 * cat.pixel), pixel: cat.pixel) }
    }

    /// Cartoon swearing, stars and anger popping out of a fight cloud.
    private func spawnFightSymbol(at p: CGPoint, pixel: CGFloat) {
        let words = ["#@!", "!", "*!", "@#", "!?"]
        let sprite: EmoteArt.Sprite?
        switch Int.random(in: 0..<5, using: &Sim.looks) {
        case 0, 1: sprite = PixelFont.sprite(words.randomElement(using: &Sim.looks)!, color: PixelFont.colors[[0, 2].randomElement(using: &Sim.looks)!])
        case 2: sprite = EmoteArt.sprites[.anger]
        case 3: sprite = EmoteArt.sprites[.exclaim]
        default: sprite = EmoteArt.sprites[.sparkOrange]
        }
        guard let sprite else { return }
        let dir: CGFloat = Bool.random(using: &Sim.looks) ? 1 : -1
        addParticle(sprite, at: CGPoint(x: p.x + dir * .random(in: 2...10, using: &Sim.looks) * pixel, y: p.y),
                    velocity: CGVector(dx: dir * .random(in: 20...60, using: &Sim.looks), dy: .random(in: 50...90, using: &Sim.looks)),
                    gravity: 110, life: .random(in: 0.5...0.8, using: &Sim.looks), pixel: max(1, pixel - 0.5))
    }

    func spawnFluff(at point: CGPoint) {
        addParticle(.fluff, at: point, velocity: CGVector(dx: .random(in: -30...30, using: &Sim.rng), dy: .random(in: 10...50, using: &Sim.rng)),
                    gravity: 200, life: .random(in: 0.4...0.7, using: &Sim.rng), pixel: geo.furniturePixel)
    }

    func sparkle(at point: CGPoint, kind: EmoteKind, count: Int) {
        for _ in 0..<count {
            let angle = CGFloat.random(in: 0...(2 * .pi), using: &Sim.rng)
            let speed = CGFloat.random(in: 25...70, using: &Sim.rng)
            addParticle(kind, at: point, velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
                        gravity: 0, life: .random(in: 0.35...0.6, using: &Sim.rng), pixel: 1.5, drag: 2.5)
        }
    }
}
