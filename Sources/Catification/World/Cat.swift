import AppKit
import QuartzCore

@MainActor
final class Cat {
    enum Activity {
        case stand, sit, groom, sleep
        case walk, run
        case chase, flee, crouch, pounce, swipe
        case petted, greet
        case carried, falling
        case calculating, jumping, hanging, climbing, scratching, eating, hunting, rummaging
    }

    enum HuntKind { case laser, ball, butterfly }

    enum Mood {
        case happy, playful, calm, sleepy, sleeping, grumpy, hungry

        var title: String {
            switch self {
            case .happy: L("😻 On cloud nine")
            case .playful: L("😸 Wants to play")
            case .calm: L("🐱 All calm")
            case .sleepy: L("🥱 Getting sleepy")
            case .sleeping: L("😴 Asleep")
            case .grumpy: L("😾 In a mood")
            case .hungry: L("🐟 Hungry")
            }
        }

        var emote: EmoteKind? {
            switch self {
            case .happy: .heart
            case .playful: .note
            case .grumpy: .anger
            case .hungry: .fish
            case .calm, .sleepy, .sleeping: nil
            }
        }
    }

    /// Walking through the notch: the cat enters one portal and simultaneously
    /// comes out of the other, so for a moment it is drawn twice, clipped at both portals.
    struct Transit {
        let entry: CGFloat
        let exit: CGFloat
        let dir: CGFloat
    }

    nonisolated static let gravity: CGFloat = 1100

    private(set) var config: CatConfig
    private(set) var sheet: SpriteSheet
    private(set) var pixel: CGFloat
    var id: UUID { config.id }
    var traits: Traits { config.personality.traits }

    // Body: `y` is the bottom of the sprite canvas (the feet) in panel coordinates.
    private(set) var x: CGFloat = 0
    private(set) var y: CGFloat = 0
    private var vx: CGFloat = 0
    private var vy: CGFloat = 0
    private(set) var surface: SurfaceID?
    private(set) var facingRight = Bool.random()

    private(set) var activity: Activity = .stand
    private var activityTime = 0.0
    private var activityDuration = 2.0
    private var targetX: CGFloat = 0
    weak var partner: Cat?
    private(set) var transit: Transit?

    // Travelling between surfaces.
    private var route: Route?
    private var routeThen: Activity?
    private var routeRunning = false
    private var routeHurried = false
    private var routeAttempts = 0
    private var approachTries = 0
    private var hop: Hop?
    private var flightIgnore: SurfaceID?
    private var failJump = false
    private var fellFromLedge = false
    private var hangPoint: CGPoint = .zero
    private var climbTargetY: CGFloat = 0
    private(set) var climbPost: UUID?
    private var calcSpawn = 0.0
    /// Demo recordings: miss the next big jump and fall, for the camera.
    var demoMiss = false

    // Places and toys.
    private(set) var bedID: UUID?
    private var bowlID: UUID?
    private var scratchPost: UUID?
    private(set) var huntKind: HuntKind?
    private(set) var huntTargetID: UUID?
    private(set) var trashID: UUID?
    private(set) var rummageHidden = false
    private var rummageFrom: CGPoint = .zero
    private var rummageExitSide: CGFloat = 1
    private var rummageSeed = 0.0
    private var trashBitCooldown = 0.0
    private var huntUntil = 0.0
    private var huntRetarget = 0.0
    private var huntMoving = false
    private var huntChasing = false
    private var huntSwitchTime = 0.0
    private var huntSmoothX: CGFloat?

    // Feelings.
    private(set) var energy = Double.random(in: 0.55...1)
    private(set) var happiness = 0.6
    private(set) var hunger = Double.random(in: 0...0.3)
    private var grumpyTime = 0.0
    private var recentSquish = 0.0
    private var strokeAmount: CGFloat = 0
    private var lastStroke = -100.0
    private var heartCooldown = 0.0
    private var zzzCooldown = 0.0
    private var moodEmoteCooldown = Double.random(in: 10...25)
    var greetCooldown = Double.random(in: 5...15)
    private var blinkTimer = Double.random(in: 1...4)
    private var blinking = 0.0
    private var squishFace = 0.0
    private var emote: (kind: EmoteKind, remaining: Double)?

    // Rendering.
    private var anim: Anim = .stand
    private var animTime = 0.0
    private var shownImage: CGImage?
    private var shownEmote: EmoteKind?
    private(set) var hitRect: CGRect = .null

    let layer = CALayer()
    private let ghost = CALayer()
    private let clip = CALayer()
    private let ghostClip = CALayer()
    private let emoteLayer = CALayer()
    private let baseZ = 10 + CGFloat.random(in: 0..<1)

    init(config: CatConfig, world: CatWorld) {
        self.config = config
        sheet = SpriteSheet.cached(config.appearance)
        pixel = world.geo.pixel(for: config.size)

        for l in [layer, ghost, emoteLayer] {
            l.anchorPoint = CGPoint(x: 0.5, y: 0)
            l.magnificationFilter = .nearest
            l.minificationFilter = .nearest
            l.disableImplicitAnimations()
        }
        for m in [clip, ghostClip] {
            m.backgroundColor = CGColor(gray: 0, alpha: 1)
            m.disableImplicitAnimations()
        }
        ghost.isHidden = true
        emoteLayer.isHidden = true
        emoteLayer.zPosition = 40
        layer.zPosition = baseZ
    }

    // MARK: - Lifecycle

    func attach(to root: CALayer) {
        root.addSublayer(layer)
        root.addSublayer(ghost)
        root.addSublayer(emoteLayer)
    }

    func detach() {
        layer.removeFromSuperlayer()
        ghost.removeFromSuperlayer()
        emoteLayer.removeFromSuperlayer()
    }

    func apply(config new: CatConfig, world: CatWorld) {
        config = new
        sheet = SpriteSheet.cached(new.appearance)
        pixel = world.geo.pixel(for: new.size)
        shownImage = nil
        if let s = surface, transit == nil { x = world.clampOnSurface(x, s, for: self) }
    }

    /// Drops the cat in from above onto the menu bar (or the floor, on the desktop).
    func spawn(world: CatWorld) {
        let p = world.spawnPoint(for: self)
        x = p.x
        y = p.y
        surface = nil
        vx = 0
        vy = 0
        begin(.falling)
    }

    /// Demo recordings: drop the cat in at a chosen spot.
    func demoPlace(x newX: CGFloat) {
        x = newX
    }

    /// The world changed shape (mode or screen): start over.
    func reset(world: CatWorld) {
        pixel = world.geo.pixel(for: config.size)
        clearPlans()
        transit = nil
        shownImage = nil
        spawn(world: world)
    }

