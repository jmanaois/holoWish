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
    @Environment(TalentArtworkStore.self) private var artworkStore

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
            } else {
                TalentPortraitView(theme: theme, cornerRadius: 0)
            }
        }
        .task(id: artworkURL) {
            if let artworkURL { await artworkStore.load(artworkURL) }
        }
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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \CardList.createdAt) private var lists: [CardList]
    @State private var selectedArtwork = 0

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
        .task { selectedArtwork = appSettings.homeArtworkIndex(for: theme) }
    }

    private func artworkCarousel(colors: ThemeColors) -> some View {
        let count = max(record?.artworkURLs.count ?? 0, 1)
        return VStack(spacing: 8) {
            TabView(selection: $selectedArtwork) {
                ForEach(0..<count, id: \.self) { index in
                    TalentArtworkView(theme: theme, artworkIndex: index)
                        .padding(.horizontal, 28)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: count > 1 ? .always : .never))
            .frame(height: 390)
            .background(
                LinearGradient(
                    colors: [colors.accent.opacity(0.24), colors.secondaryAccent.opacity(0.12), colors.surface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 28, style: .continuous)
            )
            if count > 1 {
                Text("Look \(selectedArtwork + 1) of \(count)")
                    .font(.caption).foregroundStyle(colors.secondaryText)
            }
        }
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

struct BinderCoverCard: View {
    let list: CardList
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    private var coverTheme: AppTheme? { list.coverTalentName.flatMap(AppTheme.init(rawValue:)) }

    var body: some View {
        let colors = coverTheme?.colors(for: colorScheme) ?? themeStore.colors(for: colorScheme)
        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [colors.accent.opacity(0.85), colors.secondaryAccent.opacity(0.62), colors.surface],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            if let coverTheme {
                TalentArtworkView(theme: coverTheme)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                    .padding(.leading, 44)
            } else {
                Image(systemName: "rectangle.stack.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white.opacity(0.25))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                    .padding()
            }
            LinearGradient(colors: [.clear, .black.opacity(0.74)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 2) {
                Text(list.name).font(.headline.bold()).lineLimit(1)
                Text("\(list.items.count) cards").font(.caption)
            }
            .foregroundStyle(.white)
            .padding(14)
        }
        .frame(width: 190, height: 240)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.18), lineWidth: 1) }
        .shadow(color: .black.opacity(0.18), radius: 12, y: 7)
    }
}

struct TalentCoverPicker: View {
    @Binding var selectedTalentName: String?
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var themes: [AppTheme] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppTheme.allCases.filter {
            query.isEmpty || $0.rawValue.localizedCaseInsensitiveContains(query) || $0.japaneseName.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 96), spacing: 14)], spacing: 16) {
                    Button {
                        selectedTalentName = nil
                        dismiss()
                    } label: {
                        VStack(spacing: 7) {
                            Image(systemName: "rectangle.stack")
                                .font(.largeTitle)
                                .frame(height: 86)
                            Text("No Cover").font(.caption.bold()).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)

                    ForEach(themes) { theme in
                        Button {
                            selectedTalentName = theme.rawValue
                            dismiss()
                        } label: {
                            VStack(spacing: 7) {
                                TalentPortraitView(theme: theme)
                                    .frame(height: 86)
                                    .overlay(alignment: .topTrailing) {
                                        if selectedTalentName == theme.rawValue {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(colors.accent)
                                                .background(.white, in: Circle())
                                                .padding(5)
                                        }
                                    }
                                Text(theme.rawValue).font(.caption.bold()).lineLimit(1)
                            }
                            .foregroundStyle(colors.primaryText)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(colors.background)
            .navigationTitle("Binder Cover")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $searchText, prompt: "Search talents")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .tint(colors.accent)
        }
    }
}
