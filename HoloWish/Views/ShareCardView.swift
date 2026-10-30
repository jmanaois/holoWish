import SwiftUI
import UIKit

/// What a shareable poster shows: a binder for one talent, or the wishlist/collection.
struct SharePosterContent: Identifiable {
    let title: String
    let subtitle: String
    let theme: AppTheme
    let cards: [Card]
    /// When set, cards outside this set are drawn as empty binder slots.
    var ownedIDs: Set<Int>?

    var id: String { title }
    static let maxCards = 16
}

/// Toolbar button that opens the share preview for some poster content.
struct SharePosterButton: View {
    let content: () -> SharePosterContent
    @State private var presented: SharePosterContent?

    var body: some View {
        Button { presented = content() } label: {
            Image(systemName: "square.and.arrow.up")
        }
        .accessibilityLabel("Share as image")
        .sheet(item: $presented) { SharePosterSheet(content: $0) }
    }
}

struct SharePosterSheet: View {
    let content: SharePosterContent
    @Environment(CardArtworkStore.self) private var artwork
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var rendered: UIImage?

    var body: some View {
        let colors = content.theme.colors(for: colorScheme)
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if let rendered {
                        Image(uiImage: rendered)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            .shadow(color: colors.accent.opacity(0.3), radius: 18, y: 8)
                            .accessibilityLabel("Preview of \(content.title) image")

                        ShareLink(
                            item: Image(uiImage: rendered),
                            preview: SharePreview(content.title, image: Image(uiImage: rendered))
                        ) {
                            Label("Share Image", systemImage: "square.and.arrow.up")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.borderedProminent)
                        .buttonBorderShape(.capsule)
                        .controlSize(.large)
                    } else {
                        ProgressView("Preparing image…")
                            .frame(maxWidth: .infinity, minHeight: 360)
                    }
                }
                .padding()
            }
            .background(colors.background)
            .navigationTitle("Share")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .tint(colors.accent)
        }
        .presentationBackground(colors.background)
        .task(id: colorScheme) { await render() }
    }

    private func render() async {
        let shown = Array(content.cards.prefix(SharePosterContent.maxCards))
        var images: [Int: UIImage] = [:]
        for card in shown where content.ownedIDs?.contains(card.id) ?? true {
            if let image = await artwork.image(for: card) { images[card.id] = image }
        }
        let renderer = ImageRenderer(content: SharePoster(content: content, shown: shown, images: images)
            .environment(\.colorScheme, colorScheme))
        renderer.scale = 3
        rendered = renderer.uiImage
    }
}

private struct SharePoster: View {
    let content: SharePosterContent
    let shown: [Card]
    let images: [Int: UIImage]
    @Environment(\.colorScheme) private var colorScheme

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 4)

    var body: some View {
        let colors = content.theme.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                TalentPortraitView(theme: content.theme, cornerRadius: 16)
                    .frame(width: 60, height: 60)
                VStack(alignment: .leading, spacing: 3) {
                    Text(content.title)
                        .font(.title3.bold())
                        .foregroundStyle(colors.primaryText)
                        .lineLimit(2)
                    Text(content.subtitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(colors.accent)
                }
            }

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(shown) { card in
                    slot(for: card, colors: colors)
                }
            }

            HStack {
                if content.cards.count > shown.count {
                    Text("+\(content.cards.count - shown.count) more")
                        .font(.caption.bold())
                        .foregroundStyle(colors.secondaryText)
                }
                Spacer()
                Label("holoWish", systemImage: "sparkles")
                    .font(.caption.bold())
                    .foregroundStyle(colors.secondaryText)
            }
        }
        .padding(20)
        .frame(width: 380)
        .background {
            ZStack {
                colors.background
                LinearGradient(
                    colors: [colors.accent.opacity(0.32), colors.secondaryAccent.opacity(0.14), .clear],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    @ViewBuilder private func slot(for card: Card, colors: ThemeColors) -> some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        colors.surface
            .aspectRatio(63.0 / 88.0, contentMode: .fit)
            .overlay {
                if let image = images[card.id] {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Text(card.number.uppercased())
                        .font(.system(size: 8, weight: .semibold, design: .monospaced))
                        .foregroundStyle(colors.secondaryText)
                        .minimumScaleFactor(0.6)
                        .padding(3)
                }
            }
            .clipShape(shape)
        .overlay { shape.stroke(colors.primaryText.opacity(0.12), lineWidth: 0.5) }
    }
}