    private func clearPlans() {
        route = nil
        routeThen = nil
        hop = nil
        partner = nil
        huntKind = nil
        huntTargetID = nil
        trashID = nil
        rummageHidden = false
        climbPost = nil
        failJump = false
        flightIgnore = nil
    }

    // MARK: - Derived state

    var halfWidth: CGFloat { 11.5 * pixel }
    var catHeight: CGFloat { 14 * pixel }
    var canvasSize: CGSize { CGSize(width: CGFloat(CatArt.W) * pixel, height: CGFloat(CatArt.H) * pixel) }
    private var facingSign: CGFloat { facingRight ? 1 : -1 }

    var mood: Mood {
        if activity == .sleep { return .sleeping }
        if grumpyTime > 0 || happiness < 0.25 { return .grumpy }
        if hunger > 0.7 { return .hungry }
        if energy < 0.25 { return .sleepy }
        if happiness > 0.75 { return .happy }
        if energy > 0.6, traits.playfulness >= 1 { return .playful }
        return .calm
    }

    var isAsleep: Bool { activity == .sleep }
    var isStanding: Bool { surface != nil && transit == nil }

    var canInteract: Bool {
        transit == nil && ![.carried, .falling, .jumping, .hanging, .climbing, .rummaging].contains(activity)
    }

    var isIdle: Bool { surface != nil && transit == nil && [.stand, .sit, .groom, .walk].contains(activity) }

    var isPlayable: Bool {
        isStanding && grumpyTime <= 0 && [.stand, .sit, .groom, .walk, .greet].contains(activity)
    }

    var canGreet: Bool {
        isStanding && greetCooldown <= 0 && [.walk, .stand, .sit].contains(activity)
    }

    /// Is this cat on its way to (or sleeping in) the given bed?
    func claims(bed: UUID) -> Bool {
        bedID == bed && (activity == .sleep || routeThen == .sleep)
    }

    func headPoint() -> CGPoint {
        CGPoint(x: x + facingSign * anim.head.dx * pixel, y: y + visualLift + anim.head.dy * pixel)
    }

    private var visualLift: CGFloat { activity == .sleep && bedID != nil ? 2 * pixel : 0 }

    private func walkSpeed(_ world: CatWorld) -> CGFloat { 11 * pixel * CGFloat(traits.speed * world.store.speed) }
    private func runSpeed(_ world: CatWorld) -> CGFloat { 38 * pixel * CGFloat(traits.speed * world.store.speed) }
    private var sleepDuration: Double { Double.random(in: 18...40) * (0.6 + 0.4 * traits.laziness) }

    // MARK: - Simulation

    func update(dt: Double, world: CatWorld) {
        activityTime += dt
        // Legs keep pace with the actual speed (personality and the speed slider).
        let moving = [.walk, .run, .chase, .flee].contains(activity) || (activity == .hunting && huntMoving)
        animTime += moving ? dt * traits.speed * world.store.speed : dt
        tickStats(dt, world: world)
        tickTimers(dt, world: world)

        if let t = transit {
            continueTransit(t, dt: dt, world: world)
            return
        }

        switch activity {
        case .stand, .sit, .groom:
            if activityTime >= activityDuration { decide(world) }
        case .greet:
            if activityTime >= activityDuration { begin(.sit, for: .random(in: 2...5)) }
        case .swipe:
            if let p = partner { face(p.x) }
            if activityTime >= activityDuration {
                if huntKind != nil { begin(.hunting) } else { decide(world) }
            }
        case .sleep:
            if activityTime >= activityDuration || (energy >= 1 && activityTime > 12) { wakeUp() }
        case .walk, .run:
            followRoute(dt, world)
        case .chase:
            guard let p = partner, p.activity == .flee, p.surface == surface else { endPlay(); break }
            targetX = world.clampOnSurface(p.x + (p.x > x ? -9 : 9) * pixel, surface!, for: self)
            _ = move(toward: targetX, speed: runSpeed(world) * 1.06, dt: dt, world: world)
            if activityTime >= activityDuration { endChase(world) }
        case .flee:
            if move(toward: targetX, speed: runSpeed(world), dt: dt, world: world) {
                targetX = fleeTarget(world)
            }
            if activityTime >= activityDuration + 1.5 {
                partner = nil
                begin(.sit, for: .random(in: 2...4))
            }
        case .crouch:
            guard let p = partner, p.isPlayable, p.surface == surface else { endPlay(); break }
            face(p.x)
            if activityTime >= activityDuration { pounce(at: p.x, world: world) }
        case .pounce, .falling, .jumping:
            fly(dt: dt, world: world)
        case .calculating:
            calculate(dt, world)
        case .hanging:
            if activityTime >= activityDuration { resolveHang(world) }
        case .climbing:
            climb(dt, world)
        case .scratching:
            if Double.random(in: 0...1) < dt * 5 {
                world.spawnFluff(at: CGPoint(x: x + .random(in: -5...5) * pixel, y: y + .random(in: 4...12) * pixel))
            }
            if activityTime >= activityDuration { afterScratch(world) }
        case .eating:
            if activityTime >= activityDuration { finishEating() }
        case .hunting:
            hunt(dt, world)
        case .rummaging:
            rummage(dt, world)
        case .petted:
            if world.now - lastStroke > 1.4 {
                begin(.sit, for: .random(in: 3...6))
                showEmote(.heart, for: 1.5)
            }
        case .carried:
            break
        }
    }

    private func tickStats(_ dt: Double, world: CatWorld) {
        switch activity {
        case .sleep: energy += 0.03 * dt
        case .run, .chase, .flee, .pounce, .jumping, .climbing, .hunting, .rummaging: energy -= 0.01 * dt
        case .walk: energy -= 0.0035 * dt
        default: energy -= 0.0012 * dt
        }
        energy = min(1, max(0, energy))
        if world.hasBowl, activity != .eating { hunger = min(1, hunger + dt / 700) }
        happiness += (0.55 - happiness) * 0.003 * dt
        grumpyTime = max(0, grumpyTime - dt)
        recentSquish = max(0, recentSquish - 0.3 * dt)
    }

