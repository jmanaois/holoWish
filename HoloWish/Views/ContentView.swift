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
            DashboardView(openSearch: { selectedTab = .search }, openLists: { selectedTab = .lists })
                .tabItem { Label("Home", systemImage: "house.fill") }
                .tag(AppTab.home)
            BrowseView()
                .tabItem { Label("Search", systemImage: "magnifyingglass") }
                .tag(AppTab.search)
            ListsView()
                .tabItem { Label("My Lists", systemImage: "heart.text.square") }
                .tag(AppTab.lists)
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

private enum AppTab: Hashable { case home, search, lists }
