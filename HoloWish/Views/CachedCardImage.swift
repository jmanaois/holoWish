import SwiftUI
import UIKit

struct CachedCardImage: View {
    let card: Card
    var contentMode: ContentMode = .fit
    @Environment(CardArtworkStore.self) private var artwork
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var image: UIImage?

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        Group {
            if let image {
                Image(uiImage: image).resizable().aspectRatio(contentMode: contentMode)
            } else {
                ZStack {
                    colors.surface
                    ProgressView().tint(colors.accent)
                }
            }
        }
        .task(id: card.id) { image = await artwork.image(for: card) }
    }
}

struct CachedSetImage: View {
    let set: CardSetSummary
    @Environment(CardArtworkStore.self) private var artwork
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @State private var image: UIImage?

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                ZStack {
                    colors.surface
                    Image(systemName: "shippingbox.fill").font(.title2).foregroundStyle(colors.secondaryText)
                }
            }
        }
        .task(id: set.id) { image = await artwork.image(for: set) }
    }
}