    private func tickTimers(_ dt: Double, world: CatWorld) {
        blinkTimer -= dt
        if blinkTimer <= 0 {
            blinking = 0.16
            blinkTimer = .random(in: 2.5...6)
        }
        blinking = max(0, blinking - dt)
        squishFace = max(0, squishFace - dt)
        heartCooldown -= dt
        greetCooldown -= dt
        strokeAmount *= CGFloat(exp(-dt * 1.2))

        if let e = emote {
            emote = e.remaining > dt ? (e.kind, e.remaining - dt) : nil
        }

        if activity == .sleep, transit == nil {
            zzzCooldown -= dt
            if zzzCooldown <= 0 {
                world.spawnZ(from: self)
                zzzCooldown = 1.8
            }
        }

        moodEmoteCooldown -= dt
        if moodEmoteCooldown <= 0 {
            moodEmoteCooldown = .random(in: 18...40)
            if world.store.moodEmotes, emote == nil, canInteract, let kind = mood.emote {
                showEmote(kind, for: 1.8)
            }
        }

        // Toys catch the eye even mid-stroll.
        if huntKind == nil, isIdle, grumpyTime <= 0, energy > 0.15 {
            if world.laserOn, Double.random(in: 0...1) < dt * 0.6 * traits.playfulness {
                startHunting(.laser, world: world)
            } else if let ball = world.ballInfo, ball.speed > 40, abs(ball.point.x - x) < 420,
                      Double.random(in: 0...1) < dt * 0.5 * traits.playfulness {
                startHunting(.ball, world: world)
            } else if let b = world.nearestButterfly(to: headPoint(), within: 320), !b.isLeaving,
                      Double.random(in: 0...1) < dt * 0.7 * traits.playfulness {
                startHunting(.butterfly, target: b.id, world: world)
            }
        }
    }

    private static let debugLog = ProcessInfo.processInfo.environment["CATIFICATION_DEBUG"] != nil

    func begin(_ a: Activity, for duration: Double = 0) {
        if Self.debugLog, a != activity {
            let t = String(format: "%.2f", CACurrentMediaTime().truncatingRemainder(dividingBy: 10000))
            FileHandle.standardError.write("\(t) \(config.name): \(a) on \(surface.map { "\($0)" } ?? "-") x=\(Int(x)) y=\(Int(y))\n".data(using: .utf8)!)
        }
        if a != .sleep { bedID = nil }
        activity = a
        activityTime = 0
        activityDuration = duration
    }

    private func face(_ tx: CGFloat) {
        if abs(tx - x) > 1 { facingRight = tx > x }
    }

    func showEmote(_ kind: EmoteKind, for duration: Double) {
        emote = (kind, duration)
    }

    // MARK: - Decisions

    private func decide(_ world: CatWorld) {
        partner = nil
        route = nil
        routeThen = nil
        routeAttempts = 0
        guard surface != nil else { return }
        let t = traits
        let grumpy = grumpyTime > 0

        if energy < 0.12 {
            goToSleep(world)
            return
        }
        if hunger > 0.65, goEat(world) { return }

        var options: [(Double, () -> Bool)] = [
            (1.0, { self.begin(.stand, for: .random(in: 2...5)); return true }),
            (1.5, { self.begin(.sit, for: .random(in: 4...10)); return true }),
            (0.7, { self.begin(.groom, for: .random(in: 2...4.5)); return true }),
            (1.6 * t.curiosity, { self.wander(world) }),
            (0.45 * t.playfulness * energy * (grumpy ? 0.3 : 1), { self.zoomies(world) }),
            ((1.1 - energy) * 2.2 * t.laziness, { self.goToSleep(world); return true }),
        ]
        if world.hasOtherSurfaces {
            options.append((1.3 * t.curiosity, { self.explore(world) }))
        }
        if world.hasPosts {
            options.append((0.6, { self.goScratch(world) }))
        }
        if world.hasTrash {
            options.append((0.5 * t.curiosity, { self.goRummage(world) }))
        }
        if !grumpy, energy > 0.35, let mate = world.playmate(for: self) {
            options.append((1.4 * t.playfulness * energy, { self.startPlay(with: mate, world: world); return true }))
        }
        if !grumpy, energy > 0.3, world.ballInfo != nil {
            options.append((0.8 * t.playfulness * energy, { self.startHunting(.ball, world: world); return true }))
        }
        if t.affection > 1.2, world.mouseNearCats {
            options.append((1.6, { self.comeToCursor(world) }))
        }

        // Try options in weighted-random order until one works out.
        while !options.isEmpty {
            var r = Double.random(in: 0..<options.reduce(0) { $0 + $1.0 })
            let index = options.firstIndex { r -= $0.0; return r < 0 } ?? 0
            if options[index].1() { return }
            options.remove(at: index)
        }
        begin(.sit, for: 3)
    }

    /// Travel to a point, on this surface or another one. Returns false if there is no way there.
    @discardableResult
    func go(to dest: SurfaceID, x gx: CGFloat, then next: Activity? = nil, running: Bool = false,
            hurried: Bool = false, world: CatWorld) -> Bool {
        guard let current = surface, transit == nil else { return false }
        let goalX = world.clampOnSurface(gx, dest, for: self)
        let r: Route
        if dest == current, world.sameSegment(current, x, goalX) {
            r = Route(hops: [], goal: dest, goalX: goalX)
        } else {
            guard let planned = world.route(for: self, to: dest, x: goalX) else { return false }
            r = planned
        }
        route = r
        routeThen = next
        routeRunning = running
        routeHurried = hurried
        targetX = r.hops.first?.takeoffX ?? r.goalX
        begin(running ? .run : .walk)
        return true
    }

    private func walk(to tx: CGFloat, then next: Activity? = nil, running: Bool = false, world: CatWorld) {
        guard let s = surface else { return }
        go(to: s, x: tx, then: next, running: running, world: world)
    }

    private func wander(_ world: CatWorld) -> Bool {
        guard let s = surface else { return false }
        return go(to: s, x: world.randomSpot(on: s, near: x, for: self), world: world)
    }

    private func explore(_ world: CatWorld) -> Bool {
        guard let dest = world.randomDestination(for: self) else { return false }
        return go(to: dest.surface, x: dest.x, world: world)
    }

    private func zoomies(_ world: CatWorld) -> Bool {
        guard let s = surface else { return false }
        let dir: CGFloat = Bool.random() ? 1 : -1
        if Bool.random() { showEmote(.note, for: 1) }
        return go(to: s, x: x + dir * .random(in: 200...520), running: true, world: world)
    }

    func goToSleep(_ world: CatWorld, here: Bool = false) {
        guard canInteract, surface != nil else { return }
        partner = nil
        huntKind = nil
        if !here {
            if let bed = world.freeBed(for: self), Double.random(in: 0...1) < 0.7,
               go(to: bed.surface, x: bed.x, then: .sleep, world: world) {
                bedID = bed.id
                return
            }
            if let buddy = world.sleepingBuddy(for: self), let s = buddy.surface, Double.random(in: 0...1) < 0.7 {
                let side: CGFloat = buddy.x > x ? -1 : 1
                if go(to: s, x: buddy.x + side * 17 * pixel, then: .sleep, world: world) { return }
            }
        }
        route = nil
        begin(.sleep, for: sleepDuration)
    }

    func wakeUp() {
        guard activity == .sleep else { return }
        begin(.stand, for: .random(in: 1...2))
    }

