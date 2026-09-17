import SwiftData
import SwiftUI

struct DashboardView: View {
    let openSearch: () -> Void
    let openLists: () -> Void
    @Environment(CardArtworkStore.self) private var artwork
    @Environment(CardCatalog.self) private var catalog
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CardList.createdAt) private var lists: [CardList]
    @State private var showingThemes = false

    private var wishlist: CardList? { lists.first { $0.builtInKind == .wishlist } }
    private var collection: CardList? { lists.first { $0.builtInKind == .collection } }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Your holoWish")
                            .font(.largeTitle.bold()).foregroundStyle(colors.primaryText)
                        Text("Your collection, wishlist, and Japanese holoCards at a glance.")
                            .foregroundStyle(colors.secondaryText)
                    }

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        if let wishlist {
                            NavigationLink { ListDetailView(list: wishlist) } label: {
                                DashboardButton(title: "Wishlist", subtitle: "\(wishlist.items.count) cards", icon: "heart.fill", color: colors.accent)
                            }
                        }
                        if let collection {
                            NavigationLink { ListDetailView(list: collection) } label: {
                                DashboardButton(title: "Collection", subtitle: "\(collection.items.count) owned", icon: "square.stack.3d.up.fill", color: colors.secondaryAccent)
                            }
                        }
                        Button(action: openSearch) {
                            DashboardButton(title: "Search", subtitle: "Cards & sets", icon: "magnifyingglass", color: colors.accent)
                        }
                        Button(action: openLists) {
                            DashboardButton(title: "My Lists", subtitle: "\(max(0, lists.count - 2)) custom", icon: "list.bullet.rectangle.fill", color: colors.secondaryAccent)
                        }
                    }
                    .buttonStyle(.plain)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Offline artwork", systemImage: "arrow.down.circle.fill")
                                .font(.headline)
                            Spacer()
                            Text("\(artwork.downloadedCount) / \(artwork.totalCount)")
                                .font(.subheadline.monospacedDigit()).foregroundStyle(colors.secondaryText)
                        }
                        ProgressView(value: artwork.progress).tint(colors.accent)
                        HStack {
                            Text(artwork.isDownloading ? "Downloading gently in the background…" : artwork.downloadedCount < artwork.totalCount ? "Artwork download is paused." : "Artwork is available offline.")
                                .font(.caption).foregroundStyle(colors.secondaryText)
                            Spacer()
                            if artwork.downloadedCount < artwork.totalCount {
                                Button(artwork.isDownloading ? "Pause" : "Resume") {
                                    if artwork.isDownloading { artwork.pauseDownloading() }
                                    else { artwork.beginDownloading(catalog.cards) }
                                }
                                .font(.caption.bold())
                            }
                        }
                    }
                    .padding(18)
                    .background(colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .padding()
            }
            .background(colors.background)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingThemes = true } label: { Image(systemName: "paintpalette.fill") }
                        .accessibilityLabel("Choose theme")
                }
            }
            .sheet(isPresented: $showingThemes) { ThemePickerView() }
            .tint(colors.accent)
        }
    }
}

private struct DashboardButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: icon).font(.title).foregroundStyle(colors.background)
                .frame(width: 52, height: 52).background(color, in: RoundedRectangle(cornerRadius: 15))
            Spacer(minLength: 8)
            Text(title).font(.title3.bold()).foregroundStyle(colors.primaryText)
            Text(subtitle).font(.caption).foregroundStyle(colors.secondaryText)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .leading)
        .padding(16)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}
