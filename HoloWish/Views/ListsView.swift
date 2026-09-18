import Charts
import SwiftData
import SwiftUI

struct ListsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CardList.createdAt) private var lists: [CardList]
    @State private var showingNewList = false
    @State private var newListName = ""

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        List {
            ForEach(lists) { list in
                NavigationLink { ListDetailView(list: list) } label: {
                    Label {
                        HStack {
                            Text(list.name).foregroundStyle(colors.primaryText)
                            Spacer()
                            Text(list.items.count.formatted()).foregroundStyle(colors.secondaryText)
                        }
                    } icon: {
                        if let theme = list.coverTalentName.flatMap(AppTheme.init(rawValue:)) {
                            TalentPortraitView(theme: theme, cornerRadius: 7)
                                .frame(width: 34, height: 34)
                        } else {
                            Image(systemName: icon(for: list)).foregroundStyle(colors.accent)
                        }
                    }
                }
                .listRowBackground(colors.surface)
                .swipeActions {
                    if list.builtInKind == nil {
                        Button(role: .destructive) { modelContext.delete(list) } label: { Label("Delete", systemImage: "trash") }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .contentMargins(.bottom, 100, for: .scrollContent)
        .background(colors.background)
        .navigationTitle("My Lists")
        .toolbar { Button { showingNewList = true } label: { Image(systemName: "plus") }.accessibilityLabel("New list") }
        .alert("New List", isPresented: $showingNewList) {
            TextField("Trade binder", text: $newListName)
            Button("Cancel", role: .cancel) { newListName = "" }
            Button("Create") { createList() }.disabled(newListName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        } message: { Text("Give your custom card list a name.") }
        .tint(colors.accent)
    }

    private func icon(for list: CardList) -> String {
        switch list.builtInKind { case .wishlist: "heart"; case .collection: "square.stack.3d.up"; case nil: "list.bullet" }
    }

    private func createList() {
        let name = newListName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        modelContext.insert(CardList(name: name)); newListName = ""
    }
}

struct ListDetailView: View {
    let list: CardList
    let titleOverride: String?
    @Environment(CardCatalog.self) private var catalog
    @Environment(ThemeStore.self) private var themeStore
    @Environment(AppSettings.self) private var appSettings
    @Environment(AppNavigation.self) private var navigation
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CollectionValueSnapshot.recordedAt) private var allValueSnapshots: [CollectionValueSnapshot]
    @Query(sort: \CardList.createdAt) private var lists: [CardList]
    @State private var purchaseCard: Card?
    @State private var showingCoverPicker = false

    init(list: CardList, titleOverride: String? = nil) {
        self.list = list
        self.titleOverride = titleOverride
    }

    private var wishlist: CardList? { lists.first { $0.builtInKind == .wishlist } }
    private var collection: CardList? { lists.first { $0.builtInKind == .collection } }
    private var wishlistIDs: Set<Int> { Set(wishlist?.items.map(\.cardID) ?? []) }
    private var collectionIDs: Set<Int> { Set(collection?.items.map(\.cardID) ?? []) }

    private var valueSnapshots: [CollectionValueSnapshot] {
        allValueSnapshots.filter { $0.listID == list.id }
    }

    private var visibleItems: [(CardListItem, Card)] {
        list.items.compactMap { item in catalog.cardsByID[item.cardID].map { (item, $0) } }.sorted { $0.1.number.localizedStandardCompare($1.1.number) == .orderedAscending }
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        Group {
            if list.items.isEmpty {
                ContentUnavailableView {
                    Label(emptyTitle, systemImage: emptySystemImage)
                } description: {
                    Text(emptyDescription)
                } actions: {
                    Button {
                        navigation.selectedTab = .search
                    } label: {
                        Label("Browse Cards", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        if list.tracksPurchases { valueHistory }

                        LazyVGrid(columns: CardGridLayout.columns, spacing: 24) {
                            ForEach(visibleItems, id: \.0.id) { item, card in
                                NavigationLink { CardDetailView(card: card) } label: {
                                    listCard(item: item, card: card)
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    if let wishlist {
                                        let isIncluded = wishlist.contains(cardID: card.id)
                                        Button(role: isIncluded ? .destructive : nil) {
                                            wishlist.toggleMembership(cardID: card.id, in: modelContext)
                                        } label: {
                                            Label(isIncluded ? "Remove from Wishlist" : "Add to Wishlist", systemImage: isIncluded ? "heart.slash" : "heart")
                                        }
                                    }
                                    if let collection {
                                        let isIncluded = collection.contains(cardID: card.id)
                                        Button(role: isIncluded ? .destructive : nil) {
                                            if !isIncluded && appSettings.quickAddBehavior == .askForDetails {
                                                purchaseCard = card
                                            } else {
                                                collection.toggleMembership(cardID: card.id, in: modelContext)
                                            }
                                        } label: {
                                            Label(isIncluded ? "Remove from Collection" : "Add to Collection", systemImage: isIncluded ? "minus.circle" : "plus.circle")
                                        }
                                    }
                                    if list.builtInKind == nil {
                                        Divider()
                                        Button(role: .destructive) {
                                            remove(item)
                                        } label: {
                                            Label("Remove from \(list.name)", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .contentMargins(.bottom, 100, for: .scrollContent)
            }
        }
        .background(colors.background)
        .tint(colors.accent)
        .navigationTitle(titleOverride ?? list.name)
        .toolbar {
            if list.builtInKind == nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCoverPicker = true } label: {
                        Image(systemName: "photo.badge.plus")
                    }
                    .accessibilityLabel("Choose binder cover")
                }
            }
        }
        .task { ensureValueHistory() }
        .sheet(item: $purchaseCard) { card in
            if let collection { PurchaseEditorView(card: card, list: collection) }
        }
        .sheet(isPresented: $showingCoverPicker) {
            TalentCoverPicker(
                selectedTalentName: Binding(
                    get: { list.coverTalentName },
                    set: {
                        list.coverTalentName = $0
                        try? modelContext.save()
                    }
                )
            )
        }
    }

    private var emptyTitle: String {
        switch list.builtInKind {
        case .wishlist: "Your wishlist is empty"
        case .collection: "Your collection is empty"
        case nil: "No cards in this list"
        }
    }

    private var emptySystemImage: String {
        switch list.builtInKind {
        case .wishlist: "heart"
        case .collection: "square.stack.3d.up"
        case nil: "rectangle.stack.badge.plus"
        }
    }

    private var emptyDescription: String {
        switch list.builtInKind {
        case .wishlist: "Save cards you want to find again or collect later."
        case .collection: "Browse the catalog and add your first card."
        case nil: "Browse the catalog to add cards to this list."
        }
    }

    private var valueHistory: some View {
        let colors = themeStore.colors(for: colorScheme)
        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("COLLECTION VALUE")
                        .font(.caption.bold())
                        .foregroundStyle(colors.secondaryText)
                    Text("Based on your saved purchase prices")
                        .font(.caption2)
                        .foregroundStyle(colors.secondaryText)
                }
                Spacer()
                Text(list.totalPaidYen.formatted(.currency(code: "JPY")))
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(colors.primaryText)
            }

            Chart(valueSnapshots) { snapshot in
                AreaMark(
                    x: .value("Date", snapshot.recordedAt),
                    y: .value("Value", snapshot.chartValue)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [colors.accent.opacity(0.28), colors.accent.opacity(0.03)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Date", snapshot.recordedAt),
                    y: .value("Value", snapshot.chartValue)
                )
                .foregroundStyle(colors.accent)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))

                PointMark(
                    x: .value("Date", snapshot.recordedAt),
                    y: .value("Value", snapshot.chartValue)
                )
                .foregroundStyle(colors.accent)
                .symbolSize(24)
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(colors.secondaryText.opacity(0.12))
                    AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        .foregroundStyle(colors.secondaryText)
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 4)) {
                    AxisGridLine().foregroundStyle(colors.secondaryText.opacity(0.12))
                    AxisValueLabel().foregroundStyle(colors.secondaryText)
                }
            }
            .frame(height: 180)

            if list.unpricedQuantity > 0 {
                Label(
                    "Some cards have no purchase price and are excluded from the graph.",
                    systemImage: "info.circle"
                )
                .font(.caption)
                .foregroundStyle(colors.secondaryText)
            }
        }
        .padding(18)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .padding(.horizontal)
    }

    private func listCard(item: CardListItem, card: Card) -> some View {
        let colors = themeStore.colors(for: colorScheme)
        return VStack(alignment: .leading, spacing: 8) {
            CardTile(
                card: card,
                isWishlisted: wishlistIDs.contains(card.id),
                isCollected: collectionIDs.contains(card.id)
            )
            if list.tracksPurchases {
                HStack(spacing: 6) {
                    Text(item.purchasePrice.map { "Paid \($0.formatted(.currency(code: "JPY")))" } ?? "No purchase price")
                    Spacer(minLength: 4)
                    if item.quantity > 1 { Text("×\(item.quantity)") }
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(colors.secondaryText)
                .frame(height: 16)
            }
        }
    }

    private func ensureValueHistory() {
        guard list.tracksPurchases, valueSnapshots.isEmpty else { return }
        modelContext.insert(CollectionValueSnapshot(listID: list.id, totalValue: 0, recordedAt: list.createdAt))
        var runningTotal = Decimal.zero
        for item in list.items.sorted(by: { $0.addedAt < $1.addedAt }) {
            runningTotal += (item.purchasePrice ?? 0) * Decimal(item.quantity)
            modelContext.insert(CollectionValueSnapshot(listID: list.id, totalValue: runningTotal, recordedAt: item.addedAt))
        }
        try? modelContext.save()
    }

    private func remove(_ item: CardListItem) {
        let removedValue = (item.purchasePrice ?? 0) * Decimal(item.quantity)
        let newValue = max(Decimal.zero, list.totalPaidYen - removedValue)
        list.items.removeAll { $0.id == item.id }
        modelContext.delete(item)
        list.recordValue(newValue, in: modelContext)
        try? modelContext.save()
    }
}
