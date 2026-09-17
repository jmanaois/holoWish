import SwiftData
import SwiftUI

struct CardDetailView: View {
    let card: Card
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeStore.self) private var themeStore
    @Environment(CardPriceStore.self) private var prices
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CardList.createdAt) private var lists: [CardList]
    @State private var purchaseList: CardList?

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        ScrollView {
            VStack(spacing: 24) {
                CachedCardImage(card: card)
                .frame(maxHeight: 480)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .shadow(color: .black.opacity(0.18), radius: 18, y: 8)
                .padding(.horizontal, 30)

                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(card.type).font(.caption.bold()).foregroundStyle(colors.accent).textCase(.uppercase)
                        Text(card.name).font(.title.bold()).foregroundStyle(colors.primaryText)
                        if let englishName = card.displayEnglishName, englishName != card.name {
                            Text(englishName).font(.title3.weight(.semibold)).foregroundStyle(colors.secondaryText)
                        }
                        Text("\(card.number) · \(card.rarity)").font(.subheadline).foregroundStyle(colors.secondaryText)
                    }

                    if !detailTags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack { ForEach(detailTags, id: \.self) { Text($0).font(.caption).padding(.horizontal, 9).padding(.vertical, 6).background(.quaternary, in: Capsule()) } }
                        }
                    }

                    Divider()
                    priceSection

                    Divider()
                    if !card.allSets.isEmpty {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("収録商品").font(.caption.bold()).foregroundStyle(.secondary)
                            ForEach(card.allSets, id: \.self) { Text($0).font(.subheadline) }
                            ForEach(card.allEnglishSets, id: \.self) { Text($0).font(.caption).foregroundStyle(.secondary) }
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("MY LISTS").font(.caption.bold()).foregroundStyle(colors.secondaryText)
                        HStack(spacing: 12) {
                            if let wishlist = lists.first(where: { $0.builtInKind == .wishlist }) {
                                builtInListButton(wishlist, color: colors.accent)
                            }
                            if let collection = lists.first(where: { $0.builtInKind == .collection }) {
                                builtInListButton(collection, color: colors.secondaryAccent)
                            }
                        }

                        if let collection = lists.first(where: { $0.builtInKind == .collection }),
                           let item = collection.items.first(where: { $0.cardID == card.id }) {
                            collectionControls(item: item, list: collection)
                        }

                        let customLists = lists.filter { $0.builtInKind == nil }
                        if !customLists.isEmpty {
                            Text("CUSTOM LISTS")
                                .font(.caption.bold())
                                .foregroundStyle(colors.secondaryText)
                                .padding(.top, 4)
                            ForEach(customLists) { list in listControl(list) }
                        }
                    }

                    Link(destination: card.sourceUrl) {
                        Label("View on official Japanese card list", systemImage: "arrow.up.right.square")
                            .font(.subheadline.weight(.semibold))
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .background(colors.background)
        .tint(colors.accent)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $purchaseList) { list in
            PurchaseEditorView(card: card, list: list)
        }
    }

    private var detailTags: [String] {
        card.allColors + [card.bloomLevel].filter { !$0.isEmpty } + card.tags
    }

    @ViewBuilder
    private var priceSection: some View {
        let colors = themeStore.colors(for: colorScheme)
        let result = prices.result(for: card)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("YUYUTEI PRICE LOOKUP").font(.caption.bold()).foregroundStyle(colors.secondaryText)
                    Text("Japanese shop listings in JPY").font(.caption2).foregroundStyle(colors.secondaryText)
                }
                Spacer()
                if result != nil {
                    Button("Refresh") { Task { await prices.lookup(card, force: true) } }
                        .font(.caption.bold())
                        .disabled(prices.isLoading(card))
                }
            }

            if prices.isLoading(card) {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Checking current listings…").font(.subheadline).foregroundStyle(colors.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            } else if let result {
                if result.quotes.isEmpty {
                    Text("No Yuyutei listing was found for \(card.number).")
                        .font(.subheadline).foregroundStyle(colors.secondaryText)
                } else {
                    ForEach(result.quotes) { quote in priceRow(quote) }
                }
                Text("Updated \(result.fetchedAt.formatted(date: .abbreviated, time: .shortened)) · Cached for 12 hours")
                    .font(.caption2).foregroundStyle(colors.secondaryText)
            } else if let error = prices.error(for: card) {
                Text(error).font(.subheadline).foregroundStyle(colors.secondaryText)
                Button("Try again") { Task { await prices.lookup(card, force: true) } }
                    .font(.subheadline.bold())
            } else {
                Button { Task { await prices.lookup(card) } } label: {
                    Label("Look up current price", systemImage: "yensign.circle.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 12) {
                Link(destination: prices.searchURL(for: card)) {
                    Label("Open Yuyutei search", systemImage: "arrow.up.right.square")
                }
                Spacer()
                Text("Shop price, not market value")
            }
            .font(.caption)
            .foregroundStyle(colors.secondaryText)
        }
    }

    private func priceRow(_ quote: YuyuteiPriceQuote) -> some View {
        let colors = themeStore.colors(for: colorScheme)
        let isCurrentRarity = quote.rarity.caseInsensitiveCompare(card.rarity) == .orderedSame
        return VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text(quote.rarity)
                    .font(.caption.bold())
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .foregroundStyle(isCurrentRarity ? colors.background : colors.primaryText)
                    .background(isCurrentRarity ? colors.accent : colors.background, in: Capsule())
                if isCurrentRarity { Text("This printing").font(.caption2.bold()).foregroundStyle(colors.accent) }
                Spacer()
                Text(quote.priceYen, format: .currency(code: "JPY").precision(.fractionLength(0)))
                    .font(.headline.monospacedDigit()).foregroundStyle(colors.primaryText)
            }
            Text(quote.title).font(.subheadline).foregroundStyle(colors.primaryText).lineLimit(2)
            HStack {
                Label(quote.inStock ? "In stock" : "Out of stock", systemImage: quote.inStock ? "checkmark.circle.fill" : "xmark.circle")
                    .foregroundStyle(quote.inStock ? colors.secondaryAccent : colors.secondaryText)
                Spacer()
                Link("View listing", destination: quote.url).fontWeight(.semibold)
            }
            .font(.caption)
        }
        .padding(12)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func builtInListButton(_ list: CardList, color: Color) -> some View {
        let colors = themeStore.colors(for: colorScheme)
        let item = list.items.first { $0.cardID == card.id }
        let isAdded = item != nil
        let title = switch list.builtInKind {
        case .wishlist: isAdded ? "In Wishlist" : "Add to Wishlist"
        case .collection: isAdded ? "In Collection" : "Add to Collection"
        case nil: list.name
        }

        return Button { toggle(cardIn: list, item: item) } label: {
            Label(title, systemImage: isAdded ? "checkmark" : "plus")
                .font(.subheadline.bold())
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 48)
                .padding(.horizontal, 8)
                .foregroundStyle(isAdded ? colors.background : color)
                .background(isAdded ? color : colors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(color.opacity(isAdded ? 0 : 0.5), lineWidth: 1)
                }
        }
        .buttonStyle(.plain)
        .accessibilityHint(isAdded ? "Removes this card from \(list.name)" : "Adds this card to \(list.name)")
    }

    private func collectionControls(item: CardListItem, list: CardList) -> some View {
        let colors = themeStore.colors(for: colorScheme)
        return HStack(spacing: 10) {
            Button { changeQuantity(of: item, in: list, by: -1) } label: {
                Image(systemName: "minus.circle.fill")
            }
            .accessibilityLabel("Decrease quantity")
            Text(item.quantity.formatted())
                .font(.subheadline.bold().monospacedDigit())
                .frame(minWidth: 24)
            Button { changeQuantity(of: item, in: list, by: 1) } label: {
                Image(systemName: "plus.circle.fill")
            }
            .accessibilityLabel("Increase quantity")

            Spacer()

            Button { purchaseList = list } label: {
                if let price = item.purchasePrice {
                    Label(price.formatted(.currency(code: "JPY")), systemImage: "pencil")
                } else {
                    Label("Add price", systemImage: "pencil")
                }
            }
            .font(.caption.bold())
        }
        .foregroundStyle(colors.accent)
        .padding(12)
        .background(colors.surface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func listControl(_ list: CardList) -> some View {
        let colors = themeStore.colors(for: colorScheme)
        let item = list.items.first { $0.cardID == card.id }
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Button { toggle(cardIn: list, item: item) } label: {
                    Label(list.name, systemImage: item == nil ? "circle" : "checkmark.circle.fill")
                        .foregroundStyle(item == nil ? colors.primaryText : colors.accent)
                }
                Spacer()
                if list.tracksPurchases, let item {
                    Button { changeQuantity(of: item, in: list, by: -1) } label: { Image(systemName: "minus.circle") }
                        .accessibilityLabel("Decrease quantity")
                    Text("\(item.quantity)").monospacedDigit().frame(minWidth: 22)
                    Button { changeQuantity(of: item, in: list, by: 1) } label: { Image(systemName: "plus.circle") }
                        .accessibilityLabel("Increase quantity")
                }
            }
            if list.tracksPurchases, let item {
                Button { purchaseList = list } label: {
                    if let price = item.purchasePrice {
                        Text("Paid \(price.formatted(.currency(code: "JPY"))) per copy · Edit")
                    } else {
                        Label("Add purchase price", systemImage: "pencil")
                    }
                }
                .font(.caption).foregroundStyle(colors.accent)
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func toggle(cardIn list: CardList, item: CardListItem?) {
        if let item {
            let removedValue = (item.purchasePrice ?? 0) * Decimal(item.quantity)
            let newValue = max(Decimal.zero, list.totalPaidYen - removedValue)
            list.items.removeAll { $0.id == item.id }
            modelContext.delete(item)
            list.recordValue(newValue, in: modelContext)
            try? modelContext.save()
        }
        else if list.tracksPurchases { purchaseList = list }
        else { list.items.append(CardListItem(cardID: card.id)) }
    }

    private func changeQuantity(of item: CardListItem, in list: CardList, by change: Int) {
        let newQuantity = max(1, item.quantity + change)
        guard newQuantity != item.quantity else { return }
        item.quantity = newQuantity
        list.recordValue(in: modelContext)
        try? modelContext.save()
    }
}

struct PurchaseEditorView: View {
    let card: Card
    let list: CardList
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var amount = ""
    @State private var quantity = 1
    @State private var saveError: String?

    private var item: CardListItem? { list.items.first { $0.cardID == card.id } }
    private var trimmedAmount: String { amount.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var parsedAmount: Decimal? {
        guard trimmedAmount.range(of: #"^[0-9]+$"#, options: .regularExpression) != nil,
              let value = Decimal(string: trimmedAmount, locale: Locale(identifier: "en_US_POSIX")),
              value <= 999_999_999 else { return nil }
        return value
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(card.name).font(.headline)
                    Text("\(card.number) · \(card.rarity)").foregroundStyle(.secondary)
                    Stepper("Quantity: \(quantity)", value: $quantity, in: 1...999_999)
                }
                Section {
                    TextField("Price per copy in JPY (optional)", text: $amount)
                        .keyboardType(.numberPad)
                    if !trimmedAmount.isEmpty && parsedAmount == nil {
                        Text("Enter a whole-yen price from 0 to 999,999,999, without commas.")
                            .font(.caption).foregroundStyle(.red)
                    }
                } footer: {
                    Text("For copies bought at different prices, enter the average price per copy. Leave blank if unknown. Your purchase details are saved on this device.")
                }
                if let saveError { Text(saveError).foregroundStyle(.red) }
            }
            .navigationTitle(item == nil ? "Add to \(list.name)" : "Edit purchase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(!trimmedAmount.isEmpty && parsedAmount == nil)
                }
            }
            .onAppear {
                if let item {
                    quantity = item.quantity
                    amount = item.purchasePriceText ?? ""
                }
            }
        }
    }

    private func save() {
        let existing = item
        let target = existing ?? CardListItem(cardID: card.id)
        let oldQuantity = target.quantity
        let oldPrice = target.purchasePriceText
        if existing == nil { list.items.append(target) }
        target.quantity = quantity
        target.purchasePriceText = parsedAmount.map { NSDecimalNumber(decimal: $0).stringValue }
        let snapshot = list.recordValue(in: modelContext)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            if let snapshot { modelContext.delete(snapshot) }
            if existing == nil {
                list.items.removeAll { $0.id == target.id }
                modelContext.delete(target)
            } else {
                target.quantity = oldQuantity
                target.purchasePriceText = oldPrice
            }
            saveError = "Could not save your purchase. Please try again."
        }
    }
}