    private func comeToCursor(_ world: CatWorld) -> Bool {
        let showLove = { self.showEmote(.heart, for: 1.2) }
        if let spot = world.surfaceUnder(world.mouse), go(to: spot.surface, x: spot.x, then: .sit, world: world) {
            showLove()
            return true
        }
        guard let s = surface else { return false }
        showLove()
        return go(to: s, x: world.mouse.x, then: .sit, world: world)
    }

    /// Called from the menu: come over to this point on the menu bar (or the floor on the desktop).
    func call(to tx: CGFloat, world: CatWorld) {
        guard canInteract, surface != nil else { return }
        if activity == .sleep { showEmote(.exclaim, for: 1) }
        partner = nil
        huntKind = nil
        let dest: SurfaceID = world.geo.mode.hasMenuBar ? .menuBar : .ground
        if !go(to: dest, x: tx + .random(in: -40...40), then: .sit, running: true, world: world) {
            showEmote(.question, for: 1.5)
        }
    }

    // MARK: - Following a route

    private func followRoute(_ dt: Double, _ world: CatWorld) {
        let speed = activity == .walk ? walkSpeed(world) : runSpeed(world)
        if move(toward: targetX, speed: speed, dt: dt, world: world) {
            reachedWaypoint(world)
        } else if activity == .walk {
            checkGreeting(world)
        }
    }

    private func reachedWaypoint(_ world: CatWorld) {
        guard let r = route else {
            decide(world)
            return
        }
        if let next = r.hops.first {
            startHop(next, world)
        } else {
            route = nil
            let next = routeThen
            routeThen = nil
            arrive(next, world)
        }
    }

    private func continueRoute(_ world: CatWorld) {
        guard let r = route else {
            decide(world)
            return
        }
        targetX = r.hops.first?.takeoffX ?? r.goalX
        begin(routeRunning ? .run : .walk)
    }

    private func replan(_ world: CatWorld) {
        hop = nil
        routeAttempts += 1
        guard let r = route, routeAttempts <= 3, surface != nil,
              go(to: r.goal, x: r.goalX, then: routeThen, running: routeRunning, hurried: routeHurried, world: world)
        else {
            route = nil
            routeThen = nil
            if surface != nil {
                showEmote(.question, for: 1.2)
                begin(.sit, for: .random(in: 1.5...3))
            }
            return
        }
    }

    private func arrive(_ next: Activity?, _ world: CatWorld) {
        routeAttempts = 0
        switch next {
        case nil:
            decide(world)
        case .sleep:
            if let bed = bedID, let b = world.bed(bed), b.surface == surface, abs(b.x - x) < 8 * pixel {
                x = b.x
                facingRight = Bool.random()
                activity = .sleep
                activityTime = 0
                activityDuration = sleepDuration
            } else {
                begin(.sleep, for: sleepDuration)
            }
        case .crouch:
            guard let p = partner, p.isPlayable, p.surface == surface else {
                endPlay()
                return
            }
            if abs(p.x - x) > 40 * pixel, approachTries < 3 {
                approachTries += 1
                approach(p, world: world)
            } else {
                begin(.crouch, for: .random(in: 0.7...1.4))
            }
        case .sit:
            begin(.sit, for: .random(in: 4...9))
        case .eating:
            startEating(world)
        case .scratching:
            startScratching(world)
        case .hunting:
            begin(.hunting)
        case .rummaging:
            startRummaging(world)
        case let other?:
            begin(other, for: 3)
        }
    }

    private func startHop(_ planned: Hop, _ world: CatWorld) {
        guard surface == planned.from, let fresh = world.refreshHop(planned, from: x, for: self) else {
            replan(world)
            return
        }
        hop = fresh
        switch fresh.kind {
        case .climbUp, .climbDown:
            guard let toY = world.surfaceY(fresh.to) else {
                replan(world)
                return
            }
            x = fresh.takeoffX
            climbTargetY = toY
            climbPost = world.postID(for: fresh)
            surface = nil
            begin(.climbing)
        case .jump:
            guard let toY = world.surfaceY(fresh.to) else {
                replan(world)
                return
            }
            face(fresh.landX)
            let dy = toY - y, dx = abs(fresh.landX - x)
            let big = dy > 2.2 * catHeight || dx > 5 * halfWidth * 2 || dy < -7 * catHeight
            if big, !routeHurried, world.store.jumpMath {
                let thinking = 1.2 + .random(in: 0...0.9) + min(Double(abs(dy)) / 500, 0.8)
                begin(.calculating, for: thinking)
                calcSpawn = 0
                world.startCalculation(for: self, from: CGPoint(x: x, y: y), to: CGPoint(x: fresh.landX, y: toY))
            } else {
                launch(world)
            }
        }
    }

    // MARK: - Jumping

    private func calculate(_ dt: Double, _ world: CatWorld) {
        guard let h = hop else {
            decide(world)
            return
        }
        face(h.landX)
        calcSpawn -= dt
        if calcSpawn <= 0 {
            calcSpawn = .random(in: 0.16...0.28)
            world.spawnFormula(near: self, hop: h)
        }
        world.updateCalculation(for: self, progress: activityTime / activityDuration)
        if activityTime >= activityDuration {
            showEmote(.check, for: 0.7)
            launch(world)
        }
    }

    private func launch(_ world: CatWorld) {
        world.finishCalculation(for: self)
        guard let h = hop, let toY = world.surfaceY(h.to) else {
            replan(world)
            return
        }
        flightIgnore = surface
        surface = nil
        failJump = false

        if toY - y > 3 * catHeight, !routeHurried, demoMiss || Double.random(in: 0...1) < 0.12 {
            // Miscalculated: only just reach the edge and hang on it by the front paws.
            failJump = true
            hangPoint = CGPoint(x: h.landX, y: toY - CGFloat(CatArt.H - 1) * pixel)
            vy = (2 * Self.gravity * max(hangPoint.y - y, 4)).squareRoot()
            vx = (hangPoint.x - x) / (vy / Self.gravity)
        } else {
            let b = Navigator.ballistic(from: CGPoint(x: x, y: y), to: CGPoint(x: h.landX, y: toY),
                                        ceiling: world.ceiling(for: self), gravity: Self.gravity)
            vx = b.vx
            vy = b.vy
        }
        if abs(vx) > 1 { facingRight = vx > 0 }
        begin(.jumping)
    }

