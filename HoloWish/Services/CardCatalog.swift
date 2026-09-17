import Foundation
import Observation

@MainActor
@Observable
final class CardCatalog {
    private static let updateURL = URL(string: "https://raw.githubusercontent.com/jmanaois/holoWish/main/HoloWish/Resources/cards.json")!
    private static let checkInterval: TimeInterval = 24 * 60 * 60
    private static let lastCheckKey = "catalog.lastCheck"
    private static let eTagKey = "catalog.eTag"

    private(set) var cards: [Card] = []
    private(set) var cardsByID: [Int: Card] = [:]
    private(set) var searchIndex: [Int: String] = [:]
    private(set) var rarities: [String] = []
    private(set) var types: [String] = []
    private(set) var bloomLevels: [String] = []
    private(set) var colors: [String] = []
    private(set) var sets: [String] = []
    private(set) var setSummaries: [CardSetSummary] = []
    private(set) var syncedAt: String?
    private(set) var isLoading = false
    private(set) var isCheckingForUpdates = false
    private(set) var errorMessage: String?
    private(set) var updateMessage: String?

    func start() async {
        await load()
        await checkForUpdates()
    }

    func load() async {
        guard cards.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        guard let bundledURL = Bundle.main.url(forResource: "cards", withExtension: "json") else {
            errorMessage = "The bundled card catalog is missing."
            return
        }
        do {
            let bundledPayload = try await Self.readCatalog(from: bundledURL)
            if FileManager.default.fileExists(atPath: localCatalogURL.path),
               let localPayload = try? await Self.readCatalog(from: localCatalogURL),
               localPayload.syncedAt >= bundledPayload.syncedAt {
                await apply(localPayload)
            } else {
                await apply(bundledPayload)
                try? await Self.copyCatalog(from: bundledURL, to: localCatalogURL)
            }
        } catch {
            errorMessage = "Couldn’t load the card catalog: \(error.localizedDescription)"
        }
    }

    func checkForUpdates(force: Bool = false) async {
        guard !isCheckingForUpdates else { return }
        let defaults = UserDefaults.standard
        if !force,
           let lastCheck = defaults.object(forKey: Self.lastCheckKey) as? Date,
           Date().timeIntervalSince(lastCheck) < Self.checkInterval {
            return
        }

        isCheckingForUpdates = true
        if force { updateMessage = nil }
        defer { isCheckingForUpdates = false }

        do {
            var request = URLRequest(url: Self.updateURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 30)
            if let eTag = defaults.string(forKey: Self.eTagKey) { request.setValue(eTag, forHTTPHeaderField: "If-None-Match") }
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw CatalogUpdateError.invalidResponse }
            defaults.set(Date(), forKey: Self.lastCheckKey)

            if http.statusCode == 304 {
                if force { updateMessage = "The catalog is already up to date." }
                return
            }
            guard http.statusCode == 200 else { throw CatalogUpdateError.httpStatus(http.statusCode) }

            let payload = try await Self.decodeCatalog(data)
            guard payload.sourceLanguage == "ja", payload.count == payload.cards.count, !payload.cards.isEmpty else {
                throw CatalogUpdateError.invalidCatalog
            }

            guard payload.syncedAt > (syncedAt ?? "") || payload.count != cards.count else {
                if let eTag = http.value(forHTTPHeaderField: "ETag") { defaults.set(eTag, forKey: Self.eTagKey) }
                if force { updateMessage = "The catalog is already up to date." }
                return
            }

            let previousCount = cards.count
            try await Self.saveCatalog(data, to: localCatalogURL)
            await apply(payload)
            if let eTag = http.value(forHTTPHeaderField: "ETag") { defaults.set(eTag, forKey: Self.eTagKey) }
            let added = max(0, payload.cards.count - previousCount)
            updateMessage = added > 0 ? "Catalog updated with \(added) new cards." : "Catalog updated."
        } catch {
            defaults.set(Date(), forKey: Self.lastCheckKey)
            if force { updateMessage = "Couldn’t update the catalog. Your offline copy is still available." }
        }
    }

    func dismissUpdateMessage() {
        updateMessage = nil
    }

    private var localCatalogURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appending(path: "HoloWish", directoryHint: .isDirectory).appending(path: "cards.json")
    }

    private func apply(_ payload: CardCatalogPayload) async {
        let prepared = await Self.prepare(payload)
        cards = prepared.cards
        cardsByID = prepared.cardsByID
        searchIndex = prepared.searchIndex
        rarities = prepared.rarities
        types = prepared.types
        bloomLevels = prepared.bloomLevels
        colors = prepared.colors
        sets = prepared.sets
        setSummaries = prepared.setSummaries
        syncedAt = payload.syncedAt
        errorMessage = nil
    }

    nonisolated private static func prepare(_ payload: CardCatalogPayload) async -> PreparedCatalog {
        await Task.detached(priority: .userInitiated) {
            let loadedCards = payload.cards
            let sort: ([String]) -> [String] = {
                $0.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            }
            let values: (KeyPath<Card, String>) -> [String] = { keyPath in
                sort(Array(Set(loadedCards.map { $0[keyPath: keyPath] }.filter { !$0.isEmpty })))
            }
            var cardsBySet: [String: Set<Int>] = [:]
            let products = payload.products ?? []
            let productByName = Dictionary(uniqueKeysWithValues: products.map { ($0.name, $0) })
            let productOrderByName = Dictionary(uniqueKeysWithValues: products.enumerated().map { ($0.element.name, $0.offset) })
            for card in loadedCards {
                for setName in card.allSets {
                    cardsBySet[setName, default: []].insert(card.id)
                }
            }
            let setSummaries = cardsBySet.map { name, ids in
                let product = productByName[name]
                return CardSetSummary(
                    name: name,
                    englishName: product?.englishName?.isEmpty == false ? product?.englishName : nil,
                    cardIDs: ids.sorted(),
                    productCode: product?.code,
                    productImage: product?.image,
                    category: product?.category,
                    sortOrder: productOrderByName[name] ?? .max
                )
            }.sorted {
                if $0.group != $1.group { return $0.group.sortOrder < $1.group.sortOrder }
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
            }
            return PreparedCatalog(
                cards: loadedCards,
                cardsByID: Dictionary(uniqueKeysWithValues: loadedCards.map { ($0.id, $0) }),
                searchIndex: Dictionary(uniqueKeysWithValues: loadedCards.map { ($0.id, $0.searchableText) }),
                rarities: values(\.rarity),
                types: values(\.type),
                bloomLevels: values(\.bloomLevel),
                colors: sort(Array(Set(loadedCards.flatMap(\.allColors)))),
                sets: sort(Array(Set(loadedCards.flatMap(\.allSets)))),
                setSummaries: setSummaries
            )
        }.value
    }

    nonisolated private static func readCatalog(from url: URL) async throws -> CardCatalogPayload {
        let data = try await Task.detached(priority: .utility) { try Data(contentsOf: url) }.value
        return try await decodeCatalog(data)
    }

    nonisolated private static func decodeCatalog(_ data: Data) async throws -> CardCatalogPayload {
        try await Task.detached(priority: .utility) { try JSONDecoder().decode(CardCatalogPayload.self, from: data) }.value
    }

    nonisolated private static func saveCatalog(_ data: Data, to url: URL) async throws {
        try await Task.detached(priority: .utility) {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: url, options: .atomic)
        }.value
    }

    nonisolated private static func copyCatalog(from source: URL, to destination: URL) async throws {
        try await Task.detached(priority: .utility) {
            let data = try Data(contentsOf: source, options: .mappedIfSafe)
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: destination, options: .atomic)
        }.value
    }

}

