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
    @State private var talentArtwork = TalentArtworkStore()
    @State private var prices = CardPriceStore()
    @State private var themeStore = ThemeStore()
    @State private var appSettings = AppSettings()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if themeStore.hasChosenOshi {
                    ContentView()
                        .transition(.opacity)
                } else {
                    OshiSetupView()
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: themeStore.hasChosenOshi)
            .environment(catalog)
            .environment(artwork)
            .environment(talentArtwork)
            .environment(prices)
            .environment(themeStore)
            .environment(appSettings)
            .preferredColorScheme(appSettings.appearance.colorScheme)
            .task {
                configureNewCardAlerts()
                talentArtwork.beginDownloading()
                await catalog.start()
                artwork.beginDownloading(catalog.cards)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background, appSettings.newCardAlerts {
                    NewCardNotifier.shared.scheduleBackgroundRefresh()
                }
                if phase == .active {
                    talentArtwork.beginDownloading()
                    Task {
                        await catalog.checkForUpdates()
                        artwork.beginDownloading(catalog.cards)
                    }
                }
            }
        }
        .modelContainer(modelContainer)
        .backgroundTask(.appRefresh(NewCardNotifier.refreshTaskID)) {
            await refreshCatalogInBackground()
        }
    }

    private func configureNewCardAlerts() {
        NewCardNotifier.shared.activate()
        catalog.onCardsAdded = { [themeStore, appSettings] cards in
            guard appSettings.newCardAlerts, themeStore.hasChosenOshi else { return }
            NewCardNotifier.shared.notify(about: cards, following: themeStore.followedOshi)
        }
    }

    private func refreshCatalogInBackground() async {
        configureNewCardAlerts()
        guard appSettings.newCardAlerts else { return }
        NewCardNotifier.shared.scheduleBackgroundRefresh()
        await catalog.load()
        await catalog.checkForUpdates()
    }
}
