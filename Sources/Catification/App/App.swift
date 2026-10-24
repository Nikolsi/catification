import AppKit

@main
enum CatificationApp {
    @MainActor
    static func main() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--dump-sprites"), args.count > i + 1 {
            SpriteDump.run(to: args[i + 1], only: args.count > i + 2 ? args[i + 2].components(separatedBy: ",") : nil)
            return
        }
        if let i = args.firstIndex(of: "--render-social"), args.count > i + 1 {
            SocialPreviewRenderer.run(to: args[i + 1])
            return
        }
        if let i = args.firstIndex(of: "--render-banner"), args.count > i + 1 {
            BannerRenderer.run(to: args[i + 1])
            return
        }
        if let i = args.firstIndex(of: "--render-icon"), args.count > i + 1 {
            IconRenderer.run(to: args[i + 1])
            return
        }

        if args.contains("--simulate") {
            Simulate.run(args)
            return
        }

        // A repeatable run: the same seed gives the same cats doing the same things (with the same input).
        if let seed = Sim.commandLineSeed { Sim.seed(seed) }

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        // `delegate` stays alive for the lifetime of run(); NSApplication only holds it weakly.
        withExtendedLifetime(delegate) {}
    }
}
