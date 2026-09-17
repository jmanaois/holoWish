import SwiftData
import SwiftUI

enum CardGridLayout {
    static let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 180), spacing: 16, alignment: .top)
    ]
}

struct CardTile: View {
    let card: Card
    let isWishlisted: Bool
    let isCollected: Bool
    @Environment(ThemeStore.self) private var themeStore
    @Environment(AppSettings.self) private var appSettings
    @Environment(\.colorScheme) private var colorScheme

    init(card: Card, isWishlisted: Bool = false, isCollected: Bool = false) {
        self.card = card
        self.isWishlisted = isWishlisted
        self.isCollected = isCollected
    }

    var body: some View {
        let colors = themeStore.colors(for: colorScheme)
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topLeading) {
                CachedCardImage(card: card, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .aspectRatio(5 / 7, contentMode: .fit)
                .background(colors.surface)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.12), radius: 10, y: 5)

                if !card.rarity.isEmpty {
                    let rarityStyle = RarityBadgeStyle(rarity: card.rarity, fallback: colors.accent)
                    Text(card.rarity)
                        .font(.caption2.bold())
                        .foregroundStyle(rarityStyle.foreground)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(rarityStyle.background, in: Capsule())
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.45), lineWidth: 0.75)
                        }
                        .shadow(color: rarityStyle.background.opacity(0.35), radius: 3, y: 1)
                        .padding(8)
                }

                if isWishlisted || isCollected {
                    HStack(spacing: 5) {
                        if isWishlisted {
                            Image(systemName: "heart.fill")
                                .foregroundStyle(colors.accent)
                                .accessibilityLabel("In Wishlist")
                        }
                        if isCollected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(colors.secondaryAccent)
                                .accessibilityLabel("In Collection")
                        }
                    }
                    .font(.caption.bold())
                    .padding(7)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay { Capsule().stroke(.white.opacity(0.5), lineWidth: 0.75) }
                    .shadow(color: .black.opacity(0.18), radius: 4, y: 2)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .topTrailing)
                }
            }
            HStack {
                Text(card.number.uppercased())
                Spacer()
                if let hp = card.hp { Text("\(hp) HP") }
                else if let life = card.life { Text("\(life) LIFE") }
            }
            .font(.caption2.weight(.medium))
            .foregroundStyle(colors.secondaryText)
            .frame(height: 15)

            Text(card.primaryName(for: appSettings.cardNamePreference))
                .font(.subheadline.bold())
                .foregroundStyle(colors.primaryText)
                .lineLimit(1)
                .frame(height: 19, alignment: .leading)
            Text(englishSubtitle)
                .font(.caption)
                .foregroundStyle(colors.secondaryText)
                .lineLimit(1)
                .opacity(englishSubtitle.isEmpty ? 0 : 1)
                .frame(height: 16, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var englishSubtitle: String {
        card.secondaryName(for: appSettings.cardNamePreference) ?? ""
    }
}

struct RarityBadgeStyle {
    let background: Color
    let foreground: Color

    init(rarity: String, fallback: Color) {
        switch rarity.uppercased() {
        case "C":
            background = Color(red: 0.39, green: 0.45, blue: 0.55)
            foreground = .white
        case "U":
            background = Color(red: 0.05, green: 0.46, blue: 0.35)
            foreground = .white
        case "R":
            background = Color(red: 0.10, green: 0.37, blue: 0.78)
            foreground = .white
        case "RR":
            background = Color(red: 0.31, green: 0.27, blue: 0.90)
            foreground = .white
        case "SR":
            background = Color(red: 0.49, green: 0.23, blue: 0.93)
            foreground = .white
        case "UR":
            background = Color(red: 0.75, green: 0.15, blue: 0.83)
            foreground = .white
        case "SEC":
            background = Color(red: 0.96, green: 0.56, blue: 0.05)
            foreground = .black
        case "OUR":
            background = Color(red: 0.98, green: 0.78, blue: 0.08)
            foreground = .black
        case "OSR":
            background = Color(red: 0.88, green: 0.11, blue: 0.28)
            foreground = .white
        case "P":
            background = Color(red: 0.02, green: 0.57, blue: 0.70)
            foreground = .white
        case "S":
            background = Color(red: 0.05, green: 0.58, blue: 0.53)
            foreground = .white
        case "SY":
            background = Color(red: 0.92, green: 0.31, blue: 0.06)
            foreground = .white
        case "OC":
            background = Color(red: 0.16, green: 0.18, blue: 0.22)
            foreground = .white
        case "HR":
            background = Color(red: 0.86, green: 0.15, blue: 0.47)
            foreground = .white
        default:
            background = fallback
            foreground = .white
        }
    }
}

struct CardQuickActionsModifier: ViewModifier {
    let card: Card
    let wishlist: CardList?
    let collection: CardList?
    @Environment(\.modelContext) private var modelContext
    @Environment(AppSettings.self) private var appSettings
    @State private var purchaseList: CardList?

    func body(content: Content) -> some View {
        content.contextMenu {
            if let wishlist {
                let isIncluded = wishlist.contains(cardID: card.id)
                Button(role: isIncluded ? .destructive : nil) {
                    wishlist.toggleMembership(cardID: card.id, in: modelContext)
                } label: {
                    Label(
                        isIncluded ? "Remove from Wishlist" : "Add to Wishlist",
                        systemImage: isIncluded ? "heart.slash" : "heart"
                    )
                }
            }

            if let collection {
                let isIncluded = collection.contains(cardID: card.id)
                Button(role: isIncluded ? .destructive : nil) {
                    if !isIncluded && appSettings.quickAddBehavior == .askForDetails {
                        purchaseList = collection
                    } else {
                        collection.toggleMembership(cardID: card.id, in: modelContext)
                    }
                } label: {
                    Label(
                        isIncluded ? "Remove from Collection" : "Add to Collection",
                        systemImage: isIncluded ? "minus.circle" : "plus.circle"
                    )
                }
            }
        }
        .sheet(item: $purchaseList) { list in
            PurchaseEditorView(card: card, list: list)
        }
    }
}

extension View {
    func cardQuickActions(card: Card, wishlist: CardList?, collection: CardList?) -> some View {
        modifier(CardQuickActionsModifier(card: card, wishlist: wishlist, collection: collection))
    }
}
