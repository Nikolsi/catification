import AppKit

@main
enum CatificationApp {
    @MainActor
    static func main() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--dump-sprites"), args.count > i + 1 {
            SpriteDump.run(to: args[i + 1])
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

        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        // `delegate` stays alive for the lifetime of run(); NSApplication only holds it weakly.
        withExtendedLifetime(delegate) {}
    }
}