    private func resolveHang(_ world: CatWorld) {
        failJump = false
        guard let h = hop else {
            begin(.falling)
            return
        }
        let scrambleUp = !demoMiss && Double.random(in: 0...1) < 0.5
        demoMiss = false
        if scrambleUp, let s = world.surface(h.to), s.segmentIndex(containing: hangPoint.x, tolerance: 2) != nil {
            // Scrambles up after all.
            y = s.y
            surface = s.id
            x = world.clampOnSurface(hangPoint.x, s.id, for: self)
            hop = nil
            if var r = route, r.hops.first?.to == s.id {
                r.hops.removeFirst()
                route = r
            }
            showEmote(.exclaim, for: 0.8)
            continueRoute(world)
        } else {
            fellFromLedge = true
            flightIgnore = h.to
            hop = nil
            route = nil
            vx = 0
            vy = 0
            begin(.falling)
        }
    }

    private func pounce(at tx: CGFloat, height: CGFloat = 14, world: CatWorld) {
        let dir: CGFloat = tx > x ? 1 : -1
        facingRight = dir > 0
        let hop = min(max((world.ceiling(for: self) - y) * 0.9, 3), max(height, 3))
        vy = (2 * Self.gravity * hop).squareRoot()
        let flight = 2 * vy / Self.gravity
        let distance = max(abs(tx - x) - 8 * pixel, 6 * pixel)
        vx = dir * min(distance / flight, 90 * pixel)
        flightIgnore = nil
        surface = nil
        begin(.pounce)
    }

    private func fly(dt: Double, world: CatWorld) {
        let d = CGFloat(dt)
        let previousY = y
        vy -= Self.gravity * d
        x += vx * d
        y += vy * d

        let edge = canvasSize.width * 0.4
        if x < world.playArea.minX + edge {
            x = world.playArea.minX + edge
            vx = abs(vx) * 0.5
        }
        if x > world.playArea.maxX - edge {
            x = world.playArea.maxX - edge
            vx = -abs(vx) * 0.5
        }
        let ceiling = world.ceiling(for: self)
        if y > ceiling {
            y = ceiling
            vy = min(vy, 0)
        }

        if failJump, vy <= 0 {
            x = hangPoint.x
            y = hangPoint.y
            vx = 0
            vy = 0
            begin(.hanging, for: .random(in: 0.9...1.5))
            showEmote(.exclaim, for: 1.2)
            return
        }
        if vy <= 0, let s = world.landingSurface(x: x, from: previousY, to: y, ignoring: flightIgnore) {
            land(on: s, world: world)
            return
        }
        if vy < 0, y < -canvasSize.height, let rescue = world.surfaceAbove(x: x, y: y) {
            // Fell out of the world (menu bar mode has no floor): leap back up.
            vy = (2 * Self.gravity * (rescue - y + 5 * pixel)).squareRoot()
            vx *= 0.3
            flightIgnore = nil
        }
    }

    private func land(on s: Surface, world: CatWorld) {
        let impact = -vy
        y = s.y
        vx = 0
        vy = 0
        surface = s.id
        flightIgnore = nil
        x = world.clampOnSurface(x, s.id, for: self)
        if impact > 650 { squashOnLanding() }

        switch activity {
        case .pounce:
            if huntKind != nil {
                begin(.hunting)
            } else if let p = partner, p.isPlayable, p.surface == surface, abs(p.x - x) < 34 * pixel {
                let d = Double.random(in: 2.5...5)
                p.startFlee(from: self, duration: d, world: world)
                begin(.chase, for: d)
            } else {
                endPlay()
            }
        case .jumping:
            if let h = hop, h.to == s.id, var r = route {
                if r.hops.first?.to == s.id { r.hops.removeFirst() }
                route = r
                hop = nil
                continueRoute(world)
            } else {
                hop = nil
                if route != nil { replan(world) } else { decide(world) }
            }
        default:
            if fellFromLedge {
                // "I meant to do that."
                fellFromLedge = false
                showEmote(.question, for: 1.2)
                begin(.groom, for: .random(in: 2.5...4))
                return
            }
            if impact > 420 { showEmote(.exclaim, for: 1) }
            begin(.stand, for: .random(in: 0.8...1.6))
        }
    }

    private func squashOnLanding() {
        let squash = CAKeyframeAnimation(keyPath: "transform")
        squash.values = [
            CATransform3DIdentity,
            CATransform3DMakeScale(1.18, 0.78, 1),
            CATransform3DMakeScale(0.96, 1.05, 1),
            CATransform3DIdentity,
        ].map { NSValue(caTransform3D: $0) }
        squash.keyTimes = [0, 0.3, 0.65, 1]
        squash.duration = 0.3
        layer.add(squash, forKey: "land")
    }

    // MARK: - Climbing and scratching

    private func climb(_ dt: Double, _ world: CatWorld) {
        guard let h = hop else {
            begin(.falling)
            return
        }
        let speed = 22 * pixel * CGFloat(world.store.speed)
        let dir: CGFloat = climbTargetY > y ? 1 : -1
        y += dir * speed * CGFloat(dt)
        guard (climbTargetY - y) * dir <= 0 else { return }
        y = climbTargetY
        surface = h.to
        climbPost = nil
        hop = nil
        if var r = route, r.hops.first?.to == h.to {
            r.hops.removeFirst()
            route = r
        }
        continueRoute(world)
    }

    private func goScratch(_ world: CatWorld) -> Bool {
        guard let post = world.randomPost() else { return false }
        scratchPost = post.id
        return go(to: post.base, x: post.x, then: .scratching, world: world)
    }

    private func startScratching(_ world: CatWorld) {
        guard let id = scratchPost, let post = world.post(id), post.base == surface, abs(post.x - x) < 6 * pixel else {
            decide(world)
            return
        }
        x = post.x
        begin(.scratching, for: .random(in: 2...4))
    }

    private func afterScratch(_ world: CatWorld) {
        defer { scratchPost = nil }
        happiness = min(1, happiness + 0.05)
        if let id = scratchPost, let post = world.post(id), Double.random(in: 0...1) < 0.55,
           go(to: post.perch, x: post.x, then: .sit, world: world) {
            return
        }
        decide(world)
    }

    // MARK: - Eating

    private func goEat(_ world: CatWorld) -> Bool {
        guard let bowl = world.nearestBowl(for: self) else { return false }
        let side: CGFloat = x < bowl.x ? -1 : 1
        bowlID = bowl.id
        return go(to: bowl.surface, x: bowl.x + side * 9 * pixel, then: .eating, world: world)
    }

    private func startEating(_ world: CatWorld) {
        guard let id = bowlID, let bowl = world.bowl(id), bowl.surface == surface, abs(bowl.x - x) < 20 * pixel else {
            bowlID = nil
            decide(world)
            return
        }
        face(bowl.x)
        if world.takeFood(from: id) {
            begin(.eating, for: .random(in: 4...7))
        } else {
            // Empty bowl: sit next to it and complain.
            bowlID = nil
            showEmote(.fish, for: 2.5)
            begin(.sit, for: .random(in: 4...7))
        }
    }

