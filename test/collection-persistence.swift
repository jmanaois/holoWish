import Foundation
import SwiftData

// Run on macOS 14+ with Xcode's Swift compiler (see README).
@main
struct CollectionPersistenceChecks {
    @MainActor
    static func main() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let configuration = ModelConfiguration(url: directory.appendingPathComponent("test.store"), cloudKitDatabase: .none)
        try createStore(configuration)
        try reopenStore(configuration)
        print("Collection totals and local persistence checks passed.")
    }

    @MainActor
    static func createStore(_ configuration: ModelConfiguration) throws {
        let container = try ModelContainer(for: CardList.self, CardListItem.self, configurations: configuration)
        let context = ModelContext(container)
        let list = CardList(name: "Collection", builtInKind: .collection)
        context.insert(list)
        let paid = CardListItem(cardID: 1, quantity: 3)
        paid.purchasePriceText = "1250"
        let unknown = CardListItem(cardID: 2, quantity: 2)
        let free = CardListItem(cardID: 3)
        free.purchasePriceText = "0"
        list.items.append(contentsOf: [paid, unknown, free])
        precondition(list.totalPaidYen == 3750)
        precondition(list.unpricedQuantity == 2, "A free card is priced; an unknown price is not.")
        precondition(!CardList(name: "Wishlist", builtInKind: .wishlist).tracksPurchases)
        precondition(CardList(name: "Binder").tracksPurchases)
        try context.save()
    }

    @MainActor
    static func reopenStore(_ configuration: ModelConfiguration) throws {
        let container = try ModelContainer(for: CardList.self, CardListItem.self, configurations: configuration)
        let context = ModelContext(container)
        let list = try context.fetch(FetchDescriptor<CardList>()).first!
        precondition(list.items.count == 3)
        precondition(list.totalPaidYen == 3750)
        precondition(list.unpricedQuantity == 2)
        let paid = list.items.first { $0.cardID == 1 }!
        paid.quantity = 4
        precondition(list.totalPaidYen == 5000)
        paid.purchasePriceText = "1500"
        precondition(list.totalPaidYen == 6000)
        paid.purchasePriceText = nil
        precondition(list.totalPaidYen == 0 && list.unpricedQuantity == 6)
        context.delete(list)
        try context.save()
        let remainingItems = try context.fetchCount(FetchDescriptor<CardListItem>())
        precondition(remainingItems == 0)
    }
}
