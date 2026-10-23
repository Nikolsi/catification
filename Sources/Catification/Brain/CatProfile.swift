import AppKit
import UniformTypeIdentifiers

/// A shareable cat: looks, character and the owner's description, as a `.catprofile` JSON file.
struct CatProfile: Codable {
    static let fileExtension = "catprofile"

    var format = "catification.cat"
    var version = 1
    var cat: CatConfig

    init(cat: CatConfig) {
        var cat = cat
        // Write the full character out, so the file still works if presets change later.
        cat.brain = cat.effectiveBrain
        self.cat = cat
    }

    func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    static func decode(_ data: Data) throws -> CatConfig {
        var cat = try JSONDecoder().decode(CatProfile.self, from: data).cat
        cat.id = UUID()  // an imported cat is a new cat, even if it came from this Mac
        return cat
    }
}

@MainActor
enum CatProfileFiles {
    private static var contentType: UTType { UTType(filenameExtension: CatProfile.fileExtension) ?? .json }

    static func export(_ cat: CatConfig) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [contentType]
        panel.nameFieldStringValue = "\(cat.name).\(CatProfile.fileExtension)"
        panel.message = L("Share this cat: anyone with Catification can import the file.")
        activate()
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try CatProfile(cat: cat).encoded().write(to: url, options: .atomic)
        } catch {
            show(error)
        }
    }

    /// Asks for one or more profiles and returns the cats in them.
    static func pick() -> [CatConfig] {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [contentType, .json]
        panel.allowsMultipleSelection = true
        panel.message = L("Choose cat profiles to import.")
        activate()
        guard panel.runModal() == .OK else { return [] }
        var cats: [CatConfig] = []
        for url in panel.urls {
            do {
                cats.append(try CatProfile.decode(Data(contentsOf: url)))
            } catch {
                show(error, file: url.lastPathComponent)
            }
        }
        return cats
    }

    private static func activate() {
        if #available(macOS 14, *) { NSApp.activate() } else { NSApp.activate(ignoringOtherApps: true) }
    }

    private static func show(_ error: Error, file: String? = nil) {
        let alert = NSAlert()
        alert.messageText = file.map { String(format: L("Couldn't read %@"), $0) } ?? L("Couldn't save the cat")
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }
}
