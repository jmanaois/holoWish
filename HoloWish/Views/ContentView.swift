import SwiftData
import SwiftUI

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Query private var lists: [CardList]
    @State private var selectedTab: AppTab = .home

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView()
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)
            BrowseView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppTab.search)
            BuiltInListTabView(kind: .wishlist)
                .tabItem { Label("Wishlist", systemImage: "heart.fill") }
                .tag(AppTab.wishlist)
            BuiltInListTabView(kind: .collection)
                .tabItem { Label("Collection", systemImage: "square.stack.3d.up.fill") }
                .tag(AppTab.collection)
        }
        .tint(themeStore.colors(for: colorScheme).accent)
        .task { seedBuiltInLists() }
    }

    private func seedBuiltInLists() {
        let existing = Set(lists.compactMap(\.builtInKind))
        if !existing.contains(.wishlist) { modelContext.insert(CardList(name: "Wishlist", builtInKind: .wishlist)) }
        if !existing.contains(.collection) { modelContext.insert(CardList(name: "My Collection", builtInKind: .collection)) }
    }
}

private struct BuiltInListTabView: View {
    let kind: BuiltInList
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CardList.createdAt) private var lists: [CardList]

    private var list: CardList? { lists.first { $0.builtInKind == kind } }
    private var title: String { kind == .wishlist ? "Wishlist" : "Collection" }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        NavigationStack {
            if let list {
                ListDetailView(list: list, titleOverride: title)
            } else {
                ProgressView("Preparing \(title.lowercased())…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(colors.background)
                    .navigationTitle(title)
            }
        }
        .tint(colors.accent)
    }
}

private enum AppTab: Hashable { case home, search, wishlist, collection }
