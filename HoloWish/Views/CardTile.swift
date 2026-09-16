import SwiftUI

struct CardTile: View {
    let card: Card
    @Environment(ThemeStore.self) private var themeStore
    @Environment(\.colorScheme) private var colorScheme

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
                    Text(card.rarity)
                        .font(.caption2.bold())
                        .foregroundStyle(colors.background)
                        .padding(.horizontal, 7).padding(.vertical, 4)
                        .background(colors.accent, in: Capsule())
                        .padding(8)
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

            Text(card.name)
                .font(.subheadline.bold())
                .foregroundStyle(colors.primaryText)
                .lineLimit(1)
            if let englishName = card.displayEnglishName, englishName != card.name {
                Text(englishName).font(.caption).foregroundStyle(colors.secondaryText).lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