    private func finishEating() {
        hunger = 0
        happiness = min(1, happiness + 0.1)
        bowlID = nil
        showEmote(.heart, for: 1.2)
        begin(.groom, for: .random(in: 2...4))
    }

    // MARK: - Hunting toys

    func startHunting(_ kind: HuntKind, target: UUID? = nil, world: CatWorld) {
        guard surface != nil, canInteract else { return }
        huntTargetID = target
        huntSmoothX = nil
        huntChasing = false
        partner = nil
        route = nil
        routeThen = nil
        huntKind = kind
        huntUntil = world.now + .random(in: 15...35)
        huntRetarget = 0
        showEmote(.exclaim, for: 0.6)
        begin(.hunting)
    }

    private func stopHunting(confused: Bool) {
        huntKind = nil
        huntMoving = false
        if confused { showEmote(.question, for: 1.5) }
        begin(.sit, for: .random(in: 2...4))
    }

    private func hunt(_ dt: Double, _ world: CatWorld) {
        huntMoving = false
        guard let kind = huntKind, world.now < huntUntil, energy > 0.08 else {
            stopHunting(confused: false)
            return
        }
        guard let target = world.huntTarget(kind, for: self), let current = surface else {
            stopHunting(confused: true)
            return
        }
        // Follow a smoothed position, not every flutter of the target.
        let smoothX = huntSmoothX.map { $0 + (target.point.x - $0) * CGFloat(min(1, dt * 4)) } ?? target.point.x
        huntSmoothX = smoothX
        let tx = kind == .butterfly ? smoothX : target.point.x
        let height = target.point.y - y
        let leapReach = 4 * catHeight
        face(tx)
        huntRetarget -= dt

        let onMySurface = target.surface == current && world.sameSegment(current, x, tx)
        // A butterfly overhead can be chased from below and leapt at.
        let overhead = kind == .butterfly && height > -10 && world.sameSegment(current, x, tx)
        if onMySurface || overhead {
            let dx = tx - x
            // Hysteresis: start running when the target is clearly away, stop only when it's close,
            // and don't flip between the two faster than a few times a second.
            huntSwitchTime += dt
            let wantChase = huntChasing ? abs(dx) > 5 * pixel : abs(dx) > 14 * pixel
            if wantChase != huntChasing, huntSwitchTime > 0.3 {
                huntChasing = wantChase
                huntSwitchTime = 0
            }
            if !huntChasing {
                guard abs(dx) < 10 * pixel else { return }
                switch kind {
                case .ball where abs(height) < 12 * pixel:
                    world.kickBall(dir: facingSign, power: .random(in: 0.6...1.2))
                    begin(.swipe, for: 0.45)
                case .laser where abs(height) < 12 * pixel:
                    if Double.random(in: 0...1) < dt * 2.5 { pounce(at: tx, world: world) }
                case .butterfly where height < leapReach:
                    if Double.random(in: 0...1) < dt * 2 {
                        world.startleButterflies(near: target.point)
                        pounce(at: tx, height: height + 6 * pixel, world: world)
                    }
                default:
                    break
                }
            } else {
                huntMoving = true
                let goal = world.clampOnSurface(tx - (dx > 0 ? 4 : -4) * pixel, current, for: self)
                if move(toward: goal, speed: runSpeed(world) * 1.1, dt: dt, world: world) {
                    // Ran out of room (end of a shelf) or got there: stop instead of running in place.
                    huntChasing = false
                    huntSwitchTime = 0
                    huntMoving = false
                }
            }
        } else if let ts = target.surface, huntRetarget <= 0 {
            huntRetarget = 0.6
            go(to: ts, x: tx, then: .hunting, running: true, hurried: true, world: world)
        }
    }

    // MARK: - Trash

    func goRummage(_ world: CatWorld) -> Bool {
        guard let can = world.randomTrash(for: self) else { return false }
        trashID = can.id
        let side: CGFloat = x < can.x ? -1 : 1
        return go(to: can.surface, x: can.x + side * 14 * pixel, then: .rummaging, world: world)
    }

    private func startRummaging(_ world: CatWorld) {
        guard let id = trashID, let can = world.trash(id), can.surface == surface, abs(can.x - x) < 24 * pixel,
              !world.trashOccupied(id, by: self)
        else {
            trashID = nil
            decide(world)
            return
        }
        rummageFrom = CGPoint(x: x, y: y)
        rummageExitSide = Bool.random() ? 1 : -1
        rummageSeed = .random(in: 0...6)
        begin(.rummaging, for: .random(in: 5...9))
    }

    private static let hopTime = 0.35

    private var rummagePhase: Int {
        if activityTime < Self.hopTime { return 0 }
        if activityTime < activityDuration - Self.hopTime { return 1 }
        return 2
    }

    private func rummage(_ dt: Double, _ world: CatWorld) {
        guard let id = trashID, let can = world.trash(id) else {
            trashID = nil
            rummageHidden = false
            fallOff()
            return
        }
        let rim = can.y + CGFloat(PropArt.trashHeight) * world.geo.furniturePixel
        let hidden = rim - 11 * pixel, peeking = rim - 3 * pixel
        func arc(_ k: CGFloat, _ from: CGPoint, _ to: CGPoint) -> CGPoint {
            let bump = (rim + 6 * pixel - min(from.y, to.y)) * sin(k * .pi)
            return CGPoint(x: from.x + (to.x - from.x) * k, y: from.y + (to.y - from.y) * k + max(0, bump - abs(to.y - from.y) * 0.5))
        }

        switch rummagePhase {
        case 0:
            let k = CGFloat(activityTime / Self.hopTime)
            let p = arc(k, rummageFrom, CGPoint(x: can.x, y: hidden))
            x = p.x
            y = p.y
        case 1:
            x = can.x
            // Mostly head-down in the trash, popping up for a look now and then.
            let wave = sin((activityTime - Self.hopTime) * 1.3 + rummageSeed)
            let amount = max(0, (wave - 0.2) / 0.8)
            y = hidden + (peeking - hidden) * CGFloat(amount)
            rummageHidden = amount < 0.25
            if rummageHidden {
                trashBitCooldown -= dt
                if trashBitCooldown <= 0 {
                    trashBitCooldown = .random(in: 0.15...0.35)
                    world.spawnTrashBit(at: CGPoint(x: can.x + .random(in: -4...4) * pixel, y: rim + pixel))
                }
            }
        default:
            rummageHidden = false
            let exitX = world.clampOnSurface(can.x + rummageExitSide * 14 * pixel, can.surface, for: self)
            let k = CGFloat(min(1, (activityTime - (activityDuration - Self.hopTime)) / Self.hopTime))
            let p = arc(k, CGPoint(x: can.x, y: hidden), CGPoint(x: exitX, y: can.y))
            x = p.x
            y = p.y
            facingRight = rummageExitSide > 0
            if k >= 1 {
                x = exitX
                y = can.y
                trashID = nil
                happiness = min(1, happiness + 0.06)
                showEmote(Bool.random() ? .fish : .heart, for: 1.2)
                begin(.stand, for: .random(in: 1...2))
            }
        }
    }

