import SwiftData
import SwiftUI
import UIKit

struct TalentPortraitView: View {
    let theme: AppTheme
    var cornerRadius: CGFloat = 15

    var body: some View {
        Group {
            if let url = Bundle.main.url(
                forResource: theme.portraitFileName,
                withExtension: nil,
                subdirectory: "TalentPortraits"
            ), let image = UIImage(contentsOfFile: url.path) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "person.crop.square.fill")
                    .resizable()
                    .scaledToFit()
                    .padding(12)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.22), lineWidth: 1)
        }
    }
}

struct TalentArtworkView: View {
    let theme: AppTheme
    var artworkIndex = 0
    var contentMode: ContentMode = .fit
    var showsPortraitPlaceholder = true
    @Environment(TalentArtworkStore.self) private var artworkStore
    @State private var displayedImage: UIImage?
    @State private var displayedThemeName = ""

    private var artworkURL: URL? {
        guard let urls = TalentArtworkCatalog.record(for: theme)?.artworkURLs, !urls.isEmpty else { return nil }
        return urls[min(artworkIndex, urls.count - 1)]
    }

    var body: some View {
        Group {
            if let artworkURL, let image = artworkStore.image(for: artworkURL) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else if displayedThemeName == theme.rawValue, let displayedImage {
                Image(uiImage: displayedImage)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                if showsPortraitPlaceholder {
                    TalentPortraitView(theme: theme, cornerRadius: 0)
                } else {
                    ProgressView()
                        .controlSize(.large)
                }
            }
        }
        .task(id: artworkURL) {
            guard let artworkURL else { return }
            if let image = artworkStore.image(for: artworkURL) {
                displayedThemeName = theme.rawValue
                displayedImage = image
                return
            }
            if displayedThemeName != theme.rawValue {
                displayedImage = nil
                displayedThemeName = theme.rawValue
            }
            await artworkStore.load(artworkURL)
            if let image = artworkStore.image(for: artworkURL) {
                displayedImage = image
            }
        }
    }
}

struct AnimatedTalentArtworkView: View {
    let theme: AppTheme
    let artworkIndex: Int
    var transitionDirection: CGFloat = 1
    var contentMode: ContentMode = .fit
    var showsPortraitPlaceholder = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var artworkID: String { "\(theme.rawValue)-\(artworkIndex)" }

    private var artworkTransition: AnyTransition {
        let distance = reduceMotion ? 0 : 46 * transitionDirection
        return .asymmetric(
            insertion: .offset(x: distance).combined(with: .opacity),
            removal: .offset(x: -distance).combined(with: .opacity)
        )
    }

    var body: some View {
        ZStack {
            TalentArtworkView(
                theme: theme,
                artworkIndex: artworkIndex,
                contentMode: contentMode,
                showsPortraitPlaceholder: showsPortraitPlaceholder
            )
            .id(artworkID)
            .transition(artworkTransition)
        }
        .animation(.easeInOut(duration: reduceMotion ? 0.18 : 0.34), value: artworkID)
    }
}

enum TalentCardFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case owned = "Owned"
    case missing = "Missing"
    case wishlist = "Wishlist"
    var id: String { rawValue }
}

