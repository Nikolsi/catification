import AppKit

/// `Catification --simulate [hours] [--seed N] [cat.catprofile …]`: runs a world without showing it,
/// faster than real time, and prints what every cat did. Without profiles, one cat per personality.
@MainActor
enum Simulate {
    static func run(_ args: [String]) {
        var hours = 8.0
        if let i = args.firstIndex(of: "--simulate"), args.count > i + 1, let h = Double(args[i + 1]) { hours = h }
        var cats: [CatConfig] = []
        for path in args where path.hasSuffix(".\(CatProfile.fileExtension)") {
            do {
                cats.append(try CatProfile.decode(Data(contentsOf: URL(fileURLWithPath: path))))
            } catch {
                FileHandle.standardError.write("Couldn't read \(path): \(error.localizedDescription)\n".data(using: .utf8)!)
            }
        }
        if cats.isEmpty {
            let coats: [CoatPreset] = [.ginger, .tuxedo, .siamese, .gray, .calico, .white]
            for (personality, coat) in zip(Personality.allCases, coats) {
                cats.append(CatConfig(name: personality.rawValue.capitalized, coat: coat, personality: personality))
            }
        }

        let world = World(seed: Sim.commandLineSeed ?? 1)
        for cat in cats { world.spawn(character: cat) }
        let began = Date()
        world.run(for: hours * 3600)
        print(world.report.text)
        print(String(format: "(%.1f s)", Date().timeIntervalSince(began)))
    }
}
