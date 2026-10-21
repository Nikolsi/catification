import SwiftUI

/// Big animated preview that cycles through what the cat can do.
struct CatPreview: View {
    let config: CatConfig

    private static let script: [(anim: Anim, duration: Double, caption: String)] = [
        (.walk, 2.4, "%@ is strolling"),
        (.sit, 1.8, "%@ is sitting"),
        (.petted, 2.2, "%@ is purring"),
        (.groom, 1.8, "%@ is grooming"),
        (.crouch, 1.2, "%@ is hunting"),
        (.run, 1.8, "%@ has the zoomies"),
        (.sleep, 3.0, "%@ is asleep"),
        (.dangle, 1.6, "%@ is being held"),
    ]
    private static let total = script.reduce(0) { $0 + $1.duration }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1.0 / 12)) { context in
            let (anim, local, caption) = Self.step(at: context.date.timeIntervalSinceReferenceDate)
            let sheet = SpriteSheet.cached(config.appearance)
            let frame = Int(local * anim.fps) % sheet.frameCount(anim)
            VStack(spacing: 6) {
                Image(decorative: sheet.image(anim, frame, facingRight: true), scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: CGFloat(CatArt.W) * 5, height: CGFloat(CatArt.H) * 5)
                Text(String(format: L(caption), config.name))
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private static func step(at time: TimeInterval) -> (Anim, Double, String) {
        var t = time.truncatingRemainder(dividingBy: total)
        for item in script {
            if t < item.duration { return (item.anim, t, item.caption) }
            t -= item.duration
        }
        return (.stand, 0, "")
    }
}

struct CatThumbnail: View {
    let config: CatConfig

    var body: some View {
        Image(decorative: SpriteSheet.cached(config.appearance).image(.sit, 0, facingRight: true), scale: 1)
            .interpolation(.none)
            .resizable()
            .aspectRatio(contentMode: .fit)
    }
}