private struct PreparedCatalog: Sendable {
    let cards: [Card]
    let cardsByID: [Int: Card]
    let searchIndex: [Int: String]
    let rarities: [String]
    let types: [String]
    let bloomLevels: [String]
    let colors: [String]
    let sets: [String]
    let setSummaries: [CardSetSummary]
}

struct CardSetSummary: Identifiable, Hashable, Sendable {
    let name: String
    let englishName: String?
    let cardIDs: [Int]
    let productCode: String?
    let productImage: URL?
    let category: String?
    let sortOrder: Int
    var id: String { name }
    var displayName: String {
        let original = englishName?.isEmpty == false ? englishName! : name
        let cleaned: String
        switch group {
        case .boosters:
            cleaned = original.replacingOccurrences(
                of: #"(?i)^\s*(?:extra\s+)?booster(?:\s+pack)?\s*[–—-]?\s*"#,
                with: "",
                options: .regularExpression
            )
        case .decks:
            cleaned = original
                .replacingOccurrences(
                    of: #"(?i)^\s*event\s+exclusive\s+(?:live\s+)?start\s+deck\s+set\s*[–—-]?\s*"#,
                    with: "Event Exclusive – ",
                    options: .regularExpression
                )
                .replacingOccurrences(
                    of: #"(?i)^\s*(?:live\s+)?start\s+deck(?:\s+set)?\s*[–—-]?\s*"#,
                    with: "",
                    options: .regularExpression
                )
        default:
            cleaned = original
        }
        let trimmed = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? original : trimmed
    }
    var group: CardSetGroup { CardSetGroup(category: category) }

    var searchableText: String {
        [name, englishName ?? ""].joined(separator: " ").localizedLowercase
    }
}

enum CardSetGroup: String, CaseIterable, Identifiable, Sendable {
    case boosters
    case decks
    case accessories
    case promos
    case other

    var id: String { rawValue }
    var sortOrder: Int { Self.allCases.firstIndex(of: self) ?? .max }

    var title: String {
        switch self {
        case .boosters: "Boosters"
        case .decks: "Start Decks"
        case .accessories: "Accessories & Collections"
        case .promos: "Promo Cards"
        case .other: "Other Sets"
        }
    }

    var systemImage: String {
        switch self {
        case .boosters: "shippingbox.fill"
        case .decks: "rectangle.stack.fill"
        case .accessories: "sparkles.rectangle.stack.fill"
        case .promos: "star.square.fill"
        case .other: "square.grid.2x2.fill"
        }
    }

    init(category: String?) {
        let value = category?.localizedLowercase ?? ""
        if value.contains("booster") { self = .boosters }
        else if value.contains("deck") { self = .decks }
        else if value.contains("accessory") { self = .accessories }
        else if value.contains("promo") || value.contains("prカード") { self = .promos }
        else { self = .other }
    }
}

private enum CatalogUpdateError: LocalizedError {
    case invalidResponse
    case httpStatus(Int)
    case invalidCatalog
}
