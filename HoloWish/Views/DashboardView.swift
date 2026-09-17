import Charts
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
    @Query(sort: \CollectionValueSnapshot.recordedAt) private var allValueSnapshots: [CollectionValueSnapshot]
    @State private var showingThemes = false

    private var wishlist: CardList? { lists.first { $0.builtInKind == .wishlist } }
    private var collection: CardList? { lists.first { $0.builtInKind == .collection } }
    private var collectionIDs: Set<Int> { Set(collection?.items.map(\.cardID) ?? []) }
    private var collectionQuantity: Int { collection?.items.reduce(0) { $0 + $1.quantity } ?? 0 }
    private var collectionSnapshots: [CollectionValueSnapshot] {
        guard let collection else { return [] }
        return allValueSnapshots.filter { $0.listID == collection.id }
    }
    private var recentCards: [Card] {
        guard let collection else { return [] }
        return collection.items
            .sorted { $0.addedAt > $1.addedAt }
            .prefix(6)
            .compactMap { catalog.cardsByID[$0.cardID] }
    }
    private var closestSet: CardSetSummary? {
        catalog.setSummaries
            .filter { summary in
                let owned = summary.cardIDs.reduce(0) { $0 + (collectionIDs.contains($1) ? 1 : 0) }
                return owned > 0 && owned < summary.cardIDs.count
            }
            .max { lhs, rhs in
                setProgress(lhs) < setProgress(rhs)
            }
    }

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
                                DashboardButton(title: "Collection", subtitle: "\(collectionQuantity) cards", icon: "square.stack.3d.up.fill", color: colors.secondaryAccent)
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

                    if let collection {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Collection Insights")
                                .font(.title2.bold())
                                .foregroundStyle(colors.primaryText)

                            CollectionValueCard(list: collection, snapshots: collectionSnapshots)

                            if let closestSet {
                                NavigationLink { SetDetailView(summary: closestSet) } label: {
                                    ClosestSetCard(
                                        summary: closestSet,
                                        ownedCount: closestSet.cardIDs.reduce(0) { $0 + (collectionIDs.contains($1) ? 1 : 0) }
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !recentCards.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Recently Added")
                                    .font(.title2.bold())
                                    .foregroundStyle(colors.primaryText)
                                Spacer()
                                if let collection {
                                    NavigationLink("View all") { ListDetailView(list: collection) }
                                        .font(.caption.bold())
                                }
                            }
                            ScrollView(.horizontal, showsIndicators: false) {
                                LazyHStack(spacing: 12) {
                                    ForEach(recentCards) { card in
                                        NavigationLink { CardDetailView(card: card) } label: {
                                            RecentCardTile(card: card)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }

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
            .contentMargins(.bottom, 100, for: .scrollContent)
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

    private func setProgress(_ summary: CardSetSummary) -> Double {
        guard !summary.cardIDs.isEmpty else { return 0 }
        let owned = summary.cardIDs.reduce(0) { $0 + (collectionIDs.contains($1) ? 1 : 0) }
        return Double(owned) / Double(summary.cardIDs.count)
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

private struct CollectionValueCard: View {
    let list: CardList
    let snapshots: [CollectionValueSnapshot]
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    private var recentSnapshots: [CollectionValueSnapshot] { Array(snapshots.suffix(20)) }
    private var movement: Decimal {
        guard snapshots.count > 1, let last = snapshots.last else { return 0 }
        return last.totalValue - snapshots[snapshots.count - 2].totalValue
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Label("Tracked purchase value", systemImage: "yensign.circle.fill")
                    .font(.caption.bold())
                    .foregroundStyle(colors.secondaryText)
                Text(list.totalPaidYen.formatted(.currency(code: "JPY")))
                    .font(.title2.bold().monospacedDigit())
                    .foregroundStyle(colors.primaryText)
                if movement != 0 {
                    Label(
                        movement.formatted(.currency(code: "JPY")),
                        systemImage: movement > 0 ? "arrow.up.right" : "arrow.down.right"
                    )
                    .font(.caption.bold().monospacedDigit())
                    .foregroundStyle(movement > 0 ? colors.secondaryAccent : colors.secondaryText)
                } else {
                    Text("Add purchase prices to track movement")
                        .font(.caption)
                        .foregroundStyle(colors.secondaryText)
                }
            }
            Spacer(minLength: 4)
            if recentSnapshots.count > 1 {
                Chart(recentSnapshots) { snapshot in
                    LineMark(
                        x: .value("Date", snapshot.recordedAt),
                        y: .value("Value", snapshot.chartValue)
                    )
                    .foregroundStyle(colors.accent)
                    .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
                    AreaMark(
                        x: .value("Date", snapshot.recordedAt),
                        y: .value("Value", snapshot.chartValue)
                    )
                    .foregroundStyle(colors.accent.opacity(0.12))
                }
                .chartXAxis(.hidden)
                .chartYAxis(.hidden)
                .frame(width: 110, height: 70)
            } else {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.largeTitle)
                    .foregroundStyle(colors.accent.opacity(0.7))
                    .frame(width: 90)
            }
        }
        .padding(18)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct ClosestSetCard: View {
    let summary: CardSetSummary
    let ownedCount: Int
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    private var progress: Double {
        summary.cardIDs.isEmpty ? 0 : Double(ownedCount) / Double(summary.cardIDs.count)
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        HStack(spacing: 14) {
            CachedSetImage(set: summary, contentMode: .fit)
                .frame(width: 104, height: 70)
                .background(colors.background.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 7) {
                Text("CLOSEST TO COMPLETION")
                    .font(.caption2.bold())
                    .foregroundStyle(colors.secondaryText)
                Text(summary.displayName)
                    .font(.headline)
                    .foregroundStyle(colors.primaryText)
                    .lineLimit(1)
                ProgressView(value: progress).tint(colors.accent)
                HStack {
                    Text("\(ownedCount) / \(summary.cardIDs.count)")
                    Spacer()
                    Text(progress.formatted(.percent.precision(.fractionLength(0))))
                }
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(colors.secondaryText)
            }
            Image(systemName: "chevron.right")
                .font(.caption.bold())
                .foregroundStyle(colors.secondaryText)
        }
        .padding(16)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

private struct RecentCardTile: View {
    let card: Card
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: 6) {
            CachedCardImage(card: card, contentMode: .fill)
                .frame(width: 104, height: 146)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            Text(card.displayEnglishName ?? card.name)
                .font(.caption.bold())
                .foregroundStyle(colors.primaryText)
                .lineLimit(1)
            Text(card.number.uppercased())
                .font(.caption2.monospaced())
                .foregroundStyle(colors.secondaryText)
        }
        .frame(width: 104, alignment: .leading)
    }
}
