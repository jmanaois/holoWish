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

@Model
final class CollectionValueSnapshot {
    var id: UUID
    var listID: UUID
    var recordedAt: Date
    var totalValueText: String

    var totalValue: Decimal {
        Decimal(string: totalValueText, locale: Locale(identifier: "en_US_POSIX")) ?? 0
    }

    var chartValue: Double {
        NSDecimalNumber(decimal: totalValue).doubleValue
    }

    init(listID: UUID, totalValue: Decimal, recordedAt: Date = .now) {
        id = UUID()
        self.listID = listID
        self.recordedAt = recordedAt
        totalValueText = NSDecimalNumber(decimal: totalValue).stringValue
    }
}

extension CardList {
    func contains(cardID: Int) -> Bool {
        items.contains { $0.cardID == cardID }
    }

    @discardableResult
    func toggleMembership(cardID: Int, in context: ModelContext) -> Bool {
        if let item = items.first(where: { $0.cardID == cardID }) {
            let removedValue = (item.purchasePrice ?? 0) * Decimal(item.quantity)
            let newValue = max(Decimal.zero, totalPaidYen - removedValue)
            items.removeAll { $0.id == item.id }
            context.delete(item)
            recordValue(newValue, in: context)
            try? context.save()
            return false
        }

        items.append(CardListItem(cardID: cardID))
        recordValue(in: context)
        try? context.save()
        return true
    }

    @discardableResult
    func recordValue(_ value: Decimal? = nil, at date: Date = .now, in context: ModelContext) -> CollectionValueSnapshot? {
        guard tracksPurchases else { return nil }
        let snapshot = CollectionValueSnapshot(listID: id, totalValue: value ?? totalPaidYen, recordedAt: date)
        context.insert(snapshot)
        return snapshot
    }
}
