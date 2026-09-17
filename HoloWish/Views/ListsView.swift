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
        NavigationStack {
            List {
                ForEach(lists) { list in
                    NavigationLink { ListDetailView(list: list) } label: {
                        Label {
                            HStack { Text(list.name); Spacer(); Text(list.items.count.formatted()).foregroundStyle(.secondary) }
                        } icon: {
                            Image(systemName: icon(for: list)).foregroundStyle(colors.accent)
                        }
                    }
                    .swipeActions {
                        if list.builtInKind == nil {
                            Button(role: .destructive) { modelContext.delete(list) } label: { Label("Delete", systemImage: "trash") }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
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
    @Environment(CardCatalog.self) private var catalog
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(CardPriceStore.self) private var prices
    @State private var refreshingPrices = false
    @State private var refreshTask: Task<Void, Never>?

    private var estimatedValue: Decimal {
        visibleItems.reduce(Decimal.zero) { total, pair in
            total + Decimal(prices.estimatedPriceYen(for: pair.1) ?? 0) * Decimal(pair.0.quantity)
        }
    }

    private var valuedQuantity: Int {
        visibleItems.filter { prices.estimatedPriceYen(for: $0.1) != nil }.reduce(0) { $0 + $1.0.quantity }
    }

    private var totalQuantity: Int { list.items.reduce(0) { $0 + $1.quantity } }

    private var visibleItems: [(CardListItem, Card)] {
        list.items.compactMap { item in catalog.cardsByID[item.cardID].map { (item, $0) } }.sorted { $0.1.number.localizedStandardCompare($1.1.number) == .orderedAscending }
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        Group {
            if list.items.isEmpty {
                ContentUnavailableView("No cards yet", systemImage: "rectangle.stack.badge.plus", description: Text("Add cards from the Cards tab."))
            } else {
                List {
                    if list.tracksPurchases { valueSummary }
                    ForEach(visibleItems, id: \.0.id) { item, card in
                        NavigationLink { CardDetailView(card: card) } label: {
                            HStack(spacing: 12) {
                                CachedCardImage(card: card, contentMode: .fill)
                                    .frame(width: 48, height: 67).clipShape(RoundedRectangle(cornerRadius: 5))
                                VStack(alignment: .leading) {
                                    Text(card.name).font(.headline)
                                    Text("\(card.number) · \(card.rarity)").font(.caption).foregroundStyle(.secondary)
                                    if list.tracksPurchases {
                                        if let price = item.purchasePrice {
                                            Text("Paid \(price.formatted(.currency(code: "JPY"))) per copy")
                                                .font(.caption).foregroundStyle(.secondary)
                                        } else {
                                            Text("Purchase price not entered").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                Spacer()
                                if list.tracksPurchases { Text("×\(item.quantity)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary) }
                            }
                        }
                        .swipeActions { Button(role: .destructive) { modelContext.delete(item) } label: { Label("Remove", systemImage: "trash") } }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .background(colors.background)
        .tint(colors.accent)
        .navigationTitle(list.name)
        .task(id: list.items.map(\.cardID).sorted()) {
            guard list.tracksPurchases else { return }
            for (_, card) in visibleItems {
                guard !Task.isCancelled else { return }
                await prices.loadCachedPrice(for: card)
            }
        }
        .onDisappear { refreshTask?.cancel() }
    }

    private var valueSummary: some View {
        Section {
            LabeledContent("Copies", value: totalQuantity.formatted())
            LabeledContent("Total paid") {
                Text(list.totalPaidYen.formatted(.currency(code: "JPY")))
                    .monospacedDigit()
            }
            if list.unpricedQuantity > 0 {
                Text("\(list.unpricedQuantity) copies have no purchase price and are excluded from total paid.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            LabeledContent(valuedQuantity == totalQuantity ? "Estimated shop value" : "Known shop value") {
                if valuedQuantity > 0 {
                    Text(estimatedValue.formatted(.currency(code: "JPY"))).monospacedDigit()
                } else {
                    Text("Not available").foregroundStyle(.secondary)
                }
            }
            Text("Prices available for \(valuedQuantity) of \(totalQuantity) copies. Uses the lowest cached Yuyutei listing matching each card’s number and rarity, including out-of-stock listings. Shop prices are estimates, not resale values.")
                .font(.caption).foregroundStyle(.secondary)
            if let oldest = visibleItems.compactMap({ prices.result(for: $0.1)?.fetchedAt }).min() {
                Text("Oldest lookup: \(oldest.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if visibleItems.contains(where: { prices.error(for: $0.1) != nil }) {
                Text("Some prices could not be refreshed. Any previously saved prices are still included.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Button {
                refreshingPrices = true
                refreshTask = Task { @MainActor in
                    defer { refreshingPrices = false }
                    for (_, card) in visibleItems {
                        guard !Task.isCancelled else { return }
                        await prices.lookup(card, force: true)
                    }
                }
            } label: {
                HStack {
                    Text(refreshingPrices ? "Refreshing prices…" : "Refresh Yuyutei value")
                    if refreshingPrices { Spacer(); ProgressView() }
                }
            }
            .disabled(refreshingPrices)
        } header: {
            Text("Collection worth")
        } footer: {
            Text("Purchase prices and cached shop prices are saved on this device and available offline.")
        }
    }
}
