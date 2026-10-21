import AppKit
import SwiftUI

/// Floating toolbar shown while arranging furniture.
struct EditPaletteView: View {
    let add: (FurnitureKind) -> Void
    let throwBall: () -> Void
    let done: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ForEach(FurnitureKind.allCases) { kind in
                    tile(kind.title, image: Self.preview(kind)) { add(kind) }
                }
                tile(L("Yarn"), image: PropArt.yarn(frame: 0).image) { throwBall() }
            }
            Text("Drag things around with the mouse. The ends of a shelf change its width, the top of the scratching post its height. Right-click to delete.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                Button("Done", action: done)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(14)
        .frame(width: 560)
    }

    private func tile(_ title: String, image: CGImage, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(decorative: image, scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 44, height: 34)
                Text(title).font(.caption)
            }
            .frame(width: 70, height: 60)
        }
        .buttonStyle(.bordered)
    }

    private static func preview(_ kind: FurnitureKind) -> CGImage {
        switch kind {
        case .shelf: PropArt.shelf(width: 22).image
        case .post: PropArt.post(height: 26).image
        case .bed: PropArt.bed(front: false).image
        case .bowl: PropArt.bowl(food: 2).image
        case .trash: PropArt.trash(front: false).image
        }
    }
}
