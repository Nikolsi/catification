import AppKit
import SwiftUI

/// "Bring your own cat": the real cat editor next to a room, worked by a drawn cursor. Every
/// change goes through the editor's own store, so the cat on stage changes exactly the way it
/// does for a person at the controls. Written as one story from top to bottom with async waits.
extension DemoDirector {
    /// A new cat, still plain: a calico's colours, but no pattern yet.
    static var editorCat: CatConfig {
        var cat = CatConfig(name: L("Whiskers"), coat: .calico, personality: .affectionate)
        cat.pattern = .solid
        return cat
    }

    private static let editorName = "Biscuit"
    private static let editorStory = "Raids the trash. Naps belly up in her bed. Follows me around after cuddles."
    /// Seconds between keys: uneven, like a person typing, and the same every run.
    private static let keyGaps = [0.04, 0.06, 0.03, 0.05, 0.08, 0.04, 0.045, 0.06, 0.035, 0.07]

    // MARK: Setting up

    /// The editor window on the left, under the menu bar; on the right a room with a trash can and a bed.
    func setUpEditor(in world: CatWorld, stage: CGRect) {
        // Before the editor's views exist, so they register for the cursor.
        DemoTargets.enabled = true
        showWallpaper(in: world, stage: stage)

        let frame = world.geo.frame
        let ground = stage.minY + Self.floor
        let rect = CGRect(x: stage.minX + 24, y: ground + 30, width: 480, height: world.geo.menuBarY - 16 - (ground + 30))
        // A panel that doesn't activate the app: it looks like a normal window and can be key (title
        // bar, focus rings, a blinking caret) while the terminal running the recording stays in front.
        let window = NSPanel(contentRect: rect.offsetBy(dx: frame.minX, dy: frame.minY),
                             styleMask: [.titled, .closable, .miniaturizable, .resizable, .nonactivatingPanel],
                             backing: .buffered, defer: false)
        window.becomesKeyOnlyIfNeeded = false
        window.title = "Catification"
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: .aqua)
        window.contentView = NSHostingView(rootView: EditorDemoView(store: world.store))
        window.setFrame(rect.offsetBy(dx: frame.minX, dy: frame.minY), display: true)
        window.orderFrontRegardless()
        window.makeKey()
        editorWindow = window

