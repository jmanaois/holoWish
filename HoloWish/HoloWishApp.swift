import SwiftData
import SwiftUI

@main
struct HoloWishApp: App {
    private let modelContainer: ModelContainer = {
        let schema = Schema([CardList.self, CardListItem.self, CollectionValueSnapshot.self])
        let configuration = ModelConfiguration(schema: schema, cloudKitDatabase: .none)

        do {
            return try ModelContainer(for: schema, configurations: configuration)
        } catch {
            fatalError("Unable to create the local model container: \(error)")
        }
    }()

    @State private var catalog = CardCatalog()
    @State private var artwork = CardArtworkStore()
    @State private var prices = CardPriceStore()
    @State private var themeStore = ThemeStore()
    @State private var appSettings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(catalog)
                .environment(artwork)
                .environment(prices)
                .environment(themeStore)
                .environment(appSettings)
                .preferredColorScheme(appSettings.appearance.colorScheme)
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
        .modelContainer(modelContainer)
    }
}
