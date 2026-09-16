import SwiftData
import SwiftUI

@main
struct HoloWishApp: App {
    @State private var catalog = CardCatalog()
    @State private var artwork = CardArtworkStore()
    @State private var prices = CardPriceStore()
    @State private var themeStore = ThemeStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(catalog)
                .environment(artwork)
                .environment(prices)
                .environment(themeStore)
                .task {
                    await catalog.start()
                    artwork.beginDownloading(catalog.cards)
                }
                .onChange(of: scenePhase) { _, phase in
                    if phase == .active {
                        Task {
                            await catalog.checkForUpdates()
                            artwork.beginDownloading(catalog.cards)
                        }
                    }
                }
        }
        .modelContainer(for: [CardList.self, CardListItem.self])
    }
}
