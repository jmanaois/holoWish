import Foundation

struct CardCatalogPayload: Decodable, Sendable {
    let source: URL
    let sourceLanguage: String
    let syncedAt: String
    let count: Int
    let cards: [Card]
    let products: [CatalogProduct]?
}

struct CatalogProduct: Decodable, Hashable, Sendable {
    let code: String
    let name: String
    let englishName: String?
    let image: URL
    let category: String
}

struct Card: Decodable, Identifiable, Hashable, Sendable {
    let id: Int
    let number: String
    let name: String
    let englishName: String?
    let image: URL?
    let sourceUrl: URL
    let type: String
    let rarity: String
    let color: String
    let colors: [String]?
    let set: String
    let sets: [String]?
    let englishSets: [String]?
    let tags: [String]
    let bloomLevel: String
    let hp: Int?
    let life: Int?
    let parallel: Bool

    var allColors: [String] { colors?.isEmpty == false ? colors! : [color].filter { !$0.isEmpty } }
    var allSets: [String] { sets?.isEmpty == false ? sets! : [set].filter { !$0.isEmpty } }
    var allEnglishSets: [String] { englishSets ?? [] }
    var displayEnglishName: String? { englishName?.isEmpty == false ? englishName : nil }
    var searchableText: String {
        ([name, englishName ?? "", number] + tags + allSets + allEnglishSets)
            .joined(separator: " ").localizedLowercase
    }
}

struct CardFilters: Equatable {
    var rarity = ""
    var type = ""
    var color = ""
    var bloomLevel = ""
    var set = ""
    var parallelsOnly = false

    var isActive: Bool {
        !rarity.isEmpty || !type.isEmpty || !color.isEmpty || !bloomLevel.isEmpty || !set.isEmpty || parallelsOnly
    }

    mutating func clear() { self = CardFilters() }
}
