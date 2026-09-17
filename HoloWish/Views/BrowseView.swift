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
    @AppStorage("search.recentQueries") private var recentSearchesStorage = "[]"

    private let columns = CardGridLayout.columns
    private let setColumns = [GridItem(.adaptive(minimum: 108, maximum: 156), spacing: 8, alignment: .top)]

    private var wishlist: CardList? { lists.first { $0.builtInKind == .wishlist } }
    private var collection: CardList? { lists.first { $0.builtInKind == .collection } }
    private var wishlistIDs: Set<Int> { Set(wishlist?.items.map(\.cardID) ?? []) }
    private var collectionIDs: Set<Int> {
        Set(collection?.items.map(\.cardID) ?? [])
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
    private var recentSearches: [String] {
        guard let data = recentSearchesStorage.data(using: .utf8),
              let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return values
    }

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
                    ContentUnavailableView {
                        Label("Catalog unavailable", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(message)
                    } actions: {
                        Button("Try Again") {
                            Task {
                                await catalog.load()
                                await catalog.checkForUpdates(force: true)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else if normalizedQuery.isEmpty && !filters.isActive {
                    setBrowser
                } else {
                    searchResults
                }
            }
            .background(colors.background)
            .navigationTitle("Search")
            .searchable(text: $searchText, prompt: "English/Japanese card or set name")
            .onSubmit(of: .search) { rememberSearch(searchText) }
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
                searchShortcuts

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
                                .buttonStyle(CardPressButtonStyle())
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                }
            }
            .padding(.vertical)
        }
        .background(colors.background)
        .contentMargins(.bottom, 100, for: .scrollContent)
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
                                    .buttonStyle(CardPressButtonStyle())
                                    .simultaneousGesture(TapGesture().onEnded { rememberSearch(searchText) })
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
                    ContentUnavailableView {
                        Label("No matching cards", systemImage: "rectangle.stack.badge.magnifyingglass")
                    } description: {
                        Text("Try a different name or remove some filters.")
                    } actions: {
                        HStack {
                            if !normalizedQuery.isEmpty {
                                Button("Clear Search") { searchText = "" }
                            }
                            if filters.isActive {
                                Button("Clear Filters") { filters.clear() }
                            }
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(cards.prefix(visibleLimit)) { card in
                            NavigationLink { CardDetailView(card: card) } label: {
                                CardTile(
                                    card: card,
                                    isWishlisted: wishlistIDs.contains(card.id),
                                    isCollected: collectionIDs.contains(card.id)
                                )
                            }
                                .buttonStyle(CardPressButtonStyle())
                                .cardQuickActions(card: card, wishlist: wishlist, collection: collection)
                                .simultaneousGesture(TapGesture().onEnded { rememberSearch(searchText) })
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
        .contentMargins(.bottom, 100, for: .scrollContent)
    }

    private var updateAlertBinding: Binding<Bool> {
        Binding(get: { catalog.updateMessage != nil }, set: { if !$0 { catalog.dismissUpdateMessage() } })
    }

    private var searchShortcuts: some View {
        let colors = themeStore.colors(for: colorScheme)
        return VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Quick Filters")
                    .font(.headline)
                    .foregroundStyle(colors.primaryText)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        quickFilterButton("Oshi", systemImage: "star.fill", filter: .oshi)
                        quickFilterButton("Members", systemImage: "person.2.fill", filter: .members)
                        quickFilterButton("Super Rare", systemImage: "sparkles", filter: .superRare)
                        quickFilterButton("Parallel", systemImage: "square.2.layers.3d", filter: .parallel)
                        if catalog.setSummaries.first != nil {
                            quickFilterButton("Newest Set", systemImage: "clock.badge", filter: .newestSet)
                        }
                    }
                    .padding(.horizontal)
                }
                .contentMargins(.horizontal, -16, for: .scrollContent)
            }

            if !recentSearches.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Recent Searches")
                            .font(.headline)
                            .foregroundStyle(colors.primaryText)
                        Spacer()
                        Button("Clear") { recentSearchesStorage = "[]" }
                            .font(.caption.bold())
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(recentSearches, id: \.self) { query in
                                Button {
                                    searchText = query
                                    rememberSearch(query)
                                } label: {
                                    Label(query, systemImage: "clock.arrow.circlepath")
                                        .font(.caption.bold())
                                        .padding(.horizontal, 11)
                                        .padding(.vertical, 8)
                                        .background(colors.surface, in: Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .contentMargins(.horizontal, -16, for: .scrollContent)
                }
            }
        }
        .padding(.horizontal)
    }

    private func quickFilterButton(_ title: String, systemImage: String, filter: BrowseQuickFilter) -> some View {
        let colors = themeStore.colors(for: colorScheme)
        return Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                searchText = ""
                filters.clear()
                switch filter {
                case .oshi: filters.type = "推しホロメン"
                case .members: filters.type = "ホロメン"
                case .superRare: filters.rarity = "SR"
                case .parallel: filters.parallelsOnly = true
                case .newestSet: filters.set = catalog.setSummaries.first?.name ?? ""
                }
            }
        } label: {
            Label(title, systemImage: systemImage)
                .font(.caption.bold())
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .foregroundStyle(colors.accent)
                .background(colors.surface, in: Capsule())
                .overlay { Capsule().stroke(colors.accent.opacity(0.25), lineWidth: 1) }
        }
        .buttonStyle(CardPressButtonStyle())
    }

    private func rememberSearch(_ value: String) {
        let query = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return }
        var values = recentSearches.filter { $0.localizedCaseInsensitiveCompare(query) != .orderedSame }
        values.insert(query, at: 0)
        values = Array(values.prefix(6))
        guard let data = try? JSONEncoder().encode(values),
              let encoded = String(data: data, encoding: .utf8) else { return }
        recentSearchesStorage = encoded
    }
}

