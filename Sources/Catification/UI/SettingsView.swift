import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        TabView {
            CatsTab(store: store)
                .tabItem { Label("Cats", systemImage: "pawprint") }
            GeneralTab(store: store)
                .tabItem { Label("General", systemImage: "gearshape") }
        }
        .padding(12)
        .frame(minWidth: 700, minHeight: 500)
    }
}

// MARK: - Cats

private struct CatsTab: View {
    @ObservedObject var store: SettingsStore

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                List(selection: $store.selectedCatID) {
                    ForEach(store.cats) { cat in
                        HStack(spacing: 8) {
                            CatThumbnail(config: cat)
                                .frame(width: 39, height: 27)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(cat.name)
                                Text(cat.personality.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .tag(cat.id)
                    }
                }
                Divider()
                HStack(spacing: 4) {
                    Button {
                        store.selectedCatID = store.addRandomCat().id
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Add a cat")
                    Button {
                        if let id = store.selectedCatID { store.remove(id) }
                    } label: {
                        Image(systemName: "minus")
                    }
                    .disabled(store.selectedCatID == nil)
                    .help("Let the cat go")
                    Spacer()
                    Button {
                        let imported = CatProfileFiles.pick()
                        store.cats += imported
                        if let last = imported.last { store.selectedCatID = last.id }
                    } label: {
                        Image(systemName: "square.and.arrow.down")
                    }
                    .help("Import cats from .catprofile files")
                }
                .buttonStyle(.borderless)
                .padding(8)
            }
            .frame(width: 210)

            Divider()

            if let id = store.selectedCatID, store.cats.contains(where: { $0.id == id }) {
                CatEditor(cat: binding(for: id))
                    .id(id)
            } else {
                VStack(spacing: 8) {
                    Text("Pick a cat on the left")
                        .foregroundStyle(.secondary)
                    Button("Add a cat") { store.selectedCatID = store.addRandomCat().id }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    /// Looks the cat up by id on every access, so deleting it never leaves a dangling index.
    private func binding(for id: UUID) -> Binding<CatConfig> {
        Binding(
            get: { store.cats.first { $0.id == id } ?? CatConfig.defaults[0] },
            set: { new in
                if let i = store.cats.firstIndex(where: { $0.id == id }) { store.cats[i] = new }
            }
        )
    }
}

private struct CatEditor: View {
    @Binding var cat: CatConfig

    var body: some View {
        Form {
            Section {
                CatPreview(config: cat)
                    .frame(maxWidth: .infinity)
                    .frame(height: 150)
            }

            Section("Cat") {
                TextField("Name", text: $cat.name)
                Picker("Personality", selection: $cat.personality) {
                    ForEach(Personality.allCases) { Text($0.title).tag($0) }
                }
                Text(cat.personality.details)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Picker("Size", selection: $cat.size) {
                    ForEach(CatSize.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            Section("Coat") {
                Menu("Coat presets") {
                    ForEach(CoatPreset.all) { preset in
                        Button(preset.title) { cat.apply(preset) }
                    }
                }
                Picker("Pattern", selection: $cat.pattern) {
                    ForEach(FurPattern.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                ColorPicker("Fur", selection: color($cat.fur), supportsOpacity: false)
                ColorPicker(cat.pattern.secondaryTitle, selection: color($cat.secondary), supportsOpacity: false)
                    .disabled(cat.pattern == .solid)
                ColorPicker(cat.pattern == .calico ? L("Belly, paws and white patches") : L("Belly and paws"),
                            selection: color($cat.belly), supportsOpacity: false)
                ColorPicker("Eyes", selection: color($cat.eyes), supportsOpacity: false)
            }

            CharacterSections(cat: $cat)
        }
        .formStyle(.grouped)
    }

    private func color(_ rgb: Binding<RGB>) -> Binding<Color> {
        Binding(get: { rgb.wrappedValue.color }, set: { rgb.wrappedValue = RGB($0) })
    }
}

// MARK: - General

private struct GeneralTab: View {
    @ObservedObject var store: SettingsStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginError: String?
    @State private var iconsTrusted = DesktopIconTracker.isTrusted

    var body: some View {
        Form {
            Section("World") {
                Picker("Where cats live", selection: $store.mode) {
                    ForEach(WorldMode.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.radioGroup)
                Text(store.mode.details)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Toggle("Walk on top of windows", isOn: $store.walkOnWindows)
                    .disabled(store.mode != .screen)
                Toggle("Cats work out the trajectory before jumping", isOn: $store.jumpMath)
                Toggle("Butterflies", isOn: $store.butterflies)
                Toggle("Climb desktop icons", isOn: $store.climbIcons)
                    .disabled(!store.mode.hasFurniture)
                    .onChange(of: store.climbIcons) { on in
                        if on, !DesktopIconTracker.isTrusted { DesktopIconTracker.requestAccess() }
                        iconsTrusted = DesktopIconTracker.isTrusted
                    }
                if store.climbIcons, !iconsTrusted {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("To see the icons, Catification needs access: System Settings → Privacy & Security → Accessibility. After every rebuild of the app the permission has to be granted again.")
                            .font(.callout)
                            .foregroundStyle(.orange)
                        HStack {
                            Button("Open Accessibility Settings") {
                                NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                            }
                            Button("Check") { iconsTrusted = DesktopIconTracker.isTrusted }
                        }
                    }
                }
                Button("Restore default furniture") { store.resetFurniture() }
                    .disabled(!store.mode.hasFurniture)
            }

            Section("Cats") {
                Toggle("Show cats", isOn: $store.catsVisible)
                Toggle("Mood bubbles", isOn: $store.moodEmotes)
                Picker("Stand out", selection: $store.standout) {
                    ForEach(Standout.allCases) { Text($0.title).tag($0) }
                }
                Text("A light ring or a shadow behind cats and furniture, so they don't get lost on a busy menu bar or a bright wallpaper.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Speed") {
                    Slider(value: $store.speed, in: 0.5...2) {
                        EmptyView()
                    } minimumValueLabel: {
                        Image(systemName: "tortoise")
                    } maximumValueLabel: {
                        Image(systemName: "hare")
                    }
                }
                Toggle("Portals in the middle if the screen has no notch", isOn: $store.virtualNotch)
                Picker("Menu bar ledge", selection: $store.menuBarLedge) {
                    ForEach(MenuBarLedge.allCases) { Text($0.title).tag($0) }
                }
                Text("A line along the bottom of a see-through menu bar, so cats walking there have something to stand on.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("System") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in
                        do {
                            if enabled {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                            loginError = nil
                        } catch {
                            loginError = String(format: L("Didn't work: %@. This only works from the built .app."), error.localizedDescription)
                        }
                    }
                if let loginError {
                    Text(loginError).font(.callout).foregroundStyle(.red)
                }
                Button("Restore default cats") { store.resetCats() }
            }

            Section("How to play") {
                VStack(alignment: .leading, spacing: 6) {
                    Text("🖐  Move the cursor over a cat to pet it. It purrs and hearts fly.")
                    Text("👆  Click: squish! Don't overdo it, the cat may take offence.")
                    Text("✊  Drag a cat to pick it up. You can toss it.")
                    Text("🌀  Cats get past the notch through portals.")
                    Text("📐  Before a big jump a cat works out the trajectory. Sometimes it gets it wrong.")
                    Text("🪑  Arrange furniture from the menu bar icon → “Arrange Furniture…”.")
                    Text("🥣  Click the bowl to fill it. A hungry cat comes to eat on its own.")
                    Text("🧶  Throw the yarn ball with the mouse and the cats will bat it around.")
                    Text("🦋  Cats hunt butterflies and the red dot of the laser pointer.")
                    Text("🗑  Sometimes a cat climbs into the trash can and rummages around.")
                    Text("🖱  Right-click a cat to see its mood and actions.")
                }
                .font(.callout)
            }
        }
        .formStyle(.grouped)
    }
}
