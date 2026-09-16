import SwiftData
import SwiftUI

struct BrowseView: View {
    @Environment(CardCatalog.self) private var catalog
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Query private var lists: [CardList]
    @State private var searchText = ""
    @State private var filters = CardFilters()
    @State private var showingFilters = false
    @State private var visibleLimit = 40

    private let columns = [GridItem(.adaptive(minimum: 156), spacing: 16)]
    private let setColumns = [GridItem(.adaptive(minimum: 108, maximum: 180), spacing: 8)]

    private var collectionIDs: Set<Int> {
        Set(lists.first { $0.builtInKind == .collection }?.items.map(\.cardID) ?? [])
    }

    private var normalizedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }

    private var filteredCards: [Card] {
        let query = normalizedQuery
        return catalog.cards.filter { card in
            (query.isEmpty || catalog.searchIndex[card.id, default: ""].contains(query)) &&
            (filters.rarity.isEmpty || card.rarity == filters.rarity) &&
            (filters.type.isEmpty || card.type == filters.type) &&
            (filters.color.isEmpty || card.allColors.contains(filters.color)) &&
            (filters.bloomLevel.isEmpty || card.bloomLevel == filters.bloomLevel) &&
            (filters.set.isEmpty || card.allSets.contains(filters.set)) &&
            (!filters.parallelsOnly || card.parallel)
        }
    }

    private var matchingSets: [CardSetSummary] {
        guard !normalizedQuery.isEmpty else { return [] }
        return catalog.setSummaries.filter { $0.searchableText.contains(normalizedQuery) }
    }

    private var setSections: [SetSection] { sections(for: catalog.setSummaries) }

    private func sections(for sets: [CardSetSummary]) -> [SetSection] {
        CardSetGroup.allCases.compactMap { group in
            let matching = sets.filter { $0.group == group }
            return matching.isEmpty ? nil : SetSection(group: group, sets: matching)
        }
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        NavigationStack {
            Group {
                if catalog.isLoading && catalog.cards.isEmpty {
                    ProgressView("Loading Japanese card catalog…")
                } else if let message = catalog.errorMessage {
                    ContentUnavailableView("Catalog unavailable", systemImage: "exclamationmark.triangle", description: Text(message))
                } else if normalizedQuery.isEmpty && !filters.isActive {
                    setBrowser
                } else {
                    searchResults
                }
            }
            .background(colors.background)
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "English/Japanese card or set name")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { Task { await catalog.checkForUpdates(force: true) } } label: {
                        if catalog.isCheckingForUpdates { ProgressView() }
                        else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(catalog.isCheckingForUpdates)
                    .accessibilityLabel("Update card catalog")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingFilters = true } label: {
                        Image(systemName: filters.isActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    }
                    .accessibilityLabel("Filters")
                }
            }
            .sheet(isPresented: $showingFilters) { FilterSheet(filters: $filters).environment(catalog) }
            .onChange(of: searchText) { _, _ in visibleLimit = 40 }
            .onChange(of: filters) { _, _ in visibleLimit = 40 }
            .alert("Card Catalog", isPresented: updateAlertBinding) {
                Button("OK") { catalog.dismissUpdateMessage() }
            } message: { Text(catalog.updateMessage ?? "") }
            .tint(colors.accent)
        }
    }

    private var setBrowser: some View {
        let colors = themeStore.colors(for: colorScheme)
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Browse Sets")
                        .font(.title2.bold()).foregroundStyle(colors.primaryText)
                    Text("Grouped by product type, newest first.")
                        .font(.subheadline).foregroundStyle(colors.secondaryText)
                }
                .padding(.horizontal)

                ForEach(setSections) { section in
                    VStack(alignment: .leading, spacing: 10) {
                        SetSectionHeader(section: section)
                        LazyVGrid(columns: setColumns, spacing: 8) {
                            ForEach(section.sets) { summary in
                                NavigationLink { SetDetailView(summary: summary) } label: {
                                    SetTile(summary: summary, collectionIDs: collectionIDs)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(colors.background)
    }

    private var searchResults: some View {
        let cards = filteredCards
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                if !matchingSets.isEmpty {
                    Text("Matching Sets").font(.headline).padding(.horizontal)
                    ForEach(sections(for: matchingSets)) { section in
                        VStack(alignment: .leading, spacing: 10) {
                            SetSectionHeader(section: section)
                            LazyVGrid(columns: setColumns, spacing: 8) {
                                ForEach(section.sets) { summary in
                                    NavigationLink { SetDetailView(summary: summary) } label: {
                                        SetTile(summary: summary, collectionIDs: collectionIDs)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 12)
                        }
                    }
                }

                HStack {
                    Text("Cards").font(.headline)
                    Spacer()
                    Text("\(cards.count.formatted()) results").font(.caption).foregroundStyle(.secondary)
                    if filters.isActive { Button("Clear filters") { filters.clear() }.font(.caption.bold()) }
                }
                .padding(.horizontal)

                if cards.isEmpty {
                    ContentUnavailableView.search(text: searchText).frame(maxWidth: .infinity).padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(cards.prefix(visibleLimit)) { card in
                            NavigationLink { CardDetailView(card: card) } label: { CardTile(card: card) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal)
                    if visibleLimit < cards.count {
                        Button("Show more cards") { visibleLimit += 40 }
                            .fontWeight(.semibold).frame(maxWidth: .infinity).padding(.vertical, 12)
                            .buttonStyle(.bordered).padding(.horizontal)
                    }
                }
            }
            .padding(.vertical)
        }
    }

    private var updateAlertBinding: Binding<Bool> {
        Binding(get: { catalog.updateMessage != nil }, set: { if !$0 { catalog.dismissUpdateMessage() } })
    }
}

private struct SetSection: Identifiable {
    let group: CardSetGroup
    let sets: [CardSetSummary]
    var id: CardSetGroup { group }
}

private struct SetSectionHeader: View {
    let section: SetSection
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        HStack(spacing: 8) {
            Label(section.group.title, systemImage: section.group.systemImage)
                .font(.headline)
                .foregroundStyle(colors.primaryText)
            Spacer()
            Text(section.sets.count.formatted())
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(colors.secondaryText)
        }
        .padding(.horizontal)
    }
}

private struct SetTile: View {
    let summary: CardSetSummary
    let collectionIDs: Set<Int>
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

    private var ownedCount: Int { summary.cardIDs.reduce(0) { $0 + (collectionIDs.contains($1) ? 1 : 0) } }
    private var progress: Double { summary.cardIDs.isEmpty ? 0 : Double(ownedCount) / Double(summary.cardIDs.count) }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: 0) {
            CachedSetImage(set: summary)
                .aspectRatio(506 / 314, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
            VStack(alignment: .leading, spacing: 5) {
                Text(summary.displayName)
                    .font(.caption2.bold())
                    .foregroundStyle(colors.primaryText)
                    .lineLimit(2)
                    .frame(height: 30, alignment: .topLeading)
                ProgressView(value: progress).tint(colors.accent)
                Text("\(ownedCount) / \(summary.cardIDs.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(colors.secondaryText)
            }
            .padding(8)
        }
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct SetDetailView: View {
    let summary: CardSetSummary
    @Environment(CardCatalog.self) private var catalog
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Query private var lists: [CardList]
    private let columns = [GridItem(.adaptive(minimum: 156), spacing: 16)]

    private var cards: [Card] {
        summary.cardIDs.compactMap { catalog.cardsByID[$0] }
            .sorted { $0.number.localizedStandardCompare($1.number) == .orderedAscending }
    }
    private var collectionIDs: Set<Int> {
        Set(lists.first { $0.builtInKind == .collection }?.items.map(\.cardID) ?? [])
    }
    private var ownedCount: Int { summary.cardIDs.reduce(0) { $0 + (collectionIDs.contains($1) ? 1 : 0) } }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if summary.productImage != nil {
                    CachedSetImage(set: summary)
                        .aspectRatio(506 / 314, contentMode: .fit)
                        .frame(maxWidth: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Label(summary.group.title, systemImage: summary.group.systemImage)
                        .font(.caption.bold())
                        .foregroundStyle(colors.accent)
                    if let englishName = summary.englishName, !englishName.isEmpty {
                        Text(englishName).font(.title2.bold()).foregroundStyle(colors.primaryText)
                        Text(summary.name).font(.subheadline).foregroundStyle(colors.secondaryText)
                    } else {
                        Text(summary.name).font(.title2.bold()).foregroundStyle(colors.primaryText)
                    }
                    ProgressView(value: Double(ownedCount), total: Double(max(1, summary.cardIDs.count))).tint(colors.accent)
                    Text("\(ownedCount) of \(summary.cardIDs.count) collected")
                        .font(.subheadline.monospacedDigit()).foregroundStyle(colors.secondaryText)
                }
                .padding(.horizontal)

                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(cards) { card in
                        NavigationLink { CardDetailView(card: card) } label: { CardTile(card: card) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(colors.background)
        .tint(colors.accent)
        .navigationTitle(summary.displayName)
        .navigationBarTitleDisplayMode(.inline)
    }
}
