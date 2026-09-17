import Foundation
import SwiftData

enum BuiltInList: String, Codable {
    case wishlist
    case collection
}

@Model
final class CardList {
    var id: UUID
    var name: String
    var createdAt: Date
    var builtInKindRaw: String?

    @Relationship(deleteRule: .cascade, inverse: \CardListItem.list)
    var items: [CardListItem]

    init(name: String, builtInKind: BuiltInList? = nil) {
        id = UUID()
        self.name = name
        createdAt = .now
        builtInKindRaw = builtInKind?.rawValue
        items = []
    }

    var builtInKind: BuiltInList? { builtInKindRaw.flatMap(BuiltInList.init(rawValue:)) }

    var tracksPurchases: Bool { builtInKind != .wishlist }

    var totalPaidYen: Decimal {
        items.reduce(Decimal.zero) { $0 + ($1.purchasePrice ?? 0) * Decimal($1.quantity) }
    }

    var unpricedQuantity: Int {
        items.filter { $0.purchasePrice == nil }.reduce(0) { $0 + $1.quantity }
    }
}

@Model
final class CardListItem {
    var id: UUID
    var cardID: Int
    var quantity: Int
    var addedAt: Date
    var list: CardList?
    // Optional storage allows existing local collections to migrate without a price.
    // A decimal string preserves exact yen amounts without floating-point rounding.
    var purchasePriceText: String?

    var purchasePrice: Decimal? {
        purchasePriceText.flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }
    }

    init(cardID: Int, quantity: Int = 1, list: CardList? = nil) {
        id = UUID()
        self.cardID = cardID
        self.quantity = max(1, quantity)
        addedAt = .now
        self.list = list
    }
}
