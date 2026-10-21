import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSWindowDelegate {
    private let demo = DemoDirector.requested.map(DemoDirector.init)
    lazy var store: SettingsStore = demo?.makeStore() ?? SettingsStore()
    private var world: CatWorld!
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?
    private var palette: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        world = CatWorld(store: store)
        world.contextMenuProvider = { [weak self] cat in
            self?.menu(for: cat, includeCall: false) ?? NSMenu()
        }
        world.onEditModeChange = { [weak self] editing in
            self?.showPalette(editing)
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = CatArt.statusIcon()
        statusItem.button?.toolTip = "Catification"
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        if CommandLine.arguments.contains("--settings") { openSettings() }
        demo?.start(in: world)
    }

    // MARK: - Status menu

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if world.cats.isEmpty {
            let empty = NSMenuItem(title: L("No cats yet"), action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
        for cat in world.cats {
            let item = NSMenuItem(title: "\(cat.config.name) — \(cat.mood.title)", action: nil, keyEquivalent: "")
            item.image = thumbnail(for: cat.config)
            item.submenu = self.menu(for: cat, includeCall: true)
            menu.addItem(item)
        }

        menu.addItem(.separator())
        menu.addItem(ActionItem(L("Add a Cat")) { [weak self] in
            self?.store.addRandomCat()
        })
        menu.addItem(ActionItem(L("Call Everyone Here")) { [weak self] in
            self?.callCatsToStatusItem(nil)
        })

        menu.addItem(.separator())
        let modeItem = NSMenuItem(title: L("Cat World"), action: nil, keyEquivalent: "")
        let modes = NSMenu()
        for mode in WorldMode.allCases {
            let item = ActionItem(mode.title) { [weak self] in self?.store.mode = mode }
            item.state = store.mode == mode ? .on : .off
            modes.addItem(item)
        }
        modeItem.submenu = modes
        menu.addItem(modeItem)

        if world.editMode {
            menu.addItem(ActionItem(L("Finish Arranging")) { [weak self] in self?.world.setEditMode(false) })
        } else {
            menu.addItem(ActionItem(L("Arrange Furniture…")) { [weak self] in self?.startArranging() })
        }
        let laser = ActionItem(L("Laser Pointer")) { [weak self] in
            guard let self else { return }
            self.world.setLaser(!self.world.laserOn)
        }
        laser.state = world.laserOn ? .on : .off
        menu.addItem(laser)
        if store.mode.hasFurniture {
            if world.ball == nil {
                menu.addItem(ActionItem(L("Throw the Yarn Ball")) { [weak self] in self?.world.spawnBall() })
            } else {
                menu.addItem(ActionItem(L("Take the Yarn Ball Away")) { [weak self] in self?.world.removeBall() })
            }
        }
        menu.addItem(ActionItem(L("Release a Butterfly")) { [weak self] in self?.world.releaseButterfly() })
        if world.hasBowl {
            menu.addItem(ActionItem(L("Fill the Bowl")) { [weak self] in self?.world.refillBowls() })
        }
        menu.addItem(.separator())
        let visible = ActionItem(L("Show Cats")) { [weak self] in
            self?.store.catsVisible.toggle()
        }
        visible.state = store.catsVisible ? .on : .off
        menu.addItem(visible)
        menu.addItem(ActionItem(L("Settings…"), key: ",") { [weak self] in
            self?.openSettings()
        })
        menu.addItem(.separator())
        menu.addItem(ActionItem(L("Quit"), key: "q") {
            NSApp.terminate(nil)
        })
    }

    private func menu(for cat: Cat, includeCall: Bool) -> NSMenu {
        let menu = NSMenu()
        let id = cat.id

        for line in [
            cat.config.name,
            String(format: L("Mood: %@"), cat.mood.title),
            String(format: L("Energy: %@   Happiness: %@"), bar(cat.energy), bar(cat.happiness)),
            String(format: L("Personality: %@"), cat.config.personality.title),
        ] {
            let info = NSMenuItem(title: line, action: nil, keyEquivalent: "")
            info.isEnabled = false
            menu.addItem(info)
        }
        menu.addItem(.separator())

        if cat.isAsleep {
            menu.addItem(ActionItem(L("Wake Up")) { [weak cat] in cat?.wakeUp() })
        } else {
            menu.addItem(ActionItem(L("Put to Sleep")) { [weak self, weak cat] in
                guard let self, let cat else { return }
                cat.goToSleep(self.world, here: true)
            })
        }
        if includeCall {
            menu.addItem(ActionItem(L("Call Here")) { [weak self] in
                self?.callCatsToStatusItem(id)
            })
        }
        menu.addItem(ActionItem(L("Customize…")) { [weak self] in
            self?.openSettings(select: id)
        })
        menu.addItem(.separator())
        menu.addItem(ActionItem(L("Let Go (Remove)")) { [weak self] in
            self?.store.remove(id)
        })
        return menu
    }

    private func bar(_ value: Double) -> String {
        let filled = Int((value * 5).rounded())
        return String(repeating: "●", count: filled) + String(repeating: "○", count: 5 - filled)
    }

    private func thumbnail(for config: CatConfig) -> NSImage {
        let image = SpriteSheet.cached(config.appearance).image(.sit, 0, facingRight: true)
        return NSImage(cgImage: image, size: NSSize(width: CatArt.W, height: CatArt.H))
    }

    private func callCatsToStatusItem(_ id: UUID?) {
        guard let frame = statusItem.button?.window?.frame else { return }
        if let id, let cat = world.cats.first(where: { $0.id == id }) {
            cat.call(to: frame.midX - world.geo.frame.minX, world: world)
        } else {
            world.callCats(toScreenX: frame.midX)
        }
    }

    // MARK: - Arranging furniture

    private func startArranging() {
        guard store.mode.hasFurniture else {
            // Furniture only exists in the full-screen modes.
            store.mode = .screen
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                MainActor.assumeIsolated { self?.world.setEditMode(true) }
            }
            return
        }
        world.setEditMode(true)
    }

    private func showPalette(_ show: Bool) {
        guard show else {
            palette?.orderOut(nil)
            return
        }
        if palette == nil {
            let view = EditPaletteView(
                add: { [weak self] kind in self?.world.addFurniture(kind) },
                throwBall: { [weak self] in self?.world.spawnBall() },
                done: { [weak self] in self?.world.setEditMode(false) }
            )
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 560, height: 150),
                styleMask: [.titled, .closable, .utilityWindow, .nonactivatingPanel],
                backing: .buffered, defer: false
            )
            panel.title = L("Arrange Furniture")
            panel.contentViewController = NSHostingController(rootView: view)
            panel.level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
            panel.isFloatingPanel = true
            panel.becomesKeyOnlyIfNeeded = true
            panel.hidesOnDeactivate = false
            panel.isReleasedWhenClosed = false
            panel.delegate = self
            palette = panel
        }
        if let panel = palette, let screen = NSScreen.main {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: screen.frame.midX - size.width / 2, y: screen.visibleFrame.maxY - size.height - 40))
        }
        palette?.orderFrontRegardless()
    }

    func windowWillClose(_ notification: Notification) {
        if (notification.object as? NSPanel) === palette, world.editMode {
            world.setEditMode(false)
        }
    }

    // MARK: - Settings window

    func openSettings(select id: UUID? = nil) {
        if let id { store.selectedCatID = id }
        if settingsWindow == nil {
            let window = NSWindow(contentViewController: NSHostingController(rootView: SettingsView(store: store)))
            window.title = "Catification"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 780, height: 580))
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        if #available(macOS 14, *) {
            NSApp.activate()
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}

/// NSMenuItem that runs a closure.
final class ActionItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(fire), keyEquivalent: key)
        target = self
    }

    required init(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    @objc private func fire() { handler() }
}