private enum BrowseQuickFilter { case oshi, members, superRare, parallel, newestSet }

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
            ZStack {
                colors.background.opacity(0.55)
                CachedSetImage(set: summary, contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(6)
            }
            .aspectRatio(506 / 314, contentMode: .fit)
            .clipped()
            VStack(alignment: .leading, spacing: 5) {
                Text(summary.displayName)
                    .font(.caption2.bold())
                    .foregroundStyle(colors.primaryText)
                    .lineLimit(2)
                    .frame(height: 30, alignment: .topLeading)
                ProgressView(value: progress)
                    .tint(progress >= 1 ? colors.secondaryAccent : colors.accent)
                    .scaleEffect(x: 1, y: 1.25)
                    .animation(.easeInOut(duration: 0.3), value: progress)
                HStack(spacing: 4) {
                    Text("\(ownedCount) / \(summary.cardIDs.count)")
                    Spacer(minLength: 2)
                    Text(progress.formatted(.percent.precision(.fractionLength(0))))
                    if progress >= 1 { Image(systemName: "checkmark.seal.fill") }
                }
                .font(.caption2.bold().monospacedDigit())
                .foregroundStyle(progress >= 1 ? colors.secondaryAccent : colors.secondaryText)
            }
            .padding(8)
        }
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(summary.displayName)
        .accessibilityValue("\(ownedCount) of \(summary.cardIDs.count) cards collected")
    }
}

struct SetDetailView: View {
    let summary: CardSetSummary
    @Environment(CardCatalog.self) private var catalog
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Query private var lists: [CardList]
    @State private var searchText = ""
    @State private var filters = CardFilters()
    @State private var showingFilters = false
    @State private var sortOrder = SetCardSort.cardNumber
    @State private var sortAscending = true
    private let columns = CardGridLayout.columns

