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
        NavigationStack {
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
                            Image(systemName: icon(for: list)).foregroundStyle(colors.accent)
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
    @Query(sort: \CollectionValueSnapshot.recordedAt) private var allValueSnapshots: [CollectionValueSnapshot]

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
                ContentUnavailableView("No cards yet", systemImage: "rectangle.stack.badge.plus", description: Text("Add cards from the Cards tab."))
                    .foregroundStyle(colors.primaryText)
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
                                    Button(role: .destructive) {
                                        remove(item)
                                    } label: {
                                        Label("Remove from \(list.name)", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }
        }
        .background(colors.background)
        .tint(colors.accent)
        .navigationTitle(list.name)
        .task { ensureValueHistory() }
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
            CardTile(card: card)
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