        world.store.furniture = [
            Furniture(id: trash, kind: .trash, x: Double(stage.minX + 745), y: Double(ground)),
            Furniture(id: bed, kind: .bed, x: Double(stage.minX + 875), y: Double(ground)),
        ]
        world.reloadFurnitureForDemo()
    }

    // MARK: The story

    func editorScript() {
        Task { @MainActor in
            guard let world, let cat = world.cats.first, let window = editorWindow else { return }
            await waitUntil { _ in cat.surface != nil }
            cat.begin(.sit, for: 120)
            // The cursor starts out in the room, near the cat, and heads for the editor.
            point(at: CGPoint(x: window.frame.maxX + 190, y: window.frame.midY - 40))
            await wait(0.8)

            // A name, then the looks: big, striped, then spotted. The cat changes as it's clicked.
            await glide(to: centre(of: "name"))
            click()
            event("name", atScreen: cursorPoint ?? .zero)
            await type(Self.editorName, into: "name", replacing: true)
            await wait(0.4)
            await pick(segment: 2, of: "size") { $0.size = .large }
            await scroll(to: "pattern", margin: 95)
            await pick(segment: 1, of: "pattern") { $0.pattern = .tabby }
            await pick(segment: 2, of: "pattern") { $0.pattern = .calico }
            await wait(0.5)

            // Her story, in the owner's words…
            await scroll(to: "about")
            await glide(to: centre(of: "about"))
            click()
            event("story", atScreen: cursorPoint ?? .zero)
            await type(Self.editorStory, into: "about", replacing: false)
            await wait(0.6)

            // …and the settings that make it true. "Raids the trash":
            await scroll(to: "habit.rummage")
            event("habit", atScreen: centre(of: "habit.rummage") ?? .zero)
            await drag(slider: "habit.rummage", to: 3) { value in self.editBrain { $0.habits[.rummage] = value } }
            event("trash", cat: cat)
            _ = cat.goRummage(world)
            await waitUntil { _ in cat.activity == .rummaging }
            event("rummage", cat: cat)
            await waitUntil { _ in cat.activity != .rummaging && cat.surface != nil }
            cat.begin(.sit, for: 120)
            event("rummaged", cat: cat)
            await wait(0.8)

            // "Naps belly up in her bed":
            await scroll(to: "spot.bed")
            event("spot", atScreen: centre(of: "spot.bed") ?? .zero)
            await drag(slider: "spot.bed", to: 3) { value in self.editBrain { $0.places[.bed] = value } }
            await glide(to: centre(of: "sleeps", rightPart: true))
            click()
            editBrain { $0.sleepPose = .bellyUp }
            await wait(0.5)
            cat.demoPose = .bellyUp
            cat.demoNoWake = true
            _ = cat.demoNap(at: .bed, world: world)
            event("nap", cat: cat)
            await waitUntil { _ in cat.activity == .sleep }
            event("asleep", cat: cat)
            await wait(2)

            // "Follows me around after cuddles": a ritual, and every time, not just sometimes.
            await scroll(to: "addRitual")
            event("ritual", atScreen: centre(of: "addRitual") ?? .zero)
            await glide(to: centre(of: "addRitual"))
            click()
            editBrain { $0.recipes.append(RecipeTemplate.followAfterPetting.make()) }
            await wait(0.6)
            await drag(slider: "ritual.followAfterPetting", to: 1) { value in
                self.editBrain { brain in
                    if let i = brain.recipes.firstIndex(where: { $0.template == .followAfterPetting }) { brain.recipes[i].chance = value }
                }
            }
            await wait(0.5)

            // A stroke wakes her (she purrs in her sleep first), a proper cuddle, and she follows the
            // cursor over to the editor. It stays down at her level, where she can see it.
            await glide(to: strokePoint(cat, phase: 0), over: 1)
            event("pet", cat: cat)
            await stroke(cat, for: 1.2)
            cat.demoNoWake = false
            cat.wakeUp()
            await wait(0.6)
            await stroke(cat, for: 2.2)
            let ground = world.geo.frame.minY + (world.geo.groundY ?? 0)
            await glide(to: CGPoint(x: window.frame.maxX + 70, y: ground + 14 * cat.pixel), over: 1.6)
            await waitUntil { _ in cat.activity == .walk || cat.activity == .run }
            event("follow", cat: cat)
            await waitUntil { _ in cat.activity == .sit }
            event("home", cat: cat)
            await wait(1)
            await glide(to: strokePoint(cat, phase: 0), over: 0.5)
            await stroke(cat, for: 2)
            event("end", cat: cat)
        }
    }

    // MARK: Waiting

    /// Waits `seconds` of simulated time.
    private func wait(_ seconds: Double) async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            at(seconds) { _ in done.resume() }
        }
    }

    private func waitUntil(_ condition: @escaping (CatWorld) -> Bool) async {
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            poll { world in
                guard condition(world) else { return false }
                done.resume()
                return true
            }
        }
    }

    /// Calls `step` every frame for `seconds` of real time with an eased 0…1.
    private func animate(over seconds: Double, _ step: @escaping (CGFloat) -> Void) async {
        let began = CACurrentMediaTime()
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            Timer.scheduledTimer(withTimeInterval: 1.0 / 60, repeats: true) { timer in
                MainActor.assumeIsolated {
                    let t = min(1, (CACurrentMediaTime() - began) / seconds)
                    step(CGFloat(t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2))
                    guard t >= 1 else { return }
                    timer.invalidate()
                    done.resume()
                }
            }
        }
    }

    // MARK: The cursor

    /// The drawn cursor at a point on screen; the world takes it for the mouse.
    private func point(at p: CGPoint) {
        showCursor(at: p)
        guard let world else { return }
        world.demoMouse = CGPoint(x: p.x - world.geo.frame.minX, y: p.y - world.geo.frame.minY)
    }

    /// Moves the cursor along a slight curve, as a hand does; the farther, the longer it takes.
    private func glide(to target: CGPoint?, over seconds: Double? = nil) async {
        guard let target else { return }
        let from = cursorPoint ?? CGPoint(x: target.x + 120, y: target.y - 80)
        let dx = target.x - from.x, dy = target.y - from.y
        let length = hypot(dx, dy)
        await animate(over: seconds ?? min(1, 0.3 + Double(length) / 900)) { k in
            let bow = sin(k * .pi) * length * 0.08
            self.point(at: CGPoint(x: from.x + dx * k - dy / max(length, 1) * bow,
                                   y: from.y + dy * k + dx / max(length, 1) * bow))
        }
    }

    /// A ring that grows and fades under the cursor, so clicks read in a video.
    private func click() {
        guard let p = cursorPoint else { return }
        let size: CGFloat = 40
        let w = NSWindow(contentRect: CGRect(x: p.x - size / 2, y: p.y - size / 2, width: size, height: size),
                         styleMask: .borderless, backing: .buffered, defer: false)
        w.level = NSWindow.Level(rawValue: NSWindow.Level.screenSaver.rawValue - 1)
        w.isOpaque = false
        w.backgroundColor = .clear
        w.hasShadow = false
        w.ignoresMouseEvents = true
        w.isReleasedWhenClosed = false
        let view = NSView(frame: CGRect(x: 0, y: 0, width: size, height: size))
        view.wantsLayer = true
        let ring = CAShapeLayer()
        ring.frame = view.bounds
        ring.path = CGPath(ellipseIn: view.bounds.insetBy(dx: 3, dy: 3), transform: nil)
        ring.fillColor = RGB(hex: 0xF08A3C).nsColor.withAlphaComponent(0.25).cgColor
        ring.strokeColor = RGB(hex: 0xF08A3C).nsColor.cgColor
        ring.lineWidth = 2.5
        ring.opacity = 0
        view.layer?.addSublayer(ring)
        w.contentView = view
        w.orderFrontRegardless()

        let grow = CABasicAnimation(keyPath: "transform.scale")
        grow.fromValue = 0.3
        grow.toValue = 1
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        let group = CAAnimationGroup()
        group.animations = [grow, fade]
        group.duration = 0.45
        group.timingFunction = CAMediaTimingFunction(name: .easeOut)
        ring.add(group, forKey: "click")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { w.close() }
    }

    /// Strokes along the cat's back for `seconds`, which is exactly how petting works.
    private func stroke(_ cat: Cat, for seconds: Double) async {
        await animate(over: seconds) { k in
            self.point(at: self.strokePoint(cat, phase: Double(k) * seconds))
        }
    }

    private func strokePoint(_ cat: Cat, phase: Double) -> CGPoint {
        let frame = world?.geo.frame ?? .zero
        let lift: CGFloat = cat.activity == .sleep ? 5 : 8
        return CGPoint(x: frame.minX + cat.x + CGFloat(sin(phase * 4)) * 7 * cat.pixel,
                       y: frame.minY + cat.y + lift * cat.pixel)
    }

    // MARK: The editor's controls

    /// The middle of a marked control, or of its right half (where a row's popup button sits).
    private func centre(of target: String, rightPart: Bool = false) -> CGPoint? {
        guard let f = DemoTargets.frame(target) else { return nil }
        return CGPoint(x: rightPart ? f.maxX - 60 : f.midX, y: f.midY)
    }

    private func screenFrame(_ view: NSView) -> CGRect {
        view.window?.convertToScreen(view.convert(view.bounds, to: nil)) ?? .zero
    }

    /// The AppKit control of a kind that overlaps a marked area most: SwiftUI draws its
    /// controls with AppKit ones on the Mac.
    private func control<T: NSView>(_ type: T.Type, in target: String) -> T? {
        guard let area = DemoTargets.frame(target), let root = editorWindow?.contentView else { return nil }
        var best: (control: T, overlap: CGFloat)?
        func visit(_ view: NSView) {
            if let control = view as? T, !view.isHiddenOrHasHiddenAncestor {
                let overlap = screenFrame(view).intersection(area)
                let size = overlap.isNull ? 0 : overlap.width * overlap.height
                if size > (best?.overlap ?? 0) { best = (control, size) }
            }
            view.subviews.forEach(visit)
        }
        visit(root)
        return best?.control
    }

    /// Scrolls the editor so a marked area comes into view near the top, as far as it goes.
    private func scroll(to target: String, margin: CGFloat = 50) async {
        guard let view = DemoTargets.view(target), let scrollView = view.enclosingScrollView else { return }
        let clip = scrollView.contentView
        let rect = clip.convert(view.bounds, from: view)
        let documentHeight = scrollView.documentView?.frame.height ?? 0
        let room = max(0, documentHeight - clip.bounds.height)
        let wanted = clip.isFlipped ? rect.minY - margin : rect.maxY + margin - clip.bounds.height
        let goal = min(max(wanted, 0), room)
        let from = clip.bounds.origin.y
        guard abs(goal - from) > 2 else { return }
        await animate(over: 0.7) { k in
            clip.scroll(to: CGPoint(x: clip.bounds.origin.x, y: from + (goal - from) * k))
            scrollView.reflectScrolledClipView(clip)
        }
        await wait(0.15)
    }

    /// Clicks a segment of a segmented control, then makes the change it stands for.
    private func pick(segment: Int, of target: String, _ change: @escaping (inout CatConfig) -> Void) async {
        guard let control = control(NSSegmentedControl.self, in: target) else { return }
        // In a form the segments share the width equally.
        let f = screenFrame(control)
        await glide(to: CGPoint(x: f.minX + f.width * (CGFloat(segment) + 0.5) / CGFloat(max(1, control.segmentCount)), y: f.midY))
        click()
        editCat(change)
        sparkle()
        await wait(0.7)
    }

    /// Takes hold of a slider's knob and drags it to `value`, the cursor holding on all the way.
    private func drag(slider target: String, to value: Double, set: @escaping (Double) -> Void) async {
        guard let slider = control(NSSlider.self, in: target) else { return }
        let from = slider.doubleValue
        await glide(to: knob(of: slider))
        click()
        await wait(0.1)
        await animate(over: 0.9) { k in
            let v = ((from + (value - from) * Double(k)) * 100).rounded() / 100
            set((v * 10).rounded() / 10)
            slider.doubleValue = v
            if let p = self.knob(of: slider) { self.point(at: p) }
        }
        await wait(0.4)
    }

    private func knob(of slider: NSSlider) -> CGPoint? {
        guard let cell = slider.cell as? NSSliderCell else { return nil }
        let knob = cell.knobRect(flipped: slider.isFlipped)
        let f = slider.window?.convertToScreen(slider.convert(knob, to: nil)) ?? .zero
        return CGPoint(x: f.midX, y: f.midY)
    }

    /// Types into the text field or text view in a marked area, a key at a time.
    private func type(_ text: String, into target: String, replacing: Bool) async {
        guard let window = editorWindow else { return }
        let field: NSView? = control(NSTextView.self, in: target) ?? control(NSTextField.self, in: target)
        guard let field, window.makeFirstResponder(field), let editor = window.firstResponder as? NSTextView else { return }
        if replacing {
            editor.selectAll(nil)
        } else {
            editor.setSelectedRange(NSRange(location: (editor.string as NSString).length, length: 0))
        }
        for (i, character) in text.enumerated() {
            editor.insertText(String(character), replacementRange: editor.selectedRange())
            await wait(Self.keyGaps[i % Self.keyGaps.count] * (character == " " ? 1.4 : 1))
        }
    }

    // MARK: The cat

    private func editCat(_ change: (inout CatConfig) -> Void) {
        guard let store = world?.store, !store.cats.isEmpty else { return }
        change(&store.cats[0])
    }

    private func editBrain(_ change: (inout CatBrain) -> Void) {
        editCat { cat in
            var brain = cat.effectiveBrain
            change(&brain)
            cat.brain = brain
        }
    }

    /// A little burst on the cat, once the world has picked up its new looks.
    private func sparkle() {
        at(0.05) { world in
            guard let cat = world.cats.first else { return }
            world.sparkle(at: CGPoint(x: cat.x, y: cat.y + cat.catHeight / 2), kind: .sparkOrange, count: 8)
        }
    }
}

/// The real cat editor, for the first (and only) cat of the scene.
private struct EditorDemoView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        CatEditor(cat: Binding(
            get: { store.cats.first ?? DemoDirector.editorCat },
            set: { if !store.cats.isEmpty { store.cats[0] = $0 } }
        ))
    }
}