struct TalentCardBrowserView: View {
    let theme: AppTheme
    @Environment(CardCatalog.self) private var catalog
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CardList.createdAt) private var lists: [CardList]
    @State private var filter = TalentCardFilter.all

    private var wishlist: CardList? { lists.first { $0.builtInKind == .wishlist } }
    private var collection: CardList? { lists.first { $0.builtInKind == .collection } }
    private var wishlistIDs: Set<Int> { Set(wishlist?.items.map(\.cardID) ?? []) }
    private var collectionIDs: Set<Int> { Set(collection?.items.map(\.cardID) ?? []) }
    private var talentCards: [Card] {
        catalog.cards.filter { $0.belongs(to: theme) }.sorted { $0.number.localizedStandardCompare($1.number) == .orderedAscending }
    }
    private var visibleCards: [Card] {
        switch filter {
        case .all: talentCards
        case .owned: talentCards.filter { collectionIDs.contains($0.id) }
        case .missing: talentCards.filter { !collectionIDs.contains($0.id) }
        case .wishlist: talentCards.filter { wishlistIDs.contains($0.id) }
        }
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                talentHeader(colors: colors)

                Picker("Cards", selection: $filter) {
                    ForEach(TalentCardFilter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)

                if talentCards.isEmpty {
                    ContentUnavailableView(
                        "No cards found",
                        systemImage: "rectangle.stack",
                        description: Text("The current OCG catalog does not have cards matched to \(theme.rawValue) yet.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 280)
                } else if visibleCards.isEmpty {
                    ContentUnavailableView(
                        "Nothing here yet",
                        systemImage: filter == .wishlist ? "heart" : "square.stack.3d.up",
                        description: Text("Try another filter or add a card from the All view.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                } else {
                    LazyVGrid(columns: CardGridLayout.columns, spacing: 24) {
                        ForEach(visibleCards) { card in
                            NavigationLink { CardDetailView(card: card) } label: {
                                CardTile(
                                    card: card,
                                    isWishlisted: wishlistIDs.contains(card.id),
                                    isCollected: collectionIDs.contains(card.id)
                                )
                            }
                            .buttonStyle(.plain)
                            .cardQuickActions(card: card, wishlist: wishlist, collection: collection)
                        }
                    }
                }
            }
            .padding()
        }
        .background(colors.background)
        .navigationTitle(theme.rawValue)
        .navigationBarTitleDisplayMode(.inline)
        .tint(colors.accent)
    }

    private func talentHeader(colors: ThemeColors) -> some View {
        HStack(spacing: 14) {
            TalentPortraitView(theme: theme)
                .frame(width: 72, height: 72)
            VStack(alignment: .leading, spacing: 4) {
                Text(theme.japaneseName)
                    .font(.headline)
                    .foregroundStyle(colors.primaryText)
                Text("\(collectionIDs.intersection(talentCards.map(\.id)).count) of \(talentCards.count) collected")
                    .font(.subheadline)
                    .foregroundStyle(colors.secondaryText)
                ProgressView(value: Double(collectionIDs.intersection(talentCards.map(\.id)).count), total: Double(max(talentCards.count, 1)))
                    .tint(colors.accent)
            }
        }
        .padding(14)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct TalentShowcaseView: View {
    let theme: AppTheme
    @Environment(CardCatalog.self) private var catalog
    @Environment(ThemeStore.self) private var themeStore
    @Environment(AppSettings.self) private var appSettings
    @Environment(TalentArtworkStore.self) private var artworkStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CardList.createdAt) private var lists: [CardList]
    @State private var selectedArtwork = 0
    @State private var artworkTransitionDirection: CGFloat = 1

    private var record: TalentArtworkRecord? { TalentArtworkCatalog.record(for: theme) }
    private var cardCount: Int { catalog.cards.filter { $0.belongs(to: theme) }.count }
    private var collectedCount: Int {
        let cards = Set(catalog.cards.filter { $0.belongs(to: theme) }.map(\.id))
        let owned = Set(lists.first { $0.builtInKind == .collection }?.items.map(\.cardID) ?? [])
        return cards.intersection(owned).count
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    artworkCarousel(colors: colors)

                    VStack(spacing: 5) {
                        Text(theme.rawValue).font(.title.bold()).foregroundStyle(colors.primaryText)
                        Text(theme.japaneseName).font(.headline).foregroundStyle(colors.secondaryText)
                        Text(theme.category.rawValue)
                            .font(.caption.bold()).textCase(.uppercase)
                            .foregroundStyle(colors.secondaryText)
                    }

                    HStack(spacing: 12) {
                        stat(value: cardCount.formatted(), label: "Cards", colors: colors)
                        stat(value: collectedCount.formatted(), label: "Collected", colors: colors)
                        stat(value: (record?.artworkURLs.count ?? 0).formatted(), label: "Looks", colors: colors)
                    }

                    if (record?.artworkURLs.count ?? 0) > 1 {
                        Button {
                            appSettings.setHomeArtworkIndex(selectedArtwork, for: theme)
                        } label: {
                            Label(
                                appSettings.homeArtworkIndex(for: theme) == selectedArtwork
                                    ? "Look \(selectedArtwork + 1) is on Home"
                                    : "Use Look \(selectedArtwork + 1) on Home",
                                systemImage: appSettings.homeArtworkIndex(for: theme) == selectedArtwork
                                    ? "checkmark.circle.fill"
                                    : "house.fill"
                            )
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    NavigationLink {
                        TalentCardBrowserView(theme: theme)
                    } label: {
                        Label("Browse \(theme.rawValue) Cards", systemImage: "rectangle.stack.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 13)
                    }
                    .buttonStyle(.borderedProminent)

                    if let profileURL = record?.profileURL {
                        Link(destination: profileURL) {
                            Label("Official Talent Profile", systemImage: "arrow.up.right.square")
                        }
                        .font(.subheadline.bold())
                    }
                }
                .padding()
            }
            .background(colors.background)
            .navigationTitle("Talent Showcase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .tint(colors.accent)
        }
        .presentationBackground(colors.background)
        .task {
            selectedArtwork = appSettings.homeArtworkIndex(for: theme)
            guard let urls = record?.artworkURLs, !urls.isEmpty else { return }
            let preferredIndex = min(selectedArtwork, urls.count - 1)
            await artworkStore.load(urls[preferredIndex])
            for (index, url) in urls.enumerated() where index != preferredIndex {
                await artworkStore.load(url)
            }
        }
    }

    private func artworkCarousel(colors: ThemeColors) -> some View {
        let count = max(record?.artworkURLs.count ?? 0, 1)
        return VStack(spacing: 8) {
            AnimatedTalentArtworkView(
                theme: theme,
                artworkIndex: selectedArtwork,
                transitionDirection: artworkTransitionDirection,
                showsPortraitPlaceholder: false
            )
            .padding(.horizontal, 28)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard count > 1, abs(value.translation.width) > 36 else { return }
                        moveArtwork(by: value.translation.width < 0 ? 1 : -1, count: count)
                    }
            )
            .frame(maxWidth: .infinity)
            .frame(height: 390)
            .background(
                LinearGradient(
                    colors: [colors.accent.opacity(0.24), colors.secondaryAccent.opacity(0.12), colors.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            if count > 1 {
                HStack(spacing: 18) {
                    Button { moveArtwork(by: -1, count: count) } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Previous outfit")

                    Text("Look \(selectedArtwork + 1) of \(count)")
                        .font(.caption)
                        .foregroundStyle(colors.secondaryText)
                        .contentTransition(.numericText())

                    Button { moveArtwork(by: 1, count: count) } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Next outfit")
                }
                .font(.caption.bold())
            }
        }
    }

    private func moveArtwork(by offset: Int, count: Int) {
        guard count > 1 else { return }
        artworkTransitionDirection = offset < 0 ? -1 : 1
        selectedArtwork = (selectedArtwork + offset + count) % count
    }

    private func stat(value: String, label: String, colors: ThemeColors) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.title3.bold()).foregroundStyle(colors.primaryText)
            Text(label).font(.caption).foregroundStyle(colors.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