    private var wishlist: CardList? { lists.first { $0.builtInKind == .wishlist } }
    private var collection: CardList? { lists.first { $0.builtInKind == .collection } }
    private var wishlistIDs: Set<Int> { Set(wishlist?.items.map(\.cardID) ?? []) }
    private var allCards: [Card] { summary.cardIDs.compactMap { catalog.cardsByID[$0] } }
    private var normalizedQuery: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines).localizedLowercase
    }
    private var filtersActive: Bool {
        !filters.rarity.isEmpty || !filters.type.isEmpty || !filters.color.isEmpty ||
        !filters.bloomLevel.isEmpty || filters.parallelsOnly
    }
    private var cards: [Card] {
        allCards.filter { card in
            (normalizedQuery.isEmpty || catalog.searchIndex[card.id, default: card.searchableText].contains(normalizedQuery)) &&
            (filters.rarity.isEmpty || card.rarity == filters.rarity) &&
            (filters.type.isEmpty || card.type == filters.type) &&
            (filters.color.isEmpty || card.allColors.contains(filters.color)) &&
            (filters.bloomLevel.isEmpty || card.bloomLevel == filters.bloomLevel) &&
            (!filters.parallelsOnly || card.parallel)
        }.sorted(by: cardSort)
    }
    private var collectionIDs: Set<Int> {
        Set(collection?.items.map(\.cardID) ?? [])
    }
    private var ownedCount: Int { summary.cardIDs.reduce(0) { $0 + (collectionIDs.contains($1) ? 1 : 0) } }
    private var progress: Double { summary.cardIDs.isEmpty ? 0 : Double(ownedCount) / Double(summary.cardIDs.count) }
    private var activeFilterCount: Int {
        [filters.rarity, filters.type, filters.color, filters.bloomLevel].filter { !$0.isEmpty }.count
            + (filters.parallelsOnly ? 1 : 0)
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if summary.productImage != nil {
                    ZStack {
                        colors.surface
                        CachedSetImage(set: summary, contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(10)
                    }
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
                        Text(summary.displayName).font(.title2.bold()).foregroundStyle(colors.primaryText)
                        Text(summary.name).font(.subheadline).foregroundStyle(colors.secondaryText)
                    } else {
                        Text(summary.name).font(.title2.bold()).foregroundStyle(colors.primaryText)
                    }
                    ProgressView(value: progress)
                        .tint(progress >= 1 ? colors.secondaryAccent : colors.accent)
                        .scaleEffect(x: 1, y: 1.5)
                    HStack {
                        Text("\(ownedCount) of \(summary.cardIDs.count) collected")
                        Spacer()
                        if progress >= 1 {
                            Label("Complete", systemImage: "checkmark.seal.fill")
                                .foregroundStyle(colors.secondaryAccent)
                        } else {
                            Text(progress.formatted(.percent.precision(.fractionLength(0))))
                        }
                    }
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(colors.secondaryText)
                }
                .padding(.horizontal)

                if cards.isEmpty {
                    ContentUnavailableView(
                        "No matching cards",
                        systemImage: "rectangle.stack.badge.magnifyingglass",
                        description: Text("Try another name or clear the active filters.")
                    )
                    Button("Clear Search & Filters") {
                        searchText = ""
                        filters.clear()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 36)
                } else {
                    LazyVGrid(columns: columns, spacing: 24) {
                        ForEach(cards) { card in
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
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
        .contentMargins(.bottom, 100, for: .scrollContent)
        .background(colors.background)
        .tint(colors.accent)
        .navigationTitle(summary.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search this set")
        .safeAreaInset(edge: .top, spacing: 0) {
            setControlBar
        }
        .sheet(isPresented: $showingFilters) {
            FilterSheet(filters: $filters, availableCards: allCards, showsSetPicker: false)
                .environment(catalog)
        }
    }

    private var setControlBar: some View {
        let colors = themeStore.colors(for: colorScheme)
        return HStack(spacing: 12) {
            Text(filtersActive || !normalizedQuery.isEmpty ? "\(cards.count) of \(allCards.count)" : "\(allCards.count) cards")
                .font(.caption.bold().monospacedDigit())
                .foregroundStyle(colors.secondaryText)
            Spacer()
            if filtersActive || !normalizedQuery.isEmpty {
                Button("Clear") { searchText = ""; filters.clear() }
                    .font(.caption.bold())
            }
            Menu {
                Picker("Sort by", selection: $sortOrder) {
                    ForEach(SetCardSort.allCases) { option in
                        Label(option.title, systemImage: option.systemImage).tag(option)
                    }
                }
                Divider()
                Button { sortAscending.toggle() } label: {
                    Label(sortAscending ? "Ascending" : "Descending", systemImage: sortAscending ? "arrow.up" : "arrow.down")
                }
            } label: {
                Label(sortOrder.title, systemImage: sortAscending ? "arrow.up" : "arrow.down")
                    .font(.caption.bold())
            }
            Button { showingFilters = true } label: {
                HStack(spacing: 4) {
                    Image(systemName: filtersActive ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    if activeFilterCount > 0 { Text(activeFilterCount.formatted()) }
                }
                .font(.subheadline.bold())
            }
            .accessibilityLabel(activeFilterCount > 0 ? "Filters, \(activeFilterCount) active" : "Filters")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) { Divider().opacity(0.35) }
    }

    private func cardSort(_ lhs: Card, _ rhs: Card) -> Bool {
        let comparison = sortOrder.compare(lhs, rhs)
        if comparison == .orderedSame {
            return lhs.number.localizedStandardCompare(rhs.number) == .orderedAscending
        }
        return sortAscending ? comparison == .orderedAscending : comparison == .orderedDescending
    }
}

private enum SetCardSort: String, CaseIterable, Identifiable {
    case cardNumber
    case name
    case rarity
    case cardType
    case color

    var id: String { rawValue }
    var title: String {
        switch self {
        case .cardNumber: "Card Number"
        case .name: "Name"
        case .rarity: "Rarity"
        case .cardType: "Card Type"
        case .color: "Color"
        }
    }
    var systemImage: String {
        switch self {
        case .cardNumber: "number"
        case .name: "textformat"
        case .rarity: "sparkles"
        case .cardType: "rectangle.stack"
        case .color: "paintpalette"
        }
    }

    func compare(_ lhs: Card, _ rhs: Card) -> ComparisonResult {
        let left: String
        let right: String
        switch self {
        case .cardNumber:
            left = lhs.number; right = rhs.number
        case .name:
            left = lhs.displayEnglishName ?? lhs.name; right = rhs.displayEnglishName ?? rhs.name
        case .rarity:
            let leftPriority = Self.rarityPriority(lhs.rarity)
            let rightPriority = Self.rarityPriority(rhs.rarity)
            if leftPriority != rightPriority {
                return leftPriority < rightPriority ? .orderedAscending : .orderedDescending
            }
            left = lhs.rarity; right = rhs.rarity
        case .cardType:
            left = lhs.type; right = rhs.type
        case .color:
            left = lhs.color; right = rhs.color
        }
        return left.localizedStandardCompare(right)
    }

    private static func rarityPriority(_ rarity: String) -> Int {
        switch rarity.uppercased() {
        case "SEC": 0
        case "OUR": 1
        case "UR": 2
        case "OSR": 3
        case "SR": 4
        default: 5
        }
    }
}
