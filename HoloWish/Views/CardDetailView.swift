import SwiftData
import SwiftUI

struct CardDetailView: View {
    let card: Card
    @Environment(\.modelContext) private var modelContext
    @Environment(ThemeStore.self) private var themeStore
    @Environment(CardPriceStore.self) private var prices
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CardList.createdAt) private var lists: [CardList]

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

                    VStack(alignment: .leading, spacing: 0) {
                        Text("MY LISTS").font(.caption.bold()).foregroundStyle(.secondary).padding(.bottom, 8)
                        ForEach(lists) { list in listControl(list) }
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

    @ViewBuilder
    private func listControl(_ list: CardList) -> some View {
        let colors = themeStore.colors(for: colorScheme)
        let item = list.items.first { $0.cardID == card.id }
        HStack {
            Button { toggle(cardIn: list, item: item) } label: {
                Label(list.name, systemImage: item == nil ? "circle" : "checkmark.circle.fill")
                    .foregroundStyle(item == nil ? colors.primaryText : colors.accent)
            }
            Spacer()
            if list.builtInKind == .collection, let item {
                Button { item.quantity = max(1, item.quantity - 1) } label: { Image(systemName: "minus.circle") }
                Text("\(item.quantity)").monospacedDigit().frame(minWidth: 22)
                Button { item.quantity += 1 } label: { Image(systemName: "plus.circle") }
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 11)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func toggle(cardIn list: CardList, item: CardListItem?) {
        if let item { modelContext.delete(item) }
        else { list.items.append(CardListItem(cardID: card.id)) }
    }
}