    // MARK: - Play

    func startPlay(with mate: Cat, world: CatWorld) {
        partner = mate
        approachTries = 0
        showEmote(.note, for: 1)
        if abs(mate.x - x) < 26 * pixel {
            begin(.crouch, for: .random(in: 0.7...1.4))
        } else {
            approach(mate, world: world)
        }
    }

    private func approach(_ mate: Cat, world: CatWorld) {
        let side: CGFloat = x < mate.x ? -1 : 1
        let p = partner
        walk(to: mate.x + side * 20 * pixel, then: .crouch, running: true, world: world)
        partner = p
    }

    func startFlee(from chaser: Cat, duration: Double, world: CatWorld) {
        partner = chaser
        route = nil
        routeThen = nil
        begin(.flee, for: duration)
        targetX = fleeTarget(world)
        showEmote(.exclaim, for: 0.8)
    }

    private func fleeTarget(_ world: CatWorld) -> CGFloat {
        guard let s = surface else { return x }
        var dir: CGFloat = (partner.map { $0.x < x } ?? Bool.random()) ? 1 : -1
        var candidate = world.clampOnSurface(x + dir * .random(in: 45...120) * pixel, s, for: self)
        if abs(candidate - x) < 20 * pixel {
            dir = -dir
            candidate = world.clampOnSurface(x + dir * .random(in: 45...120) * pixel, s, for: self)
        }
        return candidate
    }

    private func endChase(_ world: CatWorld) {
        guard let p = partner else {
            endPlay()
            return
        }
        if p.activity == .flee, energy > 0.3, p.energy > 0.3, Double.random(in: 0...1) < 0.35 {
            // Swap roles: now the other one chases.
            let d = Double.random(in: 2...4)
            p.partner = self
            p.begin(.chase, for: d)
            startFlee(from: p, duration: d, world: world)
        } else {
            if p.activity == .flee { p.relaxAfterPlay() }
            relaxAfterPlay()
            showEmote(.heart, for: 1.2)
        }
    }

    func relaxAfterPlay() {
        partner = nil
        happiness = min(1, happiness + 0.08)
        if Bool.random() {
            begin(.groom, for: .random(in: 2...4))
        } else {
            begin(.sit, for: .random(in: 3...6))
        }
    }

    private func endPlay() {
        partner = nil
        route = nil
        routeThen = nil
        begin(.stand, for: .random(in: 1...2.5))
    }

    private func checkGreeting(_ world: CatWorld) {
        guard greetCooldown <= 0, happiness > 0.5 else { return }
        guard let other = world.cats.first(where: {
            $0 !== self && $0.canGreet && $0.surface == surface && abs($0.x - x) < 14 * pixel
        }) else { return }
        greetCooldown = 25
        other.greetCooldown = 25
        guard Double.random(in: 0...1) < 0.6, other.happiness > 0.45 else { return }
        greet(facing: other.x)
        other.greet(facing: x)
        let a = headPoint(), b = other.headPoint()
        world.spawnHeart(at: CGPoint(x: (a.x + b.x) / 2, y: max(a.y, b.y) + 2 * pixel), pixel: max(1, pixel - 0.5))
    }

    func greet(facing tx: CGFloat) {
        partner = nil
        route = nil
        routeThen = nil
        begin(.greet, for: 2.5)
        face(tx)
    }

    // MARK: - Movement

    /// Moves towards `target` along the current surface; returns true on arrival.
    /// On the menu bar, a path through the notch becomes a portal transit.
    private func move(toward target: CGFloat, speed: CGFloat, dt: Double, world: CatWorld) -> Bool {
        let dx = target - x
        if abs(dx) < 0.75 {
            x = target
            return true
        }
        let dir: CGFloat = dx > 0 ? 1 : -1
        facingRight = dir > 0
        let step = min(abs(dx), speed * CGFloat(dt))

        if surface == .menuBar, let portals = world.portalXs {
            let entry = dir > 0 ? portals.left : portals.right
            let exit = dir > 0 ? portals.right : portals.left
            if (target - entry) * dir > 0, (entry - x) * dir > 0 {
                let ahead = (entry - (x + dir * halfWidth)) * dir
                if ahead < 70 { world.touchPortals() }
                if ahead <= step {
                    x += dir * step
                    transit = Transit(entry: entry, exit: exit, dir: dir)
                    world.portalTransitBegan(at: entry)
                    return false
                }
            }
        }
        x += dir * step
        return false
    }

    private func continueTransit(_ t: Transit, dt: Double, world: CatWorld) {
        let speed = activity == .walk ? walkSpeed(world) : runSpeed(world)
        x += t.dir * speed * CGFloat(dt)
        facingRight = t.dir > 0
        if (x - t.entry) * t.dir > halfWidth {
            x += t.exit - t.entry
            transit = nil
            world.portalTransitEnded(at: t.exit)
        }
    }

    /// The surface under the cat moved (a window or a shelf being dragged).
    func ride(dx: CGFloat, toY newY: CGFloat) {
        x += dx
        y = newY
        if transit != nil { transit = nil }
    }

    /// The surface under the cat is gone.
    func fallOff() {
        let wasAsleep = activity == .sleep
        clearPlans()
        transit = nil
        surface = nil
        vx = 0
        vy = 0
        begin(.falling)
        if wasAsleep { showEmote(.exclaim, for: 1) }
    }

    // MARK: - Interaction

    func stroke(_ amount: CGFloat, world: CatWorld) {
        guard canInteract else { return }
        strokeAmount += amount
        lastStroke = world.now
        grumpyTime = max(0, grumpyTime - Double(amount) * 0.01)

        if activity == .sleep {
            // Purrs in its sleep without waking up.
            if strokeAmount > 50, heartCooldown <= 0 {
                world.spawnHearts(from: self, count: 1, burst: false)
                heartCooldown = 0.7
                happiness = min(1, happiness + 0.02)
            }
            return
        }
        if activity != .petted, strokeAmount > 45 {
            world.finishCalculation(for: self)
            clearPlans()
            begin(.petted)
        }
        if activity == .petted, heartCooldown <= 0 {
            world.spawnHearts(from: self, count: 1, burst: false)
            heartCooldown = 0.35
            happiness = min(1, happiness + 0.03 * traits.affection)
        }
    }

