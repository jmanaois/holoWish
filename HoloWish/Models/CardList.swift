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
}

@Model
final class CardListItem {
    var id: UUID
    var cardID: Int
    var quantity: Int
    var addedAt: Date
    var list: CardList?

    init(cardID: Int, quantity: Int = 1, list: CardList? = nil) {
        id = UUID()
        self.cardID = cardID
        self.quantity = max(1, quantity)
        addedAt = .now
        self.list = list
    }
}
