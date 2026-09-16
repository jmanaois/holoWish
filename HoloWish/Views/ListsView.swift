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

    private var visibleItems: [(CardListItem, Card)] {
        list.items.compactMap { item in catalog.cardsByID[item.cardID].map { (item, $0) } }.sorted { $0.1.number.localizedStandardCompare($1.1.number) == .orderedAscending }
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        Group {
            if visibleItems.isEmpty {
                ContentUnavailableView("No cards yet", systemImage: "rectangle.stack.badge.plus", description: Text("Add cards from the Cards tab."))
            } else {
                List {
                    ForEach(visibleItems, id: \.0.id) { item, card in
                        NavigationLink { CardDetailView(card: card) } label: {
                            HStack(spacing: 12) {
                                CachedCardImage(card: card, contentMode: .fill)
                                    .frame(width: 48, height: 67).clipShape(RoundedRectangle(cornerRadius: 5))
                                VStack(alignment: .leading) { Text(card.name).font(.headline); Text("\(card.number) · \(card.rarity)").font(.caption).foregroundStyle(.secondary) }
                                Spacer()
                                if list.builtInKind == .collection { Text("×\(item.quantity)").font(.subheadline.monospacedDigit()).foregroundStyle(.secondary) }
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
    }
}