    func squish(world: CatWorld) {
        guard canInteract else { return }
        let wasAsleep = activity == .sleep
        recentSquish += 1
        squishFace = 0.45
        world.finishCalculation(for: self)
        clearPlans()

        let squash = CAKeyframeAnimation(keyPath: "transform")
        squash.values = [
            CATransform3DIdentity,
            CATransform3DMakeScale(1.28, 0.62, 1),
            CATransform3DMakeScale(0.9, 1.12, 1),
            CATransform3DMakeScale(1.05, 0.96, 1),
            CATransform3DIdentity,
        ].map { NSValue(caTransform3D: $0) }
        squash.keyTimes = [0, 0.18, 0.45, 0.72, 1]
        squash.duration = 0.5
        layer.add(squash, forKey: "squish")

        if recentSquish > 3 * traits.patience + 1 {
            // Enough is enough.
            recentSquish = 0
            grumpyTime = 12
            happiness = max(0, happiness - 0.2)
            showEmote(.anger, for: 2)
            let away: CGFloat = world.mouse.x < x ? 1 : -1
            walk(to: x + away * .random(in: 160...320), then: .sit, running: true, world: world)
            return
        }
        if wasAsleep {
            showEmote(.exclaim, for: 1.2)
            happiness = max(0, happiness - 0.05)
        } else {
            world.spawnHearts(from: self, count: .random(in: 3...5), burst: true)
            happiness = min(1, happiness + 0.04 * traits.affection)
        }
        begin(.stand, for: .random(in: 1.2...2.5))
    }

    func pickUp(world: CatWorld) {
        world.finishCalculation(for: self)
        clearPlans()
        transit = nil
        surface = nil
        squishFace = 0
        begin(.carried)
    }

    func carry(to p: CGPoint, world: CatWorld) {
        let size = canvasSize
        x = min(max(p.x, size.width / 2), world.geo.width - size.width / 2)
        let top = world.geo.height - size.height + pixel
        y = min(max(p.y - (CGFloat(CatArt.H) - 2) * pixel, 0), top)
    }

    func drop(velocity v: CGVector, world: CatWorld) {
        guard activity == .carried else { return }
        vx = max(-700, min(700, v.dx))
        vy = max(-500, min(700, v.dy))
        if !world.hasSurfaceBelow(x: x, y: y), let target = world.surfaceAbove(x: x, y: y) {
            // Nothing to land on below: leap back up.
            vy = max(vy, (2 * Self.gravity * (target - y + 5 * pixel)).squareRoot())
            vx *= 0.35
        }
        begin(.falling)
    }

    // MARK: - Rendering

    private var currentAnim: Anim {
        if squishFace > 0, activity == .stand { return .squish }
        switch activity {
        case .stand: return blinking > 0 ? .blink : .stand
        case .sit: return blinking > 0 ? .sitBlink : .sit
        case .groom: return .groom
        case .sleep: return .sleep
        case .walk: return .walk
        case .run, .chase, .flee: return .run
        case .crouch: return .crouch
        case .calculating: return calcLooksUp ? .crouchUp : .crouch
        case .pounce, .falling, .jumping: return .jump
        case .swipe: return .swipe
        case .petted, .greet: return .petted
        case .carried: return .dangle
        case .hanging: return .hang
        case .climbing: return .climb
        case .scratching: return .scratch
        case .eating: return .eat
        case .hunting:
            if huntMoving { return .run }
            return huntKind == .butterfly ? .crouchUp : .crouch
        case .rummaging: return rummagePhase == 1 ? .peek : .jump
        }
    }

    /// Set by the world when a calculation starts, so the cat looks at where it is going.
    var calcLooksUp = false

    func sync(world: CatWorld) {
        let a = currentAnim
        if a != anim {
            anim = a
            animTime = 0
        }
        let index = Int(animTime * a.fps) % sheet.frameCount(a)
        let image = sheet.image(a, index, facingRight: facingRight)
        if image !== shownImage {
            layer.contents = image
            ghost.contents = image
            shownImage = image
        }

        let size = canvasSize
        let px = (x * 2).rounded() / 2
        let py = ((y + visualLift) * 2).rounded() / 2
        layer.bounds = CGRect(origin: .zero, size: size)
        layer.position = CGPoint(x: px, y: py)
        switch activity {
        case .carried, .falling, .jumping, .hanging: layer.zPosition = 30
        case .climbing, .scratching: layer.zPosition = 12
        case .sleep where bedID != nil: layer.zPosition = 7
        case .rummaging: layer.zPosition = 7
        default: layer.zPosition = baseZ
        }

        let originX = px - size.width / 2
        let box = sheet.bounds(a, index, facingRight: facingRight)
        hitRect = CGRect(x: originX + box.minX * pixel, y: py + box.minY * pixel,
                         width: box.width * pixel, height: box.height * pixel).insetBy(dx: -2, dy: -2)

        if let t = transit {
            let shift = t.exit - t.entry
            if t.dir > 0 {
                setClip(clip, from: 0, to: t.entry - originX, size: size)
                setClip(ghostClip, from: t.exit - (originX + shift), to: size.width, size: size)
            } else {
                setClip(clip, from: t.entry - originX, to: size.width, size: size)
                setClip(ghostClip, from: 0, to: t.exit - (originX + shift), size: size)
            }
            layer.mask = clip
            ghost.mask = ghostClip
            ghost.bounds = layer.bounds
            ghost.position = CGPoint(x: px + shift, y: py)
            ghost.zPosition = layer.zPosition
            ghost.isHidden = false
        } else {
            if layer.mask != nil { layer.mask = nil }
            ghost.isHidden = true
        }

        syncEmote(world: world)
    }

    private func setClip(_ m: CALayer, from lo: CGFloat, to hi: CGFloat, size: CGSize) {
        let a = min(max(lo, 0), size.width), b = min(max(hi, 0), size.width)
        m.frame = CGRect(x: a, y: 0, width: max(0, b - a), height: size.height)
    }

    private func syncEmote(world: CatWorld) {
        guard let e = emote, transit == nil, let sprite = EmoteArt.sprites[e.kind] else {
            emoteLayer.isHidden = true
            return
        }
        let p = max(1, pixel - 0.5)
        if shownEmote != e.kind {
            emoteLayer.contents = sprite.image
            shownEmote = e.kind
        }
        let size = CGSize(width: CGFloat(sprite.width) * p, height: CGFloat(sprite.height) * p)
        emoteLayer.bounds = CGRect(origin: .zero, size: size)
        let head = headPoint()
        let bob = CGFloat(sin(world.now * 5)) * 1.5
        let ey = min(head.y + 2 * pixel + bob, world.geo.height - size.height)
        emoteLayer.position = CGPoint(x: ((head.x + facingSign * 6 * pixel) * 2).rounded() / 2, y: (ey * 2).rounded() / 2)
        emoteLayer.isHidden = false
    }
}
